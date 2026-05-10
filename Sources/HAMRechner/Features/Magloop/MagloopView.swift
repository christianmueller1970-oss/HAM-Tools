import SwiftUI

// MARK: - Model

enum MagloopShape: String, CaseIterable, Identifiable {
    case kreis    = "Kreis"
    case achteck  = "Achteck"
    case quadrat  = "Quadrat"
    var id: String { rawValue }
}

private struct MagloopErgebnis {
    let f: Double
    let d: Double         // Loop-Durchmesser m
    let wire_mm: Double   // Drahtdurchmesser mm
    let power: Double     // Sendeleistung W
    let shape: MagloopShape
    let L_h: Double       // Induktivität H
    let L_uH: Double      // Induktivität µH
    let XL: Double        // induktiver Blindwiderstand Ω
    let C_f: Double       // Resonanzkapazität F
    let C_pF: Double      // Resonanzkapazität pF
    let V_rms: Double     // Spannung am Kondensator V
    let R_rad: Double     // Strahlungswiderstand Ω
    let R_loss: Double    // Verlustwiderstnd Ω
    let R_total: Double
    let Q: Double
    let BW_hz: Double     // Bandbreite Hz
    let eta: Double       // Wirkungsgrad %
    let couplingD: Double // Kopplungsschleife m

    var spannungBewertung: SpannungsBewertung {
        if V_rms > 2000 { return .gefahr }
        if V_rms > 1000 { return .warnung }
        return .ok
    }

    enum SpannungsBewertung {
        case ok, warnung, gefahr
        var farbe: Color { switch self { case .ok: .green; case .warnung: .orange; case .gefahr: .red } }
        var label: String { switch self { case .ok: "OK"; case .warnung: "Warnung"; case .gefahr: "Gefahr!" } }
    }

    static func berechne(f: Double, d: Double, wire_mm: Double, power: Double, shape: MagloopShape) -> MagloopErgebnis? {
        guard f > 0, d > 0, wire_mm > 0, power > 0 else { return nil }
        let mu0    = 4.0 * .pi * 1e-7
        let rho_cu = 1.72e-8
        let f_hz   = f * 1e6
        let r      = d / 2.0            // Loop-Radius m
        let a      = wire_mm / 2.0 / 1000.0  // Drahtradius m

        let L_h: Double
        let perim: Double
        switch shape {
        case .kreis:
            L_h  = mu0 * r * (log(8.0 * r / a) - 2.0)
            perim = 2.0 * .pi * r
        case .achteck:
            perim = 8.0 * d * tan(.pi / 8.0)
            L_h  = mu0 * perim / (2.0 * .pi) * (log(perim / (.pi * a)) - 0.2235 * (8.0 - 1.0) + 0.726)
        case .quadrat:
            perim = 4.0 * d
            L_h  = mu0 * perim / (2.0 * .pi) * (log(perim / (.pi * a)) - 0.2235 * (4.0 - 1.0) + 0.726)
        }

        guard L_h > 0 else { return nil }
        let L_uH  = L_h * 1e6
        let XL    = 2.0 * .pi * f_hz * L_h
        let C_f   = 1.0 / ((2.0 * .pi * f_hz) * (2.0 * .pi * f_hz) * L_h)
        let C_pF  = C_f * 1e12

        let V_rms = sqrt(power * XL)

        // Strahlungswiderstand (kleine Schleife)
        let lambda = 300.0 / f    // m, f in MHz
        let R_rad  = 31200.0 * pow(perim / lambda, 4)

        // Verlustwiderstand (Skin-Effekt)
        let Rs     = sqrt(.pi * f_hz * mu0 * rho_cu)
        let R_loss = Rs * perim / (2.0 * .pi * a)

        let R_total = R_rad + R_loss
        let Q       = XL / R_total
        let BW_hz   = f_hz / Q
        let eta     = R_rad / R_total * 100.0

        return MagloopErgebnis(
            f: f, d: d, wire_mm: wire_mm, power: power, shape: shape,
            L_h: L_h, L_uH: L_uH, XL: XL,
            C_f: C_f, C_pF: C_pF, V_rms: V_rms,
            R_rad: R_rad, R_loss: R_loss, R_total: R_total,
            Q: Q, BW_hz: BW_hz, eta: eta,
            couplingD: d / 5.0
        )
    }
}

// MARK: - View

struct MagloopView: View {
    @State private var freqText   = "14.2"
    @State private var diamText   = "1.0"
    @State private var wireText   = "22.0"
    @State private var powerText  = "10"
    @State private var shape      = MagloopShape.kreis

    private var f:     Double { Double(freqText.replacingOccurrences(of: ",", with: "."))  ?? 0 }
    private var d:     Double { Double(diamText.replacingOccurrences(of: ",", with: "."))  ?? 0 }
    private var wire:  Double { Double(wireText.replacingOccurrences(of: ",", with: "."))  ?? 0 }
    private var power: Double { Double(powerText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var ergebnis: MagloopErgebnis? { MagloopErgebnis.berechne(f: f, d: d, wire_mm: wire, power: power, shape: shape) }

    private let bands: [(String, Double)] = [
        ("160m", 1.85), ("80m", 3.65), ("40m", 7.1), ("30m", 10.125),
        ("20m", 14.175), ("17m", 18.118), ("15m", 21.225), ("12m", 24.94), ("10m", 28.5)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if let r = ergebnis {
                    spannungsWarnung(r)
                    ergebnisBereich(r)
                    skizzeBereich(r)
                    detailBereich(r)
                }
                infoBereich
                RechnerBeschreibung(resourceName: "magloop")
            }
            .padding(24)
        }
        .navigationTitle("Magnetic Loop")
    }

    // MARK: Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Parameter") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Band-Schnellwahl").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 6) {
                        ForEach(bands.prefix(9), id: \.0) { name, freq in
                            Button(name) { freqText = String(freq) }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .tint(abs(f - freq) < 0.5 ? .accentColor : nil)
                        }
                    }
                }
                Divider()
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Frequenz").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("MHz", text: $freqText).textFieldStyle(.roundedBorder)
                            Text("MHz").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Loop-Durchmesser").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("m", text: $diamText).textFieldStyle(.roundedBorder).frame(width: 80)
                            Text("m").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Leiter-Ø (Rohr/Draht)").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("mm", text: $wireText).textFieldStyle(.roundedBorder).frame(width: 80)
                            Text("mm").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sendeleistung").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("W", text: $powerText).textFieldStyle(.roundedBorder).frame(width: 80)
                            Text("W").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Loop-Form").font(.caption).foregroundStyle(.secondary)
                    Picker("Form", selection: $shape) {
                        ForEach(MagloopShape.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    // MARK: Spannung

    @ViewBuilder
    private func spannungsWarnung(_ r: MagloopErgebnis) -> some View {
        let b = r.spannungBewertung
        if b != .ok {
            HStack(spacing: 12) {
                Image(systemName: b == .gefahr ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(b.farbe).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(b == .gefahr ? "Hohe Kondensatorspannung – Lebensgefahr!" : "Kondensatorspannung erhöht")
                        .fontWeight(.semibold).foregroundStyle(b.farbe)
                    Text(b == .gefahr
                         ? "Spannung von \(String(format: "%.0f V", r.V_rms)) RMS! Hochspannungs-Luftdrehkondensator oder Vakuumkondensator erforderlich. Niemals während Betrieb berühren."
                         : "Spannung von \(String(format: "%.0f V", r.V_rms)) V RMS am Drehko. Spezial-Kondensator mit ausreichend Spannungsfestigkeit nötig.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(b.farbe.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: Ergebnis

    private func ergebnisBereich(_ r: MagloopErgebnis) -> some View {
        SectionCard(title: "Kenngrößen") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                KenngroesseKachel(wert: String(format: "%.2f µH", r.L_uH), label: "Induktivität", hervorheben: true, farbe: .accentColor)
                KenngroesseKachel(wert: String(format: "%.1f pF", r.C_pF), label: "Resonanzkapazität")
                KenngroesseKachel(wert: voltString(r.V_rms), label: "Spannung Drehko", hervorheben: r.V_rms > 1000, farbe: r.spannungBewertung.farbe)
                KenngroesseKachel(wert: String(format: "%.0f", r.Q), label: "Güte Q")
                KenngroesseKachel(wert: bwString(r.BW_hz), label: "Bandbreite BW")
                KenngroesseKachel(wert: String(format: "%.1f %%", r.eta), label: "Wirkungsgrad η")
            }
        }
    }

    private func voltString(_ v: Double) -> String {
        v >= 1000 ? String(format: "%.1f kV", v/1000) : String(format: "%.0f V", v)
    }

    private func bwString(_ hz: Double) -> String {
        hz >= 1000 ? String(format: "%.1f kHz", hz/1000) : String(format: "%.0f Hz", hz)
    }

    // MARK: Skizze

    private func skizzeBereich(_ r: MagloopErgebnis) -> some View {
        SectionCard(title: "Skizze") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let cx = W / 2, cy = H / 2 - 10
                let rad = min(W, H) * 0.32
                let coupRad = rad / 5.0

                // Hauptschleife
                ctx.stroke(Path { p in
                    p.addEllipse(in: CGRect(x: cx - rad, y: cy - rad, width: 2*rad, height: 2*rad))
                }, with: .color(.blue), lineWidth: 4)

                // Kondensator oben
                let capY = cy - rad
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx - 12, y: capY))
                    p.addLine(to: CGPoint(x: cx + 12, y: capY))
                }, with: .color(.orange), lineWidth: 3)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx - 12, y: capY - 6))
                    p.addLine(to: CGPoint(x: cx + 12, y: capY - 6))
                }, with: .color(.orange), lineWidth: 3)

                // Kopplungsschleife unten
                let coupCy = cy + rad - coupRad - 8
                ctx.stroke(Path { p in
                    p.addEllipse(in: CGRect(x: cx - coupRad, y: coupCy - coupRad, width: 2*coupRad, height: 2*coupRad))
                }, with: .color(.green), lineWidth: 2)

                // Beschriftungen
                ctx.draw(Text("Drehko").font(.caption2).foregroundStyle(.orange), at: CGPoint(x: cx, y: capY - 14), anchor: .center)
                ctx.draw(Text(String(format: "%.0f V", r.V_rms)).font(.caption).bold().foregroundStyle(r.spannungBewertung.farbe), at: CGPoint(x: cx + rad + 4, y: capY), anchor: .leading)
                ctx.draw(Text(String(format: "Ø %.0f cm", r.couplingD*100)).font(.caption2).foregroundStyle(.green), at: CGPoint(x: cx, y: coupCy + coupRad + 12), anchor: .center)
                ctx.draw(Text("Kopplung").font(.caption2).foregroundStyle(.green), at: CGPoint(x: cx, y: coupCy + coupRad + 24), anchor: .center)
                ctx.draw(Text(String(format: "Ø %.2f m", r.d)).font(.caption).foregroundStyle(.secondary), at: CGPoint(x: cx, y: cy + rad + 12), anchor: .center)
            }
            .frame(height: 280)
        }
    }

    // MARK: Detail

    private func detailBereich(_ r: MagloopErgebnis) -> some View {
        SectionCard(title: "Technische Details") {
            VStack(spacing: 4) {
                ResultRow(label: "Induktivität L", value: String(format: "%.3f µH", r.L_uH))
                ResultRow(label: "Induktiver Blindwiderstand XL", value: String(format: "%.1f Ω", r.XL))
                ResultRow(label: "Resonanzkapazität C", value: String(format: "%.2f pF", r.C_pF))
                ResultRow(label: "Spannung am Drehko", value: voltString(r.V_rms), highlight: true)
                Divider().padding(.vertical, 2)
                ResultRow(label: "Strahlungswiderstand R_rad", value: String(format: "%.4f Ω", r.R_rad))
                ResultRow(label: "Verlustwiderstand R_loss", value: String(format: "%.3f Ω", r.R_loss))
                ResultRow(label: "Güte Q", value: String(format: "%.0f", r.Q))
                ResultRow(label: "Bandbreite BW", value: bwString(r.BW_hz))
                ResultRow(label: "Wirkungsgrad η", value: String(format: "%.2f %%", r.eta))
                Divider().padding(.vertical, 2)
                ResultRow(label: "Kopplungsschleife Ø", value: String(format: "%.3f m  (%.0f cm)", r.couplingD, r.couplingD * 100))
            }
        }
    }

    // MARK: Info

    private var infoBereich: some View {
        SectionCard(title: "Hinweis") {
            Text("Die Kopplungsschleife hat 1/5 des Hauptloop-Durchmessers und wird am unteren Ende der Hauptschleife montiert. Position und Abstand beeinflussen die Anpassung (50Ω). Experimentieren erforderlich! Frequenz-Abstimmung durch Ändern der Kapazität des Drehkos. Nur bei resonanter Abstimmung maximale Effizienz.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
