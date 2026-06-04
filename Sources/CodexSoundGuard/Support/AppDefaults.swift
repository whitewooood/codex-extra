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
            Key.volume: 0.8
        ])
    }
}
