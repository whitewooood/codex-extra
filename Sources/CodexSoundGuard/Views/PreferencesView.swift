import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @EnvironmentObject private var monitor: SessionMonitor

    @AppStorage(AppDefaults.Key.monitoringEnabled) private var monitoringEnabled = true
    @AppStorage(AppDefaults.Key.completionSoundEnabled) private var completionSoundEnabled = true
    @AppStorage(AppDefaults.Key.failureSoundEnabled) private var failureSoundEnabled = true
    @AppStorage(AppDefaults.Key.commandFailureHeuristicEnabled) private var commandFailureHeuristicEnabled = false
    @AppStorage(AppDefaults.Key.completionSoundPath) private var completionSoundPath = AppDefaults.defaultCompletionSoundPath
    @AppStorage(AppDefaults.Key.failureSoundPath) private var failureSoundPath = AppDefaults.defaultFailureSoundPath
    @AppStorage(AppDefaults.Key.volume) private var volume = 0.8
    @AppStorage(AppDefaults.Key.menuBarDisplayMode) private var menuBarDisplayMode = MenuBarDisplayMode.graphic.rawValue
    @AppStorage(AppDefaults.Key.primaryLimitWarningThreshold) private var primaryThreshold = 20.0
    @AppStorage(AppDefaults.Key.secondaryLimitWarningThreshold) private var secondaryThreshold = 20.0
    @AppStorage(AppDefaults.Key.quietHoursEnabled) private var quietHoursEnabled = false
    @AppStorage(AppDefaults.Key.quietHoursStartMinute) private var quietHoursStartMinute = 22 * 60
    @AppStorage(AppDefaults.Key.quietHoursEndMinute) private var quietHoursEndMinute = 8 * 60

    @State private var selectedPane = PreferencesPane.general
    @State private var loginItemInstalled = LoginItemManager.isInstalled
    @State private var loginItemMessage: String?

    var body: some View {
        HStack(spacing: 0) {
            PreferencesSidebar(
                selectedPane: $selectedPane,
                isRunning: monitor.isRunning,
                filesWatched: monitor.filesWatched
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PreferencesHeader(pane: selectedPane)

                    paneContent
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.regularMaterial)
        }
        .frame(width: 720, height: 500)
        .onAppear {
            loginItemInstalled = LoginItemManager.isInstalled
        }
        .onChange(of: monitoringEnabled) { _ in
            monitor.applySettings()
        }
    }

    @ViewBuilder
    private var paneContent: some View {
        switch selectedPane {
        case .general:
            generalPane
        case .sounds:
            soundsPane
        case .limits:
            limitsPane
        }
    }

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            PreferenceGroup(title: "运行状态", iconName: "waveform.path.ecg") {
                PreferenceToggleRow(
                    title: "监听 Codex 本地日志",
                    value: monitor.isRunning ? "运行中" : "已暂停",
                    isOn: $monitoringEnabled
                )

                PreferenceInfoRow(
                    title: "当前日志",
                    value: "\(monitor.filesWatched) 个文件 · \(monitor.recognizedEventCount) 个事件"
                )
            }

            PreferenceGroup(title: "菜单栏", iconName: "menubar.rectangle") {
                VStack(alignment: .leading, spacing: 8) {
                    PreferenceRowHeader(title: "显示模式", value: selectedDisplayMode.title)

                    Picker("菜单栏显示", selection: $menuBarDisplayMode) {
                        ForEach(MenuBarDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                PreferenceToggleRow(
                    title: "命令非 0 退出算失败",
                    value: commandFailureHeuristicEnabled ? "已开启" : "默认关闭",
                    isOn: $commandFailureHeuristicEnabled
                )
            }

            PreferenceGroup(title: "启动项", iconName: "power") {
                PreferenceToggleRow(
                    title: "登录时启动",
                    value: loginItemInstalled ? "已安装 LaunchAgent" : "未安装 LaunchAgent",
                    isOn: loginItemBinding
                )

                if let loginItemMessage {
                    Text(loginItemMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var soundsPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            PreferenceGroup(title: "音量", iconName: "speaker.wave.2") {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.1")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    Slider(value: $volume, in: 0...1)
                    Text("\(Int(volume * 100))%")
                        .font(.callout.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
                .frame(height: 28)
            }

            PreferenceGroup(title: "提醒声音", iconName: "bell.badge") {
                SoundPreferenceRow(
                    title: "完成提醒",
                    subtitle: "任务结束且未识别到失败时播放",
                    isEnabled: $completionSoundEnabled,
                    path: completionSoundPath,
                    testAction: { monitor.testCompletionSound() },
                    chooseAction: { chooseSound(defaultKey: AppDefaults.Key.completionSoundPath) }
                )

                SoundPreferenceRow(
                    title: "失败提醒",
                    subtitle: "任务结束且识别到失败时播放",
                    isEnabled: $failureSoundEnabled,
                    path: failureSoundPath,
                    testAction: { monitor.testFailureSound() },
                    chooseAction: { chooseSound(defaultKey: AppDefaults.Key.failureSoundPath) }
                )
            }

            PreferenceGroup(title: "安静时段", iconName: "moon.zzz") {
                PreferenceToggleRow(
                    title: "暂停提示音",
                    value: quietHoursEnabled ? quietHoursSummary : "关闭",
                    isOn: $quietHoursEnabled
                )

                HStack(spacing: 12) {
                    QuietHourPicker(title: "开始", selection: $quietHoursStartMinute)
                    QuietHourPicker(title: "结束", selection: $quietHoursEndMinute)
                }
                .disabled(!quietHoursEnabled)
                .opacity(quietHoursEnabled ? 1 : 0.46)

                Text("安静时段只会暂停自动完成/失败提示音；试听按钮仍会播放。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var limitsPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            PreferenceGroup(title: "剩余额度", iconName: "gauge.with.dots.needle.50percent") {
                ThresholdPreferenceRow(
                    title: "5 小时窗口",
                    value: $primaryThreshold
                )

                ThresholdPreferenceRow(
                    title: "7 天窗口",
                    value: $secondaryThreshold
                )
            }

            PreferenceGroup(title: "当前用量", iconName: "chart.bar.xaxis") {
                if let usage = monitor.latestUsage {
                    PreferenceInfoRow(
                        title: "最近 token",
                        value: UsageFormatter.tokenCount(usage.last.totalTokens)
                    )
                    PreferenceInfoRow(
                        title: "累计 token",
                        value: UsageFormatter.tokenCount(usage.total.totalTokens)
                    )
                    PreferenceInfoRow(
                        title: "上下文窗口",
                        value: UsageFormatter.contextWindow(usage.modelContextWindow)
                    )
                } else {
                    PreferenceInfoRow(title: "状态", value: "等待 Codex 用量事件")
                }
            }
        }
    }

    private var selectedDisplayMode: MenuBarDisplayMode {
        MenuBarDisplayMode(rawValue: menuBarDisplayMode) ?? .graphic
    }

    private var loginItemBinding: Binding<Bool> {
        Binding(
            get: { loginItemInstalled },
            set: { isEnabled in
                setLoginItem(isEnabled)
            }
        )
    }

    private var quietHoursSummary: String {
        "\(Self.timeLabel(for: quietHoursStartMinute)) - \(Self.timeLabel(for: quietHoursEndMinute))"
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

    private func setLoginItem(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try LoginItemManager.install()
                loginItemMessage = "登录项已安装。"
            } else {
                try LoginItemManager.uninstall()
                loginItemMessage = "登录项已移除。"
            }
            loginItemInstalled = LoginItemManager.isInstalled
        } catch {
            loginItemMessage = error.localizedDescription
            loginItemInstalled = LoginItemManager.isInstalled
        }
    }

    private static func timeLabel(for minuteOfDay: Int) -> String {
        String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }
}

private enum PreferencesPane: String, CaseIterable, Identifiable {
    case general
    case sounds
    case limits

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .general:
            return "通用"
        case .sounds:
            return "声音"
        case .limits:
            return "额度"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "监听、菜单栏与启动项"
        case .sounds:
            return "完成与失败提醒"
        case .limits:
            return "阈值与当前用量"
        }
    }

    var iconName: String {
        switch self {
        case .general:
            return "switch.2"
        case .sounds:
            return "speaker.wave.2"
        case .limits:
            return "gauge.with.dots.needle.50percent"
        }
    }
}

private struct PreferencesSidebar: View {
    @Binding var selectedPane: PreferencesPane
    let isRunning: Bool
    let filesWatched: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Codex Monitor")
                    .font(.headline.weight(.semibold))
                Text("设置")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            VStack(spacing: 4) {
                ForEach(PreferencesPane.allCases) { pane in
                    SidebarButton(
                        pane: pane,
                        isSelected: pane == selectedPane
                    ) {
                        selectedPane = pane
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.primary.opacity(isRunning ? 0.68 : 0.28))
                    .frame(width: 7, height: 7)
                Text(isRunning ? "监听中" : "已暂停")
                    .font(.caption.weight(.medium))
                Spacer()
                Text("\(filesWatched)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding([.horizontal, .bottom], 10)
        }
        .frame(width: 190)
        .background(.bar)
    }
}

private struct SidebarButton: View {
    let pane: PreferencesPane
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: pane.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(pane.title)
                        .font(.callout.weight(.medium))
                    Text(pane.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
        .background(selectionBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var selectionBackground: Color {
        isSelected ? Color.accentColor.opacity(0.16) : Color.clear
    }
}

private struct PreferencesHeader: View {
    let pane: PreferencesPane

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: pane.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(pane.title)
                    .font(.title3.weight(.semibold))
                Text(pane.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PreferenceGroup<Content: View>: View {
    let title: String
    let iconName: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(12)
            .background(.quaternary.opacity(0.42), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.separator.opacity(0.22), lineWidth: 1)
            }
        }
    }
}

private struct PreferenceRowHeader: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.callout.weight(.medium))
            Spacer(minLength: 16)
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct PreferenceInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        PreferenceRowHeader(title: title, value: value)
            .frame(minHeight: 30)
    }
}

private struct PreferenceToggleRow: View {
    let title: String
    let value: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .frame(minHeight: 34)
    }
}

private struct SoundPreferenceRow: View {
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool
    let path: String
    let testAction: () -> Void
    let chooseAction: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.medium))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)
            }

            HStack(spacing: 8) {
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: testAction) {
                    Label("试听", systemImage: "play.fill")
                }
                .disabled(!isEnabled)

                Button(action: chooseAction) {
                    Label("选择", systemImage: "folder")
                }
            }
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

private struct QuietHourPicker: View {
    let title: String
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(title, selection: $selection) {
                ForEach(Self.timeOptions, id: \.self) { minute in
                    Text(Self.timeLabel(for: minute)).tag(minute)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
    }

    private static let timeOptions = Array(stride(from: 0, through: 23 * 60 + 30, by: 30))

    private static func timeLabel(for minuteOfDay: Int) -> String {
        String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }
}

private struct ThresholdPreferenceRow: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PreferenceRowHeader(title: title, value: "\(Int(value))%")

            HStack(spacing: 10) {
                Slider(value: $value, in: 5...80, step: 5)

                ProgressView(value: value, total: 100)
                    .frame(width: 74)
            }
        }
        .padding(.vertical, 4)
    }
}
