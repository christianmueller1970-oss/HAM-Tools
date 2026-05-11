import SwiftUI

@main
struct HAMRechnerApp: App {
    @StateObject private var themeManager  = ThemeManager()
    @StateObject private var clusterStore  = ClusterSettingsStore()
    @StateObject private var watchList     = WatchListStore()
    @StateObject private var logbuchStore  = LogbuchStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(clusterStore)
                .environmentObject(watchList)
                .environmentObject(logbuchStore)
                .frame(minWidth: 900, minHeight: 580)
                .preferredColorScheme(themeManager.theme.colorScheme)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1280, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            EinstellungenView()
                .environmentObject(themeManager)
                .environmentObject(clusterStore)
                .environmentObject(watchList)
                .environmentObject(logbuchStore)
                .preferredColorScheme(themeManager.theme.colorScheme)
        }
    }
}
