import SwiftUI

// MARK: - Model

enum DipolTyp: String, CaseIterable, Identifiable {
    case klassisch = "λ/2 Dipol (klassisch)"
    case falter    = "Faltdipol (λ/2)"
    var id: String { rawValue }
}

private struct DipolErgebnis {
    let f: Double
    let vf: Double
    let typ: DipolTyp
    let gesamt_m: Double   // Gesamtlänge
    let arm_m: Double      // jeder Arm
    let impedanz: String

    static func berechne(f: Double, vf: Double, typ: DipolTyp) -> DipolErgebnis? {
        guard f > 0, vf > 0 else { return nil }
        let gesamt = 150.0 / f * vf
        let imp = typ == .klassisch ? "≈ 50–75 Ω" : "≈ 240–300 Ω (4:1 Balun → 50 Ω)"
        return DipolErgebnis(f: f, vf: vf, typ: typ, gesamt_m: gesamt, arm_m: gesamt / 2, impedanz: imp)
    }
}

// MARK: - View

struct DipolView: View {
    @EnvironmentObject var simBridge: AntennaSimBridge
    @State private var freqText = "14.175"
    @State private var vfText   = "0.95"
    @State private var typ: DipolTyp = .klassisch

    private var f:  Double { Double(freqText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var vf: Double { Double(vfText.replacingOccurrences(of: ",", with: "."))   ?? 0.95 }
    private var ergebnis: DipolErgebnis? { DipolErgebnis.berechne(f: f, vf: vf, typ: typ) }

    private let bands: [(String, Double)] = [
        ("160m", 1.85), ("80m", 3.65), ("60m", 5.36), ("40m", 7.1),
        ("30m", 10.125), ("20m", 14.175), ("17m", 18.118), ("15m", 21.225),
        ("12m", 24.94), ("10m", 28.5), ("6m", 50.15), ("2m", 145.0)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                typWahl
                eingabeBereich
                if let r = ergebnis { ergebnisBereich(r); skizzeBereich(r); hinweisBereich(r) }
                RechnerBeschreibung(resourceName: "dipol")
            }
            .padding(24)
        }
        .navigationTitle("Dipol")
    }

    // MARK: Typ-Wahl

    private var typWahl: some View {
        SectionCard(title: "Dipol-Variante") {
            Picker("", selection: $typ) {
                ForEach(DipolTyp.allCases) { t in Text(t.rawValue).tag(t) }
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
                                .buttonStyle(.bordered).controlSize(.mini)
                                .tint(abs(f - freq) < 0.5 ? .accentColor : nil)
                        }
                    }
                }
                Divider()
                HStack(spacing: 16) {
                    fieldBox(label: "Frequenz", text: $freqText, unit: "MHz")
                    fieldBox(label: "Verkürzungsfaktor VF", text: $vfText, unit: "")
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

    private func ergebnisBereich(_ r: DipolErgebnis) -> some View {
        SectionCard(title: "Maße") {
            VStack(spacing: 4) {
                ResultRow(label: "Gesamtlänge (λ/2)",        value: String(format: "%.3f m", r.gesamt_m), highlight: true)
                ResultRow(label: "Arm-Länge (λ/4, je Seite)", value: String(format: "%.3f m", r.arm_m))
                ResultRow(label: "Speisepunkt-Impedanz",       value: r.impedanz)
                ResultRow(label: "Frequenz",                   value: String(format: "%.3f MHz", r.f))
                ResultRow(label: "Verkürzungsfaktor",          value: String(format: "%.3f", r.vf))
                HStack {
                    Spacer()
                    Button { imSimOeffnen(r) } label: {
                        Label("Im Sim öffnen", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 4)
            }
        }
    }

    /// "Im Sim öffnen": Dipol → NEC2-Drahtmodell (analog zu Dipol.vue buildDipolModel)
    private func imSimOeffnen(_ r: DipolErgebnis) {
        let f = r.f
        let halfLen = r.arm_m
        let lambda = 300.0 / f
        let h = max(8.0, lambda / 2.0)
        let segs = 21
        let radius_mm = 1.0

        let model: [String: Any]
        if typ == .falter {
            let d = 0.030  // 30mm Leiterabstand
            model = [
                "name": "Faltdipol \(String(format: "%.2f", halfLen * 2))m @ \(f) MHz",
                "freq": f,
                "ground": "average",
                "height": h,
                "wires": [
                    ["tag": 1, "segments": segs, "x1": -halfLen, "y1": 0.0, "z1": h, "x2": halfLen, "y2": 0.0, "z2": h, "radius_mm": radius_mm],
                    ["tag": 2, "segments": segs, "x1": -halfLen, "y1": 0.0, "z1": h + d, "x2": halfLen, "y2": 0.0, "z2": h + d, "radius_mm": radius_mm],
                    ["tag": 3, "segments": 3, "x1": -halfLen, "y1": 0.0, "z1": h, "x2": -halfLen, "y2": 0.0, "z2": h + d, "radius_mm": radius_mm],
                    ["tag": 4, "segments": 3, "x1": halfLen, "y1": 0.0, "z1": h, "x2": halfLen, "y2": 0.0, "z2": h + d, "radius_mm": radius_mm],
                ],
                "excitation": ["wire_tag": 1, "segment": Int(ceil(Double(segs) / 2.0))],
            ]
        } else {
            model = [
                "name": "Dipol \(String(format: "%.2f", halfLen * 2))m @ \(f) MHz (VF \(r.vf))",
                "freq": f,
                "ground": "average",
                "height": h,
                "wires": [
                    ["tag": 1, "segments": segs, "x1": -halfLen, "y1": 0.0, "z1": h, "x2": halfLen, "y2": 0.0, "z2": h, "radius_mm": radius_mm],
                ],
                "excitation": ["wire_tag": 1, "segment": Int(ceil(Double(segs) / 2.0))],
            ]
        }
        simBridge.openInSim(model: model)
    }

    // MARK: Skizze

    private func skizzeBereich(_ r: DipolErgebnis) -> some View {
        SectionCard(title: "Skizze") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let cy = H / 2
                let cx = W / 2
                let margin: CGFloat = 40
                let armLen = (W - 2 * margin) / 2

                // Dipol-Arme
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx - armLen, y: cy))
                    p.addLine(to: CGPoint(x: cx + armLen, y: cy))
                }, with: .color(.blue), lineWidth: r.typ == .falter ? 2 : 4)

                if r.typ == .falter {
                    // Paralleler Draht für Faltdipol
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: cx - armLen, y: cy - 14))
                        p.addLine(to: CGPoint(x: cx + armLen, y: cy - 14))
                    }, with: .color(.blue), lineWidth: 2)
                    // Verbindungen an den Enden
                    for dx: CGFloat in [-armLen, armLen] {
                        ctx.stroke(Path { p in
                            p.move(to: CGPoint(x: cx + dx, y: cy - 14))
                            p.addLine(to: CGPoint(x: cx + dx, y: cy))
                        }, with: .color(.blue), lineWidth: 2)
                    }
                }

                // Speisepunkt-Dot
                ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: cy-5, width: 10, height: 10)), with: .color(.accentColor))
                ctx.draw(Text("50Ω").font(.system(size: 11)).bold().foregroundStyle(Color.accentColor),
                         at: CGPoint(x: cx, y: cy + 20), anchor: .center)

                // Bemaßung
                let dimY = cy - 36
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx - armLen, y: dimY))
                    p.addLine(to: CGPoint(x: cx + armLen, y: dimY))
                }, with: .color(.secondary.opacity(0.5)), lineWidth: 1)
                for xTick: CGFloat in [cx - armLen, cx + armLen] {
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: xTick, y: dimY - 4))
                        p.addLine(to: CGPoint(x: xTick, y: dimY + 4))
                    }, with: .color(.secondary.opacity(0.5)), lineWidth: 1)
                }
                ctx.draw(Text(String(format: "%.3f m", r.gesamt_m)).font(.system(size: 11)).foregroundStyle(.secondary),
                         at: CGPoint(x: cx, y: dimY - 14), anchor: .center)

                // Arm-Labels
                ctx.draw(Text(String(format: "← %.3f m →", r.arm_m)).font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: cx - armLen / 2, y: cy + 20), anchor: .center)
                ctx.draw(Text(String(format: "← %.3f m →", r.arm_m)).font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: cx + armLen / 2, y: cy + 20), anchor: .center)
            }
            .frame(height: 120)
        }
    }

    // MARK: Hinweis

    private func hinweisBereich(_ r: DipolErgebnis) -> some View {
        SectionCard(title: "Hinweis") {
            VStack(alignment: .leading, spacing: 6) {
                if r.typ == .klassisch {
                    Text("Klassischer λ/2 Dipol. Einspeisung in der Mitte mit 50Ω Koaxkabel über 1:1 Balun. Verkürzungsfaktor VF=\(String(format: "%.2f", r.vf)) berücksichtigt Isoliermaterial und Endeffekte. In der Praxis: VF ≈ 0.95–0.97 für blanken Draht in der Luft.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("Faltdipol: zwei parallele Drähte (Abstand ~10–25 mm), an den Enden verbunden. Transformiert die Impedanz um Faktor 4 auf ~300 Ω. Ideal für Speisung über 300 Ω Flachleitung oder 4:1 Balun auf 50 Ω. Breitbandiger als der klassische Dipol.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }
}
