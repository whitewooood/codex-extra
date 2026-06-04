import Foundation

public enum SessionLogParser {
    public static func parseLine(_ line: String) -> SessionEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return nil
        }

        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let topLevelType = root["type"] as? String,
            let payload = root["payload"] as? [String: Any]
        else {
            return nil
        }

        let timestamp = parseDate(root["timestamp"] as? String)
        let payloadType = payload["type"] as? String
        let turnID = payload["turn_id"] as? String ?? root["turn_id"] as? String

        if let status = payload["status"] as? String,
           status.caseInsensitiveCompare("failed") == .orderedSame
            || status.caseInsensitiveCompare("error") == .orderedSame {
            return SessionEvent(kind: .failureSignal("status:\(status)"), timestamp: timestamp, turnID: turnID)
        }

        switch topLevelType {
        case "event_msg":
            return parseEventMessage(payloadType: payloadType, payload: payload, timestamp: timestamp, turnID: turnID)
        case "response_item":
            return parseResponseItem(payloadType: payloadType, payload: payload, timestamp: timestamp, turnID: turnID)
        default:
            return SessionEvent(kind: .ignored, timestamp: timestamp, turnID: turnID)
        }
    }

    private static func parseEventMessage(
        payloadType: String?,
        payload: [String: Any],
        timestamp: Date?,
        turnID: String?
    ) -> SessionEvent {
        guard let payloadType else {
            return SessionEvent(kind: .ignored, timestamp: timestamp, turnID: turnID)
        }

        switch payloadType {
        case "task_started":
            return SessionEvent(kind: .taskStarted, timestamp: timestamp, turnID: turnID)
        case "task_complete":
            return SessionEvent(kind: .taskComplete, timestamp: timestamp, turnID: turnID)
        case "agent_message":
            if let message = payload["message"] as? String {
                return SessionEvent(kind: .assistantMessage(message), timestamp: timestamp, turnID: turnID)
            }
            return SessionEvent(kind: .ignored, timestamp: timestamp, turnID: turnID)
        default:
            if payloadType.localizedCaseInsensitiveContains("failed")
                || payloadType.localizedCaseInsensitiveContains("error") {
                return SessionEvent(kind: .failureSignal("event:\(payloadType)"), timestamp: timestamp, turnID: turnID)
            }
            return SessionEvent(kind: .ignored, timestamp: timestamp, turnID: turnID)
        }
    }

    private static func parseResponseItem(
        payloadType: String?,
        payload: [String: Any],
        timestamp: Date?,
        turnID: String?
    ) -> SessionEvent {
        if payloadType == "message",
           payload["role"] as? String == "assistant",
           let message = assistantText(from: payload) {
            return SessionEvent(kind: .assistantMessage(message), timestamp: timestamp, turnID: turnID)
        }

        if payloadType == "function_call_output",
           let output = payload["output"] as? String,
           let code = commandExitCode(in: output) {
            return SessionEvent(kind: .commandExit(code: code), timestamp: timestamp, turnID: turnID)
        }

        return SessionEvent(kind: .ignored, timestamp: timestamp, turnID: turnID)
    }

    private static func assistantText(from payload: [String: Any]) -> String? {
        guard let content = payload["content"] as? [[String: Any]] else {
            return nil
        }

        let parts = content.compactMap { item -> String? in
            guard item["type"] as? String == "output_text" else {
                return nil
            }
            return item["text"] as? String
        }

        let message = parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? nil : message
    }

    private static func commandExitCode(in output: String) -> Int? {
        let pattern = #"Process exited with code\s+(-?\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard
            let match = regex.firstMatch(in: output, range: range),
            let codeRange = Range(match.range(at: 1), in: output)
        else {
            return nil
        }

        return Int(output[codeRange])
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }
        return ISO8601DateFormatter.codex.date(from: value)
    }
}

private extension ISO8601DateFormatter {
    static let codex: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
