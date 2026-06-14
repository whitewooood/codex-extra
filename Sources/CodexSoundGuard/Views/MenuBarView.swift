import AppKit
import CodexSoundGuardCore
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var monitor: SessionMonitor
    @EnvironmentObject private var updateChecker: UpdateChecker

    @AppStorage(AppDefaults.Key.monitoringEnabled) private var monitoringEnabled = true
    @AppStorage(AppDefaults.Key.sessionsRootPath) private var sessionsRootPath = AppDefaults.sessionsRootPath

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            usagePanel
            trendPanel
            sessionRankingPanel
            statusStrip
            footer
        }
        .padding(14)
        .frame(width: 404)
        .background(.regularMaterial)
        .controlSize(.small)
        .onAppear {
            updateChecker.checkAutomaticallyIfNeeded()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Monitor")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(statusSubheading)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Toggle("", isOn: $monitoringEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: monitoringEnabled) { _ in
                        monitor.applySettings()
                    }

                Text(monitor.isRunning ? "监听" : "暂停")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var statusStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color.primary.opacity(statusOpacity))
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

            Text("原因：\(monitor.lastClassificationReason)")
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
                    title: "剩余额度",
                    iconName: "gauge.with.dots.needle.50percent",
                    trailing: usageHeaderValue
                )

                if let usage = monitor.latestUsage {
                    RemainingLimitStack(usage: usage)

                    TokenSummaryRow(usage: usage)
                } else {
                    EmptyStateLine(iconName: "hourglass", text: "等待用量数据")
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
                    EmptyStateLine(iconName: "chart.line.uptrend.xyaxis", text: "等待用量数据")
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
                    EmptyStateLine(iconName: "doc.text.magnifyingglass", text: "暂无会话用量")
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
        .padding(.top, 1)
    }

    private var statusSubheading: String {
        monitor.isRunning ? "用量与提醒" : "已暂停"
    }

    private var statusLine: String {
        let prefix = monitor.isRunning ? "监听中" : "已暂停"
        return "\(prefix) · \(lastOutcomeLabel)"
    }

    private var usageHeaderValue: String {
        guard let usage = monitor.latestUsage else {
            return "--"
        }
        return "最近 \(UsageFormatter.tokenCount(usage.last.totalTokens))"
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

    private var statusOpacity: Double {
        guard monitor.isRunning else {
            return 0.30
        }

        switch monitor.lastOutcome {
        case .completed:
            return 0.68
        case .failed:
            return 1.0
        case nil:
            return 0.52
        }
    }

    private func openSettings() {
        PreferencesWindowController.shared.show(monitor: monitor, updateChecker: updateChecker)
    }

}
