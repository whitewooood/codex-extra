import AppKit
import CodexSoundGuardCore
import Foundation
import OSLog

@MainActor
final class SessionMonitor: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var filesWatched = 0
    @Published private(set) var lastStatus = "Idle"
    @Published private(set) var lastOutcome: TurnOutcome?

    private let soundPlayer = SoundPlayer()
    private let logger = Logger(subsystem: "com.whitewood.codex-sound-guard", category: "monitor")
    private var timer: Timer?
    private var offsets: [String: UInt64] = [:]
    private var partialLines: [String: String] = [:]
    private var turns: [String: TurnAccumulator] = [:]
    private var primed = false
    private let startedAt = Date()

    init() {
        applySettings()
    }

    var menuIconName: String {
        guard isRunning else {
            return "bell.slash"
        }

        switch lastOutcome {
        case .failed:
            return "bell.badge"
        case .completed:
            return "bell.and.waves.left.and.right"
        case nil:
            return "bell"
        }
    }

    func applySettings() {
        if UserDefaults.standard.bool(forKey: AppDefaults.Key.monitoringEnabled) {
            start()
        } else {
            stop()
        }
    }

    func start() {
        guard !isRunning else {
            return
        }

        isRunning = true
        lastStatus = "Monitoring"
        scan()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scan()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        lastStatus = "Paused"
    }

    func testCompletionSound() {
        play(outcome: .completed)
    }

    func testFailureSound() {
        play(outcome: .failed)
    }

    private func scan() {
        let urls = sessionFiles()
        filesWatched = urls.count

        let activePaths = Set(urls.map(\.path))
        for path in offsets.keys where !activePaths.contains(path) && turns[path] == nil {
            offsets.removeValue(forKey: path)
            partialLines.removeValue(forKey: path)
        }

        for url in urls {
            scanFile(url)
        }

        primed = true
    }

    private func sessionFiles() -> [URL] {
        let root = URL(fileURLWithPath: UserDefaults.standard.string(forKey: AppDefaults.Key.sessionsRootPath) ?? AppDefaults.sessionsRootPath)
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        let files = enumerator.compactMap { item -> (url: URL, date: Date) in
            guard let url = item as? URL, url.pathExtension == "jsonl" else {
                return (URL(fileURLWithPath: ""), .distantPast)
            }

            let values = try? url.resourceValues(forKeys: Set(keys))
            return (url, values?.contentModificationDate ?? .distantPast)
        }

        return files
            .filter { !$0.url.path.isEmpty }
            .sorted { $0.date > $1.date }
            .prefix(60)
            .map(\.url)
    }

    private func scanFile(_ url: URL) {
        let path = url.path

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let sizeNumber = attributes[.size] as? NSNumber else {
            return
        }

        let size = sizeNumber.uint64Value
        let modifiedAt = attributes[.modificationDate] as? Date ?? .distantPast

        if offsets[path] == nil {
            if !primed || modifiedAt < startedAt.addingTimeInterval(-5) {
                offsets[path] = size
                return
            }
            offsets[path] = 0
        }

        var offset = offsets[path] ?? 0
        if size < offset {
            offset = 0
        }

        guard size > offset else {
            return
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return
        }

        do {
            try handle.seek(toOffset: offset)
            let data = try handle.readToEnd() ?? Data()
            try? handle.close()
            offsets[path] = size
            process(data: data, path: path)
        } catch {
            try? handle.close()
        }
    }

    private func process(data: Data, path: String) {
        guard !data.isEmpty else {
            return
        }

        var text = String(decoding: data, as: UTF8.self)
        if let pending = partialLines[path] {
            text = pending + text
            partialLines[path] = nil
        }

        let endedWithNewline = text.hasSuffix("\n")
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if !endedWithNewline, let pending = lines.popLast() {
            partialLines[path] = pending
        }

        for line in lines {
            guard let event = SessionLogParser.parseLine(line) else {
                continue
            }
            process(event: event, path: path)
        }
    }

    private func process(event: SessionEvent, path: String) {
        switch event.kind {
        case .taskStarted:
            turns[path] = TurnAccumulator(startedAt: event.timestamp)
        case .assistantMessage(let message):
            var turn = turns[path] ?? TurnAccumulator()
            turn.latestAssistantMessage = message
            turns[path] = turn
        case .failureSignal:
            var turn = turns[path] ?? TurnAccumulator()
            turn.hasFailureSignal = true
            turns[path] = turn
        case .commandExit(let code):
            guard code != 0 else {
                return
            }
            var turn = turns[path] ?? TurnAccumulator()
            turn.hasCommandFailure = true
            turns[path] = turn
        case .taskComplete:
            let turn = turns[path] ?? TurnAccumulator()
            let includeCommands = UserDefaults.standard.bool(forKey: AppDefaults.Key.commandFailureHeuristicEnabled)
            let classification = TurnClassifier.classify(turn, includeCommandFailures: includeCommands)
            turns[path] = nil
            logger.info("Turn classified as \(classification.outcome.rawValue, privacy: .public): \(classification.reason, privacy: .public)")
            play(outcome: classification.outcome)
            lastOutcome = classification.outcome
            lastStatus = "\(classification.outcome.title) at \(Self.timeFormatter.string(from: Date()))"
        case .ignored:
            break
        }
    }

    private func play(outcome: TurnOutcome) {
        let defaults = UserDefaults.standard
        let volume = defaults.double(forKey: AppDefaults.Key.volume)

        switch outcome {
        case .completed:
            guard defaults.bool(forKey: AppDefaults.Key.completionSoundEnabled) else {
                return
            }
            let path = defaults.string(forKey: AppDefaults.Key.completionSoundPath) ?? AppDefaults.defaultCompletionSoundPath
            soundPlayer.play(path: path, volume: volume)
        case .failed:
            guard defaults.bool(forKey: AppDefaults.Key.failureSoundEnabled) else {
                return
            }
            let path = defaults.string(forKey: AppDefaults.Key.failureSoundPath) ?? AppDefaults.defaultFailureSoundPath
            soundPlayer.play(path: path, volume: volume)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

private extension TurnOutcome {
    var title: String {
        switch self {
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
}
