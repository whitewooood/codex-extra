import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @EnvironmentObject private var monitor: SessionMonitor
    @EnvironmentObject private var updateChecker: UpdateChecker
    private let loginItemStatusProvider: () -> LoginItemStatus

    @AppStorage(AppDefaults.Key.monitoringEnabled) private var alertsEnabled = true
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

    init(
        initialPane: PreferencesPane = .general,
        loginItemStatusProvider: @escaping () -> LoginItemStatus = { LoginItemManager.status }
    ) {
        self.loginItemStatusProvider = loginItemStatusProvider
        _selectedPane = State(initialValue: initialPane)
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
        case .diagnostics:
            diagnosticsPane
        }
    }

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(title: "运行") {
                SettingsValueRow(
                    title: "用量监测",
                    value: monitor.isRunning ? "常开" : "启动中"
                )

                SettingsToggleRow(
                    title: "声音提醒",
                    detail: alertsEnabled ? "自动播放完成/失败提示音" : "静音；用量仍会更新",
                    isOn: $alertsEnabled
                )

                SettingsValueRow(
                    title: "已识别",
                    value: "\(monitor.filesWatched) 个文件 · \(monitor.recognizedEventCount) 个事件"
                )
            }

            SettingsSection(title: "菜单栏") {
                SettingsInfoBox(
                    title: "推荐默认值",
                    text: "“仅图形”最适合常驻菜单栏；需要精确数字时再切换到 5 小时、7 天或最近用量。"
                )

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

                SettingsInfoBox(
                    title: "为什么默认关闭",
                    text: "Codex 经常运行探索性命令，单个命令失败不一定代表整个任务失败；开启后会更敏感。"
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

                SettingsInfoBox(
                    title: "安全说明",
                    text: "自动检查更新只请求 GitHub Releases 获取版本号和发布说明，不会上传 Codex 日志，也不会自动下载或替换应用。"
                )

                SettingsButtonRow(
                    title: "当前版本",
                    detail: updateStatusDetail,
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
                SettingsInfoBox(
                    title: "推荐默认值",
                    text: "80% 通常能在后台任务结束时听清，又不会像系统警告音那样打断当前工作。"
                )

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
                SettingsInfoBox(
                    title: "建议用法",
                    text: "适合设置为睡眠或会议时段；手动试听会绕过安静时段，方便确认声音文件。"
                )

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
                SettingsInfoBox(
                    title: "推荐默认值",
                    text: "20% 适合提前知道额度快用完，但不会太早打扰。阈值越高，提醒越早。"
                )

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

    private var diagnosticsPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(title: "工作状态") {
                DiagnosticStatusRow(
                    title: "日志目录",
                    detail: sessionsRootExists ? sessionsRootPath : "未找到 \(sessionsRootPath)",
                    status: sessionsRootExists ? .ok : .warning,
                    actionTitle: sessionsRootExists ? "打开" : nil,
                    actionIcon: "folder"
                ) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: sessionsRootPath))
                }

                DiagnosticStatusRow(
                    title: "Session 文件",
                    detail: monitor.filesWatched > 0 ? "\(monitor.filesWatched) 个文件正在扫描" : "先运行 Codex Desktop 完成一次任务",
                    status: monitor.filesWatched > 0 ? .ok : .warning
                )

                DiagnosticStatusRow(
                    title: "事件识别",
                    detail: monitor.recognizedEventCount > 0 ? "已识别 \(monitor.recognizedEventCount) 个 Codex 事件" : "等待 task_complete、token_count 等事件",
                    status: monitor.recognizedEventCount > 0 ? .ok : .neutral
                )

                DiagnosticStatusRow(
                    title: "用量数据",
                    detail: usageDiagnosticDetail,
                    status: monitor.latestUsage == nil ? .neutral : .ok
                )
            }

            SettingsSection(title: "声音与启动") {
                DiagnosticStatusRow(
                    title: "完成声音",
                    detail: soundDiagnostic(path: completionSoundPath, isEnabled: completionSoundEnabled),
                    status: soundStatus(path: completionSoundPath, isEnabled: completionSoundEnabled)
                )

                DiagnosticStatusRow(
                    title: "失败声音",
                    detail: soundDiagnostic(path: failureSoundPath, isEnabled: failureSoundEnabled),
                    status: soundStatus(path: failureSoundPath, isEnabled: failureSoundEnabled)
                )

                DiagnosticStatusRow(
                    title: "安静时段",
                    detail: quietHoursEnabled ? "\(quietHoursSummary) 自动静音；试听不受影响" : "关闭",
                    status: quietHoursEnabled ? .neutral : .ok
                )

                DiagnosticStatusRow(
                    title: "登录时启动",
                    detail: loginItemStatus.detail,
                    status: loginItemStatus.isInstalled ? .ok : .neutral
                )
            }

            SettingsSection(title: "隐私与更新") {
                SettingsInfoBox(
                    title: "本地优先",
                    text: "Codex Monitor 只在本机解析 ~/.codex/sessions，用来提取事件、用量和任务状态；不会上传原始日志、prompt、命令输出或文件路径。",
                    iconName: "lock.shield"
                )

                DiagnosticStatusRow(
                    title: "联网行为",
                    detail: automaticUpdateChecksEnabled ? "仅每天检查一次 GitHub Releases" : "自动检查更新关闭；手动点击才联网",
                    status: automaticUpdateChecksEnabled ? .neutral : .ok
                )

                DiagnosticStatusRow(
                    title: "更新状态",
                    detail: updateStatusDetail,
                    status: updateStatus
                )
            }
        }
    }

    private var selectedDisplayMode: MenuBarDisplayMode {
        MenuBarDisplayMode(rawValue: menuBarDisplayMode) ?? .graphic
    }

    private var sessionsRootPath: String {
        UserDefaults.standard.string(forKey: AppDefaults.Key.sessionsRootPath) ?? AppDefaults.sessionsRootPath
    }

    private var sessionsRootExists: Bool {
        FileManager.default.fileExists(atPath: sessionsRootPath)
    }

    private var usageDiagnosticDetail: String {
        guard let usage = monitor.latestUsage else {
            return "等待 token_count；通常会在下一次 Codex 任务后出现"
        }
        return "最近 \(UsageFormatter.tokenCount(usage.last.totalTokens)) · 累计 \(UsageFormatter.tokenCount(usage.total.totalTokens))"
    }

    private var updateStatusDetail: String {
        if updateChecker.isChecking {
            return "正在请求 GitHub Releases"
        }

        switch updateChecker.lastResult {
        case .updateAvailable(let release):
            return "发现 \(release.version)，请从 GitHub Release 手动下载 DMG"
        case .upToDate(let version):
            return "当前 \(version) 已是最新"
        case .ignored(let version):
            return "已忽略 \(version)"
        case .failed(let message):
            return message
        case nil:
            return automaticUpdateChecksEnabled ? "每天最多检查一次" : "仅手动检查"
        }
    }

    private var updateStatus: DiagnosticStatusRow.Status {
        if updateChecker.isChecking {
            return .neutral
        }

        switch updateChecker.lastResult {
        case .updateAvailable:
            return .warning
        case .failed:
            return .warning
        case .upToDate:
            return .ok
        case .ignored, nil:
            return .neutral
        }
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

    private func soundDiagnostic(path: String, isEnabled: Bool) -> String {
        guard isEnabled else {
            return "已关闭"
        }
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return "文件不存在：\(path)"
    }

    private func soundStatus(path: String, isEnabled: Bool) -> DiagnosticStatusRow.Status {
        guard isEnabled else {
            return .neutral
        }
        return FileManager.default.fileExists(atPath: path) ? .ok : .warning
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
