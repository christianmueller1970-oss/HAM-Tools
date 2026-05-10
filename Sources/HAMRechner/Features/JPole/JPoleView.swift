import SwiftUI

// MARK: - Model

enum JPoleVariant: String, CaseIterable, Identifiable {
    case jpole   = "J-Pole"
    case slimjim = "Slim Jim / J-Zepp"
    var id: String { rawValue }
}

private struct JPoleErgebnis {
    let f: Double
    let vf: Double
    let variant: JPoleVariant
    let strahler_m: Double   // λ/2
    let stub_m: Double       // λ/4
    let gesamt_m: Double     // λ/2 + λ/4
    let feed_m: Double       // Einspeisepunkt ab unten (% des Stubs)
    let feedProzent: Double

    static func berechne(f: Double, vf: Double, variant: JPoleVariant) -> JPoleErgebnis? {
        guard f > 0, vf > 0 else { return nil }
        let strahler = 150.0 / f * vf
        let stub     = 75.0  / f * vf
        let pct: Double = variant == .jpole ? 0.05 : 0.04  // Feed-Position
        let feed = stub * pct
        return JPoleErgebnis(f: f, vf: vf, variant: variant,
                             strahler_m: strahler, stub_m: stub,
                             gesamt_m: strahler + stub, feed_m: feed, feedProzent: pct * 100)
    }
}

// MARK: - View

struct JPoleView: View {
    @State private var freqText = "145.0"
    @State private var vfText   = "0.95"
    @State private var variant: JPoleVariant = .jpole

    private var f:  Double { Double(freqText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var vf: Double { Double(vfText.replacingOccurrences(of: ",", with: "."))   ?? 0.95 }
    private var ergebnis: JPoleErgebnis? { JPoleErgebnis.berechne(f: f, vf: vf, variant: variant) }

    private let bands: [(String, Double)] = [
        ("10m", 28.5), ("6m", 50.15), ("4m", 70.0),
        ("2m", 145.0), ("70cm", 432.0), ("23cm", 1296.0)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                variantWahl
                eingabeBereich
                if let r = ergebnis { ergebnisBereich(r); skizzeBereich(r); hinweisBereich(r) }
                RechnerBeschreibung(resourceName: "jpole")
            }
            .padding(24)
        }
        .navigationTitle("J-Pole / Slim Jim")
    }

    // MARK: Variante

    private var variantWahl: some View {
        SectionCard(title: "Variante") {
            Picker("", selection: $variant) {
                ForEach(JPoleVariant.allCases) { v in Text(v.rawValue).tag(v) }
            }
            .pickerStyle(.segmented)
        }
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
                                .buttonStyle(.bordered).controlSize(.small)
                                .tint(abs(f - freq) < 1.0 ? .accentColor : nil)
                        }
                    }
                }
                Divider()
                HStack(spacing: 16) {
                    fieldBox(label: "Frequenz", text: $freqText, unit: "MHz")
                    fieldBox(label: "Verkürzungsfaktor VF", text: $vfText, unit: "")
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

    private func ergebnisBereich(_ r: JPoleErgebnis) -> some View {
        SectionCard(title: "Maße") {
            VStack(spacing: 4) {
                ResultRow(label: "Gesamtlänge (3/4 λ)",          value: String(format: "%.3f m", r.gesamt_m), highlight: true)
                ResultRow(label: "Strahler (λ/2)",                value: String(format: "%.3f m", r.strahler_m))
                ResultRow(label: "Anpass-Stub (λ/4)",             value: String(format: "%.3f m", r.stub_m))
                ResultRow(label: "Einspeisepunkt ab unten",       value: String(format: "%.3f m  (%.0f%% des Stubs)", r.feed_m, r.feedProzent))
                ResultRow(label: "Speisepunkt-Impedanz",          value: "≈ 50 Ω am Einspeisepunkt")
                ResultRow(label: "Frequenz",                      value: String(format: "%.3f MHz", r.f))
            }
        }
    }

    // MARK: Skizze

    private func skizzeBereich(_ r: JPoleErgebnis) -> some View {
        SectionCard(title: "Skizze") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let cx = W / 2
                let topY: CGFloat = 16, botY: CGFloat = H - 24
                let totalPx = botY - topY
                let strahlerRatio = r.strahler_m / r.gesamt_m
                let stubTop = botY - totalPx * strahlerRatio

                // Strahler (rechter Leiter)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx + 22, y: botY))
                    p.addLine(to: CGPoint(x: cx + 22, y: topY))
                }, with: .color(.blue), lineWidth: 4)

                // Stub (linker Leiter)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx - 22, y: botY))
                    p.addLine(to: CGPoint(x: cx - 22, y: stubTop))
                }, with: .color(variant == .slimjim ? Color.orange : Color.gray), lineWidth: 3)

                // Verbindung unten
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx - 22, y: botY))
                    p.addLine(to: CGPoint(x: cx + 22, y: botY))
                }, with: .color(.gray), lineWidth: 2)

                // Offenes Ende des Stubs
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx - 30, y: stubTop))
                    p.addLine(to: CGPoint(x: cx - 14, y: stubTop))
                }, with: .color(.gray), lineWidth: 2)

                // Einspeisepunkt
                let feedRatio = r.feed_m / r.gesamt_m
                let feedY = botY - totalPx * feedRatio
                ctx.fill(Path(ellipseIn: CGRect(x: cx-22-5, y: feedY-5, width: 10, height: 10)), with: .color(.accentColor))
                ctx.draw(Text("50Ω").font(.system(size: 10)).bold().foregroundStyle(Color.accentColor),
                         at: CGPoint(x: cx - 30, y: feedY), anchor: .trailing)

                // Labels
                ctx.draw(Text(String(format: "λ/2  %.3f m", r.strahler_m)).font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: cx + 30, y: (topY + botY) / 2), anchor: .leading)
                ctx.draw(Text(String(format: "λ/4  %.3f m", r.stub_m)).font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: cx + 30, y: (stubTop + botY) / 2), anchor: .leading)
                ctx.draw(Text(String(format: "%.0f%%  %.3f m", r.feedProzent, r.feed_m)).font(.system(size: 10)).foregroundStyle(Color.accentColor),
                         at: CGPoint(x: cx - 30, y: feedY - 14), anchor: .trailing)
            }
            .frame(height: 260)
        }
    }

    // MARK: Hinweis

    private func hinweisBereich(_ r: JPoleErgebnis) -> some View {
        SectionCard(title: "Hinweis") {
            Text(r.variant == .jpole
                 ? "J-Pole: λ/2 Strahler + λ/4 Anpass-Stub. Stub am unteren Ende kurzgeschlossen, oben offen. Einspeisepunkt ca. 5% des Stubs von unten. Omnidirektionale Vertikalantenne ohne Gegengewicht. Ideal für 2m/70cm."
                 : "Slim Jim (J-Zepp): Ähnlich dem J-Pole, jedoch der Strahlerabschnitt einseitig offen (Zepp-Prinzip). Ca. 3 dB Gewinn über Groundplane. Einspeisepunkt ca. 4% des Stubs von unten. Sehr effizient für VHF/UHF.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
