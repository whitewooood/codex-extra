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
    @Published private(set) var lastEventStatus = "尚未识别到 Codex 事件"
    @Published private(set) var recognizedEventCount = 0
    @Published private(set) var latestUsage: TokenUsageSnapshot?
    @Published private(set) var usageTrend: [UsageTrendPoint] = []
    @Published private(set) var sessionUsageRankings: [SessionUsageSummary] = []

    private let soundPlayer = SoundPlayer()
    private let logger = Logger(subsystem: "com.whitewood.codex-monitor", category: "monitor")
    private var timer: Timer?
    private var offsets: [String: UInt64] = [:]
    private var partialLines: [String: String] = [:]
    private var turns: [String: TurnAccumulator] = [:]
    private var currentTurnIDByPath: [String: String] = [:]
    private var latestUserMessageByPath: [String: String] = [:]
    private var cachedDiscoveredFiles: [SessionFileCandidate] = []
    private var lastFullDiscoveryAt: Date?
    private var usageSamples: [UsageSample] = []
    private var sessionUsageByPath: [String: SessionUsageSummary] = [:]
    private var primed = false
    private let startedAt = Date()
    private let scanInterval: TimeInterval = 1.5
    private let recentDayLookback = 7
    private let maxRecentFiles = 120
    private let fullDiscoveryInterval: TimeInterval = 30
    private let maxDiscoveredFiles = 240
    private let bootstrapLookback: TimeInterval = 24 * 60 * 60
    private let bootstrapByteLimit: UInt64 = 1_048_576
    private let trendLookback: TimeInterval = 6 * 60 * 60
    private let maxUsageSamples = 500
    private let maxSessionRankings = 5

    init(startsMonitoring: Bool = true) {
        if startsMonitoring {
            applySettings()
        }
    }

    static func documentationPreview() -> SessionMonitor {
        let monitor = SessionMonitor(startsMonitoring: false)
        let now = Date()
        monitor.isRunning = true
        monitor.filesWatched = 18
        monitor.lastStatus = "最近完成 22:40:18"
        monitor.lastOutcome = .completed
        monitor.lastEventStatus = "识别到 task_complete · turn 7f2c"
        monitor.recognizedEventCount = 126
        monitor.latestUsage = TokenUsageSnapshot(
            total: TokenUsage(
                inputTokens: 182_430,
                cachedInputTokens: 96_120,
                outputTokens: 24_880,
                reasoningOutputTokens: 8_460,
                totalTokens: 207_310
            ),
            last: TokenUsage(
                inputTokens: 18_420,
                cachedInputTokens: 11_020,
                outputTokens: 2_940,
                reasoningOutputTokens: 1_120,
                totalTokens: 21_360
            ),
            modelContextWindow: 272_000,
            primaryRateLimit: UsageRateLimit(
                usedPercent: 42,
                windowMinutes: 300,
                resetsAt: now.addingTimeInterval(92 * 60)
            ),
            secondaryRateLimit: UsageRateLimit(
                usedPercent: 68,
                windowMinutes: 7 * 24 * 60,
                resetsAt: now.addingTimeInterval(46 * 60 * 60)
            )
        )
        monitor.usageTrend = Self.previewTrend()
        monitor.sessionUsageRankings = [
            SessionUsageSummary(path: "/Users/demo/.codex/sessions/app-redesign.jsonl", title: "重新设计 UI，现在有点花哨，不够高级", fileName: "app-redesign", totalTokens: 207_310, lastTokens: 21_360, updatedAt: now),
            SessionUsageSummary(path: "/Users/demo/.codex/sessions/readme-polish.jsonl", title: "README 双语并调整为开源项目说明", fileName: "readme-polish", totalTokens: 128_400, lastTokens: 8_920, updatedAt: now.addingTimeInterval(-28 * 60)),
            SessionUsageSummary(path: "/Users/demo/.codex/sessions/release-fix.jsonl", title: "修复发布资产里的 DMG 和截图问题", fileName: "release-fix", totalTokens: 76_820, lastTokens: 12_110, updatedAt: now.addingTimeInterval(-73 * 60))
        ]
        return monitor
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
            MainActor.assumeIsolated {
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
        for path in offsets.keys where !activePaths.contains(path) && !hasActiveTurn(forPath: path) {
            offsets.removeValue(forKey: path)
            partialLines.removeValue(forKey: path)
            currentTurnIDByPath.removeValue(forKey: path)
            latestUserMessageByPath.removeValue(forKey: path)
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

        if shouldRefreshFullDiscovery() {
            cachedDiscoveredFiles = Array(sessionFileCandidates(in: root, keys: keys)
                .sorted { $0.modifiedAt > $1.modifiedAt }
                .prefix(maxDiscoveredFiles))
            lastFullDiscoveryAt = Date()
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
        return (activeCandidates + recentURLs + cachedDiscoveredFiles)
            .filter { candidate in
                seen.insert(candidate.url.path).inserted
            }
            .map(\.url)
    }

    private func shouldRefreshFullDiscovery() -> Bool {
        guard let lastFullDiscoveryAt else {
            return true
        }
        return Date().timeIntervalSince(lastFullDiscoveryAt) >= fullDiscoveryInterval
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
            if shouldBootstrapContext(modifiedAt: modifiedAt) {
                bootstrapContext(from: url, path: path, size: size)
            }

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
        markRecognized(event)

        switch event.kind {
        case .taskStarted:
            let turnID = event.turnID ?? UUID().uuidString
            currentTurnIDByPath[path] = turnID
            turns[turnKey(path: path, turnID: turnID)] = TurnAccumulator(startedAt: event.timestamp)
        case .userMessage(let message):
            latestUserMessageByPath[path] = message
        case .assistantMessage(let message):
            let key = eventTurnKey(path: path, event: event)
            var turn = turns[key] ?? TurnAccumulator()
            turn.latestAssistantMessage = message
            turns[key] = turn
        case .failureSignal:
            let key = eventTurnKey(path: path, event: event)
            var turn = turns[key] ?? TurnAccumulator()
            turn.hasFailureSignal = true
            turns[key] = turn
        case .commandExit(let code):
            guard code != 0 else {
                return
            }
            let key = eventTurnKey(path: path, event: event)
            var turn = turns[key] ?? TurnAccumulator()
            turn.hasCommandFailure = true
            turns[key] = turn
        case .tokenCount(let usage):
            latestUsage = usage
            recordUsage(usage, timestamp: event.timestamp ?? Date(), path: path, title: latestUserMessageByPath[path])
        case .taskComplete:
            let key = eventTurnKey(path: path, event: event)
            let turn = turns[key] ?? TurnAccumulator()
            let includeCommands = UserDefaults.standard.bool(forKey: AppDefaults.Key.commandFailureHeuristicEnabled)
            let classification = TurnClassifier.classify(turn, includeCommandFailures: includeCommands)
            turns[key] = nil
            if event.turnID == nil || event.turnID == currentTurnIDByPath[path] {
                currentTurnIDByPath.removeValue(forKey: path)
            }
            logger.info("Turn classified as \(classification.outcome.rawValue, privacy: .public): \(classification.reason, privacy: .public)")
            let soundResult = play(outcome: classification.outcome)
            lastOutcome = classification.outcome
            if soundResult == .suppressedByQuietHours {
                lastStatus = "安静时段内已静音 \(Self.timeFormatter.string(from: Date()))"
            } else {
                lastStatus = "\(classification.outcome.title) \(Self.timeFormatter.string(from: Date()))"
            }
        case .ignored:
            break
        }
    }

    @discardableResult
    private func play(outcome: TurnOutcome, force: Bool = false) -> SoundPlaybackResult {
        let defaults = UserDefaults.standard
        let volume = defaults.double(forKey: AppDefaults.Key.volume)
        guard force || !Self.isQuietHoursActive(defaults: defaults, date: Date()) else {
            return .suppressedByQuietHours
        }

        switch outcome {
        case .completed:
            guard force || defaults.bool(forKey: AppDefaults.Key.completionSoundEnabled) else {
                return .skipped
            }
            let path = defaults.string(forKey: AppDefaults.Key.completionSoundPath) ?? AppDefaults.defaultCompletionSoundPath
            soundPlayer.play(path: path, volume: volume)
        case .failed:
            guard force || defaults.bool(forKey: AppDefaults.Key.failureSoundEnabled) else {
                return .skipped
            }
            let path = defaults.string(forKey: AppDefaults.Key.failureSoundPath) ?? AppDefaults.defaultFailureSoundPath
            soundPlayer.play(path: path, volume: volume)
        }
        return .played
    }

    private static func isQuietHoursActive(defaults: UserDefaults, date: Date) -> Bool {
        guard defaults.bool(forKey: AppDefaults.Key.quietHoursEnabled) else {
            return false
        }

        let startMinute = defaults.integer(forKey: AppDefaults.Key.quietHoursStartMinute)
        let endMinute = defaults.integer(forKey: AppDefaults.Key.quietHoursEndMinute)
        guard startMinute != endMinute else {
            return true
        }

        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let currentMinute = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if startMinute < endMinute {
            return currentMinute >= startMinute && currentMinute < endMinute
        }

        return currentMinute >= startMinute || currentMinute < endMinute
    }

    private func shouldBootstrapContext(modifiedAt: Date) -> Bool {
        modifiedAt >= startedAt.addingTimeInterval(-bootstrapLookback)
    }

    private func bootstrapContext(from url: URL, path: String, size: UInt64) {
        guard size > 0, let handle = try? FileHandle(forReadingFrom: url) else {
            return
        }

        do {
            let offset = size > bootstrapByteLimit ? size - bootstrapByteLimit : 0
            try handle.seek(toOffset: offset)
            let data = try handle.readToEnd() ?? Data()
            try? handle.close()

            let lines = bootstrapLines(from: data, startsMidLine: offset > 0)
            let snapshot = SessionReplay.rebuild(from: lines)
            apply(snapshot: snapshot, path: path)
        } catch {
            try? handle.close()
        }
    }

    private func bootstrapLines(from data: Data, startsMidLine: Bool) -> [String] {
        var text = String(decoding: data, as: UTF8.self)
        if startsMidLine {
            guard let firstNewline = text.firstIndex(of: "\n") else {
                return []
            }
            text = String(text[text.index(after: firstNewline)...])
        }

        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func apply(snapshot: SessionReplaySnapshot, path: String) {
        for (turnID, turn) in snapshot.turnsByID {
            turns[turnKey(path: path, turnID: turnID)] = turn
        }

        if let currentTurnID = snapshot.currentTurnID {
            currentTurnIDByPath[path] = currentTurnID
        } else {
            currentTurnIDByPath.removeValue(forKey: path)
        }

        if let latestUserMessage = snapshot.latestUserMessage {
            latestUserMessageByPath[path] = latestUserMessage
        }

        if let latestUsage = snapshot.latestUsage {
            self.latestUsage = latestUsage
            let latestTimestamp = snapshot.usageEvents.last?.timestamp ?? Date()
            updateSessionUsage(latestUsage, timestamp: latestTimestamp, path: path, title: snapshot.latestUserMessage)
        }

        for usageEvent in snapshot.usageEvents {
            recordUsage(usageEvent.usage, timestamp: usageEvent.timestamp, path: path, title: snapshot.latestUserMessage)
        }

        if !snapshot.turnsByID.isEmpty {
            logger.info("Rebuilt active turn context for \(path, privacy: .public)")
        }
    }

    private func resetScanState() {
        offsets.removeAll()
        partialLines.removeAll()
        turns.removeAll()
        currentTurnIDByPath.removeAll()
        latestUserMessageByPath.removeAll()
        cachedDiscoveredFiles.removeAll()
        lastFullDiscoveryAt = nil
        usageSamples.removeAll()
        usageTrend.removeAll()
        sessionUsageByPath.removeAll()
        sessionUsageRankings.removeAll()
        primed = false
    }

    private func recordUsage(_ usage: TokenUsageSnapshot, timestamp: Date, path: String, title: String? = nil) {
        usageSamples.append(UsageSample(timestamp: timestamp, path: path, tokens: max(0, usage.last.totalTokens)))
        if usageSamples.count > maxUsageSamples {
            usageSamples.removeFirst(usageSamples.count - maxUsageSamples)
        }

        let cutoff = Date().addingTimeInterval(-trendLookback)
        usageSamples.removeAll { $0.timestamp < cutoff }
        usageTrend = buildTrend(from: usageSamples, now: Date())
        updateSessionUsage(usage, timestamp: timestamp, path: path, title: title)
    }

    private func updateSessionUsage(_ usage: TokenUsageSnapshot, timestamp: Date, path: String, title: String? = nil) {
        let existing = sessionUsageByPath[path]
        sessionUsageByPath[path] = SessionUsageSummary(
            path: path,
            title: sessionTitle(title, fallbackPath: path, existing: existing?.title),
            fileName: sessionFileName(path),
            totalTokens: usage.total.totalTokens,
            lastTokens: usage.last.totalTokens,
            updatedAt: timestamp
        )

        sessionUsageRankings = Array(sessionUsageByPath.values
            .sorted {
                if $0.totalTokens == $1.totalTokens {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.totalTokens > $1.totalTokens
            }
            .prefix(maxSessionRankings))
    }

    private func buildTrend(from samples: [UsageSample], now: Date) -> [UsageTrendPoint] {
        let calendar = Calendar.current
        let currentHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let starts = (0..<6).compactMap { offset in
            calendar.date(byAdding: .hour, value: offset - 5, to: currentHour)
        }
        var totals = Dictionary(uniqueKeysWithValues: starts.map { ($0, 0) })

        for sample in samples {
            guard let hour = calendar.dateInterval(of: .hour, for: sample.timestamp)?.start,
                  totals[hour] != nil else {
                continue
            }
            totals[hour, default: 0] += sample.tokens
        }

        return starts.map { start in
            UsageTrendPoint(hourStart: start, tokens: totals[start, default: 0])
        }
    }

    private func sessionFileName(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let fileName = url.deletingPathExtension().lastPathComponent
        if !fileName.isEmpty {
            return fileName
        }
        return url.lastPathComponent
    }

    private func sessionTitle(_ message: String?, fallbackPath path: String, existing: String?) -> String {
        if let title = message.flatMap(Self.displayTitle(from:)) {
            return title
        }

        if let existing, existing != sessionFileName(path) {
            return existing
        }

        return sessionFileName(path)
    }

    private static func displayTitle(from message: String) -> String? {
        var text = message
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let ignoredPrefixes = [
            "# AGENTS.md instructions",
            "Codex Security file-review shard",
            "Filesystem sandboxing defines",
            "You are Codex"
        ]
        guard !ignoredPrefixes.contains(where: { text.hasPrefix($0) }) else {
            return nil
        }

        let sentenceTerminators: Set<Character> = ["。", "！", "？", "\n"]
        if let firstSentenceEnd = text.firstIndex(where: { sentenceTerminators.contains($0) }) {
            text = String(text[...firstSentenceEnd])
        }

        if text.count > 42 {
            text = String(text.prefix(42)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }

        return text.isEmpty ? nil : text
    }

    private static func previewTrend() -> [UsageTrendPoint] {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let values = [8_400, 12_900, 4_700, 23_600, 16_200, 21_360]
        return values.enumerated().compactMap { index, value in
            guard let start = calendar.date(byAdding: .hour, value: index - 5, to: currentHour) else {
                return nil
            }
            return UsageTrendPoint(hourStart: start, tokens: value)
        }
    }

    private func eventTurnKey(path: String, event: SessionEvent) -> String {
        if let turnID = event.turnID {
            return turnKey(path: path, turnID: turnID)
        }

        if let currentTurnID = currentTurnIDByPath[path] {
            return turnKey(path: path, turnID: currentTurnID)
        }

        return turnKey(path: path, turnID: "file")
    }

    private func turnKey(path: String, turnID: String) -> String {
        "\(path)\u{1F}\(turnID)"
    }

    private func hasActiveTurn(forPath path: String) -> Bool {
        turns.keys.contains { $0.hasPrefix("\(path)\u{1F}") }
    }

    private func markRecognized(_ event: SessionEvent) {
        guard event.kind != .ignored else {
            return
        }

        recognizedEventCount += 1
        lastEventStatus = "\(event.kind.title) \(Self.timeFormatter.string(from: Date()))"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

struct UsageTrendPoint: Identifiable, Equatable {
    let hourStart: Date
    let tokens: Int

    var id: Date {
        hourStart
    }
}

struct SessionUsageSummary: Identifiable, Equatable {
    let path: String
    let title: String
    let fileName: String
    let totalTokens: Int
    let lastTokens: Int
    let updatedAt: Date

    var id: String {
        path
    }
}

private struct UsageSample {
    let timestamp: Date
    let path: String
    let tokens: Int
}

private enum SoundPlaybackResult {
    case played
    case skipped
    case suppressedByQuietHours
}

private extension SessionEventKind {
    var title: String {
        switch self {
        case .taskStarted:
            return "识别到开始"
        case .taskComplete:
            return "识别到结束"
        case .userMessage:
            return "识别到用户任务"
        case .assistantMessage:
            return "识别到回复"
        case .failureSignal:
            return "识别到失败事件"
        case .commandExit:
            return "识别到命令结果"
        case .tokenCount:
            return "识别到用量"
        case .ignored:
            return "忽略事件"
        }
    }
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
