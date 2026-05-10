import SwiftUI

struct PegelUmrechnerView: View {
    @State private var eingabeArt: PegelEingabe = .watt
    @State private var eingabeText: String = "100"
    @State private var impedanz: Double = 50

    private var ergebnis: PegelErgebnis? {
        guard let value = Double(eingabeText.replacingOccurrences(of: ",", with: ".")) else { return nil }
        switch eingabeArt {
        case .watt:       return PegelErgebnis.fromWatt(value)
        case .milliwatt:  return PegelErgebnis.fromMilliwatt(value)
        case .dBm:        return PegelErgebnis.fromDBm(value)
        case .dBW:        return PegelErgebnis.fromDBW(value)
        case .volt:       return PegelErgebnis.fromVolt(value, impedance: impedanz)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if let r = ergebnis {
                    ergebnisBereich(r)
                    referenzBereich(r)
                } else if !eingabeText.isEmpty {
                    Text("Ungültige Eingabe")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
                RechnerBeschreibung(resourceName: "pegelrechner")
            }
            .padding(24)
        }
        .navigationTitle("Pegel-Umrechner")
    }

    private var eingabeBereich: some View {
        SectionCard(title: "Eingabe") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Einheit", selection: $eingabeArt) {
                    ForEach(PegelEingabe.allCases) { e in
                        Text(e.rawValue).tag(e)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    TextField("Wert", text: $eingabeText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                    Text(einheitLabel)
                        .foregroundStyle(.secondary)
                }

                if eingabeArt == .volt {
                    HStack {
                        Text("Impedanz")
                            .foregroundStyle(.secondary)
                        Picker("", selection: $impedanz) {
                            Text("50 Ω").tag(50.0)
                            Text("75 Ω").tag(75.0)
                            Text("600 Ω").tag(600.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 200)
                    }
                }
            }
        }
    }

    private func ergebnisBereich(_ r: PegelErgebnis) -> some View {
        SectionCard(title: "Ergebnisse") {
            VStack(spacing: 6) {
                ResultRow(label: "Leistung", value: formatWatt(r.watt), unit: "W", highlight: eingabeArt == .watt)
                ResultRow(label: "Leistung", value: formatZahl(r.milliwatt, 3), unit: "mW", highlight: eingabeArt == .milliwatt)
                ResultRow(label: "Pegel", value: formatZahl(r.dBm, 2), unit: "dBm", highlight: eingabeArt == .dBm)
                ResultRow(label: "Pegel", value: formatZahl(r.dBW, 2), unit: "dBW", highlight: eingabeArt == .dBW)
                ResultRow(label: "Spannung (50 Ω)", value: formatZahl(r.volt50Ohm, 3), unit: "V", highlight: eingabeArt == .volt)
            }
        }
    }

    private func referenzBereich(_ r: PegelErgebnis) -> some View {
        SectionCard(title: "Referenzpegel Amateurfunk") {
            VStack(spacing: 6) {
                let refs: [(String, Double)] = [
                    ("QRP (5 W)", 5), ("10 W", 10), ("100 W", 100), ("1 kW", 1000)
                ]
                ForEach(refs, id: \.0) { name, refW in
                    let diff = 10 * log10(r.watt / refW)
                    ResultRow(
                        label: name,
                        value: (diff >= 0 ? "+" : "") + formatZahl(diff, 1),
                        unit: "dB"
                    )
                }
            }
        }
    }

    private var einheitLabel: String {
        switch eingabeArt {
        case .watt: return "W"
        case .milliwatt: return "mW"
        case .dBm: return "dBm"
        case .dBW: return "dBW"
        case .volt: return "V"
        }
    }

    private func formatWatt(_ w: Double) -> String {
        if w >= 1000 { return String(format: "%.2f k", w / 1000) }
        if w >= 1    { return String(format: "%.3f", w) }
        if w >= 0.001 { return String(format: "%.3f m", w * 1000) }
        return String(format: "%.3f µ", w * 1_000_000)
    }

    private func formatZahl(_ v: Double, _ stellen: Int) -> String {
        String(format: "%.\(stellen)f", v)
    }
}
