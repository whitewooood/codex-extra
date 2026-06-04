import XCTest
@testable import CodexSoundGuardCore

final class SessionLogParserTests: XCTestCase {
    func testParsesTaskComplete() {
        let line = #"{"timestamp":"2026-06-04T04:25:55.549Z","type":"event_msg","payload":{"type":"task_complete"}}"#

        XCTAssertEqual(SessionLogParser.parseLine(line)?.kind, .taskComplete)
    }

    func testParsesAssistantMessage() {
        let line = #"{"timestamp":"2026-06-04T04:25:55.458Z","type":"event_msg","payload":{"type":"agent_message","message":"Done."}}"#

        XCTAssertEqual(SessionLogParser.parseLine(line)?.kind, .assistantMessage("Done."))
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

    func testIgnoresCommandFailureByDefault() {
        let turn = TurnAccumulator(hasCommandFailure: true)

        XCTAssertEqual(
            TurnClassifier.classify(turn, includeCommandFailures: false),
            TurnClassification(outcome: .completed, reason: "task complete")
        )
    }
}
