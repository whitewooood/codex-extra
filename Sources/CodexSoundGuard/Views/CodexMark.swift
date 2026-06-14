import SwiftUI
import CodexSoundGuardCore

struct CodexMark: View {
    let statusTint: Color
    var size: CGFloat
    var showsStatus: Bool = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .fill(.quaternary)
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .strokeBorder(.separator.opacity(0.45), lineWidth: 1)

                Text("C")
                    .font(.system(size: size * 0.58, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: size, height: size)

            if showsStatus {
                Circle()
                    .fill(statusTint)
                    .frame(width: max(5, size * 0.22), height: max(5, size * 0.22))
                    .offset(x: size * 0.08, y: size * 0.06)
            }
        }
        .frame(width: size + (showsStatus ? size * 0.08 : 0), height: size)
        .accessibilityLabel("Codex 声音提醒")
    }
}

struct CodexUsageMeter: View {
    let statusTint: Color
    let usage: TokenUsageSnapshot?

    var body: some View {
        HStack(spacing: 3) {
            CodexMark(statusTint: statusTint, size: 15)

            VStack(spacing: 2) {
                TinyUsageBar(usedPercent: usage?.primaryRateLimit?.usedPercent, tint: .accentColor)
                TinyUsageBar(usedPercent: usage?.secondaryRateLimit?.usedPercent, tint: .secondary)
            }
            .frame(width: 14, height: 10)
        }
        .fixedSize()
        .accessibilityLabel(accessibilityLabel)
        .help(helpText)
    }

    private var accessibilityLabel: String {
        if let usageText = UsageFormatter.menuBarSummary(usage) {
            return "Codex 声音提醒，当前用量 \(usageText)"
        }
        return "Codex 声音提醒，等待用量数据"
    }

    private var helpText: String {
        guard let usage else {
            return "等待 Codex 用量数据"
        }

        let primary = usage.primaryRateLimit.map { "5 小时 \(UsageFormatter.percent($0.usedPercent))" } ?? "5 小时 --"
        let secondary = usage.secondaryRateLimit.map { "7 天 \(UsageFormatter.percent($0.usedPercent))" } ?? "7 天 --"
        return "\(primary) · \(secondary)"
    }
}

private struct TinyUsageBar: View {
    let usedPercent: Double?
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.20))

                Capsule()
                    .fill(fillStyle)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 4)
    }

    private var progress: Double {
        guard let usedPercent else {
            return 0
        }
        return max(0, min(usedPercent, 100)) / 100
    }

    private var fillStyle: Color {
        guard usedPercent != nil else {
            return Color.clear
        }
        return tint
    }
}
