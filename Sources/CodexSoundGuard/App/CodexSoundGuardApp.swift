import AppKit
import CodexSoundGuardCore
import Foundation
import SwiftUI

@main
struct CodexSoundGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor: SessionMonitor
    @StateObject private var updateChecker: UpdateChecker

    init() {
        AppDefaults.register()
        if ProcessInfo.processInfo.arguments.contains("--render-docs-assets") {
            do {
                try DocumentationAssetRenderer.render()
                Foundation.exit(0)
            } catch {
                fputs("failed to render documentation assets: \(error)\n", stderr)
                Foundation.exit(1)
            }
        }
        _monitor = StateObject(wrappedValue: SessionMonitor())
        _updateChecker = StateObject(wrappedValue: UpdateChecker.shared)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(monitor)
                .environmentObject(updateChecker)
        } label: {
            MenuBarIconLabel(
                isRunning: monitor.isRunning,
                outcome: monitor.lastOutcome,
                latestUsage: monitor.latestUsage
            )
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("检查更新...") {
                    updateChecker.checkManually()
                }
            }
        }
    }
}

private struct MenuBarIconLabel: View {
    @AppStorage(AppDefaults.Key.menuBarDisplayMode) private var displayMode = MenuBarDisplayMode.graphic.rawValue

    let isRunning: Bool
    let outcome: TurnOutcome?
    let latestUsage: TokenUsageSnapshot?

    var body: some View {
        HStack(spacing: 4) {
            CodexUsageMeter(statusIntensity: statusIntensity, usage: latestUsage)

            if let text = displayText {
                Text(text)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
            }
        }
    }

    private var displayText: String? {
        let mode = MenuBarDisplayMode(rawValue: displayMode) ?? .graphic
        switch mode {
        case .graphic:
            return nil
        case .primaryPercent:
            return latestUsage?.primaryRateLimit.map { "5h \(UsageFormatter.percent($0.usedPercent))" } ?? "5h --"
        case .secondaryPercent:
            return latestUsage?.secondaryRateLimit.map { "7d \(UsageFormatter.percent($0.usedPercent))" } ?? "7d --"
        case .recentTokens:
            return latestUsage.map { UsageFormatter.tokenCount($0.last.totalTokens) } ?? "--"
        }
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
        Task { @MainActor in
            UpdateChecker.shared.checkAutomaticallyIfNeeded()
        }
    }
}
