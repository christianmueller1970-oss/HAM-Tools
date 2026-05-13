import SwiftUI
import AppKit

@main
struct HAMToolsLicenseGenApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("HAM-Tools License Generator") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
