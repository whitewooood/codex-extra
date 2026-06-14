import XCTest
@testable import CodexSoundGuardCore

final class SessionLogParserTests: XCTestCase {
    func testParsesTaskComplete() {
        let line = #"{"timestamp":"2026-06-04T04:25:55.549Z","type":"event_msg","payload":{"type":"task_complete"}}"#

        XCTAssertEqual(SessionLogParser.parseLine(line)?.kind, .taskComplete)
    }

    func testParsesTurnID() {
        let line = #"{"timestamp":"2026-06-04T04:25:55.549Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}"#

        let event = SessionLogParser.parseLine(line)
        XCTAssertEqual(event?.kind, .taskStarted)
        XCTAssertEqual(event?.turnID, "turn-1")
    }

    func testParsesAssistantMessage() {
        let line = #"{"timestamp":"2026-06-04T04:25:55.458Z","type":"event_msg","payload":{"type":"agent_message","message":"Done."}}"#

        XCTAssertEqual(SessionLogParser.parseLine(line)?.kind, .assistantMessage("Done."))
    }

    func testParsesResponseItemAssistantMessage() {
        let line = #"{"timestamp":"2026-06-04T04:25:55.458Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"完成。"}]}}"#

        XCTAssertEqual(SessionLogParser.parseLine(line)?.kind, .assistantMessage("完成。"))
    }

    func testParsesUserMessage() {
        let line = #"{"timestamp":"2026-06-04T04:25:55.458Z","type":"event_msg","payload":{"type":"user_message","message":"修复设置窗口打不开"}}"#

        XCTAssertEqual(SessionLogParser.parseLine(line)?.kind, .userMessage("修复设置窗口打不开"))
    }

    func testParsesResponseItemUserMessage() {
        let line = #"{"timestamp":"2026-06-04T04:25:55.458Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"增加用量趋势"}]}}"#

        XCTAssertEqual(SessionLogParser.parseLine(line)?.kind, .userMessage("增加用量趋势"))
    }

    func testParsesFailureStatus() {
        let line = #"{"timestamp":"2026-06-04T04:25:55.549Z","type":"event_msg","payload":{"type":"anything","status":"failed"}}"#

        XCTAssertEqual(SessionLogParser.parseLine(line)?.kind, .failureSignal("status:failed"))
    }

    func testParsesCommandExitCode() {
        let line = #"{"type":"response_item","payload":{"type":"function_call_output","output":"Process exited with code 128\nOutput:\nfatal"}}"#

        XCTAssertEqual(SessionLogParser.parseLine(line)?.kind, .commandExit(code: 128))
    }

    func testParsesTokenCountUsage() {
        let line = #"{"timestamp":"2026-06-14T12:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1200,"cached_input_tokens":300,"output_tokens":80,"reasoning_output_tokens":20,"total_tokens":1300},"last_token_usage":{"input_tokens":200,"cached_input_tokens":50,"output_tokens":30,"reasoning_output_tokens":10,"total_tokens":230},"model_context_window":258400},"rate_limits":{"primary":{"used_percent":37.5,"window_minutes":300,"resets_at":1781450000},"secondary":{"used_percent":12.0,"window_minutes":10080,"resets_at":1782000000},"credits":{"has_credits":false,"unlimited":false,"balance":"0"}}}}"#

        guard case .tokenCount(let usage) = SessionLogParser.parseLine(line)?.kind else {
            return XCTFail("Expected token count event")
        }

        XCTAssertEqual(usage.total.totalTokens, 1300)
        XCTAssertEqual(usage.total.cachedInputTokens, 300)
        XCTAssertEqual(usage.last.totalTokens, 230)
        XCTAssertEqual(usage.modelContextWindow, 258400)
        XCTAssertEqual(usage.primaryRateLimit?.usedPercent, 37.5)
        XCTAssertEqual(usage.secondaryRateLimit?.windowMinutes, 10080)
        XCTAssertEqual(usage.credits?.balance, "0")
    }

    func testClassifiesMessageFailure() {
        let turn = TurnAccumulator(latestAssistantMessage: "我未能完成这个任务。")

        XCTAssertEqual(
            TurnClassifier.classify(turn, includeCommandFailures: false),
            TurnClassification(outcome: .failed, reason: "assistant message")
        )
    }

    func testClassifiesBlockedAndTimeoutMessages() {
        XCTAssertTrue(TurnClassifier.messageLooksLikeFailure("任务受阻，无法继续。"))
        XCTAssertTrue(TurnClassifier.messageLooksLikeFailure("The operation timed out before completion."))
    }

    func testDoesNotClassifyNegativeFailurePhraseAsFailure() {
        XCTAssertFalse(TurnClassifier.messageLooksLikeFailure("测试通过，没有失败，也没有报错。"))
        XCTAssertFalse(TurnClassifier.messageLooksLikeFailure("Build completed with no errors."))
    }

    func testDoesNotClassifySuccessfulFixSummaryAsFailure() {
        XCTAssertFalse(TurnClassifier.messageLooksLikeFailure("已修复失败提醒误报问题，swift test 通过。"))
        XCTAssertFalse(TurnClassifier.messageLooksLikeFailure("报错已解决，安装验证也通过。"))
        XCTAssertFalse(TurnClassifier.messageLooksLikeFailure("Fixed the failed tests; all tests pass."))
    }

    func testIgnoresCommandFailureByDefault() {
        let turn = TurnAccumulator(hasCommandFailure: true)

        XCTAssertEqual(
            TurnClassifier.classify(turn, includeCommandFailures: false),
            TurnClassification(outcome: .completed, reason: "task complete")
        )
    }

    func testClassifiesCommandFailureWhenEnabled() {
        let turn = TurnAccumulator(hasCommandFailure: true)

        XCTAssertEqual(
            TurnClassifier.classify(turn, includeCommandFailures: true),
            TurnClassification(outcome: .failed, reason: "command exit")
        )
    }

    func testSuccessfulFixSummaryOverridesEarlierCommandFailure() {
        let turn = TurnAccumulator(
            latestAssistantMessage: "已修复失败提醒误报问题，swift test 通过。",
            hasCommandFailure: true
        )

        XCTAssertEqual(
            TurnClassifier.classify(turn, includeCommandFailures: true),
            TurnClassification(outcome: .completed, reason: "task complete")
        )
    }
}
