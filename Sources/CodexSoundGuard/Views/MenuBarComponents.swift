import CodexSoundGuardCore
import SwiftUI

enum SurfaceProminence {
    case regular
    case overview
    case quiet
}

struct Surface<Content: View>: View {
    var prominence: SurfaceProminence = .regular
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(prominence == .overview ? 14 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundFill, in: RoundedRectangle(cornerRadius: InterfaceDesign.panelRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: InterfaceDesign.panelRadius, style: .continuous)
                    .strokeBorder(InterfaceDesign.border, lineWidth: 1)
            }
    }

    private var backgroundFill: Color {
        switch prominence {
        case .regular:
            return InterfaceDesign.elevatedPanel.opacity(0.54)
        case .overview:
            return InterfaceDesign.elevatedPanel.opacity(0.58)
        case .quiet:
            return InterfaceDesign.basePanel.opacity(0.54)
        }
    }
}

struct StatusBadge: View {
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? InterfaceDesign.accent : Color.primary.opacity(0.32))
                .frame(width: 6, height: 6)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isActive ? .primary : .secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(InterfaceDesign.basePanel.opacity(0.60), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(InterfaceDesign.border, lineWidth: 1)
        }
    }
}

struct StatusDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                .frame(width: 34, alignment: .leading)

            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

struct PrimaryUsageSummary: View {
    let usage: TokenUsageSnapshot?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("当前用量")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(primaryValue)
                    .font(.system(size: 27, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("累计")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(totalValue)
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
            }
        }
    }

    private var primaryValue: String {
        usage.map { UsageFormatter.tokenCount($0.last.totalTokens) } ?? "--"
    }

    private var totalValue: String {
        usage.map { UsageFormatter.tokenCount($0.total.totalTokens) } ?? "--"
    }
}

struct MetricPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .frame(height: 23)
        .background(InterfaceDesign.basePanel.opacity(0.54), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct UsageSummaryPills: View {
    let usage: TokenUsageSnapshot

    var body: some View {
        HStack(spacing: 6) {
            MetricPill(title: "5 小时", value: remainingValue(usage.primaryRateLimit))
            MetricPill(title: "7 天", value: remainingValue(usage.secondaryRateLimit))
            MetricPill(title: "上下文", value: UsageFormatter.contextWindow(usage.modelContextWindow))
        }
    }

    private func remainingValue(_ limit: UsageRateLimit?) -> String {
        guard let limit else {
            return "--"
        }
        return UsageFormatter.percent(100 - max(0, min(limit.usedPercent, 100)))
    }
}

struct HeaderToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: configuration.isOn ? "pause.fill" : "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 14)
                Text(configuration.isOn ? "暂停" : "恢复")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(configuration.isOn ? .primary : .secondary)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(configuration.isOn ? InterfaceDesign.accent.opacity(0.09) : InterfaceDesign.basePanel.opacity(0.56), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(configuration.isOn ? InterfaceDesign.accent.opacity(0.22) : InterfaceDesign.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeader: View {
    let title: String
    let iconName: String
    let trailing: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(InterfaceDesign.accent)
                .frame(width: 18)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Text(trailing)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct EmptyStateLine: View {
    let iconName: String
    let text: String
    var detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(InterfaceDesign.accent.opacity(0.72))
                .frame(width: 18)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct ReadinessChecklist: View {
    let rows: [ReadinessRow]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    Image(systemName: row.isReady ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(row.isReady ? InterfaceDesign.accent : Color.secondary.opacity(0.55))
                        .frame(width: 16)

                    Text(row.title)
                        .font(.caption2)
                        .foregroundStyle(row.isReady ? .secondary : .tertiary)
                        .lineLimit(1)

                    Spacer(minLength: 6)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(InterfaceDesign.basePanel.opacity(0.50), in: RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous))
    }
}

struct ReadinessRow: Identifiable {
    let id = UUID()
    let title: String
    let isReady: Bool
}

struct InsightLine: View {
    let iconName: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(InterfaceDesign.accent.opacity(0.80))
                .frame(width: 15)
                .padding(.top, 1)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct RemainingLimitStack: View {
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
                    .font(.caption.weight(.medium))
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
                        .fill(Color.primary.opacity(0.10))

                    Capsule()
                        .fill(InterfaceDesign.accent.opacity(0.82))
                        .frame(width: proxy.size.width * remainingProgress)
                }
            }
            .frame(height: 5)
            .help(resetText)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(InterfaceDesign.basePanel.opacity(0.56), in: RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous))
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

struct TokenSummaryRow: View {
    let usage: TokenUsageSnapshot

    var body: some View {
        HStack(spacing: 0) {
            TokenMetric(title: "累计", value: UsageFormatter.tokenCount(usage.total.totalTokens))
            Divider()
                .padding(.horizontal, 9)
            TokenMetric(title: "最近", value: UsageFormatter.tokenCount(usage.last.totalTokens))
            Divider()
                .padding(.horizontal, 9)
            TokenMetric(title: "上下文", value: UsageFormatter.contextWindow(usage.modelContextWindow))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(InterfaceDesign.basePanel.opacity(0.56), in: RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous))
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

struct UsageTrendChart: View {
    let points: [UsageTrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { proxy in
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous)
                        .fill(InterfaceDesign.basePanel.opacity(0.48))

                    VStack(spacing: 0) {
                        Divider().opacity(0.16)
                        Spacer()
                        Divider().opacity(0.12)
                        Spacer()
                        Divider().opacity(0.16)
                    }
                    .padding(.vertical, 8)

                    Path { path in
                        let chartPoints = linePoints(in: proxy.size)
                        guard let first = chartPoints.first else {
                            return
                        }
                        path.move(to: CGPoint(x: first.x, y: proxy.size.height - 8))
                        path.addLine(to: first)
                        for point in chartPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                        if let last = chartPoints.last {
                            path.addLine(to: CGPoint(x: last.x, y: proxy.size.height - 8))
                        }
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [InterfaceDesign.accent.opacity(0.18), InterfaceDesign.accent.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

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
                    .stroke(InterfaceDesign.accent.opacity(0.88), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    if points.count <= 12 {
                        ForEach(Array(linePoints(in: proxy.size).enumerated()), id: \.offset) { _, point in
                            Circle()
                                .fill(InterfaceDesign.accent)
                                .frame(width: 4, height: 4)
                                .position(point)
                        }
                    }
                }
            }
            .frame(height: 76)

            HStack {
                Text(points.first.map { Self.hourFormatter.string(from: $0.hourStart) } ?? "--")
                Spacer()
                Text("合计 \(UsageFormatter.tokenCount(totalTokens))")
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

    private var totalTokens: Int {
        points.reduce(0) { $0 + $1.tokens }
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

struct SessionRankRow: View {
    let rank: Int
    let summary: SessionUsageSummary
    let maxTokens: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Text("\(rank)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(InterfaceDesign.accent)
                    .frame(width: 18, height: 22)
                    .background(InterfaceDesign.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("最近 \(UsageFormatter.tokenCount(summary.lastTokens)) · \(Self.timeFormatter.string(from: summary.updatedAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(UsageFormatter.tokenCount(summary.totalTokens))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                    .help("会话累计 token")
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.10))
                    Capsule()
                        .fill(InterfaceDesign.accent.opacity(0.68))
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(InterfaceDesign.basePanel.opacity(0.50), in: RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous))
    }

    private var progress: Double {
        guard maxTokens > 0 else {
            return 0
        }
        return max(0.04, min(1, Double(summary.totalTokens) / Double(maxTokens)))
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

struct FooterAction: View {
    let title: String
    let iconName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: iconName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 27)
        }
        .buttonStyle(QuietCapsuleButtonStyle())
    }
}

struct QuietIconButtonStyle: ButtonStyle {
    enum Role {
        case normal
        case destructive
    }

    var role: Role = .normal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(background(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            }
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
            return InterfaceDesign.basePanel.opacity(isPressed ? 0.86 : 0.58)
        case .destructive:
            return Color.red.opacity(isPressed ? 0.16 : 0.08)
        }
    }

    private var border: Color {
        switch role {
        case .normal:
            return InterfaceDesign.border
        case .destructive:
            return Color.red.opacity(0.12)
        }
    }
}

private struct QuietCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary)
            .background(InterfaceDesign.basePanel.opacity(configuration.isPressed ? 0.86 : 0.58), in: RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous)
                    .strokeBorder(InterfaceDesign.border, lineWidth: 1)
            }
    }
}
