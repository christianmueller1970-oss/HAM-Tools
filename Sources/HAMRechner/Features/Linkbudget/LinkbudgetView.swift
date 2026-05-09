import SwiftUI

// MARK: - Model

private struct LinkbudgetErgebnis {
    let ptx_dBm: Double
    let gtx_dBi: Double
    let grx_dBi: Double
    let f_MHz: Double
    let dist_km: Double
    let fspl_dB: Double
    let prx_dBm: Double
    let prx_uV: Double    // µV an 50 Ω

    static func berechne(ptx_W: Double, gtx: Double, grx: Double, f: Double, dist: Double) -> LinkbudgetErgebnis? {
        guard ptx_W > 0, f > 0, dist > 0 else { return nil }
        let ptx_dBm = 10 * log10(ptx_W * 1000)
        // Friis: FSPL(dB) = 20·log(d_km) + 20·log(f_MHz) + 32.45
        let fspl = 20 * log10(dist) + 20 * log10(f) + 32.45
        let prx  = ptx_dBm + gtx + grx - fspl
        // µV an 50Ω: P(W) = U²/50 → U = sqrt(P*50)
        let prx_W = pow(10, prx / 10) / 1000
        let prx_uV = sqrt(max(prx_W, 1e-30) * 50) * 1e6
        return LinkbudgetErgebnis(ptx_dBm: ptx_dBm, gtx_dBi: gtx, grx_dBi: grx,
                                  f_MHz: f, dist_km: dist, fspl_dB: fspl,
                                  prx_dBm: prx, prx_uV: prx_uV)
    }
}

// MARK: - View

struct LinkbudgetView: View {
    @State private var ptxText   = "100"
    @State private var gtxText   = "0"
    @State private var grxText   = "0"
    @State private var freqText  = "14.175"
    @State private var distText  = "100"
    @State private var sensitiv  = -120.0  // dBm RX-Empfindlichkeit

    private var ptx_W: Double { Double(ptxText.replacingOccurrences(of: ",", with: "."))  ?? 0 }
    private var gtx:   Double { Double(gtxText.replacingOccurrences(of: ",", with: "."))  ?? 0 }
    private var grx:   Double { Double(grxText.replacingOccurrences(of: ",", with: "."))  ?? 0 }
    private var f:     Double { Double(freqText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var dist:  Double { Double(distText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var ergebnis: LinkbudgetErgebnis? {
        LinkbudgetErgebnis.berechne(ptx_W: ptx_W, gtx: gtx, grx: grx, f: f, dist: dist)
    }

    private let bands: [(String, Double)] = [
        ("160m", 1.85), ("80m", 3.65), ("40m", 7.1), ("20m", 14.175),
        ("15m", 21.225), ("10m", 28.5), ("2m", 145.0), ("70cm", 432.0)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if let r = ergebnis { ergebnisBereich(r); marginBereich(r) }
                hinweisBereich
            }
            .padding(24)
        }
        .navigationTitle("Linkbudget / Reichweite")
    }

    private var eingabeBereich: some View {
        SectionCard(title: "Eingabe") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Band-Schnellwahl").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 4) {
                        ForEach(bands, id: \.0) { name, freq in
                            Button(name) { freqText = String(freq) }
                                .buttonStyle(.bordered).controlSize(.small)
                                .tint(abs(f - freq) < 1 ? .accentColor : nil)
                        }
                    }
                }
                Divider()
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    fieldBox(label: "TX-Leistung",   text: $ptxText,  unit: "W")
                    fieldBox(label: "TX-Gewinn",      text: $gtxText,  unit: "dBi")
                    fieldBox(label: "RX-Gewinn",      text: $grxText,  unit: "dBi")
                    fieldBox(label: "Frequenz",        text: $freqText, unit: "MHz")
                    fieldBox(label: "Distanz",         text: $distText, unit: "km")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RX-Empfindlichkeit").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $sensitiv) {
                            Text("-100 dBm").tag(-100.0)
                            Text("-110 dBm").tag(-110.0)
                            Text("-120 dBm").tag(-120.0)
                            Text("-130 dBm").tag(-130.0)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    private func fieldBox(label: String, text: Binding<String>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("0", text: text).textFieldStyle(.roundedBorder)
                Text(unit).foregroundStyle(.secondary).font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ergebnisBereich(_ r: LinkbudgetErgebnis) -> some View {
        SectionCard(title: "Ergebnis") {
            VStack(spacing: 4) {
                ResultRow(label: "TX-Leistung",          value: String(format: "%.1f dBm  (%.0f W)", r.ptx_dBm, ptx_W))
                ResultRow(label: "TX-Gewinn",            value: String(format: "%.1f dBi", r.gtx_dBi))
                ResultRow(label: "RX-Gewinn",            value: String(format: "%.1f dBi", r.grx_dBi))
                ResultRow(label: "Freiraumdämpfung FSPL", value: String(format: "%.1f dB", r.fspl_dB))
                Divider().padding(.vertical, 2)
                ResultRow(label: "Empfangspegel",         value: String(format: "%.1f dBm", r.prx_dBm), highlight: true)
                ResultRow(label: "Empfangspegel",         value: String(format: "%.3f µV (an 50 Ω)", r.prx_uV))
            }
        }
    }

    private func marginBereich(_ r: LinkbudgetErgebnis) -> some View {
        let margin = r.prx_dBm - sensitiv
        let ok = margin >= 0
        return SectionCard(title: "Link-Margin") {
            HStack(spacing: 12) {
                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(ok ? .green : .red).font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(ok ? "Verbindung möglich" : "Verbindung nicht sicher")
                        .fontWeight(.semibold)
                    Text(String(format: "Margin: %.1f dB über Empfindlichkeit (\(Int(sensitiv)) dBm)", margin))
                        .font(.callout).foregroundStyle(.secondary)
                    if !ok {
                        Text("Leistung erhöhen, bessere Antenne oder kürzere Distanz.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var hinweisBereich: some View {
        SectionCard(title: "Hinweis") {
            Text("Friis-Formel: PRX = PTX + GTX + GRX − FSPL. FSPL = 20·log(d_km) + 20·log(f_MHz) + 32.45 dB. Berechnung ohne Kabelverluste, atmosphärische Dämpfung oder Mehrwegeausbreitung (Freifeld-Modell).")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
