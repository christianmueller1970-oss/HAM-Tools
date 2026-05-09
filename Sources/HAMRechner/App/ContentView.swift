import SwiftUI

enum Calculator: String, CaseIterable, Identifiable {
    // Antennen
    case antennenDesigner = "Antennen-Designer"
    case hb9cv = "HB9CV Beam"
    case loopRechner = "Loop-Antenne"
    case magloop = "Magnetic Loop"
    case yagiRechner = "Yagi-Rechner"
    case spiderbeamMultiBand = "Spiderbeam Multi-Band"
    case spiderbeamEinzelband = "Spiderbeam Einzelband"

    // Spulen & Transformatoren
    case balunRechner = "Balun / Unun"
    case efhwVerkuerzung = "EFHW-Verkürzung"
    case spulenWickler = "Spulen-Wickler"
    case verlaengerung = "Strahler-Verlängerung"

    // Kabel & Signale
    case kabeldaempfung = "Kabeldämpfung"
    case pegelUmrechner = "Pegel-Umrechner"
    case swrSimulator = "SWR-Simulator"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .antennenDesigner: return "antenna.radiowaves.left.and.right"
        case .hb9cv: return "dot.radiowaves.left.and.right"
        case .loopRechner: return "circle.dashed"
        case .magloop: return "circle.dotted"
        case .yagiRechner: return "arrow.right.to.line.alt"
        case .spiderbeamMultiBand: return "star"
        case .spiderbeamEinzelband: return "star.leadinghalf.filled"
        case .balunRechner: return "arrow.2.squarepath"
        case .efhwVerkuerzung: return "coil"
        case .spulenWickler: return "spiral"
        case .verlaengerung: return "ruler"
        case .kabeldaempfung: return "cable.connector"
        case .pegelUmrechner: return "waveform"
        case .swrSimulator: return "chart.xyaxis.line"
        }
    }

    var category: String {
        switch self {
        case .antennenDesigner, .hb9cv, .loopRechner, .magloop,
             .yagiRechner, .spiderbeamMultiBand, .spiderbeamEinzelband:
            return "Antennen"
        case .balunRechner, .efhwVerkuerzung, .spulenWickler, .verlaengerung:
            return "Spulen & Transformatoren"
        case .kabeldaempfung, .pegelUmrechner, .swrSimulator:
            return "Kabel & Signale"
        }
    }
}

struct ContentView: View {
    @State private var selectedCalculator: Calculator? = .pegelUmrechner

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedCalculator: $selectedCalculator)
        } detail: {
            if let calc = selectedCalculator {
                CalculatorRouter(calculator: calc)
            } else {
                WelcomeView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct SidebarView: View {
    @Binding var selectedCalculator: Calculator?

    private let categories = ["Antennen", "Spulen & Transformatoren", "Kabel & Signale"]

    var body: some View {
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
        .navigationTitle("HAM-Rechner")
        .navigationSubtitle("HB9HJI Funkwelt")
    }
}

struct CalculatorRouter: View {
    let calculator: Calculator

    var body: some View {
        switch calculator {
        case .pegelUmrechner:
            PegelUmrechnerView()
        case .kabeldaempfung:
            KabeldaempfungView()
        case .swrSimulator:
            SWRSimulatorView()
        case .balunRechner:
            BalunRechnerView()
        case .spulenWickler:
            SpulenWicklerView()
        case .efhwVerkuerzung:
            EFHWVerkuerzungView()
        case .verlaengerung:
            VerlaengerungView()
        case .antennenDesigner:
            AntennenDesignerView()
        case .hb9cv:
            HB9CVView()
        case .loopRechner:
            LoopRechnerView()
        case .magloop:
            MagloopView()
        case .yagiRechner:
            YagiRechnerView()
        case .spiderbeamMultiBand:
            SpiderbeamMultiBandView()
        case .spiderbeamEinzelband:
            SpiderbeamEinzelbandView()
        }
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            Text("HAM-Rechner")
                .font(.largeTitle.bold())
            Text("Wähle einen Rechner aus der Seitenleiste")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
