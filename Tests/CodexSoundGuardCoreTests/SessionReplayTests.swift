import XCTest
@testable import CodexSoundGuardCore

final class SessionReplayTests: XCTestCase {
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
}
