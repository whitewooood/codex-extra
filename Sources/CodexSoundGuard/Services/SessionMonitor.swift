import AppKit
import CodexSoundGuardCore
import Foundation
import OSLog

@MainActor
final class SessionMonitor: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var filesWatched = 0
    @Published private(set) var lastStatus = "等待任务结束"
    @Published private(set) var lastOutcome: TurnOutcome?

    private let soundPlayer = SoundPlayer()
    private let logger = Logger(subsystem: "com.whitewood.codex-sound-guard", category: "monitor")
    private var timer: Timer?
    private var offsets: [String: UInt64] = [:]
    private var partialLines: [String: String] = [:]
    private var turns: [String: TurnAccumulator] = [:]
    private var primed = false
    private let startedAt = Date()
    private let scanInterval: TimeInterval = 1.5
    private let recentDayLookback = 7
    private let maxRecentFiles = 120

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
        lastStatus = "正在监听 Codex 会话"
        scan()
        timer = Timer.scheduledTimer(withTimeInterval: scanInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scan()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        lastStatus = "监听已暂停"
        resetScanState()
    }

    func testCompletionSound() {
        play(outcome: .completed, force: true)
    }

    func testFailureSound() {
        play(outcome: .failed, force: true)
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
        let roots = recentSessionRoots(under: root)
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]

        var activeCandidates: [SessionFileCandidate] = []
        var recentCandidates: [SessionFileCandidate] = []
        for root in roots {
            recentCandidates.append(contentsOf: sessionFileCandidates(in: root, keys: keys))
        }

        for path in offsets.keys {
            guard FileManager.default.fileExists(atPath: path) else {
                continue
            }
            let url = URL(fileURLWithPath: path)
            let values = try? url.resourceValues(forKeys: Set(keys))
            activeCandidates.append(SessionFileCandidate(url: url, modifiedAt: values?.contentModificationDate ?? .distantPast))
        }

        var seen = Set<String>()
        let recentURLs = Array(recentCandidates
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(maxRecentFiles))
        return (activeCandidates + recentURLs)
            .filter { candidate in
                seen.insert(candidate.url.path).inserted
            }
            .map(\.url)
    }

    private func recentSessionRoots(under root: URL) -> [URL] {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        var roots: [URL] = []

        for dayOffset in 0..<recentDayLookback {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else {
                continue
            }

            let components = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = components.year, let month = components.month, let day = components.day else {
                continue
            }

            let dateRoot = root
                .appendingPathComponent(String(format: "%04d", year))
                .appendingPathComponent(String(format: "%02d", month))
                .appendingPathComponent(String(format: "%02d", day))

            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: dateRoot.path, isDirectory: &isDirectory), isDirectory.boolValue {
                roots.append(dateRoot)
            }
        }

        return roots.isEmpty ? [root] : roots
    }

    private func sessionFileCandidates(in root: URL, keys: [URLResourceKey]) -> [SessionFileCandidate] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        return enumerator.compactMap { item -> SessionFileCandidate? in
            guard let url = item as? URL, url.pathExtension == "jsonl" else {
                return nil
            }

            let values = try? url.resourceValues(forKeys: Set(keys))
            return SessionFileCandidate(url: url, modifiedAt: values?.contentModificationDate ?? .distantPast)
        }
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
            lastStatus = "\(classification.outcome.title) \(Self.timeFormatter.string(from: Date()))"
        case .ignored:
            break
        }
    }

    private func play(outcome: TurnOutcome, force: Bool = false) {
        let defaults = UserDefaults.standard
        let volume = defaults.double(forKey: AppDefaults.Key.volume)

        switch outcome {
        case .completed:
            guard force || defaults.bool(forKey: AppDefaults.Key.completionSoundEnabled) else {
                return
            }
            let path = defaults.string(forKey: AppDefaults.Key.completionSoundPath) ?? AppDefaults.defaultCompletionSoundPath
            soundPlayer.play(path: path, volume: volume)
        case .failed:
            guard force || defaults.bool(forKey: AppDefaults.Key.failureSoundEnabled) else {
                return
            }
            let path = defaults.string(forKey: AppDefaults.Key.failureSoundPath) ?? AppDefaults.defaultFailureSoundPath
            soundPlayer.play(path: path, volume: volume)
        }
    }

    private func resetScanState() {
        offsets.removeAll()
        partialLines.removeAll()
        turns.removeAll()
        primed = false
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

private struct SessionFileCandidate {
    let url: URL
    let modifiedAt: Date
}

private extension TurnOutcome {
    var title: String {
        switch self {
        case .completed:
            return "上次完成"
        case .failed:
            return "上次失败"
        }
    }
}
