import Foundation

public struct AppVersion: Comparable, CustomStringConvertible, Equatable {
    public let rawValue: String
    private let components: [Int]

    public init(_ rawValue: String) {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
        self.rawValue = normalized.isEmpty ? "0.0.0" : normalized
        self.components = self.rawValue
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            .first?
            .split(separator: ".")
            .map { Int($0) ?? 0 } ?? [0]
    }

    public var description: String {
        rawValue
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
