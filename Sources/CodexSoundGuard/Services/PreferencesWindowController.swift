import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    func show(monitor: SessionMonitor) {
        let window = window ?? makeWindow(monitor: monitor)
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow(monitor: SessionMonitor) -> NSWindow {
        let hostingView = NSHostingView(rootView: PreferencesView().environmentObject(monitor))
        let size = NSSize(width: 740, height: 520)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Monitor 设置"
        window.contentView = hostingView
        window.minSize = size
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        return window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
