import SwiftUI

// MARK: - Model

private struct LNetz {
    let rs: Double  // Quellimpedanz Ω
    let rl: Double  // Lastimpedanz Ω
    let f:  Double  // Frequenz MHz
    // Konfiguration 1 (Tiefpass): Spule in Serie, Kondensator parallel zur Last
    let xl1: Double   // induktiv (serie)
    let xc1: Double   // kapazitiv (parallel)
    let l1_uH: Double
    let c1_pF: Double
    // Konfiguration 2 (Hochpass): Kondensator in Serie, Spule parallel zur Last
    let xc2: Double
    let xl2: Double
    let c2_pF: Double
    let l2_uH: Double
    let q: Double

    static func berechne(rs: Double, rl: Double, f: Double) -> LNetz? {
        guard rs > 0, rl > 0, f > 0, rs != rl else { return nil }
        let rHigh = max(rs, rl)
        let rLow  = min(rs, rl)
        let q = sqrt(rHigh / rLow - 1.0)
        let w = 2.0 * .pi * f * 1e6

        // Tiefpass: Spule Serie + C parallel
        let xl1 = rLow * q
        let xc1 = rHigh / q
        let l1 = xl1 / w * 1e6          // µH
        let c1 = 1.0 / (w * xc1) * 1e12 // pF

        // Hochpass: C Serie + Spule parallel
        let xc2 = rLow * q
        let xl2 = rHigh / q
        let c2 = 1.0 / (w * xc2) * 1e12
        let l2 = xl2 / w * 1e6

        return LNetz(rs: rs, rl: rl, f: f,
                     xl1: xl1, xc1: xc1, l1_uH: l1, c1_pF: c1,
                     xc2: xc2, xl2: xl2, c2_pF: c2, l2_uH: l2, q: q)
    }
}

// MARK: - View

struct AnpassnetzwerkView: View {
    @State private var rsText  = "50.0"
    @State private var rlText  = "200.0"
    @State private var freqText = "14.175"

    private var rs: Double { Double(rsText.replacingOccurrences(of: ",", with: "."))   ?? 0 }
    private var rl: Double { Double(rlText.replacingOccurrences(of: ",", with: "."))   ?? 0 }
    private var f:  Double { Double(freqText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var ergebnis: LNetz? { LNetz.berechne(rs: rs, rl: rl, f: f) }

    private let bands: [(String, Double)] = [
        ("160m", 1.85), ("80m", 3.65), ("40m", 7.1), ("30m", 10.125),
        ("20m", 14.175), ("17m", 18.118), ("15m", 21.225), ("10m", 28.5)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if let r = ergebnis {
                    ergebnisBereich(r)
                    skizzeBereich(r)
                } else if rs > 0 && rl > 0 && rs == rl {
                    SectionCard(title: "Kein Netzwerk nötig") {
                        Text("Quell- und Lastimpedanz sind identisch – kein Anpassnetzwerk erforderlich.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                hinweisBereich
                RechnerBeschreibung(resourceName: "anpassnetz")
            }
            .padding(24)
        }
        .navigationTitle("Anpassnetzwerk (L-Netz)")
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
                                .tint(abs(f - freq) < 0.5 ? .accentColor : nil)
                        }
                    }
                }
                Divider()
                HStack(spacing: 16) {
                    fieldBox(label: "Quellimpedanz Rs", text: $rsText, unit: "Ω")
                    fieldBox(label: "Lastimpedanz Rl",  text: $rlText, unit: "Ω")
                    fieldBox(label: "Frequenz",         text: $freqText, unit: "MHz")
                }
                Text("Typisch: Rs=50Ω (Koax) → Rl=200Ω (Antenne) oder umgekehrt").font(.caption2).foregroundStyle(.secondary)
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

    private func ergebnisBereich(_ r: LNetz) -> some View {
        VStack(spacing: 16) {
            SectionCard(title: "Tiefpass L-Netz (L + C parallel)") {
                VStack(spacing: 4) {
                    ResultRow(label: "Güte Q",               value: String(format: "%.2f", r.q))
                    ResultRow(label: "Spule (Serie)",         value: String(format: "%.3f µH  (XL = %.1f Ω)", r.l1_uH, r.xl1), highlight: true)
                    ResultRow(label: "Kondensator (Parallel)", value: String(format: "%.1f pF  (XC = %.1f Ω)", r.c1_pF, r.xc1), highlight: true)
                    ResultRow(label: "Konfiguration",         value: rs < rl ? "Rs→[L]→[C∥]→Rl" : "Rl→[L]→[C∥]→Rs")
                }
            }
            SectionCard(title: "Hochpass L-Netz (C + L parallel)") {
                VStack(spacing: 4) {
                    ResultRow(label: "Güte Q",               value: String(format: "%.2f", r.q))
                    ResultRow(label: "Kondensator (Serie)",   value: String(format: "%.1f pF  (XC = %.1f Ω)", r.c2_pF, r.xc2), highlight: true)
                    ResultRow(label: "Spule (Parallel)",      value: String(format: "%.3f µH  (XL = %.1f Ω)", r.l2_uH, r.xl2), highlight: true)
                    ResultRow(label: "Konfiguration",         value: rs < rl ? "Rs→[C]→[L∥]→Rl" : "Rl→[C]→[L∥]→Rs")
                }
            }
        }
    }

    private func skizzeBereich(_ r: LNetz) -> some View {
        SectionCard(title: "Schema Tiefpass L-Netz") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let cy = H / 2
                let margin: CGFloat = 30
                let nodeX: CGFloat = W * 0.42  // Knoten Mitte

                // Leitungen
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: margin, y: cy))
                    p.addLine(to: CGPoint(x: nodeX - 30, y: cy))
                }, with: .color(.blue), lineWidth: 2)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: nodeX + 10, y: cy))
                    p.addLine(to: CGPoint(x: W - margin, y: cy))
                }, with: .color(.blue), lineWidth: 2)

                // Spulen-Symbol (serie)
                let nCoil = 5
                let coilX: CGFloat = nodeX - 30
                let coilW: CGFloat = 40
                let coilAmp: CGFloat = 8
                var coilPath = Path()
                coilPath.move(to: CGPoint(x: coilX, y: cy))
                for i in 0..<nCoil {
                    let x1 = coilX + CGFloat(i) * coilW / CGFloat(nCoil)
                    let x2 = coilX + CGFloat(i + 1) * coilW / CGFloat(nCoil)
                    coilPath.addCurve(to: CGPoint(x: x2, y: cy),
                                      control1: CGPoint(x: x1, y: cy - coilAmp),
                                      control2: CGPoint(x: x2, y: cy - coilAmp))
                }
                ctx.stroke(coilPath, with: .color(.blue), lineWidth: 2)
                ctx.draw(Text(String(format: "%.3f µH", r.l1_uH)).font(.system(size: 10)).foregroundStyle(.blue),
                         at: CGPoint(x: coilX + coilW / 2, y: cy - 18), anchor: .center)

                // Kondensator-Symbol (parallel, senkrecht nach unten)
                let capX = nodeX + 10
                let capLen: CGFloat = 22
                let capGap: CGFloat = 5
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: capX, y: cy))
                    p.addLine(to: CGPoint(x: capX, y: cy + capLen - capGap))
                }, with: .color(.orange), lineWidth: 2)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: capX, y: cy + capLen + capGap))
                    p.addLine(to: CGPoint(x: capX, y: cy + 44))
                }, with: .color(.orange), lineWidth: 2)
                // Platten
                for yOff: CGFloat in [capLen - capGap, capLen + capGap] {
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: capX - 12, y: cy + yOff))
                        p.addLine(to: CGPoint(x: capX + 12, y: cy + yOff))
                    }, with: .color(.orange), lineWidth: 2.5)
                }
                // GND
                for (i, halfW): (Int, CGFloat) in [(0,10),(1,7),(2,4)] {
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: capX - halfW, y: cy + 44 + CGFloat(i) * 5))
                        p.addLine(to: CGPoint(x: capX + halfW, y: cy + 44 + CGFloat(i) * 5))
                    }, with: .color(.secondary), lineWidth: i == 0 ? 2 : 1)
                }
                ctx.draw(Text(String(format: "%.0f pF", r.c1_pF)).font(.system(size: 10)).foregroundStyle(.orange),
                         at: CGPoint(x: capX + 18, y: cy + capLen), anchor: .leading)

                // Labels
                ctx.draw(Text("Rs = \(String(format: "%.0f Ω", r.rs))").font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: margin, y: cy - 14), anchor: .leading)
                ctx.draw(Text("Rl = \(String(format: "%.0f Ω", r.rl))").font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: W - margin, y: cy - 14), anchor: .trailing)
            }
            .frame(height: 140)
        }
    }

    private var hinweisBereich: some View {
        SectionCard(title: "Hinweis") {
            Text("L-Netzwerk für Impedanzanpassung. Die Güte Q bestimmt die Bandbreite: hohes Q → schmal. Tiefpass-Variante unterdrückt Oberwellen. Hochpass-Variante lässt Harmonische durch. Für hohe Leistungen: Luftspulen und NP0-Kondensatoren verwenden.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
