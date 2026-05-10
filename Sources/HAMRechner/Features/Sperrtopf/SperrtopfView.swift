import SwiftUI

struct SperrtopfView: View {
    @State private var freqText  = "14.175"
    @State private var coaxVF    = 0.82

    private var f: Double { Double(freqText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var strahler_m: Double { f > 0 ? 75.0 / f * 0.95 : 0 }
    private var huelle_m: Double   { f > 0 ? 75.0 / f * coaxVF : 0 }

    private let bands: [(String, Double)] = [
        ("160m", 1.85), ("80m", 3.65), ("40m", 7.1), ("30m", 10.125),
        ("20m", 14.175), ("17m", 18.118), ("15m", 21.225), ("12m", 24.94),
        ("10m", 28.5), ("6m", 50.15), ("2m", 145.0), ("70cm", 432.0)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if f > 0 { ergebnisBereich; skizzeBereich; hinweisBereich }
                RechnerBeschreibung(resourceName: "sperrtopf")
            }
            .padding(24)
        }
        .navigationTitle("Sperrtopf")
    }

    // MARK: Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Eingabe") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Band-Schnellwahl").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 4) {
                        ForEach(bands, id: \.0) { name, freq in
                            Button(name) { freqText = String(freq) }
                                .buttonStyle(.bordered).controlSize(.mini)
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
                        Text("Koax-Verkürzungsfaktor (Hülle)").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $coaxVF) {
                            Text("0.66 (Schaum)").tag(0.66)
                            Text("0.82 (PVC)").tag(0.82)
                            Text("0.85 (PE)").tag(0.85)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    // MARK: Ergebnis

    private var ergebnisBereich: some View {
        SectionCard(title: "Maße") {
            VStack(spacing: 4) {
                ResultRow(label: "Strahler / Innenleiter (λ/4)", value: String(format: "%.3f m", strahler_m), highlight: true)
                ResultRow(label: "Koax-Hülle (λ/4 × VF)",        value: String(format: "%.3f m", huelle_m))
                ResultRow(label: "Koax-Verkürzungsfaktor",        value: String(format: "%.2f", coaxVF))
                ResultRow(label: "Speisepunkt-Impedanz",          value: "≈ 50 Ω (kein Gegengewicht nötig)")
                ResultRow(label: "Frequenz",                      value: String(format: "%.3f MHz", f))
            }
        }
    }

    // MARK: Skizze

    private var skizzeBereich: some View {
        SectionCard(title: "Skizze") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let cx = W / 2
                let topY: CGFloat = 16, botY: CGFloat = H - 28
                let innerH = botY - topY
                let sleeveH = innerH * CGFloat(coaxVF / 0.95)
                let sleeveTop = botY - sleeveH

                // Innenleiter (Strahler, blau)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx, y: botY))
                    p.addLine(to: CGPoint(x: cx, y: topY))
                }, with: .color(.blue), lineWidth: 4)

                // Koax-Hülle (grau, links + rechts)
                for dx: CGFloat in [-12, 12] {
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: cx + dx, y: botY))
                        p.addLine(to: CGPoint(x: cx + dx, y: sleeveTop))
                    }, with: .color(.gray), lineWidth: 2.5)
                }
                // Oberes Ende der Hülle
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx - 12, y: sleeveTop))
                    p.addLine(to: CGPoint(x: cx + 12, y: sleeveTop))
                }, with: .color(.gray), lineWidth: 2)
                // Unteres Ende
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx - 12, y: botY))
                    p.addLine(to: CGPoint(x: cx + 12, y: botY))
                }, with: .color(.gray), lineWidth: 2)

                // Speisepunkt
                ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: botY-5, width: 10, height: 10)), with: .color(.accentColor))
                ctx.draw(Text("50Ω").font(.system(size: 11)).bold().foregroundStyle(Color.accentColor),
                         at: CGPoint(x: cx, y: botY + 16), anchor: .center)

                // Labels
                ctx.draw(Text(String(format: "λ/4 = %.3f m", strahler_m)).font(.system(size: 11)).foregroundStyle(.secondary),
                         at: CGPoint(x: cx + 18, y: (topY + botY) / 2), anchor: .leading)
                ctx.draw(Text(String(format: "Hülle %.3f m", huelle_m)).font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: cx - 18, y: (sleeveTop + botY) / 2), anchor: .trailing)
            }
            .frame(height: 220)
        }
    }

    // MARK: Hinweis

    private var hinweisBereich: some View {
        SectionCard(title: "Hinweis") {
            Text("Sperrtopf aus Koaxkabel (auch 'Sleeve-Dipol'): Der Innenleiter bildet den λ/4 Strahler, der Außenleiter wird durch eine koaxiale Hülle (λ/4, VF des Koaxkabels) gegen Mantelwellen abgeschirmt. Kein separates Gegengewicht nötig. Der Sperrtopf wirkt gleichzeitig als Balun.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
