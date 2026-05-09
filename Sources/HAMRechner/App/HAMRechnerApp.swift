import SwiftUI

@main
struct HAMRechnerApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var clusterStore = ClusterSettingsStore()
    @StateObject private var watchList    = WatchListStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(clusterStore)
                .environmentObject(watchList)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            EinstellungenView()
                .environmentObject(themeManager)
                .environmentObject(clusterStore)
                .environmentObject(watchList)
        }
    }
}
