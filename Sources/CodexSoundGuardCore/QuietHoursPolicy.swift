import Foundation

public struct QuietHoursPolicy: Equatable {
    public let enabled: Bool
    public let startMinute: Int
    public let endMinute: Int

    public init(enabled: Bool, startMinute: Int, endMinute: Int) {
        self.enabled = enabled
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    public func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled else {
            return false
        }

        let start = Self.clampedMinute(startMinute)
        let end = Self.clampedMinute(endMinute)
        guard start != end else {
            return true
        }

        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)

        if start < end {
            return currentMinute >= start && currentMinute < end
        }

        return currentMinute >= start || currentMinute < end
    }

    private static func clampedMinute(_ minute: Int) -> Int {
        max(0, min(23 * 60 + 59, minute))
    }
}
