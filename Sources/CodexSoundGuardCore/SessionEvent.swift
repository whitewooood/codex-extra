import Foundation

public enum SessionEventKind: Equatable {
    case taskStarted
    case taskComplete
    case userMessage(String)
    case assistantMessage(String)
    case failureSignal(String)
    case commandExit(code: Int)
    case tokenCount(TokenUsageSnapshot)
    case ignored
}

public struct SessionEvent: Equatable {
    public let kind: SessionEventKind
    public let timestamp: Date?
    public let turnID: String?

    public init(kind: SessionEventKind, timestamp: Date? = nil, turnID: String? = nil) {
        self.kind = kind
        self.timestamp = timestamp
        self.turnID = turnID
    }
}

public struct TokenUsageEvent: Equatable {
    public let timestamp: Date
    public let usage: TokenUsageSnapshot

    public init(timestamp: Date, usage: TokenUsageSnapshot) {
        self.timestamp = timestamp
        self.usage = usage
    }
}

public struct TokenUsageSnapshot: Equatable {
    public let total: TokenUsage
    public let last: TokenUsage
    public let modelContextWindow: Int?
    public let primaryRateLimit: UsageRateLimit?
    public let secondaryRateLimit: UsageRateLimit?
    public let credits: UsageCredits?

    public init(
        total: TokenUsage,
        last: TokenUsage,
        modelContextWindow: Int? = nil,
        primaryRateLimit: UsageRateLimit? = nil,
        secondaryRateLimit: UsageRateLimit? = nil,
        credits: UsageCredits? = nil
    ) {
        self.total = total
        self.last = last
        self.modelContextWindow = modelContextWindow
        self.primaryRateLimit = primaryRateLimit
        self.secondaryRateLimit = secondaryRateLimit
        self.credits = credits
    }
}

public struct TokenUsage: Equatable {
    public let inputTokens: Int
    public let cachedInputTokens: Int
    public let outputTokens: Int
    public let reasoningOutputTokens: Int
    public let totalTokens: Int

    public init(
        inputTokens: Int,
        cachedInputTokens: Int,
        outputTokens: Int,
        reasoningOutputTokens: Int,
        totalTokens: Int
    ) {
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.reasoningOutputTokens = reasoningOutputTokens
        self.totalTokens = totalTokens
    }
}

public struct UsageRateLimit: Equatable {
    public let usedPercent: Double
    public let windowMinutes: Int?
    public let resetsAt: Date?

    public init(usedPercent: Double, windowMinutes: Int? = nil, resetsAt: Date? = nil) {
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
    }
}

public struct UsageCredits: Equatable {
    public let hasCredits: Bool?
    public let unlimited: Bool?
    public let balance: String?

    public init(hasCredits: Bool? = nil, unlimited: Bool? = nil, balance: String? = nil) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.balance = balance
    }
}
