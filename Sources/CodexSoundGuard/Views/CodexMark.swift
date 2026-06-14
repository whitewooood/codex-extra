import AppKit
import CodexSoundGuardCore
import SwiftUI

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
        .accessibilityLabel("Codex Monitor")
    }
}

struct CodexUsageMeter: View {
    let statusIntensity: Double
    let usage: TokenUsageSnapshot?

    var body: some View {
        Image(nsImage: meterImage)
            .resizable()
            .interpolation(.high)
            .frame(width: 19, height: 18)
            .fixedSize()
            .accessibilityLabel(accessibilityLabel)
            .help(helpText)
    }

    private var accessibilityLabel: String {
        if let usageText = UsageFormatter.menuBarSummary(usage) {
            return "Codex Monitor，当前用量 \(usageText)"
        }
        return "Codex Monitor，等待用量数据"
    }

    private var helpText: String {
        guard let usage else {
            return "等待 Codex 用量数据"
        }

        let primary = usage.primaryRateLimit.map { "5 小时 \(UsageFormatter.percent($0.usedPercent))" } ?? "5 小时 --"
        let secondary = usage.secondaryRateLimit.map { "7 天 \(UsageFormatter.percent($0.usedPercent))" } ?? "7 天 --"
        return "\(primary) · \(secondary)"
    }

    private var meterImage: NSImage {
        let image = NSImage(size: NSSize(width: 19, height: 18))
        image.isTemplate = false
        image.lockFocus()
        defer { image.unlockFocus() }

        drawStatusDot(in: CGRect(x: 14.1, y: 1.45, width: 4.8, height: 4.8))

        drawBar(
            rect: CGRect(x: 2.0, y: 10.7, width: 13.2, height: 3.2),
            usedPercent: usage?.primaryRateLimit?.usedPercent
        )
        drawBar(
            rect: CGRect(x: 2.0, y: 4.7, width: 13.2, height: 3.2),
            usedPercent: usage?.secondaryRateLimit?.usedPercent
        )

        return image
    }

    private func drawStatusDot(in rect: CGRect) {
        let haloPath = NSBezierPath(ovalIn: rect.insetBy(dx: -0.9, dy: -0.9))
        NSColor.windowBackgroundColor.withAlphaComponent(0.82).setFill()
        haloPath.fill()

        let dotPath = NSBezierPath(ovalIn: rect)
        NSColor.labelColor.withAlphaComponent(statusIntensity).setFill()
        dotPath.fill()
    }

    private func drawBar(rect: CGRect, usedPercent: Double?) {
        let trackPath = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        NSColor.labelColor.withAlphaComponent(0.16).setFill()
        trackPath.fill()

        guard let usedPercent else {
            return
        }

        let remainingProgress = 1 - (max(0, min(usedPercent, 100)) / 100)
        guard remainingProgress > 0 else {
            return
        }

        let fillWidth = max(1.2, rect.width * remainingProgress)
        let fillRect = CGRect(x: rect.minX, y: rect.minY, width: fillWidth, height: rect.height)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        NSColor.labelColor.withAlphaComponent(0.86).setFill()
        fillPath.fill()
    }
}
