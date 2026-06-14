import CodexSoundGuardCore
import Foundation

enum UsageFormatter {
    static func menuBarSummary(_ usage: TokenUsageSnapshot?) -> String? {
        guard let usage else {
            return nil
        }

        if let primaryLimit = usage.primaryRateLimit {
            return "5h \(remainingPercent(primaryLimit))"
        }

        if let secondaryLimit = usage.secondaryRateLimit {
            return "7d \(remainingPercent(secondaryLimit))"
        }

        return tokenCount(usage.last.totalTokens)
    }

    static func tokenCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    static func contextWindow(_ value: Int?) -> String {
        guard let value else {
            return "--"
        }
        return tokenCount(value)
    }

    static func percent(_ value: Double) -> String {
        "\(Int(max(0, min(value, 100)).rounded()))%"
    }

    static func remainingPercent(_ limit: UsageRateLimit) -> String {
        percent(100 - max(0, min(limit.usedPercent, 100)))
    }
}
