import SwiftUI

enum Calculator: String, CaseIterable, Identifiable {
    // Haupt-Anwendungen (Sidebar-Top)
    case logbuch   = "Logbuch"
    case dxCluster = "DX-Cluster"

    // Antennen – Drahtantennen
    case dipol            = "Dipol"
    case groundplane      = "Groundplane / Vertikal"
    case jpole            = "J-Pole / Slim Jim"
    case sperrtopf        = "Sperrtopf"
    case windom           = "Windom (OCFD)"
    case efhwRechner      = "EFHW-Antenne"
    case efhwVerkuerzung  = "EFHW-Verkürzung"
    case loopRechner      = "Loop-Antenne"

    // Antennen – Richtstrahler
    case moxon            = "Moxon Rectangle"
    case hb9cv            = "HB9CV Beam"
    case hexbeam          = "Hexbeam"
    case yagiRechner      = "Yagi-Rechner"
    case spiderbeamEinzelband = "Spiderbeam Einzelband"
    case spiderbeamMultiBand  = "Spiderbeam Multi-Band"

    // Antennen – Spezial
    case magloop          = "Magnetic Loop"

    // Spulen & Transformatoren
    case balunRechner     = "Balun / Unun"
    case mantelwellensperre = "Mantelwellensperre"
    case verlaengerung    = "Strahler-Verlängerung"
    case spulenWickler    = "Spulen-Wickler"

    // Anpassung & Leitungen
    case anpassnetzwerk   = "Anpassnetzwerk (L-Netz)"
    case koaxStub         = "Koax-Stub"
    case kabeldaempfung   = "Kabeldämpfung"

    // Kabel & Signale
    case pegelUmrechner   = "Pegel-Umrechner"
    case swrSimulator     = "SWR-Simulator"
    case linkbudget       = "Linkbudget / Reichweite"
    case qthLocator       = "QTH-Locator"
    case smithChart       = "Smith-Chart"
    case antennenSim      = "Antennen-Simulator"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dxCluster:           return "dot.radiowaves.left.and.right.circle"
        case .logbuch:             return "book.closed"
        case .dipol:               return "antenna.radiowaves.left.and.right"
        case .groundplane:         return "arrow.up.to.line"
        case .jpole:               return "j.square"
        case .sperrtopf:           return "cylinder"
        case .windom:              return "angle"
        case .efhwRechner:         return "arrow.right.to.line.alt"
        case .efhwVerkuerzung:     return "coil"
        case .loopRechner:         return "circle.dashed"
        case .moxon:               return "rectangle"
        case .hb9cv:               return "dot.radiowaves.left.and.right"
        case .hexbeam:             return "hexagon"
        case .yagiRechner:         return "arrow.right.to.line.alt"
        case .spiderbeamEinzelband: return "star.leadinghalf.filled"
        case .spiderbeamMultiBand: return "star"
        case .magloop:             return "circle.dotted"
        case .balunRechner:        return "arrow.2.squarepath"
        case .mantelwellensperre:  return "circle.hexagongrid"
        case .verlaengerung:       return "ruler"
        case .spulenWickler:       return "spiral"
        case .anpassnetzwerk:      return "slider.horizontal.3"
        case .koaxStub:            return "cable.connector"
        case .kabeldaempfung:      return "cable.connector.slash"
        case .pegelUmrechner:      return "waveform"
        case .swrSimulator:        return "chart.xyaxis.line"
        case .linkbudget:          return "dot.radiowaves.forward"
        case .qthLocator:          return "mappin.and.ellipse"
        case .smithChart:          return "circle.circle"
        case .antennenSim:         return "antenna.radiowaves.left.and.right"
        }
    }

    var category: String {
        switch self {
        case .dxCluster, .logbuch:
            return "Haupt"
        case .dipol, .groundplane, .jpole, .sperrtopf, .windom,
             .efhwRechner, .efhwVerkuerzung, .loopRechner:
            return "Drahtantennen"
        case .moxon, .hb9cv, .hexbeam, .yagiRechner,
             .spiderbeamEinzelband, .spiderbeamMultiBand:
            return "Richtstrahler"
        case .magloop:
            return "Spezialantennen"
        case .balunRechner, .mantelwellensperre, .verlaengerung, .spulenWickler:
            return "Spulen & Transformatoren"
        case .anpassnetzwerk, .koaxStub, .kabeldaempfung:
            return "Anpassung & Leitungen"
        case .pegelUmrechner, .swrSimulator, .linkbudget, .qthLocator, .smithChart, .antennenSim:
            return "Signale & Tools"
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var themeManager:   ThemeManager
    @EnvironmentObject var watchList:      WatchListStore
    @EnvironmentObject var clusterStore:   ClusterSettingsStore
    @EnvironmentObject var logbookManager: LogbookManager
    @EnvironmentObject var licenseService: LicenseService
    @EnvironmentObject var updateChecker:  UpdateChecker
    @EnvironmentObject var wsjtxSettings:  WsjtxBridgeSettings
    @EnvironmentObject var wsjtxBridge:    WsjtxBridgeService
    @StateObject private var dxClusterVM = DXClusterViewModel()
    @StateObject private var simBridge   = AntennaSimBridge.shared
    @StateObject private var logBridge   = LogEntryBridge.shared
    @State private var selectedCalculator: Calculator? = .logbuch
    @State private var pendingUpdatePayload: UpdateManifestPayload?
    @State private var showBugReport: Bool = false

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        VStack(spacing: 0) {
            LicenseBanner()
            mainContent
        }
        .preferredColorScheme(theme.colorScheme)
        .onAppear {
            // DX-Cluster-Verbindung global beim App-Start aufbauen — damit
            // Band Activity, Propagation-Daten und POTA/SOTA-Spots im Logbuch
            // sofort verfügbar sind, ohne dass der User erst auf den DX-Cluster-
            // Tab wechseln muss.
            dxClusterVM.setup(watchStore: watchList)
            if let node = clusterStore.activeNode {
                dxClusterVM.connect(host: node.host, port: node.port, name: node.name)
            } else {
                dxClusterVM.connect()
            }

            // Lizenz-Hooks im LogbookManager verkabeln. Closure-Capture statt
            // direkter Service-Referenz, damit der Manager License-agnostisch bleibt.
            let lic = licenseService
            logbookManager.licenseAllowsMoreQSOs = { lic.canLogMoreQSOs }
            logbookManager.onQSOLogged           = { lic.registerLoggedQSO() }

            // WSJT-X-Bridge: bei jedem QSOLogged-UDP-Paket → ins aktive Log
            // einfügen. Sucht das Log über currentLogID; falls keins offen ist,
            // wird das QSO verworfen (User-Feedback via wsjtxBridge.lastError
            // wäre die Alternative — aktuell konservativ).
            let lm = logbookManager
            wsjtxBridge.onQSOLogged = { msg in
                guard let logID = lm.currentLogID,
                      let activeLog = lm.logs.first(where: { $0.id == logID })
                else { return }
                let qso = WsjtxQSOConverter.qso(from: msg, into: activeLog)
                // Doppelt-Schutz für QSOs aus WSJT-X (z.B. wenn der Operator
                // zweimal "Log QSO" drückt): gleiches Call+Band+Mode innerhalb
                // 60 Sek wird verworfen.
                let isDupe = lm.currentQSOs.contains { e in
                    e.call == qso.call
                        && e.band == qso.band
                        && e.mode == qso.mode
                        && abs(e.datetime.timeIntervalSince(qso.datetime)) <= 60
                }
                guard !isDupe else { return }
                lm.addQSO(qso)
            }
            if wsjtxSettings.enabled {
                wsjtxBridge.start(port: wsjtxSettings.port)
            }

            // Update-Check beim Start (max 1×/24h).
            updateChecker.autoCheckIfDue()
        }
        .onChange(of: wsjtxSettings.enabled) { _, newValue in
            if newValue { wsjtxBridge.start(port: wsjtxSettings.port) }
            else        { wsjtxBridge.stop() }
        }
        .onChange(of: wsjtxSettings.port) { _, _ in
            if wsjtxSettings.enabled {
                wsjtxBridge.restart(port: wsjtxSettings.port)
            }
        }
        .onChange(of: updateChecker.state) { _, new in
            if case .updateAvailable(let payload) = new {
                pendingUpdatePayload = payload
            }
        }
        .sheet(item: $pendingUpdatePayload) { payload in
            UpdateAlertView(payload: payload)
                .environmentObject(updateChecker)
                .environmentObject(licenseService)
        }
        .alert(item: $updateChecker.manualCheckResult) { result in
            Alert(
                title: Text(result.title),
                message: Text(result.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showBugReport) {
            BugReportSheet()
                .environmentObject(themeManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showBugReport)) { _ in
            showBugReport = true
        }
        .onChange(of: simBridge.navigationRequest) {
            if simBridge.navigationRequest != nil {
                selectedCalculator = .antennenSim
            }
        }
        .onChange(of: logBridge.navigationRequest) {
            if logBridge.navigationRequest != nil {
                selectedCalculator = .logbuch
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            if selectedCalculator == .logbuch {
                // Logbuch übernimmt das ganze Fenster — eigene Top-Bar oben,
                // "Übersicht"-Button schaltet zur Sidebar-Welt zurück (Rechner etc.).
                LogbuchView(onBackToHome: {
                    selectedCalculator = .dxCluster
                })
                .environmentObject(themeManager)
                .environmentObject(logBridge)
                .environmentObject(dxClusterVM)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.bgApp)
                .preferredColorScheme(theme.colorScheme)
            } else {
                NavigationSplitView {
                    SidebarView(selectedCalculator: $selectedCalculator)
                } detail: {
                    if let calc = selectedCalculator {
                        CalculatorRouter(calculator: calc)
                            .environmentObject(dxClusterVM)
                            .environmentObject(themeManager)
                            .environmentObject(simBridge)
                            .environmentObject(logBridge)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(theme.bgApp)
                            .preferredColorScheme(theme.colorScheme)
                    } else {
                        WelcomeView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(theme.bgApp)
                    }
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
    }
}

// MARK: - SidebarView

struct SidebarView: View {
    @Binding var selectedCalculator: Calculator?
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.openSettings) private var openSettings

    // Sub-Kategorien unter "Rechner" — Reihenfolge ist die Anzeige-Reihenfolge.
    private let rechnerSubCategories = [
        "Drahtantennen", "Richtstrahler", "Spezialantennen",
        "Spulen & Transformatoren", "Anpassung & Leitungen", "Signale & Tools"
    ]

    // Persistierte Expand-States — User-Wunsch: Sidebar-Zustand bleibt erhalten.
    @AppStorage("sidebar.rechner.expanded")    private var rechnerExpanded:   Bool = false
    @AppStorage("sidebar.draht.expanded")      private var drahtExpanded:     Bool = false
    @AppStorage("sidebar.richt.expanded")      private var richtExpanded:     Bool = false
    @AppStorage("sidebar.spezial.expanded")    private var spezialExpanded:   Bool = false
    @AppStorage("sidebar.spulen.expanded")     private var spulenExpanded:    Bool = false
    @AppStorage("sidebar.anpassung.expanded")  private var anpassungExpanded: Bool = false
    @AppStorage("sidebar.signale.expanded")    private var signaleExpanded:   Bool = false

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedCalculator) {
                // Top-Punkte: die zwei Haupt-Anwendungen, flach ohne Section-Header.
                Label(Calculator.logbuch.rawValue, systemImage: Calculator.logbuch.icon)
                    .foregroundStyle(theme.textPrimary)
                    .tag(Calculator.logbuch)

                Label(Calculator.dxCluster.rawValue, systemImage: Calculator.dxCluster.icon)
                    .foregroundStyle(theme.textPrimary)
                    .tag(Calculator.dxCluster)

                // Rechner-Akkordeon — beim Ausklappen erscheinen die 6 Sub-Sektionen,
                // die wiederum die Einzel-Rechner als Tags enthalten.
                DisclosureGroup(isExpanded: $rechnerExpanded) {
                    ForEach(rechnerSubCategories, id: \.self) { sub in
                        DisclosureGroup(isExpanded: binding(for: sub)) {
                            ForEach(Calculator.allCases.filter { $0.category == sub }) { calc in
                                Label(calc.rawValue, systemImage: calc.icon)
                                    .foregroundStyle(theme.textPrimary)
                                    .tag(calc)
                            }
                        } label: {
                            Label(sub, systemImage: icon(for: sub))
                                .foregroundStyle(theme.textPrimary)
                        }
                    }
                } label: {
                    Label("Rechner", systemImage: "function")
                        .foregroundStyle(theme.textPrimary)
                        .font(.body.weight(.semibold))
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(theme.bgPanel)

            Divider()
            catToggleRow
            settingsButton
        }
        .background(theme.bgPanel)
        .navigationTitle("HAM-Tools")
        .navigationSubtitle("HB9HJI Funkwelt")
        .navigationSplitViewColumnWidth(min: 220, ideal: 230, max: 320)
    }

    private func binding(for subCategory: String) -> Binding<Bool> {
        switch subCategory {
        case "Drahtantennen":             return $drahtExpanded
        case "Richtstrahler":             return $richtExpanded
        case "Spezialantennen":           return $spezialExpanded
        case "Spulen & Transformatoren":  return $spulenExpanded
        case "Anpassung & Leitungen":     return $anpassungExpanded
        case "Signale & Tools":           return $signaleExpanded
        default:                          return .constant(false)
        }
    }

    private func icon(for subCategory: String) -> String {
        switch subCategory {
        case "Drahtantennen":             return "antenna.radiowaves.left.and.right"
        case "Richtstrahler":             return "dot.radiowaves.forward"
        case "Spezialantennen":           return "circle.dotted"
        case "Spulen & Transformatoren":  return "spiral"
        case "Anpassung & Leitungen":     return "slider.horizontal.3"
        case "Signale & Tools":           return "waveform"
        default:                          return "folder"
        }
    }

    private var catToggleRow: some View {
        HStack {
            CATStatusBadge(isClickable: true)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var settingsButton: some View {
        Button { openSettings() } label: {
            Label("Einstellungen", systemImage: "gear")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - CalculatorRouter

struct CalculatorRouter: View {
    let calculator: Calculator

    var body: some View {
        switch calculator {
        // Haupt-Anwendungen
        case .dxCluster:             DXClusterView()
        case .logbuch:               EmptyView()  // Logbuch wird auf Container-Ebene gerendert
        // Drahtantennen
        case .dipol:             DipolView()
        case .groundplane:       GroundplaneView()
        case .jpole:             JPoleView()
        case .sperrtopf:         SperrtopfView()
        case .windom:            WindomView()
        case .efhwRechner:       EFHWRechnerView()
        case .efhwVerkuerzung:   EFHWVerkuerzungView()
        case .loopRechner:       LoopRechnerView()
        // Richtstrahler
        case .moxon:             MoxonView()
        case .hb9cv:             HB9CVView()
        case .hexbeam:           HexbeamView()
        case .yagiRechner:       YagiRechnerView()
        case .spiderbeamEinzelband: SpiderbeamEinzelbandView()
        case .spiderbeamMultiBand:  SpiderbeamMultiBandView()
        // Spezialantennen
        case .magloop:           MagloopView()
        // Spulen & Transformatoren
        case .balunRechner:      BalunRechnerView()
        case .mantelwellensperre: MantelwellensperreView()
        case .verlaengerung:     VerlaengerungView()
        case .spulenWickler:     SpulenWicklerView()
        // Anpassung & Leitungen
        case .anpassnetzwerk:    AnpassnetzwerkView()
        case .koaxStub:          KoaxStubView()
        case .kabeldaempfung:    KabeldaempfungView()
        // Signale & Tools
        case .pegelUmrechner:    PegelUmrechnerView()
        case .swrSimulator:      SWRSimulatorView()
        case .linkbudget:        LinkbudgetView()
        case .qthLocator:        QTHLocatorView()
        case .smithChart:        SmithChartView()
        case .antennenSim:       AntennenSimulatorView()
        }
    }
}

// MARK: - WelcomeView

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            Text("HAM-Tools")
                .font(.largeTitle.bold())
            Text("Wähle ein Tool aus der Seitenleiste")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
