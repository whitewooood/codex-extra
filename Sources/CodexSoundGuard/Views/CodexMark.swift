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
        .accessibilityLabel("Codex Usage Meter")
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
            return "Codex Usage Meter，当前用量 \(usageText)"
        }
        return "Codex Usage Meter，等待用量数据"
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

        let bodyRect = CGRect(x: 0.75, y: 1.25, width: 16, height: 15.5)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 4.5, yRadius: 4.5)
        NSColor.labelColor.withAlphaComponent(0.08).setFill()
        bodyPath.fill()
        NSColor.labelColor.withAlphaComponent(0.58).setStroke()
        bodyPath.lineWidth = 1
        bodyPath.stroke()

        drawBar(
            rect: CGRect(x: 3.5, y: 10.3, width: 10, height: 3),
            usedPercent: usage?.primaryRateLimit?.usedPercent
        )
        drawBar(
            rect: CGRect(x: 3.5, y: 5.0, width: 10, height: 3),
            usedPercent: usage?.secondaryRateLimit?.usedPercent
        )

        let dotPath = NSBezierPath(ovalIn: CGRect(x: 13.25, y: 0.9, width: 5.5, height: 5.5))
        NSColor.windowBackgroundColor.withAlphaComponent(0.85).setFill()
        dotPath.fill()

        let innerDotPath = NSBezierPath(ovalIn: CGRect(x: 14.0, y: 1.65, width: 4, height: 4))
        NSColor.labelColor.withAlphaComponent(statusIntensity).setFill()
        innerDotPath.fill()

        return image
    }

    private func drawBar(rect: CGRect, usedPercent: Double?) {
        let trackPath = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        NSColor.labelColor.withAlphaComponent(0.18).setFill()
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
        NSColor.labelColor.withAlphaComponent(0.82).setFill()
        fillPath.fill()
    }
}
