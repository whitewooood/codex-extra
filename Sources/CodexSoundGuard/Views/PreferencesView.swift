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

    @State private var loginItemInstalled = LoginItemManager.isInstalled
    @State private var loginItemMessage: String?

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("通用", systemImage: "switch.2")
                }

            soundsTab
                .tabItem {
                    Label("声音", systemImage: "speaker.wave.2")
                }

            limitsTab
                .tabItem {
                    Label("阈值", systemImage: "gauge.with.dots.needle.50percent")
                }
        }
        .padding(20)
        .frame(width: 520, height: 420)
        .onChange(of: monitoringEnabled) { _ in
            monitor.applySettings()
        }
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle("监听 Codex 本地日志", isOn: $monitoringEnabled)

                Picker("菜单栏显示", selection: $menuBarDisplayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("命令非 0 退出也算失败", isOn: $commandFailureHeuristicEnabled)
            } header: {
                Text("菜单栏")
            }

            Section {
                HStack {
                    Text(loginItemInstalled ? "登录项已安装" : "登录项未安装")
                    Spacer()
                    Button(loginItemInstalled ? "移除登录项" : "安装登录项") {
                        toggleLoginItem()
                    }
                }

                if let loginItemMessage {
                    Text(loginItemMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("启动项")
            }
        }
    }

    private var soundsTab: some View {
        Form {
            Section {
                HStack {
                    Text("音量")
                    Slider(value: $volume, in: 0...1)
                    Text("\(Int(volume * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }

                PreferenceSoundRow(
                    title: "完成提醒",
                    isEnabled: $completionSoundEnabled,
                    path: completionSoundPath,
                    testAction: { monitor.testCompletionSound() },
                    chooseAction: { chooseSound(defaultKey: AppDefaults.Key.completionSoundPath) }
                )

                PreferenceSoundRow(
                    title: "失败提醒",
                    isEnabled: $failureSoundEnabled,
                    path: failureSoundPath,
                    testAction: { monitor.testFailureSound() },
                    chooseAction: { chooseSound(defaultKey: AppDefaults.Key.failureSoundPath) }
                )
            } header: {
                Text("本地声音")
            }
        }
    }

    private var limitsTab: some View {
        Form {
            Section {
                ThresholdRow(title: "5 小时窗口", value: $primaryThreshold)
                ThresholdRow(title: "7 天窗口", value: $secondaryThreshold)
            } header: {
                Text("剩余额度提醒阈值")
            } footer: {
                Text("当前版本先保存阈值并在设置中统一管理；后续可在此基础上加入低额度声音或系统通知。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    private func toggleLoginItem() {
        do {
            if loginItemInstalled {
                try LoginItemManager.uninstall()
                loginItemMessage = "登录项已移除。"
            } else {
                try LoginItemManager.install()
                loginItemMessage = "登录项已安装。"
            }
            loginItemInstalled = LoginItemManager.isInstalled
        } catch {
            loginItemMessage = error.localizedDescription
            loginItemInstalled = LoginItemManager.isInstalled
        }
    }
}

private struct PreferenceSoundRow: View {
    let title: String
    @Binding var isEnabled: Bool
    let path: String
    let testAction: () -> Void
    let chooseAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle(title, isOn: $isEnabled)

            Spacer()

            Text(URL(fileURLWithPath: path).lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 150, alignment: .trailing)

            Button("试听", action: testAction)
            Button("选择", action: chooseAction)
        }
    }
}

private struct ThresholdRow: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: 5...80, step: 5)
            Text("\(Int(value))%")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}
