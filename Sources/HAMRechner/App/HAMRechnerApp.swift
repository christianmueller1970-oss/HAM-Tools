import SwiftUI

@main
struct HAMRechnerApp: App {
    @StateObject private var themeManager     = ThemeManager()
    @StateObject private var clusterStore     = ClusterSettingsStore()
    @StateObject private var watchList        = WatchListStore()
    @StateObject private var dataRoot:         AppDataRoot
    @StateObject private var logbookSettings:  LogbookSettings
    @StateObject private var logbookManager:   LogbookManager
    @StateObject private var callbookSettings: CallbookSettings
    @StateObject private var callbookManager:  CallbookManager
    @StateObject private var memoryStore:      MemoryStore
    @StateObject private var radioState:       RadioState
    @StateObject private var catSettings:      CATSettings
    @StateObject private var catController:    CATController
    @StateObject private var potaParkService:  PotaParkService

    init() {
        // Root zuerst — alle anderen Komponenten hängen davon ab.
        let root = AppDataRoot()
        _dataRoot = StateObject(wrappedValue: root)

        // Spot-Cache liegt jetzt in Root/Cache/.
        SpotPersistence.cacheDirectory = root.cacheDir

        let settings = LogbookSettings(dataRoot: root)
        _logbookSettings = StateObject(wrappedValue: settings)
        _logbookManager  = StateObject(wrappedValue:
            LogbookManager(settings: settings, dataRoot: root))

        let cbSettings = CallbookSettings()
        _callbookSettings = StateObject(wrappedValue: cbSettings)
        _callbookManager  = StateObject(wrappedValue:
            CallbookManager(settings: cbSettings, dataRoot: root))

        _memoryStore = StateObject(wrappedValue: MemoryStore(dataRoot: root))

        // RadioState wird zentral hier instanziiert, damit CATController
        // dieselbe Instanz mitbenutzt (sonst spiegelt CAT in eine andere
        // RadioState als die UI rendert).
        let rs = RadioState()
        _radioState = StateObject(wrappedValue: rs)

        let catSet = CATSettings()
        _catSettings = StateObject(wrappedValue: catSet)
        _catController = StateObject(wrappedValue:
            CATController(radioState: rs, settings: catSet))

        // POTA-Park-DB. Schlägt der Init-Throw fehl (z.B. SQLite-Permission),
        // läuft die App weiter — der Settings-Tab zeigt dann den Fehler.
        do {
            let svc = try PotaParkService(dataRoot: root)
            _potaParkService = StateObject(wrappedValue: svc)
        } catch {
            // Fallback: dummy-Init, der Fehler wird beim ersten refresh()
            // im UI angezeigt. Hier kann die App nicht crashen.
            fatalError("POTA-Park-Service konnte nicht initialisiert werden: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(clusterStore)
                .environmentObject(watchList)
                .environmentObject(dataRoot)
                .environmentObject(logbookSettings)
                .environmentObject(logbookManager)
                .environmentObject(callbookSettings)
                .environmentObject(callbookManager)
                .environmentObject(memoryStore)
                .environmentObject(radioState)
                .environmentObject(catSettings)
                .environmentObject(catController)
                .environmentObject(potaParkService)
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
                .environmentObject(dataRoot)
                .environmentObject(logbookSettings)
                .environmentObject(logbookManager)
                .environmentObject(callbookSettings)
                .environmentObject(callbookManager)
                .environmentObject(memoryStore)
                .environmentObject(radioState)
                .environmentObject(catSettings)
                .environmentObject(catController)
                .environmentObject(potaParkService)
                .preferredColorScheme(themeManager.theme.colorScheme)
        }
    }
}
