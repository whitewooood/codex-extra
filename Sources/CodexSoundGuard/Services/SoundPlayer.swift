import AppKit
import Foundation
import OSLog

@MainActor
final class SoundPlayer {
    private let logger = Logger(subsystem: "com.whitewood.codex-monitor", category: "sound")
    private var activeSounds: [NSSound] = []

    func play(path: String, volume: Double) {
        let sound = makeSound(path: path)
        guard let sound else {
            logger.warning("Sound unavailable, falling back to beep: \(path, privacy: .public)")
            NSSound.beep()
            return
        }

        sound.volume = Float(max(0, min(volume, 1)))
        activeSounds.append(sound)
        logger.info("Playing sound: \(path, privacy: .public)")
        sound.play()

        let lifetime = max(sound.duration, 0.5) + 1
        DispatchQueue.main.asyncAfter(deadline: .now() + lifetime) { [weak self, weak sound] in
            guard let self, let sound else {
                return
            }
            self.activeSounds.removeAll { $0 === sound }
        }
    }

    private func makeSound(path: String) -> NSSound? {
        if FileManager.default.fileExists(atPath: path) {
            return NSSound(contentsOfFile: path, byReference: true)
        }

        return NSSound(named: NSSound.Name(path))
    }
}
