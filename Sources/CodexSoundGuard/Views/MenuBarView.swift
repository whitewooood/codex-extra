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
        VStack(alignment: .leading, spacing: 12) {
            header
            diagnostics
            reminderGrid
            preferencesPanel
            footer
        }
        .padding(14)
        .frame(width: 388)
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

    private var reminderGrid: some View {
        HStack(alignment: .top, spacing: 10) {
            ReminderTile(
                title: "完成",
                detail: "任务结束播放",
                iconName: "checkmark.circle.fill",
                tint: .green,
                isEnabled: $completionSoundEnabled,
                soundName: shortName(completionSoundPath),
                testLabel: "试听完成提醒",
                chooseLabel: "选择完成提醒声音",
                testAction: { monitor.testCompletionSound() },
                chooseAction: { chooseSound(defaultKey: AppDefaults.Key.completionSoundPath) }
            )

            ReminderTile(
                title: "失败",
                detail: "含受阻推断",
                iconName: "exclamationmark.triangle.fill",
                tint: .red,
                isEnabled: $failureSoundEnabled,
                soundName: shortName(failureSoundPath),
                testLabel: "试听失败提醒",
                chooseLabel: "选择失败提醒声音",
                testAction: { monitor.testFailureSound() },
                chooseAction: { chooseSound(defaultKey: AppDefaults.Key.failureSoundPath) }
            )
        }
    }

    private var preferencesPanel: some View {
        Surface {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Label("策略与音量", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(volume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Slider(value: $volume, in: 0...1)

                Divider()

                Toggle(isOn: $commandFailureHeuristicEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("命令非 0 退出也算失败")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text("适合让 Codex 执行命令、测试或构建时使用")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
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

private struct ReminderTile: View {
    let title: String
    let detail: String
    let iconName: String
    let tint: Color
    @Binding var isEnabled: Bool
    let soundName: String
    let testLabel: String
    let chooseLabel: String
    let testAction: () -> Void
    let chooseAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(isEnabled ? 0.16 : 0.08))
                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isEnabled ? tint : .secondary)
                }
                .frame(width: 32, height: 32)

                Spacer(minLength: 4)

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(title)提醒")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            SoundPill(soundName: soundName)

            HStack(spacing: 7) {
                Button(action: testAction) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(IconButtonStyle(tint: tint))
                .help(testLabel)

                Button(action: chooseAction) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(IconButtonStyle(tint: .secondary))
                .help(chooseLabel)

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        }
    }

    private var borderColor: Color {
        isEnabled ? tint.opacity(0.30) : Color.secondary.opacity(0.18)
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
