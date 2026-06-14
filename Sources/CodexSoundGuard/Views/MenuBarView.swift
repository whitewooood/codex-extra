import AppKit
import CodexSoundGuardCore
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
        VStack(alignment: .leading, spacing: 10) {
            header
            statusStrip
            usagePanel
            soundPanel
            footer
        }
        .padding(14)
        .frame(width: 384)
        .background(.regularMaterial)
        .controlSize(.small)
    }

    private var header: some View {
        HStack(spacing: 11) {
            CodexMark(statusTint: statusTint, size: 30, showsStatus: false)

            VStack(alignment: .leading, spacing: 2) {
                Text("Codex 声音提醒")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(statusSubheading)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $monitoringEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .onChange(of: monitoringEnabled) { _ in
                    monitor.applySettings()
                }
        }
    }

    private var statusStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Circle()
                    .fill(statusTint)
                    .frame(width: 7, height: 7)

                Text(statusLine)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Text("\(monitor.filesWatched) 日志 · \(monitor.recognizedEventCount) 事件")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(monitor.lastStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(monitor.lastEventStatus)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator.opacity(0.32), lineWidth: 1)
        }
    }

    private var usagePanel: some View {
        Surface {
            VStack(alignment: .leading, spacing: 11) {
                SectionHeader(
                    title: "Codex 用量",
                    iconName: "chart.line.uptrend.xyaxis",
                    trailing: usageHeaderValue
                )

                if let usage = monitor.latestUsage {
                    TokenSummaryRow(usage: usage, formatTokenCount: formatTokenCount, formatContextWindow: formatContextWindow)

                    VStack(spacing: 7) {
                        RateLimitRow(title: "5 小时窗口", limit: usage.primaryRateLimit, tint: .accentColor)
                        RateLimitRow(title: "7 天窗口", limit: usage.secondaryRateLimit, tint: .secondary)
                    }
                } else {
                    EmptyStateLine(iconName: "hourglass", text: "等待 Codex 写入用量事件")
                }
            }
        }
    }

    private var soundPanel: some View {
        Surface {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(
                    title: "提醒音",
                    iconName: "speaker.wave.2",
                    trailing: "\(Int(volume * 100))%"
                )

                Slider(value: $volume, in: 0...1)

                VStack(spacing: 6) {
                    SoundRow(
                        title: "完成",
                        iconName: "checkmark",
                        isEnabled: $completionSoundEnabled,
                        soundName: shortName(completionSoundPath),
                        testLabel: "试听完成提醒",
                        chooseLabel: "选择完成提醒声音",
                        testAction: { monitor.testCompletionSound() },
                        chooseAction: { chooseSound(defaultKey: AppDefaults.Key.completionSoundPath) }
                    )

                    SoundRow(
                        title: "失败",
                        iconName: "xmark",
                        isEnabled: $failureSoundEnabled,
                        soundName: shortName(failureSoundPath),
                        testLabel: "试听失败提醒",
                        chooseLabel: "选择失败提醒声音",
                        testAction: { monitor.testFailureSound() },
                        chooseAction: { chooseSound(defaultKey: AppDefaults.Key.failureSoundPath) }
                    )
                }

                Divider()
                    .padding(.vertical, 1)

                Toggle(isOn: $commandFailureHeuristicEnabled) {
                    Text("命令非 0 退出也算失败")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .toggleStyle(.switch)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            FooterAction(title: "日志", iconName: "folder") {
                NSWorkspace.shared.open(URL(fileURLWithPath: sessionsRootPath))
            }

            FooterAction(title: "目录", iconName: "terminal") {
                NSWorkspace.shared.open(URL(fileURLWithPath: AppDefaults.codexHomePath))
            }

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(QuietIconButtonStyle(role: .destructive))
            .help("退出")
        }
        .padding(.top, 1)
    }

    private var statusSubheading: String {
        monitor.isRunning ? "完成、失败时播放本地声音" : "提醒已暂停，点击开关恢复"
    }

    private var statusLine: String {
        let prefix = monitor.isRunning ? "监听中" : "已暂停"
        return "\(prefix) · \(lastOutcomeLabel)"
    }

    private var usageHeaderValue: String {
        guard let usage = monitor.latestUsage else {
            return "--"
        }
        return "最近 \(formatTokenCount(usage.last.totalTokens))"
    }

    private var lastOutcomeLabel: String {
        switch monitor.lastOutcome {
        case .completed:
            return "最近完成"
        case .failed:
            return "最近失败"
        case nil:
            return "等待事件"
        }
    }

    private var statusTint: Color {
        guard monitor.isRunning else {
            return .secondary
        }

        switch monitor.lastOutcome {
        case .completed:
            return .green
        case .failed:
            return .red
        case nil:
            return .accentColor
        }
    }

    private func chooseSound(defaultKey: String) {
        let panel = NSOpenPanel()
        panel.title = "选择提醒声音"
        panel.prompt = "选择"
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

    private func formatTokenCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    private func formatContextWindow(_ value: Int?) -> String {
        guard let value else {
            return "--"
        }
        return formatTokenCount(value)
    }
}

private struct Surface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.separator.opacity(0.34), lineWidth: 1)
            }
    }
}

private struct SectionHeader: View {
    let title: String
    let iconName: String
    let trailing: String

    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: iconName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer()

            Text(trailing)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct EmptyStateLine: View {
    let iconName: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

private struct TokenSummaryRow: View {
    let usage: TokenUsageSnapshot
    let formatTokenCount: (Int) -> String
    let formatContextWindow: (Int?) -> String

    var body: some View {
        HStack(spacing: 0) {
            TokenMetric(title: "累计", value: formatTokenCount(usage.total.totalTokens))
            Divider()
                .padding(.horizontal, 10)
            TokenMetric(title: "最近", value: formatTokenCount(usage.last.totalTokens))
            Divider()
                .padding(.horizontal, 10)
            TokenMetric(title: "上下文", value: formatContextWindow(usage.modelContextWindow))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.quaternary.opacity(0.62), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct TokenMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RateLimitRow: View {
    let title: String
    let limit: UsageRateLimit?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(valueText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ProgressView(value: progressValue, total: 100)
                .tint(tint)
                .help(resetText)
        }
    }

    private var progressValue: Double {
        guard let limit else {
            return 0
        }
        return max(0, min(limit.usedPercent, 100))
    }

    private var valueText: String {
        guard let limit else {
            return "--"
        }

        let percent = limit.usedPercent.rounded()
        return "\(Int(percent))% · \(resetText)"
    }

    private var resetText: String {
        guard let resetDate = limit?.resetsAt else {
            return "重置 --"
        }
        return "重置 \(Self.resetFormatter.string(from: resetDate))"
    }

    private static let resetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct SoundRow: View {
    let title: String
    let iconName: String
    @Binding var isEnabled: Bool
    let soundName: String
    let testLabel: String
    let chooseLabel: String
    let testAction: () -> Void
    let chooseAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isEnabled ? .primary : .secondary)
                .frame(width: 22, height: 22)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(soundName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)

            SoundIconButton(iconName: "play.fill", help: testLabel, action: testAction)
            SoundIconButton(iconName: "music.note.list", help: chooseLabel, action: chooseAction)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct SoundIconButton: View {
    let iconName: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(QuietIconButtonStyle())
        .help(help)
    }
}

private struct FooterAction: View {
    let title: String
    let iconName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: iconName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 9)
                .frame(height: 24)
        }
        .buttonStyle(QuietCapsuleButtonStyle())
    }
}

private struct QuietIconButtonStyle: ButtonStyle {
    enum Role {
        case normal
        case destructive
    }

    var role: Role = .normal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(background(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var foreground: Color {
        switch role {
        case .normal:
            return .secondary
        case .destructive:
            return .red
        }
    }

    private func background(isPressed: Bool) -> Color {
        switch role {
        case .normal:
            return Color.secondary.opacity(isPressed ? 0.16 : 0.08)
        case .destructive:
            return Color.red.opacity(isPressed ? 0.16 : 0.08)
        }
    }
}

private struct QuietCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary)
            .background(Color.secondary.opacity(configuration.isPressed ? 0.16 : 0.08), in: Capsule())
    }
}
