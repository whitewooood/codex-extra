import Foundation

public struct UsageTrendPoint: Identifiable, Equatable {
    public let hourStart: Date
    public let tokens: Int

    public init(hourStart: Date, tokens: Int) {
        self.hourStart = hourStart
        self.tokens = tokens
    }

    public var id: Date {
        hourStart
    }
}

public struct SessionUsageSummary: Identifiable, Equatable {
    public let path: String
    public let title: String
    public let fileName: String
    public let totalTokens: Int
    public let lastTokens: Int
    public let updatedAt: Date

    public init(path: String, title: String, fileName: String, totalTokens: Int, lastTokens: Int, updatedAt: Date) {
        self.path = path
        self.title = title
        self.fileName = fileName
        self.totalTokens = totalTokens
        self.lastTokens = lastTokens
        self.updatedAt = updatedAt
    }

    public var id: String {
        path
    }
}

public struct UsageSample: Equatable {
    public let timestamp: Date
    public let path: String
    public let tokens: Int

    public init(timestamp: Date, path: String, tokens: Int) {
        self.timestamp = timestamp
        self.path = path
        self.tokens = tokens
    }
}

public enum UsageAnalytics {
    public static func buildTrend(
        from samples: [UsageSample],
        now: Date,
        hourCount: Int = 6,
        calendar: Calendar = .current
    ) -> [UsageTrendPoint] {
        let safeHourCount = max(1, hourCount)
        let currentHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let starts = (0..<safeHourCount).compactMap { offset in
            calendar.date(byAdding: .hour, value: offset - (safeHourCount - 1), to: currentHour)
        }

        var totals = Dictionary(uniqueKeysWithValues: starts.map { ($0, 0) })
        for sample in samples {
            guard let hour = calendar.dateInterval(of: .hour, for: sample.timestamp)?.start,
                  totals[hour] != nil else {
                continue
            }
            totals[hour, default: 0] += max(0, sample.tokens)
        }

        return starts.map { start in
            UsageTrendPoint(hourStart: start, tokens: totals[start, default: 0])
        }
    }

    public static func makeSessionSummary(
        usage: TokenUsageSnapshot,
        timestamp: Date,
        path: String,
        title: String?,
        existingTitle: String? = nil
    ) -> SessionUsageSummary {
        let fileName = sessionFileName(path)
        return SessionUsageSummary(
            path: path,
            title: sessionTitle(title, fileName: fileName, existing: existingTitle),
            fileName: fileName,
            totalTokens: usage.total.totalTokens,
            lastTokens: usage.last.totalTokens,
            updatedAt: timestamp
        )
    }

    public static func rankedSessions(_ summaries: [SessionUsageSummary], limit: Int) -> [SessionUsageSummary] {
        Array(summaries
            .sorted {
                if $0.totalTokens == $1.totalTokens {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.totalTokens > $1.totalTokens
            }
            .prefix(max(0, limit)))
    }

    public static func displayTitle(from message: String) -> String? {
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

    private static func sessionTitle(_ message: String?, fileName: String, existing: String?) -> String {
        if let title = message.flatMap(displayTitle(from:)) {
            return title
        }

        if let existing, existing != fileName {
            return existing
        }

        return fileName
    }

    private static func sessionFileName(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let fileName = url.deletingPathExtension().lastPathComponent
        if !fileName.isEmpty {
            return fileName
        }
        return url.lastPathComponent
    }
}
