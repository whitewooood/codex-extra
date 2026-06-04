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
            statusPanel

            SoundSettingPanel(
                title: "完成提醒",
                detail: "任务完成时播放",
                iconName: "checkmark.circle.fill",
                tint: .green,
                isEnabled: $completionSoundEnabled,
                soundName: shortName(completionSoundPath),
                testAction: { monitor.testCompletionSound() },
                chooseAction: { chooseSound(defaultKey: AppDefaults.Key.completionSoundPath) }
            )

            SoundSettingPanel(
                title: "失败提醒",
                detail: "任务失败或受阻时播放",
                iconName: "exclamationmark.triangle.fill",
                tint: .red,
                isEnabled: $failureSoundEnabled,
                soundName: shortName(failureSoundPath),
                testAction: { monitor.testFailureSound() },
                chooseAction: { chooseSound(defaultKey: AppDefaults.Key.failureSoundPath) }
            )

            preferencesPanel
            footer
        }
        .padding(14)
        .frame(width: 360)
        .background(.regularMaterial)
        .controlSize(.small)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(statusTint.opacity(0.18))
                Image(systemName: monitor.menuIconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(statusTint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("Codex 声音提醒")
                    .font(.headline)
                Text("完成、失败时直接播放本地声音")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $monitoringEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .onChange(of: monitoringEnabled) { _ in
                    monitor.applySettings()
                }
        }
    }

    private var statusPanel: some View {
        Panel {
            HStack(alignment: .center, spacing: 10) {
                StatusDot(tint: statusTint, isActive: monitor.isRunning)

                VStack(alignment: .leading, spacing: 2) {
                    Text(monitor.isRunning ? "正在监听" : "监听暂停")
                        .font(.subheadline.weight(.semibold))
                    Text(monitor.lastStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                MetricPill(iconName: "doc.text.magnifyingglass", text: "\(monitor.filesWatched) 个日志")
            }
        }
    }

    private var preferencesPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("音量", systemImage: "speaker.wave.2.fill")
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
                        Text("默认关闭，避免探索性命令误触发")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: sessionsRootPath))
            } label: {
                Label("打开日志", systemImage: "folder")
            }
            .buttonStyle(SoftButtonStyle())

            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: AppDefaults.codexHomePath))
            } label: {
                Label("Codex 目录", systemImage: "terminal")
            }
            .buttonStyle(SoftButtonStyle())

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
            }
            .buttonStyle(SoftButtonStyle(role: .destructive))
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

private struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.separator.opacity(0.45))
            }
    }
}

private struct SoundSettingPanel: View {
    let title: String
    let detail: String
    let iconName: String
    let tint: Color
    @Binding var isEnabled: Bool
    let soundName: String
    let testAction: () -> Void
    let chooseAction: () -> Void

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 10) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack(spacing: 8) {
                    MetricPill(iconName: "music.note", text: soundName)

                    Spacer(minLength: 8)

                    Button(action: testAction) {
                        Label("试听", systemImage: "play.fill")
                    }
                    .buttonStyle(SoftButtonStyle(tint: tint))

                    Button(action: chooseAction) {
                        Label("选择", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(SoftButtonStyle())
                }
            }
        }
    }
}

private struct StatusDot: View {
    let tint: Color
    let isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(isActive ? 0.18 : 0.08))
                .frame(width: 22, height: 22)
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
        }
    }
}

private struct MetricPill: View {
    let iconName: String
    let text: String

    var body: some View {
        Label(text, systemImage: iconName)
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
    }
}

private struct SoftButtonStyle: ButtonStyle {
    enum Role {
        case normal
        case destructive
    }

    var tint: Color = .accentColor
    var role: Role = .normal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .foregroundStyle(role == .destructive ? .red : tint)
            .background(backgroundColor(isPressed: configuration.isPressed), in: Capsule())
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        let base = role == .destructive ? Color.red : tint
        return base.opacity(isPressed ? 0.18 : 0.10)
    }
}
