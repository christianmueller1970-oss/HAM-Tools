import SwiftUI

enum Calculator: String, CaseIterable, Identifiable {
    // Live-Tools
    case dxCluster = "DX-Cluster"

    // Antennen – Drahtantennen
    case dipol            = "Dipol"
    case groundplane      = "Groundplane / Vertikal"
    case jpole            = "J-Pole / Slim Jim"
    case sperrtopf        = "Sperrtopf"
    case windom           = "Windom (OCFD)"
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
    case antennenDesigner = "Antennen-Designer"

    // Spulen & Transformatoren
    case balunRechner     = "Balun / Unun"
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

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dxCluster:           return "dot.radiowaves.left.and.right.circle"
        case .dipol:               return "antenna.radiowaves.left.and.right"
        case .groundplane:         return "arrow.up.to.line"
        case .jpole:               return "j.square"
        case .sperrtopf:           return "cylinder"
        case .windom:              return "angle"
        case .efhwVerkuerzung:     return "coil"
        case .loopRechner:         return "circle.dashed"
        case .moxon:               return "rectangle"
        case .hb9cv:               return "dot.radiowaves.left.and.right"
        case .hexbeam:             return "hexagon"
        case .yagiRechner:         return "arrow.right.to.line.alt"
        case .spiderbeamEinzelband: return "star.leadinghalf.filled"
        case .spiderbeamMultiBand: return "star"
        case .magloop:             return "circle.dotted"
        case .antennenDesigner:    return "wand.and.stars"
        case .balunRechner:        return "arrow.2.squarepath"
        case .verlaengerung:       return "ruler"
        case .spulenWickler:       return "spiral"
        case .anpassnetzwerk:      return "slider.horizontal.3"
        case .koaxStub:            return "cable.connector"
        case .kabeldaempfung:      return "cable.connector.slash"
        case .pegelUmrechner:      return "waveform"
        case .swrSimulator:        return "chart.xyaxis.line"
        case .linkbudget:          return "dot.radiowaves.forward"
        case .qthLocator:          return "mappin.and.ellipse"
        }
    }

    var category: String {
        switch self {
        case .dxCluster:
            return "Live-Tools"
        case .dipol, .groundplane, .jpole, .sperrtopf, .windom,
             .efhwVerkuerzung, .loopRechner:
            return "Drahtantennen"
        case .moxon, .hb9cv, .hexbeam, .yagiRechner,
             .spiderbeamEinzelband, .spiderbeamMultiBand:
            return "Richtstrahler"
        case .magloop, .antennenDesigner:
            return "Spezialantennen"
        case .balunRechner, .verlaengerung, .spulenWickler:
            return "Spulen & Transformatoren"
        case .anpassnetzwerk, .koaxStub, .kabeldaempfung:
            return "Anpassung & Leitungen"
        case .pegelUmrechner, .swrSimulator, .linkbudget, .qthLocator:
            return "Signale & Tools"
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var dxClusterVM = DXClusterViewModel()
    @State private var selectedCalculator: Calculator? = .dxCluster

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedCalculator: $selectedCalculator)
        } detail: {
            if let calc = selectedCalculator {
                CalculatorRouter(calculator: calc)
                    .environmentObject(dxClusterVM)
                    .environmentObject(themeManager)
            } else {
                WelcomeView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(themeManager.theme.colorScheme)
    }
}

// MARK: - SidebarView

struct SidebarView: View {
    @Binding var selectedCalculator: Calculator?
    @EnvironmentObject var themeManager: ThemeManager

    private let categories = [
        "Live-Tools",
        "Drahtantennen", "Richtstrahler", "Spezialantennen",
        "Spulen & Transformatoren", "Anpassung & Leitungen", "Signale & Tools"
    ]

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedCalculator) {
                ForEach(categories, id: \.self) { category in
                    Section(category) {
                        ForEach(Calculator.allCases.filter { $0.category == category }) { calc in
                            Label(calc.rawValue, systemImage: calc.icon)
                                .tag(calc)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()
            themePicker
        }
        .navigationTitle("HAM-Tools")
        .navigationSubtitle("HB9HJI Funkwelt")
        .navigationSplitViewColumnWidth(min: 220, ideal: 230, max: 320)
    }

    private var themePicker: some View {
        HStack {
            Image(systemName: "paintpalette")
                .foregroundStyle(.secondary)
                .font(.caption)
            Picker("", selection: Binding(
                get: { themeManager.theme },
                set: { themeManager.setTheme($0) }
            )) {
                ForEach(AppTheme.allCases) { t in
                    Text(t.displayName).tag(t)
                }
            }
            .pickerStyle(.menu)
        }
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
        // Drahtantennen
        case .dipol:             DipolView()
        case .groundplane:       GroundplaneView()
        case .jpole:             JPoleView()
        case .sperrtopf:         SperrtopfView()
        case .windom:            WindomView()
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
        case .antennenDesigner:  AntennenDesignerView()
        // Spulen & Transformatoren
        case .balunRechner:      BalunRechnerView()
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
