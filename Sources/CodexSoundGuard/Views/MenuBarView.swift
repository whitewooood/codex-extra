import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarView: View {
    @EnvironmentObject private var monitor: SessionMonitor

    @AppStorage(AppDefaults.Key.monitoringEnabled) private var monitoringEnabled = true
    @AppStorage(AppDefaults.Key.completionSoundEnabled) private var completionSoundEnabled = true
    @AppStorage(AppDefaults.Key.failureSoundEnabled) private var failureSoundEnabled = true
    @AppStorage(AppDefaults.Key.commandFailureHeuristicEnabled) private var commandFailureHeuristicEnabled = false
    @AppStorage(AppDefaults.Key.completionSoundPath) private var completionSoundPath = AppDefaults.defaultCompletionSoundPath
    @AppStorage(AppDefaults.Key.failureSoundPath) private var failureSoundPath = AppDefaults.defaultFailureSoundPath
    @AppStorage(AppDefaults.Key.sessionsRootPath) private var sessionsRootPath = AppDefaults.sessionsRootPath
    @AppStorage(AppDefaults.Key.volume) private var volume = 0.8

    var body: some View {
        Toggle("Monitoring", isOn: $monitoringEnabled)
            .onChange(of: monitoringEnabled) { _ in
                monitor.applySettings()
            }

        Divider()

        Toggle("Completion sound", isOn: $completionSoundEnabled)
        Button("Test completion") {
            monitor.testCompletionSound()
        }
        Button("Choose completion sound...") {
            chooseSound(defaultKey: AppDefaults.Key.completionSoundPath)
        }
        Text(shortName(completionSoundPath))
            .font(.caption)
            .foregroundStyle(.secondary)

        Divider()

        Toggle("Failure sound", isOn: $failureSoundEnabled)
        Button("Test failure") {
            monitor.testFailureSound()
        }
        Button("Choose failure sound...") {
            chooseSound(defaultKey: AppDefaults.Key.failureSoundPath)
        }
        Text(shortName(failureSoundPath))
            .font(.caption)
            .foregroundStyle(.secondary)

        Divider()

        Slider(value: $volume, in: 0...1) {
            Text("Volume")
        }

        Toggle("Treat command exits as failure", isOn: $commandFailureHeuristicEnabled)

        Divider()

        Button("Reveal Codex sessions") {
            NSWorkspace.shared.open(URL(fileURLWithPath: sessionsRootPath))
        }
        Text("\(monitor.filesWatched) files watched")
            .font(.caption)
            .foregroundStyle(.secondary)
        Text(monitor.lastStatus)
            .font(.caption)
            .foregroundStyle(.secondary)

        Divider()

        Button("Quit") {
            NSApp.terminate(nil)
        }
    }

    private func chooseSound(defaultKey: String) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]

        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: defaultKey)
        }
    }

    private func shortName(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}
