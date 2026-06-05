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

        if includeCommandFailures && turn.hasCommandFailure && !messageLooksLikeResolvedSuccess(turn.latestAssistantMessage) {
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

        let negativePatterns = [
            "没有失败",
            "未失败",
            "没有报错",
            "无报错",
            "没有出错",
            "未出错",
            "no failure",
            "no failures",
            "not failed",
            "did not fail",
            "without error",
            "no error"
        ]

        if negativePatterns.contains(where: { normalized.contains($0) }) {
            return false
        }

        if normalizedMessageLooksLikeResolvedSuccess(normalized) {
            return false
        }

        let patterns = [
            "未能",
            "没能",
            "无法完成",
            "不能完成",
            "不能继续",
            "失败",
            "报错",
            "出错",
            "受阻",
            "卡住",
            "超时",
            "中断",
            "终止",
            "被取消",
            "取消了任务",
            "崩溃",
            "权限不足",
            "blocked",
            "could not",
            "couldn't",
            "unable",
            "failed",
            "not able",
            "not completed",
            "timed out",
            "timeout",
            "aborted",
            "interrupted",
            "cancelled",
            "canceled",
            "stuck",
            "crashed",
            "permission denied"
        ]

        return patterns.contains { normalized.contains($0) }
    }

    private static func messageLooksLikeResolvedSuccess(_ message: String) -> Bool {
        let normalized = message
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        return normalizedMessageLooksLikeResolvedSuccess(normalized)
    }

    private static func normalizedMessageLooksLikeResolvedSuccess(_ normalized: String) -> Bool {
        let unresolvedPatterns = [
            "但仍",
            "但还是",
            "仍然失败",
            "仍然报错",
            "仍然出错",
            "still failed",
            "still failing",
            "still errors",
            "but failed",
            "but still"
        ]

        if unresolvedPatterns.contains(where: { normalized.contains($0) }) {
            return false
        }

        let resolvedPatterns = [
            "已修复",
            "已经修复",
            "修复完成",
            "已解决",
            "已经解决",
            "解决完成",
            "测试通过",
            "构建通过",
            "验证通过",
            "安装验证也通过",
            "fixed the failed",
            "fixed the failure",
            "resolved the error",
            "resolved the failure",
            "all tests pass",
            "tests pass",
            "build succeeded",
            "verification passed"
        ]

        return resolvedPatterns.contains { normalized.contains($0) }
    }
}
