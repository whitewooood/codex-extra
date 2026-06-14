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
            MenuBarIconLabel(isRunning: monitor.isRunning, outcome: monitor.lastOutcome)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarIconLabel: View {
    let isRunning: Bool
    let outcome: TurnOutcome?

    var body: some View {
        Image(systemName: "terminal")
            .font(.system(size: 13, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(statusTint)
                    .frame(width: 5, height: 5)
                    .offset(x: 2, y: 1)
            }
            .accessibilityLabel("Codex 声音提醒")
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
