import Foundation

public enum TurnOutcome: String, Equatable {
    case completed
    case failed
}

public struct TurnAccumulator: Equatable {
    public var startedAt: Date?
    public var latestAssistantMessage: String
    public var hasFailureSignal: Bool
    public var hasCommandFailure: Bool

    public init(
        startedAt: Date? = nil,
        latestAssistantMessage: String = "",
        hasFailureSignal: Bool = false,
        hasCommandFailure: Bool = false
    ) {
        self.startedAt = startedAt
        self.latestAssistantMessage = latestAssistantMessage
        self.hasFailureSignal = hasFailureSignal
        self.hasCommandFailure = hasCommandFailure
    }
}

public struct TurnClassification: Equatable {
    public let outcome: TurnOutcome
    public let reason: String

    public init(outcome: TurnOutcome, reason: String) {
        self.outcome = outcome
        self.reason = reason
    }
}

public enum TurnClassifier {
    public static func classify(
        _ turn: TurnAccumulator,
        includeCommandFailures: Bool
    ) -> TurnClassification {
        if turn.hasFailureSignal {
            return TurnClassification(outcome: .failed, reason: "failure event")
        }

        if includeCommandFailures && turn.hasCommandFailure {
            return TurnClassification(outcome: .failed, reason: "command exit")
        }

        if messageLooksLikeFailure(turn.latestAssistantMessage) {
            return TurnClassification(outcome: .failed, reason: "assistant message")
        }

        return TurnClassification(outcome: .completed, reason: "task complete")
    }

    public static func messageLooksLikeFailure(_ message: String) -> Bool {
        let normalized = message
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        let patterns = [
            "未能",
            "没能",
            "无法",
            "不能完成",
            "失败",
            "报错",
            "出错",
            "blocked",
            "could not",
            "couldn't",
            "unable",
            "failed",
            "not able"
        ]

        return patterns.contains { normalized.contains($0) }
    }
}
