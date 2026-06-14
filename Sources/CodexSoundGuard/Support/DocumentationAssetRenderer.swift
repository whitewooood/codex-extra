import AppKit
import CodexSoundGuardCore
import SwiftUI

@MainActor
enum DocumentationAssetRenderer {
    static func render() throws {
        let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/assets/screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let monitor = SessionMonitor.documentationPreview()
        try render(
            MenuBarPreviewStrip(usage: monitor.latestUsage),
            size: CGSize(width: 840, height: 164),
            to: outputDirectory.appendingPathComponent("menu-bar.png")
        )
        try render(
            MenuBarView()
                .environmentObject(monitor),
            size: CGSize(width: 384, height: 640),
            to: outputDirectory.appendingPathComponent("menu-panel.png")
        )
        try render(
            MenuBarView()
                .environmentObject(monitor)
                .frame(width: 384, height: 330, alignment: .top)
                .clipped(),
            size: CGSize(width: 384, height: 330),
            to: outputDirectory.appendingPathComponent("menu-panel-usage.png")
        )
    }

    private static func render<V: View>(_ view: V, size: CGSize, to url: URL) throws {
        let hostingView = NSHostingView(rootView: view.environment(\.colorScheme, .light))
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.appearance = NSAppearance(named: .aqua)
        hostingView.wantsLayer = true
        hostingView.layoutSubtreeIfNeeded()

        let window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: 120, y: 120), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.orderFrontRegardless()
        window.displayIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.windowNumber),
            [.bestResolution]
        ) else {
            window.orderOut(nil)
            throw RendererError.bitmapCreationFailed
        }

        window.orderOut(nil)
        let bitmap = NSBitmapImageRep(cgImage: cgImage)

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw RendererError.pngEncodingFailed
        }

        try data.write(to: url)
        print("rendered: \(url.path)")
    }
}

private enum RendererError: Error {
    case bitmapCreationFailed
    case pngEncodingFailed
}

private struct MenuBarPreviewStrip: View {
    let usage: TokenUsageSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.red.opacity(0.9))
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(Color.yellow.opacity(0.9))
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(Color.green.opacity(0.9))
                        .frame(width: 12, height: 12)
                }

                Text("Finder")
                    .font(.system(size: 14, weight: .semibold))

                Text("File")
                Text("Edit")
                Text("View")

                Spacer()

                CodexUsageMeter(statusIntensity: 0.70, usage: usage)
                    .frame(width: 28, height: 24)

                Text("Codex Monitor")
                    .font(.system(size: 14, weight: .medium))

                Text("22:40")
                    .font(.system(size: 14, weight: .medium).monospacedDigit())
            }
            .font(.system(size: 14))
            .foregroundStyle(.primary)
            .padding(.horizontal, 18)
            .frame(height: 42)
            .background(.thinMaterial)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.separator.opacity(0.42))
                    .frame(height: 1)
            }

            HStack(alignment: .top, spacing: 14) {
                CodexUsageMeter(statusIntensity: 0.70, usage: usage)
                    .frame(width: 48, height: 46)
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("真实菜单栏图标")
                        .font(.system(size: 17, weight: .semibold))
                    Text("上方为 5 小时剩余额度，下方为 7 天剩余额度。右下角圆点显示最近任务状态。")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.horizontal, 18)
        }
        .frame(width: 840, height: 164)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
