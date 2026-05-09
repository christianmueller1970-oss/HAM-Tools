import AppKit
import SwiftUI

@MainActor
final class SendSpotPanel: NSObject, NSWindowDelegate {
    static let shared = SendSpotPanel()

    private var panel: NSPanel?

    func show(callsign: String, onSend: @escaping (Double, String, String) -> Void) {
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let content = SendSpotSheet(
            callsign: callsign,
            onDismiss: { [weak self] in self?.close() },
            onSend: onSend
        )
        panel.contentViewController = NSHostingController(rootView: content)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = panel
    }

    func close() {
        panel?.close()
    }

    func windowWillClose(_ notification: Notification) {
        panel = nil
    }
}
