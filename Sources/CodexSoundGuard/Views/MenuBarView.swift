import AppKit
import CodexSoundGuardCore
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var monitor: SessionMonitor

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
                    EmptyStateLine(iconName: "hourglass", text: "等待 Codex 写入用量事件")
                }
            }
        }
    }

    private var trendPanel: some View {
        Surface {
            VStack(alignment: .leading, spacing: 11) {
                SectionHeader(
                    title: "用量趋势",
                    iconName: "chart.xyaxis.line",
                    trailing: "最近 6 小时"
                )

                if monitor.usageTrend.contains(where: { $0.tokens > 0 }) {
                    UsageTrendChart(points: monitor.usageTrend)
                } else {
                    EmptyStateLine(iconName: "chart.line.uptrend.xyaxis", text: "等待最近几小时的 token 用量")
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
                    trailing: "Top \(monitor.sessionUsageRankings.count)"
                )

                if monitor.sessionUsageRankings.isEmpty {
                    EmptyStateLine(iconName: "doc.text.magnifyingglass", text: "等待 session 用量数据")
                } else {
                    VStack(spacing: 6) {
                        ForEach(Array(monitor.sessionUsageRankings.enumerated()), id: \.element.id) { index, summary in
                            SessionRankRow(rank: index + 1, summary: summary)
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
        monitor.isRunning ? "本地日志用量与任务提醒" : "监听已暂停，点击开关恢复"
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
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

}

private struct Surface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.separator.opacity(0.34), lineWidth: 1)
            }
    }
}

private struct SectionHeader: View {
    let title: String
    let iconName: String
    let trailing: String

    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: iconName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer()

            Text(trailing)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct EmptyStateLine: View {
    let iconName: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

private struct RemainingLimitStack: View {
    let usage: TokenUsageSnapshot

    var body: some View {
        VStack(spacing: 8) {
            RemainingLimitRow(title: "5 小时", limit: usage.primaryRateLimit)
            RemainingLimitRow(title: "7 天", limit: usage.secondaryRateLimit)
        }
    }
}

private struct RemainingLimitRow: View {
    let title: String
    let limit: UsageRateLimit?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text(valueText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.12))

                    Capsule()
                        .fill(Color.primary.opacity(0.72))
                        .frame(width: proxy.size.width * remainingProgress)
                }
            }
            .frame(height: 5)
            .help(resetText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var remainingProgress: Double {
        guard let limit else {
            return 0
        }
        return 1 - (max(0, min(limit.usedPercent, 100)) / 100)
    }

    private var valueText: String {
        guard let limit else {
            return "--"
        }
        return "\(UsageFormatter.percent(remainingPercent(limit))) 剩余 · \(resetText)"
    }

    private var resetText: String {
        guard let resetDate = limit?.resetsAt else {
            return "重置 --"
        }
        return "重置 \(Self.resetFormatter.string(from: resetDate))"
    }

    private func remainingPercent(_ limit: UsageRateLimit) -> Double {
        100 - max(0, min(limit.usedPercent, 100))
    }

    private static let resetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct TokenSummaryRow: View {
    let usage: TokenUsageSnapshot

    var body: some View {
        HStack(spacing: 0) {
            TokenMetric(title: "累计", value: UsageFormatter.tokenCount(usage.total.totalTokens))
            Divider()
                .padding(.horizontal, 10)
            TokenMetric(title: "最近", value: UsageFormatter.tokenCount(usage.last.totalTokens))
            Divider()
                .padding(.horizontal, 10)
            TokenMetric(title: "上下文", value: UsageFormatter.contextWindow(usage.modelContextWindow))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.quaternary.opacity(0.62), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct TokenMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct UsageTrendChart: View {
    let points: [UsageTrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.quaternary.opacity(0.45))

                    Path { path in
                        let chartPoints = linePoints(in: proxy.size)
                        guard let first = chartPoints.first else {
                            return
                        }
                        path.move(to: first)
                        for point in chartPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.primary.opacity(0.78), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    ForEach(Array(linePoints(in: proxy.size).enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(Color.primary.opacity(0.86))
                            .frame(width: 4, height: 4)
                            .position(point)
                    }
                }
            }
            .frame(height: 76)

            HStack {
                Text(points.first.map { Self.hourFormatter.string(from: $0.hourStart) } ?? "--")
                Spacer()
                Text("峰值 \(UsageFormatter.tokenCount(maxTokens))")
                Spacer()
                Text(points.last.map { Self.hourFormatter.string(from: $0.hourStart) } ?? "--")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var maxTokens: Int {
        max(points.map(\.tokens).max() ?? 0, 1)
    }

    private func linePoints(in size: CGSize) -> [CGPoint] {
        guard points.count > 1 else {
            return []
        }

        let maxValue = Double(maxTokens)
        let horizontalStep = size.width / CGFloat(points.count - 1)
        return points.enumerated().map { index, point in
            let x = CGFloat(index) * horizontalStep
            let progress = CGFloat(Double(point.tokens) / maxValue)
            let y = size.height - max(3, min(size.height - 3, progress * (size.height - 12) + 6))
            return CGPoint(x: x, y: y)
        }
    }

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct SessionRankRow: View {
    let rank: Int
    let summary: SessionUsageSummary

    var body: some View {
        HStack(spacing: 9) {
            Text("\(rank)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 22)
                .background(.quaternary.opacity(0.62), in: RoundedRectangle(cornerRadius: 5, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("最近 \(UsageFormatter.tokenCount(summary.lastTokens)) · \(Self.timeFormatter.string(from: summary.updatedAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(UsageFormatter.tokenCount(summary.totalTokens))
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct FooterAction: View {
    let title: String
    let iconName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: iconName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 9)
                .frame(height: 24)
        }
        .buttonStyle(QuietCapsuleButtonStyle())
    }
}

private struct QuietIconButtonStyle: ButtonStyle {
    enum Role {
        case normal
        case destructive
    }

    var role: Role = .normal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(background(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var foreground: Color {
        switch role {
        case .normal:
            return .secondary
        case .destructive:
            return .red
        }
    }

    private func background(isPressed: Bool) -> Color {
        switch role {
        case .normal:
            return Color.secondary.opacity(isPressed ? 0.16 : 0.08)
        case .destructive:
            return Color.red.opacity(isPressed ? 0.16 : 0.08)
        }
    }
}

private struct QuietCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary)
            .background(Color.secondary.opacity(configuration.isPressed ? 0.16 : 0.08), in: Capsule())
    }
}
