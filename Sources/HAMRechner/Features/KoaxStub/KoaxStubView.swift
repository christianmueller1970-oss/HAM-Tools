import SwiftUI

struct KoaxStubView: View {
    @State private var freqText = "14.175"
    @State private var vfText   = "0.66"
    @State private var stubTyp  = 0  // 0=offen, 1=kurzgeschlossen

    private var f:  Double { Double(freqText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var vf: Double { Double(vfText.replacingOccurrences(of: ",", with: "."))   ?? 0.66 }
    private var viertel_m: Double { f > 0 ? 75.0 / f * vf : 0 }
    private var halb_m: Double    { f > 0 ? 150.0 / f * vf : 0 }

    private let bands: [(String, Double)] = [
        ("160m", 1.85), ("80m", 3.65), ("40m", 7.1), ("30m", 10.125),
        ("20m", 14.175), ("17m", 18.118), ("15m", 21.225), ("10m", 28.5)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if f > 0 { ergebnisBereich; anwendungBereich; skizzeBereich }
                hinweisBereich
                RechnerBeschreibung(resourceName: "koaxstub")
            }
            .padding(24)
        }
        .navigationTitle("Koax-Stub")
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Frequenz").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("MHz", text: $freqText).textFieldStyle(.roundedBorder)
                            Text("MHz").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Koax Verkürzungsfaktor VF").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $vfText) {
                            Text("0.66 (Schaum/typ.)").tag("0.66")
                            Text("0.82 (PVC)").tag("0.82")
                            Text("0.85 (PE)").tag("0.85")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stub-Abschluss").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $stubTyp) {
                        Text("Offen (open stub)").tag(0)
                        Text("Kurzschluss (shorted stub)").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var ergebnisBereich: some View {
        SectionCard(title: "Längen") {
            VStack(spacing: 4) {
                ResultRow(label: "λ/4 Stub-Länge",  value: String(format: "%.3f m  (%.1f cm)", viertel_m, viertel_m * 100), highlight: true)
                ResultRow(label: "λ/2 Stub-Länge",  value: String(format: "%.3f m  (%.1f cm)", halb_m, halb_m * 100))
                ResultRow(label: "VF",               value: String(format: "%.2f", vf))
                ResultRow(label: "Frequenz",          value: String(format: "%.3f MHz", f))
            }
        }
    }

    private var anwendungBereich: some View {
        SectionCard(title: "Wirkung") {
            VStack(spacing: 4) {
                if stubTyp == 0 {
                    ResultRow(label: "λ/4 offen",   value: "Wirkt wie Kurzschluss → Bandsperre (Seriensperrer)")
                    ResultRow(label: "λ/2 offen",   value: "Wirkt wie Leerlauf → transparent (kein Einfluss)")
                    ResultRow(label: "Anwendung",   value: "Oberwellen-Unterdrückung, Bandsperre")
                } else {
                    ResultRow(label: "λ/4 kurz",    value: "Wirkt wie Leerlauf → transparent (kein Einfluss)")
                    ResultRow(label: "λ/2 kurz",    value: "Wirkt wie Kurzschluss → Bandsperre")
                    ResultRow(label: "Anwendung",   value: "Mantelwellensperre, Potentialtrennung")
                }
            }
        }
    }

    private var skizzeBereich: some View {
        SectionCard(title: "Schema") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let cy = H * 0.4
                let margin: CGFloat = 30
                let stubY1 = cy
                let stubY2 = cy + H * 0.38

                // Hauptleitung
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: margin, y: cy))
                    p.addLine(to: CGPoint(x: W - margin, y: cy))
                }, with: .color(.blue), lineWidth: 3)

                // Stub (senkrecht nach unten)
                let stubX = W * 0.5
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: stubX, y: stubY1))
                    p.addLine(to: CGPoint(x: stubX, y: stubY2))
                }, with: .color(.orange), lineWidth: 2.5)

                // Abschluss
                if stubTyp == 0 {
                    // Offen: kleiner Kreis
                    ctx.stroke(Path(ellipseIn: CGRect(x: stubX-5, y: stubY2-5, width: 10, height: 10)),
                               with: .color(.orange), lineWidth: 2)
                    ctx.draw(Text("offen").font(.system(size: 10)).foregroundStyle(.orange),
                             at: CGPoint(x: stubX, y: stubY2 + 14), anchor: .center)
                } else {
                    // Kurzschluss: GND-Symbol
                    for (i, hw): (Int, CGFloat) in [(0,12),(1,8),(2,4)] {
                        ctx.stroke(Path { p in
                            p.move(to: CGPoint(x: stubX - hw, y: stubY2 + CGFloat(i) * 5))
                            p.addLine(to: CGPoint(x: stubX + hw, y: stubY2 + CGFloat(i) * 5))
                        }, with: .color(.orange), lineWidth: i == 0 ? 2 : 1)
                    }
                    ctx.draw(Text("GND").font(.system(size: 10)).foregroundStyle(.orange),
                             at: CGPoint(x: stubX, y: stubY2 + 20), anchor: .center)
                }

                // Speisepunkt-Dot
                ctx.fill(Path(ellipseIn: CGRect(x: stubX-4, y: stubY1-4, width: 8, height: 8)), with: .color(.accentColor))

                // Labels
                ctx.draw(Text("Einspeisung →").font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: margin, y: cy - 14), anchor: .leading)
                ctx.draw(Text("→ Last").font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: W - margin, y: cy - 14), anchor: .trailing)
                ctx.draw(Text(String(format: "λ/4 = %.3f m", viertel_m)).font(.system(size: 10)).bold().foregroundStyle(.orange),
                         at: CGPoint(x: stubX + 14, y: (stubY1 + stubY2) / 2), anchor: .leading)
            }
            .frame(height: 160)
        }
    }

    private var hinweisBereich: some View {
        SectionCard(title: "Hinweis") {
            Text("Koax-Stub: Stück Koaxkabel, das an einer Stelle parallel in die Leitung eingeschleift wird. Länge und Abschluss bestimmen die Wirkung. λ/4-Stub offen = Bandsperre bei Designfrequenz. Wird für Oberwellen-Unterdrückung und selektive Filterung verwendet.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
