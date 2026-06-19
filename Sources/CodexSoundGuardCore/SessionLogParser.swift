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
        let metadata = payload["metadata"] as? [String: Any]
        let turnID = payload["turn_id"] as? String ?? root["turn_id"] as? String ?? metadata?["turn_id"] as? String

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
        case "user_message":
            if let message = payload["message"] as? String {
                return SessionEvent(kind: .userMessage(message), timestamp: timestamp, turnID: turnID)
            }
            return SessionEvent(kind: .ignored, timestamp: timestamp, turnID: turnID)
        case "token_count":
            if let usage = parseTokenUsageSnapshot(payload: payload) {
                return SessionEvent(kind: .tokenCount(usage), timestamp: timestamp, turnID: turnID)
            }
            return SessionEvent(kind: .ignored, timestamp: timestamp, turnID: turnID)
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
        if payloadType == "message" {
            switch payload["role"] as? String {
            case "assistant":
                if let message = messageText(from: payload) {
                    return SessionEvent(kind: .assistantMessage(message), timestamp: timestamp, turnID: turnID)
                }
            case "user":
                if let message = messageText(from: payload) {
                    return SessionEvent(kind: .userMessage(message), timestamp: timestamp, turnID: turnID)
                }
            default:
                break
            }
        }

        if payloadType == "function_call",
           let approval = approvalRequest(from: payload) {
            return SessionEvent(kind: .approvalRequested(approval), timestamp: timestamp, turnID: turnID)
        }

        if payloadType == "function_call_output",
           let output = payload["output"] as? String,
           let code = commandExitCode(in: output) {
            return SessionEvent(kind: .commandExit(code: code), timestamp: timestamp, turnID: turnID)
        }

        return SessionEvent(kind: .ignored, timestamp: timestamp, turnID: turnID)
    }

    private static func approvalRequest(from payload: [String: Any]) -> ApprovalRequest? {
        guard
            let arguments = payload["arguments"] as? String,
            let argumentData = arguments.data(using: .utf8),
            let parsedArguments = try? JSONSerialization.jsonObject(with: argumentData) as? [String: Any],
            (parsedArguments["sandbox_permissions"] as? String) == "require_escalated"
        else {
            return nil
        }

        let toolName = payload["name"] as? String ?? "tool"
        let callID = payload["call_id"] as? String
        let fallbackID = [toolName, arguments].joined(separator: ":")
        return ApprovalRequest(
            id: callID ?? fallbackID,
            toolName: toolName,
            reason: parsedArguments["justification"] as? String
        )
    }

    private static func parseTokenUsageSnapshot(payload: [String: Any]) -> TokenUsageSnapshot? {
        guard
            let info = payload["info"] as? [String: Any],
            let totalValue = info["total_token_usage"] as? [String: Any],
            let lastValue = info["last_token_usage"] as? [String: Any],
            let total = parseTokenUsage(totalValue),
            let last = parseTokenUsage(lastValue)
        else {
            return nil
        }

        let rateLimits = payload["rate_limits"] as? [String: Any]
        let creditsValue = rateLimits?["credits"] as? [String: Any]

        return TokenUsageSnapshot(
            total: total,
            last: last,
            modelContextWindow: intValue(info["model_context_window"]),
            primaryRateLimit: parseRateLimit(rateLimits?["primary"] as? [String: Any]),
            secondaryRateLimit: parseRateLimit(rateLimits?["secondary"] as? [String: Any]),
            credits: parseCredits(creditsValue)
        )
    }

    private static func parseTokenUsage(_ value: [String: Any]) -> TokenUsage? {
        guard let totalTokens = intValue(value["total_tokens"]) else {
            return nil
        }

        return TokenUsage(
            inputTokens: intValue(value["input_tokens"]) ?? 0,
            cachedInputTokens: intValue(value["cached_input_tokens"]) ?? 0,
            outputTokens: intValue(value["output_tokens"]) ?? 0,
            reasoningOutputTokens: intValue(value["reasoning_output_tokens"]) ?? 0,
            totalTokens: totalTokens
        )
    }

    private static func parseRateLimit(_ value: [String: Any]?) -> UsageRateLimit? {
        guard let value, let usedPercent = doubleValue(value["used_percent"]) else {
            return nil
        }

        let resetTimestamp = doubleValue(value["resets_at"])
        return UsageRateLimit(
            usedPercent: usedPercent,
            windowMinutes: intValue(value["window_minutes"]),
            resetsAt: resetTimestamp.map { Date(timeIntervalSince1970: $0) }
        )
    }

    private static func parseCredits(_ value: [String: Any]?) -> UsageCredits? {
        guard let value else {
            return nil
        }

        return UsageCredits(
            hasCredits: value["has_credits"] as? Bool,
            unlimited: value["unlimited"] as? Bool,
            balance: stringValue(value["balance"])
        )
    }

    private static func messageText(from payload: [String: Any]) -> String? {
        guard let content = payload["content"] as? [[String: Any]] else {
            return nil
        }

        let parts = content.compactMap { item -> String? in
            guard let type = item["type"] as? String,
                  type == "output_text" || type == "input_text" else {
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

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        if let value = value as? String {
            return Int(value)
        }
        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        if let value = value as? String {
            return Double(value)
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let value = value as? String {
            return value
        }
        if let value = value as? NSNumber {
            return value.stringValue
        }
        return nil
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}
