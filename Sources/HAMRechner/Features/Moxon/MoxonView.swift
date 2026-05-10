import SwiftUI

// MARK: - Model

private struct MoxonErgebnis {
    let f: Double
    let vf: Double
    let A: Double  // horizontale Seite (Strahler)
    let B: Double  // Rücklauf je Seite (Strahler)
    let C: Double  // Lücke
    let D: Double  // Rücklauf je Seite (Reflektor)
    let E: Double  // horizontale Seite (Reflektor)
    let gesamttiefe: Double  // B + C + D
    let drahtLaengeTreiber: Double
    let drahtLaengeReflektor: Double

    // G3TXQ-Koeffizienten für wire-Moxon (normiert auf λ)
    static func berechne(f: Double, vf: Double) -> MoxonErgebnis? {
        guard f > 0, vf > 0 else { return nil }
        let lam = 300.0 / f * vf
        // Koeffizienten nach G3TXQ / VK2ZOI
        let A = lam * 0.4750
        let B = lam * 0.0500
        let C = lam * 0.0156
        let D = lam * 0.0624
        let E = lam * 0.4750
        return MoxonErgebnis(f: f, vf: vf, A: A, B: B, C: C, D: D, E: E,
                             gesamttiefe: B + C + D,
                             drahtLaengeTreiber: A + 2 * B,
                             drahtLaengeReflektor: E + 2 * D)
    }
}

// MARK: - View

struct MoxonView: View {
    @State private var freqText = "14.175"
    @State private var vfText   = "0.95"

    private var f:  Double { Double(freqText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var vf: Double { Double(vfText.replacingOccurrences(of: ",", with: "."))   ?? 0.95 }
    private var ergebnis: MoxonErgebnis? { MoxonErgebnis.berechne(f: f, vf: vf) }

    private let bands: [(String, Double)] = [
        ("160m", 1.85), ("80m", 3.65), ("40m", 7.1), ("30m", 10.125),
        ("20m", 14.175), ("17m", 18.118), ("15m", 21.225), ("12m", 24.94),
        ("10m", 28.5), ("6m", 50.15)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if let r = ergebnis { ergebnisBereich(r); skizzeBereich(r); hinweisBereich }
                RechnerBeschreibung(resourceName: "moxon")
            }
            .padding(24)
        }
        .navigationTitle("Moxon Rectangle")
    }

    private var eingabeBereich: some View {
        SectionCard(title: "Eingabe") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Band-Schnellwahl").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 4) {
                        ForEach(bands, id: \.0) { name, freq in
                            Button(name) { freqText = String(freq) }
                                .buttonStyle(.bordered).controlSize(.small)
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
                        Text("Verkürzungsfaktor VF").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("0.95", text: $vfText).textFieldStyle(.roundedBorder).frame(width: 80)
                        }
                    }
                }
            }
        }
    }

    private func ergebnisBereich(_ r: MoxonErgebnis) -> some View {
        VStack(spacing: 16) {
            SectionCard(title: "Maße") {
                VStack(spacing: 4) {
                    ResultRow(label: "A – Treiber horizontal",       value: String(format: "%.3f m", r.A), highlight: true)
                    ResultRow(label: "B – Treiber Rücklauf (je)",    value: String(format: "%.3f m", r.B))
                    ResultRow(label: "C – Lücke",                    value: String(format: "%.3f m", r.C))
                    ResultRow(label: "D – Reflektor Rücklauf (je)",  value: String(format: "%.3f m", r.D))
                    ResultRow(label: "E – Reflektor horizontal",     value: String(format: "%.3f m", r.E))
                    Divider().padding(.vertical, 2)
                    ResultRow(label: "Gesamttiefe (B+C+D)",          value: String(format: "%.3f m", r.gesamttiefe))
                    ResultRow(label: "Breite (= A = E)",             value: String(format: "%.3f m", r.A))
                    ResultRow(label: "Drahtlänge Treiber",           value: String(format: "%.3f m", r.drahtLaengeTreiber))
                    ResultRow(label: "Drahtlänge Reflektor",         value: String(format: "%.3f m", r.drahtLaengeReflektor))
                    ResultRow(label: "Speisepunkt-Impedanz",         value: "≈ 50 Ω")
                }
            }
        }
    }

    private func skizzeBereich(_ r: MoxonErgebnis) -> some View {
        SectionCard(title: "Skizze (Draufsicht)") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let margin: CGFloat = 44
                let labelH: CGFloat = 40
                let availW = W - 2 * margin
                let availH = H - 2 * margin - labelH

                // Skalierung: Breite = A, Tiefe = B+C+D
                let physW = r.A
                let physH = r.gesamttiefe
                let scale = min(availW / CGFloat(physW), availH / CGFloat(physH)) * 0.9

                let bPx = CGFloat(r.A) * scale
                let bRueT = CGFloat(r.B) * scale
                let gapPx = CGFloat(r.C) * scale
                let dRueR = CGFloat(r.D) * scale

                let cx = W / 2
                let topY = margin + (availH - CGFloat(physH) * scale) / 2

                let tLeft  = cx - bPx / 2
                let tRight = cx + bPx / 2
                let tY     = topY                  // Treiber horizontal
                let bY     = topY + bRueT + gapPx + dRueR  // Reflektor horizontal

                // Treiber (blau)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: tLeft, y: tY + bRueT))
                    p.addLine(to: CGPoint(x: tLeft, y: tY))
                    p.addLine(to: CGPoint(x: tRight, y: tY))
                    p.addLine(to: CGPoint(x: tRight, y: tY + bRueT))
                }, with: .color(.blue), lineWidth: 2.5)

                // Reflektor (grau)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: tLeft, y: bY - dRueR))
                    p.addLine(to: CGPoint(x: tLeft, y: bY))
                    p.addLine(to: CGPoint(x: tRight, y: bY))
                    p.addLine(to: CGPoint(x: tRight, y: bY - dRueR))
                }, with: .color(.gray), lineWidth: 2.5)

                // Lücke (gestrichelt)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: tLeft, y: tY + bRueT))
                    p.addLine(to: CGPoint(x: tLeft, y: tY + bRueT + gapPx))
                }, with: .color(.secondary.opacity(0.4)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: tRight, y: tY + bRueT))
                    p.addLine(to: CGPoint(x: tRight, y: tY + bRueT + gapPx))
                }, with: .color(.secondary.opacity(0.4)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                // Speisepunkt
                ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: tY-5, width: 10, height: 10)), with: .color(.accentColor))
                ctx.draw(Text("50Ω").font(.system(size: 10)).bold().foregroundStyle(Color.accentColor),
                         at: CGPoint(x: cx, y: tY - 14), anchor: .center)

                // Bemaßungs-Labels
                ctx.draw(Text(String(format: "A = %.3f m", r.A)).font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: cx, y: tY - 28), anchor: .center)
                ctx.draw(Text(String(format: "B=%.3f  C=%.3f  D=%.3f", r.B, r.C, r.D)).font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: W / 2, y: H - 8), anchor: .center)

                // Richtungsanzeige
                ctx.draw(Text("▶ Hauptrichtung").font(.system(size: 9)).foregroundStyle(.blue.opacity(0.7)),
                         at: CGPoint(x: W - margin + 4, y: tY + (bY - tY) / 2), anchor: .leading)
            }
            .frame(height: 240)
        }
    }

    private var hinweisBereich: some View {
        SectionCard(title: "Hinweis") {
            Text("Moxon Rectangle: kompakte 2-Element-Antenne (Treiber + Reflektor), die Enden sind nach innen gebogen und bilden eine Lücke (C). Gewinn ≈ 5 dBd, F/B-Verhältnis ≈ 20–30 dB. Speisepunkt-Impedanz ≈ 50 Ω. Footprint deutlich kleiner als ein Yagi. Koeffizienten nach G3TXQ.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
