import SwiftUI

// MARK: - Model

private struct HB9CVErgebnis {
    let f: Double
    let lambda: Double
    let vf: Double
    let d_mm: Double
    let l_refl: Double    // Reflektor m
    let l_dir: Double     // Direktor m
    let boom: Double      // Boom m
    let speise: SpeiseTyp
    let gammaPos: Double  // Gamma-Match Stabposition m

    enum SpeiseTyp { case gamma, direkt }

    static func berechne(f: Double, d_mm: Double, boomFaktor: Double, speise: SpeiseTyp, isWire: Bool) -> HB9CVErgebnis? {
        guard f > 0, d_mm > 0 else { return nil }
        let lambda = 300.0 / f
        var vf = vfFromDLambda(d_mm: d_mm, lambda_m: lambda)
        if isWire && vf < 0.97 { vf = min(0.985, vf + 0.01) }
        let l_refl = 0.5 * lambda * vf
        let l_dir  = 0.46 * lambda * vf
        let boom   = boomFaktor * lambda
        let gPos   = 0.08 * l_refl
        return HB9CVErgebnis(f: f, lambda: lambda, vf: vf, d_mm: d_mm,
                             l_refl: l_refl, l_dir: l_dir, boom: boom,
                             speise: speise, gammaPos: gPos)
    }

    private static func vfFromDLambda(d_mm: Double, lambda_m: Double) -> Double {
        let d_lambda = d_mm / (lambda_m * 1000.0)
        var vf = 0.985 - 0.04 * pow(d_lambda * 100.0, 0.4)
        vf = max(0.92, min(0.985, vf))
        return vf
    }
}

// MARK: - View

struct HB9CVView: View {
    @State private var freqText    = "144.3"
    @State private var diamText    = "6.0"
    @State private var boomFaktor  = 0.125
    @State private var speise      = HB9CVErgebnis.SpeiseTyp.gamma
    @State private var isWire      = false

    private var f: Double    { Double(freqText.replacingOccurrences(of: ",", with: "."))  ?? 0 }
    private var d: Double    { Double(diamText.replacingOccurrences(of: ",", with: "."))  ?? 0 }
    private var ergebnis: HB9CVErgebnis? { HB9CVErgebnis.berechne(f: f, d_mm: d, boomFaktor: boomFaktor, speise: speise, isWire: isWire) }

    private let bands: [(String, Double)] = [
        ("80m", 3.65), ("40m", 7.1), ("20m", 14.175), ("15m", 21.225),
        ("10m", 28.5), ("6m", 50.15), ("2m", 144.3), ("70cm", 432.1)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if let r = ergebnis {
                    ergebnisBereich(r)
                    skizzeBereich(r)
                    anpassungBereich(r)
                    bauhinweisBereich(r)
                }
            }
            .padding(24)
        }
        .navigationTitle("HB9CV Beam")
    }

    // MARK: Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Parameter") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Band-Schnellwahl").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 6) {
                        ForEach(bands, id: \.0) { name, freq in
                            Button(name) { freqText = String(freq) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
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
                        Text("Element-Ø").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("mm", text: $diamText).textFieldStyle(.roundedBorder).frame(width: 80)
                            Text("mm").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Boom-Abstand").font(.caption).foregroundStyle(.secondary)
                        Picker("Boom", selection: $boomFaktor) {
                            Text("0.1 λ").tag(0.10)
                            Text("0.125 λ").tag(0.125)
                            Text("0.15 λ").tag(0.15)
                        }
                        .pickerStyle(.segmented)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speisung").font(.caption).foregroundStyle(.secondary)
                        Picker("Speise", selection: $speise) {
                            Text("Gamma-Match").tag(HB9CVErgebnis.SpeiseTyp.gamma)
                            Text("Direkt 50 Ω").tag(HB9CVErgebnis.SpeiseTyp.direkt)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Toggle("Drahtantenne / Spiderbeam-Style", isOn: $isWire)
                    .font(.callout)
            }
        }
    }

    // MARK: Ergebnis

    private func ergebnisBereich(_ r: HB9CVErgebnis) -> some View {
        SectionCard(title: "Maße") {
            VStack(spacing: 4) {
                ResultRow(label: "Wellenlänge λ", value: String(format: "%.3f m", r.lambda))
                ResultRow(label: "Verkürzungsfaktor VF", value: String(format: "%.4f", r.vf))
                Divider().padding(.vertical, 2)
                ResultRow(label: "Reflektor (L1, hinten)", value: String(format: "%.3f m  (%.0f cm)", r.l_refl, r.l_refl * 100), highlight: true)
                ResultRow(label: "Reflektor, halbe Seite", value: String(format: "%.3f m  (%.0f cm)", r.l_refl / 2, r.l_refl / 2 * 100))
                ResultRow(label: "Direktor (L2, vorne)", value: String(format: "%.3f m  (%.0f cm)", r.l_dir, r.l_dir * 100), highlight: true)
                ResultRow(label: "Direktor, halbe Seite", value: String(format: "%.3f m  (%.0f cm)", r.l_dir / 2, r.l_dir / 2 * 100))
                ResultRow(label: "Boom-Länge", value: String(format: "%.3f m  (%.0f cm)", r.boom, r.boom * 100))
                ResultRow(label: "Refl–Direk Abstand", value: String(format: "%.3f m  (%.0f cm)", r.boom, r.boom * 100))
            }
        }
    }

    // MARK: Skizze (Canvas – Draufsicht)

    private func skizzeBereich(_ r: HB9CVErgebnis) -> some View {
        SectionCard(title: "Draufsicht") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let margin: CGFloat = 40
                let maxLen = max(r.l_refl, r.l_dir)
                let boomLen = r.boom
                let scale = min((W - 2 * margin) / CGFloat(maxLen), (H - 60) / CGFloat(boomLen + 0.2))

                let refl_y: CGFloat = margin
                let dir_y = refl_y + CGFloat(boomLen) * scale
                let cx = W / 2
                let refl_w = CGFloat(r.l_refl) * scale
                let dir_w  = CGFloat(r.l_dir) * scale

                // Boom
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx, y: refl_y))
                    p.addLine(to: CGPoint(x: cx, y: dir_y))
                }, with: .color(.gray.opacity(0.5)), lineWidth: 2)

                // Phasenleitungen (gekreuzt X)
                let phOff: CGFloat = 20
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx - phOff, y: refl_y))
                    p.addLine(to: CGPoint(x: cx + phOff, y: dir_y))
                }, with: .color(.red.opacity(0.8)), lineWidth: 2)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx + phOff, y: refl_y))
                    p.addLine(to: CGPoint(x: cx - phOff, y: dir_y))
                }, with: .color(.red.opacity(0.8)), lineWidth: 2)

                // Reflektor
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx - refl_w/2, y: refl_y))
                    p.addLine(to: CGPoint(x: cx + refl_w/2, y: refl_y))
                }, with: .color(.blue), lineWidth: 4)

                // Direktor
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx - dir_w/2, y: dir_y))
                    p.addLine(to: CGPoint(x: cx + dir_w/2, y: dir_y))
                }, with: .color(.green), lineWidth: 4)

                // Speisepunkt
                ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: refl_y-5, width: 10, height: 10)), with: .color(.orange))

                // Beschriftung
                ctx.draw(Text("Reflektor  \(String(format: "%.0f cm", r.l_refl*100))").font(.caption).bold().foregroundStyle(.blue), at: CGPoint(x: cx, y: refl_y - 16), anchor: .center)
                ctx.draw(Text("Direktor  \(String(format: "%.0f cm", r.l_dir*100))").font(.caption).bold().foregroundStyle(.green), at: CGPoint(x: cx, y: dir_y + 16), anchor: .center)
                ctx.draw(Text("Phasenltg.").font(.caption2).foregroundStyle(.red.opacity(0.8)), at: CGPoint(x: cx + phOff + 6, y: (refl_y+dir_y)/2), anchor: .leading)
                ctx.draw(Text(String(format: "← %.0f cm →", r.boom*100)).font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: W - 30, y: (refl_y+dir_y)/2), anchor: .trailing)

                // Richtungspfeil
                let arrowY = dir_y + 36
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx, y: dir_y + 6))
                    p.addLine(to: CGPoint(x: cx, y: arrowY))
                }, with: .color(.blue.opacity(0.6)), lineWidth: 1.5)
                ctx.draw(Text("▼ Abstrahlrichtung").font(.caption2).foregroundStyle(.blue.opacity(0.7)), at: CGPoint(x: cx, y: arrowY + 8), anchor: .center)
            }
            .frame(height: 300)
        }
    }

    // MARK: Anpassung

    private func anpassungBereich(_ r: HB9CVErgebnis) -> some View {
        SectionCard(title: r.speise == .gamma ? "Gamma-Match Anpassung" : "Direkte 50Ω Speisung") {
            if r.speise == .gamma {
                VStack(spacing: 4) {
                    ResultRow(label: "Gamma-Stab Position (von Mitte)", value: String(format: "%.3f m  (%.0f mm)", r.gammaPos, r.gammaPos * 1000))
                    ResultRow(label: "Gamma-Stab Länge (typ.)", value: String(format: "%.0f mm", r.l_refl * 0.04 * 1000))
                    ResultRow(label: "Anpass-Kondensator", value: "variabel, ca. 10–60 pF")
                    ResultRow(label: "Eingangsimpedanz HB9CV", value: "≈ 25–35 Ω (original)")
                }
            } else {
                VStack(spacing: 4) {
                    Text("Die Eingangsimpedanz der HB9CV liegt original bei ca. 25–35 Ω. Für direkte 50Ω-Speisung ist ein Ferrite-Kern Balun oder ein λ/4 Transformator (≈ 35 Ω Koax) nötig.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Bauhinweise

    private func bauhinweisBereich(_ r: HB9CVErgebnis) -> some View {
        SectionCard(title: "Bauhinweise") {
            VStack(alignment: .leading, spacing: 6) {
                Text("• Phasenleitung: gekreuzte Verbindung zwischen Speisepunkt am Reflektor und Einspeisepunkt am Direktor. Leitungslänge = Boom-Abstand, Impedanz ≈ 240 Ω.")
                    .font(.callout).foregroundStyle(.secondary)
                Text("• Gamma-Match-Abgleich: Innenleiter-Länge und Kondensator iterativ einstellen für minimales SWR. Erst Position, dann Kondensator.")
                    .font(.callout).foregroundStyle(.secondary)
                Text("• Reflektor leicht länger als Direktor (Faktor 0.50 vs. 0.46 × λ) – bewährtes HB9CV-Verhältnis.")
                    .font(.callout).foregroundStyle(.secondary)
                Text("• Gewinn: ca. 6–8 dBd. F/B-Verhältnis: 15–20 dB.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}
