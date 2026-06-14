import AppKit
import CodexSoundGuardCore
import Foundation
import SwiftUI

@main
struct CodexSoundGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor: SessionMonitor

    init() {
        AppDefaults.register()
        if CommandLine.arguments.contains("--render-docs-assets") {
            do {
                try DocumentationAssetRenderer.render()
                Foundation.exit(0)
            } catch {
                fputs("failed to render documentation assets: \(error)\n", stderr)
                Foundation.exit(1)
            }
        }
        _monitor = StateObject(wrappedValue: SessionMonitor())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(monitor)
        } label: {
            MenuBarIconLabel(
                isRunning: monitor.isRunning,
                outcome: monitor.lastOutcome,
                latestUsage: monitor.latestUsage
            )
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarIconLabel: View {
    let isRunning: Bool
    let outcome: TurnOutcome?
    let latestUsage: TokenUsageSnapshot?

    var body: some View {
        CodexUsageMeter(statusIntensity: statusIntensity, usage: latestUsage)
    }

    private var statusIntensity: Double {
        guard isRunning else {
            return 0.28
        }

        switch outcome {
        case .completed:
            return 0.70
        case .failed:
            return 1.0
        case nil:
            return 0.52
        }
    }

}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
