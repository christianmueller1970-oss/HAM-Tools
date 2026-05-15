import SwiftUI
import AppKit

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
    @StateObject private var potaSpotsService: PotaSpotsService = PotaSpotsService()
    @StateObject private var potaStatsService: PotaStatsService
    @StateObject private var sotaSummitService: SotaSummitService
    @StateObject private var sotaSpotsService: SotaSpotsService = SotaSpotsService()
    @StateObject private var wwffRefService: WWFFRefService
    @StateObject private var botaRefService: BOTARefService
    @StateObject private var contestService:   ContestService = ContestService()
    @StateObject private var licenseService:   LicenseService = LicenseService()
    @StateObject private var updateChecker:    UpdateChecker  = UpdateChecker()
    @StateObject private var wsjtxSettings:    WsjtxBridgeSettings = WsjtxBridgeSettings()
    @StateObject private var wsjtxBridge:      WsjtxBridgeService = WsjtxBridgeService()
    // DXClusterViewModel hier auf App-Level, damit auch Pop-up-Fenster
    // (Bandmap-Windows) denselben Spot-Stream sehen — nicht mehr nur das
    // Hauptfenster (ContentView).
    @StateObject private var dxClusterVM:      DXClusterViewModel = DXClusterViewModel()

    init() {
        // Swift-Package-Builds laufen ohne .app-Bundle; macOS würde sie ohne
        // expliziten Activation-Policy-Hint als »Accessory«/CLI behandeln und
        // die Tastatur-Eingaben gingen ans Terminal statt an die App. Beim
        // regulären Xcode-Bundle ist das ein no-op.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

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

        // POTA-Stats kann nicht throwen (Cache-Load schlägt nur still fehl).
        _potaStatsService = StateObject(wrappedValue:
            PotaStatsService(dataRoot: root))

        // SOTA-Summit-DB. Gleiche Fail-Strategie wie PotaParkService.
        do {
            let svc = try SotaSummitService(dataRoot: root)
            _sotaSummitService = StateObject(wrappedValue: svc)
        } catch {
            fatalError("SOTA-Summit-Service konnte nicht initialisiert werden: \(error)")
        }

        // WWFF-Ref-DB. Service unterstützt sowohl URL-Download (wwff-cc.org)
        // als auch manuellen CSV-Import via File-Picker.
        do {
            let svc = try WWFFRefService(dataRoot: root)
            _wwffRefService = StateObject(wrappedValue: svc)
        } catch {
            fatalError("WWFF-Reference-Service konnte nicht initialisiert werden: \(error)")
        }

        // BOTA-Ref-DB. Primär File-Import (kein offener API-Endpoint).
        do {
            let svc = try BOTARefService(dataRoot: root)
            _botaRefService = StateObject(wrappedValue: svc)
        } catch {
            fatalError("BOTA-Reference-Service konnte nicht initialisiert werden: \(error)")
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
                .environmentObject(potaSpotsService)
                .environmentObject(potaStatsService)
                .environmentObject(sotaSummitService)
                .environmentObject(sotaSpotsService)
                .environmentObject(wwffRefService)
                .environmentObject(botaRefService)
                .environmentObject(contestService)
                .environmentObject(licenseService)
                .environmentObject(updateChecker)
                .environmentObject(wsjtxSettings)
                .environmentObject(wsjtxBridge)
                .environmentObject(dxClusterVM)
                .frame(minWidth: 860, minHeight: 560)
                .preferredColorScheme(themeManager.theme.colorScheme)
                .task {
                    // QSY-Bridge: beim Klick auf einen DX-Spot springt der
                    // TRX auf die Spot-Frequenz UND in den passenden Mode
                    // (USB/LSB aus SSB + Frequenz, CW direkt, FT8/FT4/PSK
                    // als PKTUSB/PKTLSB). Die Closure wird hier einmal
                    // gesetzt, weil SpotListView selbst kein CAT-Environment
                    // haben darf (sie wird auch außerhalb des Logbuch-Trees
                    // gerendert).
                    let cat = catController
                    LogEntryBridge.shared.onRequestQSY = { mhz, hamlibMode in
                        Task { @MainActor in
                            guard case .connected = cat.status else { return }
                            await cat.setFrequencyMHz(mhz)
                            if let mode = hamlibMode {
                                await cat.setHamlibMode(mode)
                            }
                        }
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        // Default zugeschnitten auf 13" MacBook Air (1280×800 Default-Skala)
        // — Window-Chrome lässt ~755pt Höhe, Dock zieht weitere ~30pt ab.
        .defaultSize(width: 1180, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Auf Updates prüfen…") {
                    updateChecker.checkNow()
                }
                .keyboardShortcut("u", modifiers: [.command, .option])
            }
            CommandMenu("Transceiver") {
                TransceiverCommands(settings: catSettings,
                                    controller: catController)
            }
            CommandMenu("Fenster") {
                WindowCommands()
            }
            CommandGroup(replacing: .help) {
                Button("Bug melden…") {
                    NotificationCenter.default.post(name: .showBugReport, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
            }
        }

        // Pop-up-Bandmap-Fenster (Multi-Window für Mehrmonitor-Setup).
        // Über das "Fenster"-Menü → "Neue Bandmap ▸ {Band}" geöffnet.
        // WindowGroup(for: String.self) routet pro Band-Namen genau ein
        // Fenster — ein zweiter openWindow-Aufruf mit gleichem Band bringt
        // das existierende Fenster nach vorn. Position+Größe werden vom
        // NSWindow-Restoration-System gemerkt.
        WindowGroup("Bandmap", id: "bandmap", for: String.self) { $band in
            if let band {
                BandmapWindowView(band: band)
                    .environmentObject(themeManager)
                    .environmentObject(dxClusterVM)
                    .frame(minWidth: 280, minHeight: 480)
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 320, height: 800)

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
                .environmentObject(potaSpotsService)
                .environmentObject(potaStatsService)
                .environmentObject(sotaSummitService)
                .environmentObject(sotaSpotsService)
                .environmentObject(wwffRefService)
                .environmentObject(botaRefService)
                .environmentObject(contestService)
                .environmentObject(licenseService)
                .environmentObject(updateChecker)
                .environmentObject(wsjtxSettings)
                .environmentObject(wsjtxBridge)
                .preferredColorScheme(themeManager.theme.colorScheme)
        }
    }
}
