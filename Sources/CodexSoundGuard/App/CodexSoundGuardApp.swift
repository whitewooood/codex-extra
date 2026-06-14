import AppKit
import CodexSoundGuardCore
import SwiftUI

@main
struct CodexSoundGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor: SessionMonitor

    init() {
        AppDefaults.register()
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
        CodexUsageMeter(statusTint: statusTint, usage: latestUsage)
    }

    private var statusTint: Color {
        guard isRunning else {
            return .secondary
        }

        switch outcome {
        case .completed:
            return .green
        case .failed:
            return .red
        case nil:
            return .accentColor
        }
    }

}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
