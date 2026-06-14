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
        HStack(spacing: 4) {
            CodexMark(statusTint: statusTint, size: 17)

            if let usageText {
                Text(usageText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .fixedSize()
        .accessibilityLabel(accessibilityLabel)
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

    private var usageText: String? {
        UsageFormatter.menuBarSummary(latestUsage)
    }

    private var accessibilityLabel: String {
        if let usageText {
            return "Codex 声音提醒，当前用量 \(usageText)"
        }
        return "Codex 声音提醒"
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
