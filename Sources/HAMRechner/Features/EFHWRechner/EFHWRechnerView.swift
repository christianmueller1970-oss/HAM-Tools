import SwiftUI

// MARK: - Model

private struct EFHWErgebnis {
    let f: Double
    let vf: Double
    let draht_m: Double       // λ/2
    let gegengew_m: Double    // ≈ 5% λ
    let lambda_m: Double
    let bauds: [String]       // Harmonische Bänder
}

private func berechne(f: Double, vf: Double) -> EFHWErgebnis? {
    guard f > 0, vf > 0, vf <= 1.0 else { return nil }
    let lambda  = 300.0 / f
    let draht   = 150.0 / f * vf
    let gegengew = lambda * 0.05 * vf
    let bauds = harmonischeBaender(f: f)
    return EFHWErgebnis(f: f, vf: vf, draht_m: draht, gegengew_m: gegengew, lambda_m: lambda, bauds: bauds)
}

private func harmonischeBaender(f: Double) -> [String] {
    let allBaender: [(String, ClosedRange<Double>)] = [
        ("160m", 1.8...2.0), ("80m", 3.5...3.8), ("60m", 5.35...5.37),
        ("40m", 7.0...7.2), ("30m", 10.1...10.15), ("20m", 14.0...14.35),
        ("17m", 18.068...18.168), ("15m", 21.0...21.45), ("12m", 24.89...24.99),
        ("10m", 28.0...29.7), ("6m", 50.0...52.0), ("2m", 144.0...146.0)
    ]
    var treffer: [String] = []
    for n in 1...8 {
        let harmonische = f * Double(n)
        for (band, range) in allBaender {
            if range.contains(harmonische) {
                let label = n == 1 ? band : "\(band) (\(n). Harm.)"
                if !treffer.contains(label) { treffer.append(label) }
            }
        }
    }
    return treffer
}

// MARK: - View

struct EFHWRechnerView: View {
    @State private var freqText = "7.1"
    @State private var vfText   = "0.96"

    private var f:  Double { Double(freqText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var vf: Double { Double(vfText.replacingOccurrences(of: ",", with: "."))   ?? 0.96 }
    private var ergebnis: EFHWErgebnis? { berechne(f: f, vf: vf) }

    private let bands: [(String, Double)] = [
        ("160m", 1.85), ("80m", 3.65), ("60m", 5.36), ("40m", 7.1),
        ("30m", 10.125), ("20m", 14.175), ("17m", 18.118), ("15m", 21.225),
        ("12m", 24.94), ("10m", 28.5), ("6m", 50.15), ("2m", 145.0)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if let r = ergebnis {
                    ergebnisBereich(r)
                    skizzeBereich(r)
                    if !r.bauds.isEmpty { bandBereich(r) }
                    hinweisBereich
                }
                RechnerBeschreibung(resourceName: "efhw")
            }
            .padding(24)
        }
        .navigationTitle("EFHW-Antenne")
    }

    // MARK: Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Parameter") {
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
                    fieldBox(label: "Frequenz", text: $freqText, unit: "MHz")
                    fieldBox(label: "Verkürzungsfaktor VF", text: $vfText, unit: "0.90–1.00")
                }
                if f > 0 {
                    Text("λ = \(String(format: "%.3f", 300.0/f)) m  ·  λ/2 = \(String(format: "%.3f", 150.0/f)) m (ohne VF)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func fieldBox(label: String, text: Binding<String>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("0", text: text).textFieldStyle(.roundedBorder)
                if !unit.isEmpty { Text(unit).foregroundStyle(.secondary).font(.caption) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Ergebnis

    private func ergebnisBereich(_ r: EFHWErgebnis) -> some View {
        SectionCard(title: "Maße") {
            VStack(spacing: 4) {
                ResultRow(label: "Drahtlänge (λ/2)",        value: String(format: "%.3f m", r.draht_m), highlight: true)
                ResultRow(label: "Gegengewicht (≈5% λ)",    value: String(format: "%.3f m", r.gegengew_m))
                ResultRow(label: "Eingangsimpedanz",         value: "≈ 2450 Ω")
                ResultRow(label: "Anpass-Transformator",     value: "49:1 Unun")
                Divider().padding(.vertical, 4)
                ResultRow(label: "Wellenlänge λ",            value: String(format: "%.3f m", r.lambda_m))
                ResultRow(label: "Frequenz",                 value: String(format: "%.4f MHz", r.f))
                ResultRow(label: "Verkürzungsfaktor",        value: String(format: "%.3f", r.vf))
            }
        }
    }

    // MARK: Skizze

    private func skizzeBereich(_ r: EFHWErgebnis) -> some View {
        SectionCard(title: "Aufbau-Skizze") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let cy = H / 2

                // 49:1 Unun Box
                let boxW: CGFloat = 56, boxH: CGFloat = 32
                let boxX: CGFloat = 40
                let wireStart = boxX + boxW
                let wireEnd   = W - 24

                ctx.stroke(Path { p in
                    p.addRoundedRect(
                        in: CGRect(x: boxX, y: cy - boxH/2, width: boxW, height: boxH),
                        cornerSize: CGSize(width: 6, height: 6))
                }, with: .color(.orange), lineWidth: 2)
                ctx.draw(
                    Text("49:1").font(.system(size: 12)).bold().foregroundStyle(.orange),
                    at: CGPoint(x: boxX + boxW/2, y: cy - 5), anchor: .center)
                ctx.draw(
                    Text("Unun").font(.system(size: 10)).foregroundStyle(.orange.opacity(0.8)),
                    at: CGPoint(x: boxX + boxW/2, y: cy + 8), anchor: .center)

                // Draht
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: wireStart, y: cy))
                    p.addLine(to: CGPoint(x: wireEnd, y: cy))
                }, with: .color(.blue), lineWidth: 4)

                // Speisepunkt
                ctx.fill(
                    Path(ellipseIn: CGRect(x: boxX - 6, y: cy - 6, width: 12, height: 12)),
                    with: .color(.accentColor))
                ctx.draw(
                    Text("50Ω").font(.system(size: 10)).bold().foregroundStyle(Color.accentColor),
                    at: CGPoint(x: boxX - 10, y: cy), anchor: .trailing)

                // Gegengewicht nach unten
                let ggLen: CGFloat = min(CGFloat(r.gegengew_m / r.draht_m) * (wireEnd - wireStart) * 2, 80)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: boxX, y: cy))
                    p.addLine(to: CGPoint(x: boxX - ggLen * 0.6, y: cy + 40))
                }, with: .color(.secondary), lineWidth: 2)
                ctx.draw(
                    Text(String(format: "GGW %.2f m", r.gegengew_m)).font(.caption2).foregroundStyle(.secondary),
                    at: CGPoint(x: boxX - ggLen * 0.6 - 6, y: cy + 40), anchor: .trailing)

                // Bemaßung oben
                let dimY: CGFloat = cy - 28
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: wireStart, y: dimY))
                    p.addLine(to: CGPoint(x: wireEnd, y: dimY))
                }, with: .color(.secondary.opacity(0.5)), lineWidth: 1)
                for xT: CGFloat in [wireStart, wireEnd] {
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: xT, y: dimY - 4))
                        p.addLine(to: CGPoint(x: xT, y: dimY + 4))
                    }, with: .color(.secondary.opacity(0.5)), lineWidth: 1)
                }
                ctx.draw(
                    Text(String(format: "λ/2 = %.3f m", r.draht_m)).font(.caption).foregroundStyle(.secondary),
                    at: CGPoint(x: (wireStart + wireEnd) / 2, y: dimY - 12), anchor: .center)

                // Trafo-Hinweis
                ctx.draw(
                    Text("FT240-43 · 2:14 Wdg.").font(.system(size: 10)).foregroundStyle(.orange.opacity(0.7)),
                    at: CGPoint(x: boxX + boxW/2, y: cy + boxH/2 + 14), anchor: .center)
            }
            .frame(height: 160)
        }
    }

    // MARK: Harmonische Bänder

    private func bandBereich(_ r: EFHWErgebnis) -> some View {
        SectionCard(title: "Multiband-Nutzung (Harmonische)") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Diese Drahtlänge ist resonant auf folgenden Bändern:")
                    .font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                    ForEach(r.bauds, id: \.self) { band in
                        Text(band)
                            .font(.callout)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    // MARK: Hinweis

    private var hinweisBereich: some View {
        SectionCard(title: "Aufbau-Hinweise") {
            VStack(alignment: .leading, spacing: 10) {
                infoRow(symbol: "arrow.right.to.line.alt",
                        color: .blue,
                        text: "Drahtlänge exakt auf λ/2 abstimmen. Im Freien (VF ≈ 0.96–0.98) ist die physikalische Länge etwas kürzer als λ/2 in der Luft.")
                infoRow(symbol: "square.and.arrow.down",
                        color: .orange,
                        text: "49:1 Unun: 2 Primär + 14 Sekundär-Windungen auf FT240-43 (HF) oder FT140-43 (QRP). 100 pF NP0-Keramik-Kondensator parallel zur Primärwicklung verbessert die Anpassung.")
                infoRow(symbol: "arrow.down.to.line",
                        color: .secondary,
                        text: "Gegengewicht (Counterpoise) mindestens 0.05 λ lang. Kann am Unun-Gehäuse befestigt und in beliebiger Richtung verlegt werden.")
                infoRow(symbol: "checkmark.circle",
                        color: .green,
                        text: "Multiband-Betrieb: Ohne Tuner auf allen Harmonischen nutzbar. Mit ATU kann die Antenne auf weiteren Bändern betrieben werden.")
            }
        }
    }

    private func infoRow(symbol: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 20)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
    }
}
