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
        VStack(alignment: .leading, spacing: 12) {
            header
            usagePanel
            diagnostics
            soundPanel
            footer
        }
        .padding(14)
        .frame(width: 392)
        .background(.regularMaterial)
        .controlSize(.small)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusTint.opacity(0.16))
                    Circle()
                        .strokeBorder(statusTint.opacity(0.28), lineWidth: 1)
                    Image(systemName: monitor.menuIconName)
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(statusTint)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
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

            HStack(spacing: 8) {
                StatusBadge(
                    title: monitor.isRunning ? "监听中" : "已暂停",
                    iconName: monitor.isRunning ? "dot.radiowaves.left.and.right" : "pause.fill",
                    tint: statusTint
                )

                StatusBadge(
                    title: lastOutcomeLabel,
                    iconName: lastOutcomeIcon,
                    tint: statusTint
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(monitor.lastStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(monitor.lastEventStatus)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(statusTint.opacity(0.11))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(statusTint.opacity(0.22), lineWidth: 1)
        }
    }

    private var diagnostics: some View {
        HStack(spacing: 8) {
            DiagnosticMetric(
                title: "日志",
                value: "\(monitor.filesWatched)",
                iconName: "doc.text.magnifyingglass",
                tint: .blue
            )

            DiagnosticMetric(
                title: "事件",
                value: "\(monitor.recognizedEventCount)",
                iconName: "waveform.path.ecg",
                tint: .purple
            )

            DiagnosticMetric(
                title: "音量",
                value: "\(Int(volume * 100))%",
                iconName: "speaker.wave.2.fill",
                tint: .orange
            )
        }
    }

    private var usagePanel: some View {
        Surface {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Label("Codex 用量", systemImage: "chart.bar.xaxis")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(usageHeaderValue)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let usage = monitor.latestUsage {
                    HStack(spacing: 8) {
                        UsageNumber(title: "累计", value: formatTokenCount(usage.total.totalTokens), iconName: "sum", tint: .blue)
                        UsageNumber(title: "最近", value: formatTokenCount(usage.last.totalTokens), iconName: "bolt.fill", tint: .green)
                        UsageNumber(title: "上下文", value: formatContextWindow(usage.modelContextWindow), iconName: "square.stack.3d.up", tint: .purple)
                    }

                    VStack(spacing: 8) {
                        RateLimitRow(title: "5 小时窗口", limit: usage.primaryRateLimit, tint: .blue)
                        RateLimitRow(title: "7 天窗口", limit: usage.secondaryRateLimit, tint: .purple)
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("等待 Codex 写入用量事件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var soundPanel: some View {
        Surface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Label("提醒音", systemImage: "speaker.wave.2.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(volume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Slider(value: $volume, in: 0...1)

                SoundRow(
                    title: "完成",
                    iconName: "checkmark.circle.fill",
                    tint: .green,
                    isEnabled: $completionSoundEnabled,
                    soundName: shortName(completionSoundPath),
                    testLabel: "试听完成提醒",
                    chooseLabel: "选择完成提醒声音",
                    testAction: { monitor.testCompletionSound() },
                    chooseAction: { chooseSound(defaultKey: AppDefaults.Key.completionSoundPath) }
                )

                SoundRow(
                    title: "失败",
                    iconName: "exclamationmark.triangle.fill",
                    tint: .red,
                    isEnabled: $failureSoundEnabled,
                    soundName: shortName(failureSoundPath),
                    testLabel: "试听失败提醒",
                    chooseLabel: "选择失败提醒声音",
                    testAction: { monitor.testFailureSound() },
                    chooseAction: { chooseSound(defaultKey: AppDefaults.Key.failureSoundPath) }
                )

                Divider()

                Toggle(isOn: $commandFailureHeuristicEnabled) {
                    Text("命令非 0 退出也算失败")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                .toggleStyle(.switch)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            FooterAction(title: "日志", iconName: "folder", tint: .blue) {
                NSWorkspace.shared.open(URL(fileURLWithPath: sessionsRootPath))
            }

            FooterAction(title: "目录", iconName: "terminal", tint: .secondary) {
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
            .buttonStyle(IconButtonStyle(tint: .red))
            .help("退出")
        }
    }

    private var statusSubheading: String {
        monitor.isRunning ? "完成、失败时播放本地声音" : "提醒已暂停，点击开关恢复"
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

    private var lastOutcomeIcon: String {
        switch monitor.lastOutcome {
        case .completed:
            return "checkmark"
        case .failed:
            return "xmark"
        case nil:
            return "clock"
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
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.separator.opacity(0.42), lineWidth: 1)
            }
    }
}

private struct StatusBadge: View {
    let title: String
    let iconName: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: iconName)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct DiagnosticMetric: View {
    let title: String
    let value: String
    let iconName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(.separator.opacity(0.36), lineWidth: 1)
        }
    }
}

private struct UsageNumber: View {
    let title: String
    let value: String
    let iconName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
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
                    .foregroundStyle(tint)
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
    let tint: Color
    @Binding var isEnabled: Bool
    let soundName: String
    let testLabel: String
    let chooseLabel: String
    let testAction: () -> Void
    let chooseAction: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isEnabled ? tint : .secondary)
                    .frame(width: 18)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            HStack(spacing: 7) {
                SoundPill(soundName: soundName)

                SoundIconButton(iconName: "play.fill", tint: tint, help: testLabel, action: testAction)
                SoundIconButton(iconName: "music.note.list", tint: .secondary, help: chooseLabel, action: chooseAction)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        }
    }

    private var borderColor: Color {
        isEnabled ? tint.opacity(0.30) : Color.secondary.opacity(0.18)
    }
}

private struct SoundIconButton: View {
    let iconName: String
    let tint: Color
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(IconButtonStyle(tint: tint))
        .help(help)
    }
}

private struct SoundPill: View {
    let soundName: String

    var body: some View {
        Label(soundName, systemImage: "music.note")
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: Capsule())
    }
}

private struct FooterAction: View {
    let title: String
    let iconName: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: iconName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 9)
                .frame(height: 24)
        }
        .buttonStyle(FooterButtonStyle(tint: tint))
    }
}

private struct IconButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .background(tint.opacity(configuration.isPressed ? 0.18 : 0.10), in: Circle())
    }
}

private struct FooterButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .background(tint.opacity(configuration.isPressed ? 0.18 : 0.10), in: Capsule())
    }
}
