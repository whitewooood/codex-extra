import AppKit
import CodexSoundGuardCore
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var monitor: SessionMonitor
    @EnvironmentObject private var updateChecker: UpdateChecker

    @AppStorage(AppDefaults.Key.monitoringEnabled) private var alertsEnabled = true
    @AppStorage(AppDefaults.Key.sessionsRootPath) private var sessionsRootPath = AppDefaults.sessionsRootPath

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            usagePanel
            readinessPanel
            trendPanel
            sessionRankingPanel
            statusStrip
            footer
        }
        .padding(14)
        .frame(width: 408)
        .background(InterfaceDesign.window.opacity(0.96))
        .controlSize(.small)
        .onAppear {
            updateChecker.checkAutomaticallyIfNeeded()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Codex Monitor")
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(1)

                Text(statusSubheading)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            StatusBadge(title: monitor.isRunning ? "用量中" : "启动中", isActive: monitor.isRunning)

            Toggle("", isOn: $alertsEnabled)
                .labelsHidden()
                .toggleStyle(HeaderToggleStyle())
        }
    }

    private var statusStrip: some View {
        Surface(prominence: .quiet) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
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

                VStack(alignment: .leading, spacing: 4) {
                    StatusDetailRow(title: "最近", value: monitor.lastStatus)
                    StatusDetailRow(title: "原因", value: monitor.lastClassificationReason)
                }
                .help(monitor.lastEventStatus)
            }
        }
    }

    private var usagePanel: some View {
        Surface(prominence: .overview) {
            VStack(alignment: .leading, spacing: 12) {
                PrimaryUsageSummary(usage: monitor.latestUsage)

                if let usage = monitor.latestUsage {
                    UsageSummaryPills(usage: usage)
                    RemainingLimitStack(usage: usage)
                } else {
                    EmptyStateLine(
                        iconName: "hourglass",
                        text: "等待用量数据",
                        detail: usageEmptyDetail
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var readinessPanel: some View {
        if monitor.latestUsage == nil || monitor.filesWatched == 0 || monitor.recognizedEventCount == 0 {
            Surface(prominence: .quiet) {
                VStack(alignment: .leading, spacing: 9) {
                    SectionHeader(
                        title: "就绪检查",
                        iconName: "checklist",
                        trailing: readinessSummary
                    )
                    ReadinessChecklist(rows: readinessRows)
                    InsightLine(
                        iconName: "lock.shield",
                        text: "只读取本机 ~/.codex/sessions，不上传日志，也不查询云端账单。"
                    )
                }
            }
        }
    }

    private var trendPanel: some View {
        Surface {
            VStack(alignment: .leading, spacing: 11) {
                SectionHeader(
                    title: "24 小时趋势",
                    iconName: "chart.xyaxis.line",
                    trailing: trendHeaderValue
                )

                if monitor.usageTrend.contains(where: { $0.tokens > 0 }) {
                    UsageTrendChart(points: monitor.usageTrend)
                } else {
                    EmptyStateLine(
                        iconName: "chart.line.uptrend.xyaxis",
                        text: "等待趋势数据",
                        detail: "运行一次 Codex 任务后，这里会按小时显示最近 24 小时消耗。"
                    )
                }
            }
        }
    }

    private var sessionRankingPanel: some View {
        Surface {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(
                    title: "会话排行",
                    iconName: "list.number",
                    trailing: "前 \(monitor.sessionUsageRankings.count)"
                )

                if monitor.sessionUsageRankings.isEmpty {
                    EmptyStateLine(
                        iconName: "doc.text.magnifyingglass",
                        text: "暂无会话排行",
                        detail: "识别到 token 用量后，会显示最近消耗最高的 3 个任务。"
                    )
                } else {
                    VStack(spacing: 6) {
                        ForEach(Array(monitor.sessionUsageRankings.enumerated()), id: \.element.id) { index, summary in
                            SessionRankRow(
                                rank: index + 1,
                                summary: summary,
                                maxTokens: monitor.sessionUsageRankings.map(\.totalTokens).max() ?? summary.totalTokens
                            )
                        }
                    }
                }
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

            FooterAction(title: "设置", iconName: "gearshape") {
                openSettings()
            }

            FooterAction(title: "更新", iconName: updateChecker.isChecking ? "arrow.triangle.2.circlepath" : "arrow.down.circle") {
                updateChecker.checkManually()
            }
            .disabled(updateChecker.isChecking)

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
        .padding(.top, 2)
    }

    private var statusSubheading: String {
        "用量监测常开 · \(alertsEnabled ? "声音提醒开启" : "声音提醒静音")"
    }

    private var usageEmptyDetail: String {
        if !sessionsRootExists {
            return "没有找到 Codex 日志目录，先运行 Codex Desktop 完成一次任务。"
        }
        if monitor.filesWatched == 0 {
            return "已找到日志目录，但还没有可读取的 session 文件。"
        }
        if monitor.recognizedEventCount == 0 {
            return "已看到 session 文件，正在等待 Codex 写入可识别事件。"
        }
        return "已识别到事件，等待下一次 token_count 用量事件。"
    }

    private var readinessRows: [ReadinessRow] {
        [
            ReadinessRow(title: sessionsRootExists ? "已找到 Codex 日志目录" : "未找到 Codex 日志目录", isReady: sessionsRootExists),
            ReadinessRow(title: monitor.filesWatched > 0 ? "已发现 \(monitor.filesWatched) 个 session 文件" : "等待 session 文件", isReady: monitor.filesWatched > 0),
            ReadinessRow(title: monitor.recognizedEventCount > 0 ? "已识别 \(monitor.recognizedEventCount) 个事件" : "等待 Codex 写入事件", isReady: monitor.recognizedEventCount > 0),
            ReadinessRow(title: monitor.latestUsage == nil ? "等待 token_count 用量" : "已读取用量数据", isReady: monitor.latestUsage != nil)
        ]
    }

    private var readinessSummary: String {
        let ready = readinessRows.filter(\.isReady).count
        return "\(ready)/\(readinessRows.count)"
    }

    private var sessionsRootExists: Bool {
        FileManager.default.fileExists(atPath: sessionsRootPath)
    }

    private var statusLine: String {
        let prefix = monitor.isRunning ? "用量监测中" : "正在启动"
        let alerts = alertsEnabled ? "提醒开" : "已静音"
        return "\(prefix) · \(alerts) · \(lastOutcomeLabel)"
    }

    private var trendHeaderValue: String {
        let total = monitor.usageTrend.reduce(0) { $0 + $1.tokens }
        guard total > 0 else {
            return "最近 24 小时"
        }
        return "24 小时 \(UsageFormatter.tokenCount(total))"
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

    private var statusColor: Color {
        guard monitor.isRunning else {
            return Color.primary.opacity(0.30)
        }

        switch monitor.lastOutcome {
        case .completed:
            return InterfaceDesign.accent
        case .failed:
            return Color.red.opacity(0.82)
        case nil:
            return Color.primary.opacity(0.48)
        }
    }

    private func openSettings() {
        PreferencesWindowController.shared.show(monitor: monitor, updateChecker: updateChecker)
    }

}
