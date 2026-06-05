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

    func testParsesFailureStatus() {
        let line = #"{"timestamp":"2026-06-04T04:25:55.549Z","type":"event_msg","payload":{"type":"anything","status":"failed"}}"#

        XCTAssertEqual(SessionLogParser.parseLine(line)?.kind, .failureSignal("status:failed"))
    }

    func testParsesCommandExitCode() {
        let line = #"{"type":"response_item","payload":{"type":"function_call_output","output":"Process exited with code 128\nOutput:\nfatal"}}"#

        XCTAssertEqual(SessionLogParser.parseLine(line)?.kind, .commandExit(code: 128))
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
