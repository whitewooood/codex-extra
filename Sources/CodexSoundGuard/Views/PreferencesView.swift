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
                VStack(alignment: .leading, spacing: 22) {
                    PreferencesHeader(pane: selectedPane)

                    paneContent
                }
                .frame(maxWidth: 520, alignment: .leading)
                .padding(.horizontal, 34)
                .padding(.vertical, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 740, height: 520)
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
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(title: "运行") {
                SettingsToggleRow(
                    title: "监听 Codex 本地日志",
                    detail: monitor.isRunning ? "运行中" : "已暂停",
                    isOn: $monitoringEnabled
                )

                SettingsValueRow(
                    title: "当前日志",
                    value: "\(monitor.filesWatched) 个文件 · \(monitor.recognizedEventCount) 个事件"
                )
            }

            SettingsSection(title: "菜单栏") {
                SettingsPickerRow(
                    title: "显示模式",
                    value: selectedDisplayMode.title
                ) {
                    Picker("菜单栏显示", selection: $menuBarDisplayMode) {
                        ForEach(MenuBarDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 288)
                }

                SettingsToggleRow(
                    title: "命令非 0 退出算失败",
                    detail: commandFailureHeuristicEnabled ? "已开启" : "默认关闭",
                    isOn: $commandFailureHeuristicEnabled
                )
            }

            SettingsSection(title: "启动") {
                SettingsToggleRow(
                    title: "登录时启动",
                    detail: loginItemInstalled ? "LaunchAgent 已安装" : "LaunchAgent 未安装",
                    isOn: loginItemBinding
                )

                if let loginItemMessage {
                    SettingsFootnote(text: loginItemMessage)
                }
            }
        }
    }

    private var soundsPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(title: "音量") {
                SettingsControlRow(title: "提示音音量") {
                    HStack(spacing: 10) {
                        Slider(value: $volume, in: 0...1)
                            .frame(width: 230)
                        Text("\(Int(volume * 100))%")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            SettingsSection(title: "提示音") {
                SoundSettingsRow(
                    title: "完成提醒",
                    detail: "任务正常结束",
                    isEnabled: $completionSoundEnabled,
                    path: completionSoundPath,
                    testAction: { monitor.testCompletionSound() },
                    chooseAction: { chooseSound(defaultKey: AppDefaults.Key.completionSoundPath) }
                )

                SoundSettingsRow(
                    title: "失败提醒",
                    detail: "失败、受阻或超时",
                    isEnabled: $failureSoundEnabled,
                    path: failureSoundPath,
                    testAction: { monitor.testFailureSound() },
                    chooseAction: { chooseSound(defaultKey: AppDefaults.Key.failureSoundPath) }
                )
            }

            SettingsSection(title: "安静时段") {
                SettingsToggleRow(
                    title: "暂停提示音",
                    detail: quietHoursEnabled ? quietHoursSummary : "关闭",
                    isOn: $quietHoursEnabled
                )

                SettingsControlRow(title: "时间") {
                    HStack(spacing: 8) {
                        QuietHourPicker(selection: $quietHoursStartMinute)
                        Text("-")
                            .foregroundStyle(.secondary)
                        QuietHourPicker(selection: $quietHoursEndMinute)
                    }
                    .disabled(!quietHoursEnabled)
                    .opacity(quietHoursEnabled ? 1 : 0.45)
                }

                SettingsFootnote(text: "试听会绕过安静时段。")
            }
        }
    }

    private var limitsPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(title: "提醒阈值") {
                ThresholdSettingsRow(title: "5 小时窗口", value: $primaryThreshold)
                ThresholdSettingsRow(title: "7 天窗口", value: $secondaryThreshold)
            }

            SettingsSection(title: "当前用量") {
                if let usage = monitor.latestUsage {
                    SettingsValueRow(title: "最近 token", value: UsageFormatter.tokenCount(usage.last.totalTokens))
                    SettingsValueRow(title: "累计 token", value: UsageFormatter.tokenCount(usage.total.totalTokens))
                    SettingsValueRow(title: "上下文窗口", value: UsageFormatter.contextWindow(usage.modelContextWindow))
                } else {
                    SettingsValueRow(title: "状态", value: "等待 Codex 用量事件")
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
            return "监听、菜单栏、启动"
        case .sounds:
            return "提醒音与安静时段"
        case .limits:
            return "阈值与用量"
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
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Codex Monitor")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text("Preferences")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            VStack(spacing: 2) {
                ForEach(PreferencesPane.allCases) { pane in
                    SidebarRow(
                        pane: pane,
                        isSelected: pane == selectedPane
                    ) {
                        selectedPane = pane
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            SidebarStatusPill(isRunning: isRunning, filesWatched: filesWatched)
                .padding([.horizontal, .bottom], 12)
        }
        .frame(width: 196)
        .background(.bar)
    }
}

private struct SidebarRow: View {
    let pane: PreferencesPane
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: pane.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(pane.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(pane.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
            }
        }
    }
}

private struct SidebarStatusPill: View {
    let isRunning: Bool
    let filesWatched: Int

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.primary.opacity(isRunning ? 0.72 : 0.30))
                .frame(width: 7, height: 7)

            Text(isRunning ? "监听中" : "已暂停")
                .font(.caption.weight(.medium))

            Spacer(minLength: 6)

            Text("\(filesWatched)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PreferencesHeader: View {
    let pane: PreferencesPane

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(pane.title)
                .font(.system(size: 28, weight: .semibold))
                .lineLimit(1)

            Text(pane.subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.bottom, 2)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.56), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.separator.opacity(0.18), lineWidth: 1)
            }
        }
    }
}

private struct SettingsControlRow<Control: View>: View {
    let title: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 24)

            control
        }
        .settingsRow()
    }
}

private struct SettingsPickerRow<Control: View>: View {
    let title: String
    let value: String
    @ViewBuilder var control: Control

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.callout)

                Spacer(minLength: 16)

                Text(value)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            control
        }
        .settingsRow()
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .font(.callout)
            Spacer(minLength: 24)
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .settingsRow()
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 24)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .settingsRow()
    }
}

private struct SoundSettingsRow: View {
    let title: String
    let detail: String
    @Binding var isEnabled: Bool
    let path: String
    let testAction: () -> Void
    let chooseAction: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout)
                        .lineLimit(1)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 24)

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            HStack(spacing: 8) {
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: testAction) {
                    Image(systemName: "play.fill")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
                .disabled(!isEnabled)
                .help("试听")

                Button(action: chooseAction) {
                    Image(systemName: "folder")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
                .help("选择声音")
            }
        }
        .settingsRow()
    }
}

private struct SettingsFootnote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .settingsRow(verticalPadding: 8)
    }
}

private struct QuietHourPicker: View {
    @Binding var selection: Int

    var body: some View {
        Picker("时间", selection: $selection) {
            ForEach(Self.timeOptions, id: \.self) { minute in
                Text(Self.timeLabel(for: minute)).tag(minute)
            }
        }
        .labelsHidden()
        .frame(width: 92)
    }

    private static let timeOptions = Array(stride(from: 0, through: 23 * 60 + 30, by: 30))

    private static func timeLabel(for minuteOfDay: Int) -> String {
        String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }
}

private struct ThresholdSettingsRow: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.callout)

                Spacer(minLength: 16)

                Text("\(Int(value))%")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Slider(value: $value, in: 5...80, step: 5)
                ProgressView(value: value, total: 100)
                    .frame(width: 82)
            }
        }
        .settingsRow()
    }
}

private extension View {
    func settingsRow(verticalPadding: CGFloat = 12) -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.separator.opacity(0.24))
                    .frame(height: 1)
                    .padding(.leading, 14)
            }
    }
}
