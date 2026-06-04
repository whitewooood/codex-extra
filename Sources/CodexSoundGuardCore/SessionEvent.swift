import Foundation

public enum SessionEventKind: Equatable {
    case taskStarted
    case taskComplete
    case assistantMessage(String)
    case failureSignal(String)
    case commandExit(code: Int)
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
