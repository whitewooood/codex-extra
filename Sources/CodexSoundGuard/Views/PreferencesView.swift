import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @EnvironmentObject private var monitor: SessionMonitor
    @EnvironmentObject private var updateChecker: UpdateChecker
    private let loginItemStatusProvider: () -> LoginItemStatus

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
    @AppStorage(AppDefaults.Key.automaticUpdateChecksEnabled) private var automaticUpdateChecksEnabled = false

    @State private var selectedPane = PreferencesPane.general
    @State private var loginItemStatus = LoginItemManager.status
    @State private var loginItemMessage: String?

    init(loginItemStatusProvider: @escaping () -> LoginItemStatus = { LoginItemManager.status }) {
        self.loginItemStatusProvider = loginItemStatusProvider
        _loginItemStatus = State(initialValue: loginItemStatusProvider())
    }

    var body: some View {
        HStack(spacing: 0) {
            PreferencesSidebar(
                selectedPane: $selectedPane,
                isRunning: monitor.isRunning,
                filesWatched: monitor.filesWatched
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    PreferencesHeader(pane: selectedPane)

                    paneContent
                }
                .frame(maxWidth: 548, alignment: .leading)
                .padding(.horizontal, 38)
                .padding(.vertical, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(InterfaceDesign.window)
        }
        .frame(width: 780, height: 700)
        .tint(InterfaceDesign.accent)
        .onAppear {
            loginItemStatus = loginItemStatusProvider()
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
                    title: "监听日志",
                    detail: monitor.isRunning ? "运行中" : "已暂停",
                    isOn: $monitoringEnabled
                )

                SettingsValueRow(
                    title: "已识别",
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
                    .frame(width: 320)
                }

                SettingsToggleRow(
                    title: "命令失败也提醒",
                    detail: commandFailureHeuristicEnabled ? "开启" : "关闭",
                    isOn: $commandFailureHeuristicEnabled
                )
            }

            SettingsSection(title: "启动") {
                SettingsToggleRow(
                    title: "登录时启动",
                    detail: loginItemStatus.detail,
                    isOn: loginItemBinding
                )

                if let loginItemMessage {
                    SettingsFootnote(text: loginItemMessage)
                }
            }

            SettingsSection(title: "更新") {
                SettingsToggleRow(
                    title: "自动检查更新",
                    detail: automaticUpdateChecksEnabled ? "每天一次" : "手动",
                    isOn: $automaticUpdateChecksEnabled
                )

                SettingsButtonRow(
                    title: "当前版本",
                    detail: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "--",
                    buttonTitle: updateChecker.isChecking ? "检查中" : "检查更新",
                    systemImage: "arrow.down.circle",
                    isDisabled: updateChecker.isChecking
                ) {
                    updateChecker.checkManually()
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

                SettingsFootnote(text: "试听不受安静时段影响。")
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
                    SettingsValueRow(title: "最近", value: UsageFormatter.tokenCount(usage.last.totalTokens))
                    SettingsValueRow(title: "累计", value: UsageFormatter.tokenCount(usage.total.totalTokens))
                    SettingsValueRow(title: "上下文", value: UsageFormatter.contextWindow(usage.modelContextWindow))
                } else {
                    SettingsValueRow(title: "状态", value: "等待用量数据")
                }
            }
        }
    }

    private var selectedDisplayMode: MenuBarDisplayMode {
        MenuBarDisplayMode(rawValue: menuBarDisplayMode) ?? .graphic
    }

    private var loginItemBinding: Binding<Bool> {
        Binding(
            get: { loginItemStatus.isInstalled },
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
            loginItemStatus = LoginItemManager.status
        } catch {
            loginItemMessage = error.localizedDescription
            loginItemStatus = LoginItemManager.status
        }
    }

    private static func timeLabel(for minuteOfDay: Int) -> String {
        String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }
}
