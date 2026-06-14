import Foundation

enum AppDefaults {
    enum Key {
        static let monitoringEnabled = "monitoringEnabled"
        static let completionSoundEnabled = "completionSoundEnabled"
        static let failureSoundEnabled = "failureSoundEnabled"
        static let commandFailureHeuristicEnabled = "commandFailureHeuristicEnabled"
        static let completionSoundPath = "completionSoundPath"
        static let failureSoundPath = "failureSoundPath"
        static let sessionsRootPath = "sessionsRootPath"
        static let volume = "volume"
        static let menuBarDisplayMode = "menuBarDisplayMode"
        static let primaryLimitWarningThreshold = "primaryLimitWarningThreshold"
        static let secondaryLimitWarningThreshold = "secondaryLimitWarningThreshold"
        static let quietHoursEnabled = "quietHoursEnabled"
        static let quietHoursStartMinute = "quietHoursStartMinute"
        static let quietHoursEndMinute = "quietHoursEndMinute"
        static let automaticUpdateChecksEnabled = "automaticUpdateChecksEnabled"
        static let lastUpdateCheckAt = "lastUpdateCheckAt"
        static let ignoredUpdateVersion = "ignoredUpdateVersion"
    }

    static var sessionsRootPath: String {
        URL(fileURLWithPath: codexHomePath)
            .appendingPathComponent("sessions")
            .path
    }

    static var codexHomePath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
            .path
    }

    static var defaultCompletionSoundPath: String {
        let codexSound = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Sounds/codex-notification.wav")
            .path

        if FileManager.default.fileExists(atPath: codexSound) {
            return codexSound
        }

        return "/System/Library/Sounds/Glass.aiff"
    }

    static let defaultFailureSoundPath = "/System/Library/Sounds/Basso.aiff"

    static func register() {
        UserDefaults.standard.register(defaults: [
            Key.monitoringEnabled: true,
            Key.completionSoundEnabled: true,
            Key.failureSoundEnabled: true,
            Key.commandFailureHeuristicEnabled: false,
            Key.completionSoundPath: defaultCompletionSoundPath,
            Key.failureSoundPath: defaultFailureSoundPath,
            Key.sessionsRootPath: sessionsRootPath,
            Key.volume: 0.8,
            Key.menuBarDisplayMode: MenuBarDisplayMode.graphic.rawValue,
            Key.primaryLimitWarningThreshold: 20.0,
            Key.secondaryLimitWarningThreshold: 20.0,
            Key.quietHoursEnabled: false,
            Key.quietHoursStartMinute: 22 * 60,
            Key.quietHoursEndMinute: 8 * 60,
            Key.automaticUpdateChecksEnabled: true,
            Key.lastUpdateCheckAt: 0.0,
            Key.ignoredUpdateVersion: ""
        ])
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case graphic
    case primaryPercent
    case secondaryPercent
    case recentTokens

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .graphic:
            return "仅图形"
        case .primaryPercent:
            return "5 小时"
        case .secondaryPercent:
            return "7 天"
        case .recentTokens:
            return "最近 token"
        }
    }
}
