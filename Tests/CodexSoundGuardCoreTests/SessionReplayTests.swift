import XCTest
@testable import CodexSoundGuardCore

final class SessionReplayTests: XCTestCase {
    func testRebuildsCompleteCodexSessionFixture() throws {
        let snapshot = SessionReplay.rebuild(from: try fixtureLines("codex-session-complete"))

        XCTAssertNil(snapshot.currentTurnID)
        XCTAssertTrue(snapshot.turnsByID.isEmpty)
        XCTAssertEqual(snapshot.latestUserMessage, "修复 README 文案并验证打包")
        XCTAssertEqual(snapshot.latestUsage?.total.totalTokens, 1000)
        XCTAssertEqual(snapshot.usageEvents.count, 1)
    }

    func testClassifiesFailedCodexSessionFixture() throws {
        let lines = try fixtureLines("codex-session-failed")
        var turn = TurnAccumulator()

        for line in lines {
            switch SessionLogParser.parseLine(line)?.kind {
            case .assistantMessage(let message):
                turn.latestAssistantMessage = message
            case .commandExit(let code) where code != 0:
                turn.hasCommandFailure = true
            case .failureSignal:
                turn.hasFailureSignal = true
            default:
                break
            }
        }

        XCTAssertEqual(
            TurnClassifier.classify(turn, includeCommandFailures: false),
            TurnClassification(outcome: .failed, reason: "assistant message")
        )
        XCTAssertEqual(
            TurnClassifier.classify(turn, includeCommandFailures: true),
            TurnClassification(outcome: .failed, reason: "command exit")
        )
    }

    func testRebuildsActiveFailureTurnFromExistingLogLines() {
        let lines = [
            #"{"timestamp":"2026-06-05T06:00:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"mid-1"}}"#,
            #"{"timestamp":"2026-06-05T06:00:01.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"我未能完成这个任务。"}]}}"#
        ]

        let snapshot = SessionReplay.rebuild(from: lines)

        XCTAssertEqual(snapshot.currentTurnID, "mid-1")
        XCTAssertEqual(snapshot.turnsByID["mid-1"]?.latestAssistantMessage, "我未能完成这个任务。")
        XCTAssertEqual(
            TurnClassifier.classify(snapshot.turnsByID["mid-1"] ?? TurnAccumulator(), includeCommandFailures: false),
            TurnClassification(outcome: .failed, reason: "assistant message")
        )
    }

    func testDropsHistoricalTurnsAfterTaskComplete() {
        let lines = [
            #"{"timestamp":"2026-06-05T06:00:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"done-1"}}"#,
            #"{"timestamp":"2026-06-05T06:00:01.000Z","type":"response_item","payload":{"type":"message","role":"assistant","turn_id":"done-1","content":[{"type":"output_text","text":"完成。"}]}}"#,
            #"{"timestamp":"2026-06-05T06:00:02.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"done-1"}}"#
        ]

        let snapshot = SessionReplay.rebuild(from: lines)

        XCTAssertNil(snapshot.currentTurnID)
        XCTAssertTrue(snapshot.turnsByID.isEmpty)
    }

    func testRebuildsLatestTokenUsage() {
        let lines = [
            #"{"timestamp":"2026-06-14T12:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":10,"reasoning_output_tokens":0,"total_tokens":110},"last_token_usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":10,"reasoning_output_tokens":0,"total_tokens":110}}}}"#,
            #"{"timestamp":"2026-06-14T12:01:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":300,"cached_input_tokens":40,"output_tokens":30,"reasoning_output_tokens":5,"total_tokens":335},"last_token_usage":{"input_tokens":200,"cached_input_tokens":20,"output_tokens":20,"reasoning_output_tokens":5,"total_tokens":225}}}}"#
        ]

        let snapshot = SessionReplay.rebuild(from: lines)

        XCTAssertEqual(snapshot.latestUsage?.total.totalTokens, 335)
        XCTAssertEqual(snapshot.latestUsage?.last.totalTokens, 225)
        XCTAssertEqual(snapshot.usageEvents.count, 2)
        XCTAssertEqual(snapshot.usageEvents.first?.usage.last.totalTokens, 110)
        XCTAssertEqual(snapshot.usageEvents.last?.usage.last.totalTokens, 225)
    }

    func testRebuildsLatestUserMessage() {
        let lines = [
            #"{"timestamp":"2026-06-14T12:00:00.000Z","type":"event_msg","payload":{"type":"user_message","message":"先做 README"}}"#,
            #"{"timestamp":"2026-06-14T12:01:00.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"修复设置窗口打不开"}]}}"#
        ]

        let snapshot = SessionReplay.rebuild(from: lines)

        XCTAssertEqual(snapshot.latestUserMessage, "修复设置窗口打不开")
    }

    private func fixtureLines(_ name: String) throws -> [String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("\(name).jsonl")
        return try String(contentsOf: url)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }
}
