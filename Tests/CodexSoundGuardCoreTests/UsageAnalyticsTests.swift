import XCTest
@testable import CodexSoundGuardCore

final class UsageAnalyticsTests: XCTestCase {
    func testBuildsSixHourTrendFromTokenSamples() {
        let now = date(hour: 12, minute: 45)
        let samples = [
            UsageSample(timestamp: date(hour: 7, minute: 10), path: "a.jsonl", tokens: 100),
            UsageSample(timestamp: date(hour: 9, minute: 30), path: "b.jsonl", tokens: 250),
            UsageSample(timestamp: date(hour: 9, minute: 45), path: "b.jsonl", tokens: 50),
            UsageSample(timestamp: date(hour: 12, minute: 1), path: "c.jsonl", tokens: 900),
            UsageSample(timestamp: date(hour: 6, minute: 59), path: "old.jsonl", tokens: 999)
        ]

        let points = UsageAnalytics.buildTrend(from: samples, now: now, calendar: calendar)

        XCTAssertEqual(points.map(\.tokens), [100, 0, 300, 0, 0, 900])
    }

    func testSessionSummaryUsesReadableTitle() {
        let usage = usage(total: 1200, last: 300)

        let summary = UsageAnalytics.makeSessionSummary(
            usage: usage,
            timestamp: date(hour: 10, minute: 0),
            path: "/Users/demo/.codex/sessions/2026/06/15/session-1.jsonl",
            title: "修复设置窗口打不开。然后继续优化 UI"
        )

        XCTAssertEqual(summary.title, "修复设置窗口打不开。")
        XCTAssertEqual(summary.fileName, "session-1")
        XCTAssertEqual(summary.totalTokens, 1200)
        XCTAssertEqual(summary.lastTokens, 300)
    }

    func testSessionSummaryDoesNotUseFileNameAsTitleFallback() {
        let summary = UsageAnalytics.makeSessionSummary(
            usage: usage(total: 800, last: 120),
            timestamp: date(hour: 10, minute: 0),
            path: "/Users/demo/.codex/sessions/2026/06/15/3d0f34bc-2a1b-4f2b-a992-7d441753f8f2.jsonl",
            title: nil
        )

        XCTAssertEqual(summary.title, "未命名任务")
        XCTAssertEqual(summary.fileName, "3d0f34bc-2a1b-4f2b-a992-7d441753f8f2")
    }

    func testRanksSessionsByTotalThenRecencyAndLimits() {
        let older = date(hour: 10, minute: 0)
        let newer = date(hour: 11, minute: 0)
        let summaries = [
            SessionUsageSummary(path: "a", title: "a", fileName: "a", totalTokens: 100, lastTokens: 10, updatedAt: older),
            SessionUsageSummary(path: "b", title: "b", fileName: "b", totalTokens: 200, lastTokens: 20, updatedAt: older),
            SessionUsageSummary(path: "c", title: "c", fileName: "c", totalTokens: 200, lastTokens: 30, updatedAt: newer),
            SessionUsageSummary(path: "d", title: "d", fileName: "d", totalTokens: 50, lastTokens: 5, updatedAt: newer)
        ]

        let ranked = UsageAnalytics.rankedSessions(summaries, limit: 3)

        XCTAssertEqual(ranked.map(\.path), ["c", "b", "a"])
    }

    func testAppVersionComparesSemverTags() {
        XCTAssertTrue(AppVersion("v0.3.10") > AppVersion("0.3.9"))
        XCTAssertEqual(AppVersion("1.2"), AppVersion("1.2.0"))
        XCTAssertFalse(AppVersion("1.0.0-beta") > AppVersion("1.0.0"))
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(hour: Int, minute: Int) -> Date {
        DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 15, hour: hour, minute: minute).date!
    }

    private func usage(total: Int, last: Int) -> TokenUsageSnapshot {
        TokenUsageSnapshot(
            total: TokenUsage(inputTokens: total, cachedInputTokens: 0, outputTokens: 0, reasoningOutputTokens: 0, totalTokens: total),
            last: TokenUsage(inputTokens: last, cachedInputTokens: 0, outputTokens: 0, reasoningOutputTokens: 0, totalTokens: last)
        )
    }
}
