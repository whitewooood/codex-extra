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
            .frame(width: Self.iconSize.width, height: Self.iconSize.height)
            .fixedSize()
            .accessibilityLabel(accessibilityLabel)
            .help(helpText)
    }

    private var accessibilityLabel: String {
        if let usageText = UsageFormatter.menuBarSummary(usage) {
            return "Codex Monitor，剩余额度 \(usageText)"
        }
        return "Codex Monitor，等待用量数据"
    }

    private var helpText: String {
        guard let usage else {
            return "等待 Codex 用量数据"
        }

        let primary = usage.primaryRateLimit.map { "5 小时剩余 \(UsageFormatter.remainingPercent($0))" } ?? "5 小时 --"
        let secondary = usage.secondaryRateLimit.map { "7 天剩余 \(UsageFormatter.remainingPercent($0))" } ?? "7 天 --"
        return "\(primary) · \(secondary) · 右下角为最近任务状态"
    }

    private var meterImage: NSImage {
        let image = NSImage(size: Self.iconSize)
        image.isTemplate = true
        image.lockFocus()
        defer { image.unlockFocus() }

        drawAnchor()

        drawBar(
            rect: CGRect(x: 5.25, y: 10.75, width: 12.35, height: 2.65),
            usedPercent: usage?.primaryRateLimit?.usedPercent,
            fillAlpha: 0.90
        )
        drawBar(
            rect: CGRect(x: 5.25, y: 5.0, width: 12.35, height: 2.65),
            usedPercent: usage?.secondaryRateLimit?.usedPercent,
            fillAlpha: 0.72
        )

        drawStatusDot(in: CGRect(x: 17.35, y: 1.25, width: 4.3, height: 4.3))

        return image
    }

    private func drawAnchor() {
        let anchorPath = NSBezierPath(roundedRect: CGRect(x: 1.75, y: 4.55, width: 2.55, height: 9.7), xRadius: 1.25, yRadius: 1.25)
        NSColor.black.withAlphaComponent(0.46).setFill()
        anchorPath.fill()

        let topNode = NSBezierPath(ovalIn: CGRect(x: 1.35, y: 11.15, width: 3.35, height: 3.35))
        NSColor.black.withAlphaComponent(0.74).setFill()
        topNode.fill()

        let bottomNode = NSBezierPath(ovalIn: CGRect(x: 1.35, y: 4.15, width: 3.35, height: 3.35))
        NSColor.black.withAlphaComponent(0.58).setFill()
        bottomNode.fill()
    }

    private func drawStatusDot(in rect: CGRect) {
        let dotPath = NSBezierPath(ovalIn: rect)
        NSColor.black.withAlphaComponent(statusIntensity).setFill()
        dotPath.fill()
    }

    private func drawBar(rect: CGRect, usedPercent: Double?, fillAlpha: CGFloat) {
        let trackPath = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        NSColor.black.withAlphaComponent(0.16).setFill()
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
        NSColor.black.withAlphaComponent(fillAlpha).setFill()
        fillPath.fill()
    }

    private static let iconSize = NSSize(width: 22, height: 18)
}
