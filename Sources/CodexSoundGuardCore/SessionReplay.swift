import Foundation

public struct SessionReplaySnapshot: Equatable {
    public let currentTurnID: String?
    public let turnsByID: [String: TurnAccumulator]
    public let latestUsage: TokenUsageSnapshot?
    public let usageEvents: [TokenUsageEvent]
    public let latestUserMessage: String?

    public init(
        currentTurnID: String?,
        turnsByID: [String: TurnAccumulator],
        latestUsage: TokenUsageSnapshot? = nil,
        usageEvents: [TokenUsageEvent] = [],
        latestUserMessage: String? = nil
    ) {
        self.currentTurnID = currentTurnID
        self.turnsByID = turnsByID
        self.latestUsage = latestUsage
        self.usageEvents = usageEvents
        self.latestUserMessage = latestUserMessage
    }
}

public enum SessionReplay {
    public static func rebuild(from lines: [String]) -> SessionReplaySnapshot {
        var currentTurnID: String?
        var turnsByID: [String: TurnAccumulator] = [:]
        var latestUsage: TokenUsageSnapshot?
        var usageEvents: [TokenUsageEvent] = []
        var latestUserMessage: String?
        var implicitTurnCounter = 0

        for line in lines {
            guard let event = SessionLogParser.parseLine(line) else {
                continue
            }

            switch event.kind {
            case .taskStarted:
                let turnID: String
                if let eventTurnID = event.turnID {
                    turnID = eventTurnID
                } else {
                    implicitTurnCounter += 1
                    turnID = "implicit-\(implicitTurnCounter)"
                }
                currentTurnID = turnID
                turnsByID[turnID] = TurnAccumulator(startedAt: event.timestamp)
            case .userMessage(let message):
                latestUserMessage = message
            case .assistantMessage(let message):
                let turnID = replayTurnID(for: event, currentTurnID: currentTurnID)
                var turn = turnsByID[turnID] ?? TurnAccumulator()
                turn.latestAssistantMessage = message
                turnsByID[turnID] = turn
            case .failureSignal:
                let turnID = replayTurnID(for: event, currentTurnID: currentTurnID)
                var turn = turnsByID[turnID] ?? TurnAccumulator()
                turn.hasFailureSignal = true
                turnsByID[turnID] = turn
            case .commandExit(let code):
                guard code != 0 else {
                    continue
                }
                let turnID = replayTurnID(for: event, currentTurnID: currentTurnID)
                var turn = turnsByID[turnID] ?? TurnAccumulator()
                turn.hasCommandFailure = true
                turnsByID[turnID] = turn
            case .taskComplete:
                let turnID = replayTurnID(for: event, currentTurnID: currentTurnID)
                turnsByID[turnID] = nil
                if event.turnID == nil || event.turnID == currentTurnID {
                    currentTurnID = nil
                }
            case .tokenCount(let usage):
                latestUsage = usage
                usageEvents.append(TokenUsageEvent(timestamp: event.timestamp ?? Date(), usage: usage))
            case .ignored:
                break
            }
        }

        return SessionReplaySnapshot(
            currentTurnID: currentTurnID,
            turnsByID: turnsByID,
            latestUsage: latestUsage,
            usageEvents: usageEvents,
            latestUserMessage: latestUserMessage
        )
    }

    private static func replayTurnID(for event: SessionEvent, currentTurnID: String?) -> String {
        event.turnID ?? currentTurnID ?? "file"
    }
}
