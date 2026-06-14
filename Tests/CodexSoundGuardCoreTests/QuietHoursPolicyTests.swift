import XCTest
@testable import CodexSoundGuardCore

final class QuietHoursPolicyTests: XCTestCase {
    func testInactiveWhenDisabled() {
        let policy = QuietHoursPolicy(enabled: false, startMinute: 22 * 60, endMinute: 8 * 60)

        XCTAssertFalse(policy.isActive(at: date(hour: 23, minute: 0), calendar: calendar))
    }

    func testSameStartAndEndMeansAllDayQuiet() {
        let policy = QuietHoursPolicy(enabled: true, startMinute: 8 * 60, endMinute: 8 * 60)

        XCTAssertTrue(policy.isActive(at: date(hour: 12, minute: 0), calendar: calendar))
    }

    func testDaytimeRange() {
        let policy = QuietHoursPolicy(enabled: true, startMinute: 9 * 60, endMinute: 17 * 60)

        XCTAssertFalse(policy.isActive(at: date(hour: 8, minute: 59), calendar: calendar))
        XCTAssertTrue(policy.isActive(at: date(hour: 9, minute: 0), calendar: calendar))
        XCTAssertTrue(policy.isActive(at: date(hour: 16, minute: 59), calendar: calendar))
        XCTAssertFalse(policy.isActive(at: date(hour: 17, minute: 0), calendar: calendar))
    }

    func testOvernightRange() {
        let policy = QuietHoursPolicy(enabled: true, startMinute: 22 * 60, endMinute: 8 * 60)

        XCTAssertTrue(policy.isActive(at: date(hour: 23, minute: 30), calendar: calendar))
        XCTAssertTrue(policy.isActive(at: date(hour: 7, minute: 59), calendar: calendar))
        XCTAssertFalse(policy.isActive(at: date(hour: 8, minute: 0), calendar: calendar))
        XCTAssertFalse(policy.isActive(at: date(hour: 12, minute: 0), calendar: calendar))
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(hour: Int, minute: Int) -> Date {
        DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 15, hour: hour, minute: minute).date!
    }
}
