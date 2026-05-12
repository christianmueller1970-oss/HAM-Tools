import SwiftUI

enum Calculator: String, CaseIterable, Identifiable {
    // Live-Tools
    case dxCluster = "DX-Cluster"
    case bandplan  = "IARU R1 Bandplan"
    case logbuch   = "Logbuch"

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
        case .bandplan:            return "chart.bar.xaxis"
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
        case .dxCluster, .bandplan, .logbuch:
            return "Live-Tools"
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
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var dxClusterVM = DXClusterViewModel()
    @StateObject private var simBridge   = AntennaSimBridge.shared
    @StateObject private var logBridge   = LogEntryBridge.shared
    @State private var selectedCalculator: Calculator? = .dxCluster

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        Group {
            if selectedCalculator == .logbuch {
                // Logbuch übernimmt das ganze Fenster — eigene Sidebar links,
                // "Zurück"-Button schaltet auf die Startansicht.
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
        .preferredColorScheme(theme.colorScheme)
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
}

// MARK: - SidebarView

struct SidebarView: View {
    @Binding var selectedCalculator: Calculator?
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.openSettings) private var openSettings

    private let categories = [
        "Live-Tools",
        "Drahtantennen", "Richtstrahler", "Spezialantennen",
        "Spulen & Transformatoren", "Anpassung & Leitungen", "Signale & Tools"
    ]

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedCalculator) {
                ForEach(categories, id: \.self) { category in
                    Section(category) {
                        ForEach(Calculator.allCases.filter { $0.category == category }) { calc in
                            Label(calc.rawValue, systemImage: calc.icon)
                                .foregroundStyle(theme.textPrimary)
                                .tag(calc)
                        }
                    }
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
        // Live-Tools
        case .dxCluster:             DXClusterView()
        case .bandplan:              BandplanView()
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
