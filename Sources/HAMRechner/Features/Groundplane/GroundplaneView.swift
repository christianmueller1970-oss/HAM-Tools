import SwiftUI

// MARK: - Model

private struct GroundplaneErgebnis {
    let f: Double
    let vf: Double
    let strahler_m: Double
    let radial_m: Double
    let anzahlRadiale: Int
    let radialWinkel: Int   // Grad unter Horizontal
    let impedanz: String

    static func berechne(f: Double, vf: Double, anzahl: Int, winkel: Int) -> GroundplaneErgebnis? {
        guard f > 0, vf > 0 else { return nil }
        let strahler = 75.0 / f * vf
        let radial   = strahler * 1.02  // Radiale etwas länger
        // Impedanz steigt mit Neigungswinkel: 0°≈36Ω, 45°≈52Ω
        let imp: String
        switch winkel {
        case 0:  imp = "≈ 36 Ω (horizontal, λ/4 Stub nötig)"
        case 30: imp = "≈ 42 Ω"
        case 45: imp = "≈ 52 Ω (direkt 50 Ω)"
        default: imp = "≈ 50 Ω"
        }
        return GroundplaneErgebnis(f: f, vf: vf, strahler_m: strahler, radial_m: radial,
                                   anzahlRadiale: anzahl, radialWinkel: winkel, impedanz: imp)
    }
}

// MARK: - View

struct GroundplaneView: View {
    @EnvironmentObject var simBridge: AntennaSimBridge
    @State private var freqText  = "14.175"
    @State private var vfText    = "0.95"
    @State private var anzahl    = 4
    @State private var winkel    = 45

    private var f:  Double { Double(freqText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var vf: Double { Double(vfText.replacingOccurrences(of: ",", with: "."))   ?? 0.95 }
    private var ergebnis: GroundplaneErgebnis? { GroundplaneErgebnis.berechne(f: f, vf: vf, anzahl: anzahl, winkel: winkel) }

    private let bands: [(String, Double)] = [
        ("160m", 1.85), ("80m", 3.65), ("40m", 7.1), ("30m", 10.125),
        ("20m", 14.175), ("17m", 18.118), ("15m", 21.225), ("12m", 24.94),
        ("10m", 28.5), ("6m", 50.15), ("2m", 145.0), ("70cm", 432.0)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if let r = ergebnis { ergebnisBereich(r); skizzeBereich(r); hinweisBereich }
                RechnerBeschreibung(resourceName: "groundplane")
            }
            .padding(24)
        }
        .navigationTitle("Groundplane / Vertikal")
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
                Divider()
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Anzahl Radiale").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $anzahl) {
                            Text("3").tag(3)
                            Text("4").tag(4)
                            Text("8").tag(8)
                        }
                        .pickerStyle(.segmented).frame(maxWidth: 200)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Neigungswinkel Radiale").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $winkel) {
                            Text("0° (horizontal)").tag(0)
                            Text("30° nach unten").tag(30)
                            Text("45° nach unten").tag(45)
                        }
                        .pickerStyle(.segmented).frame(maxWidth: 280)
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
                if !unit.isEmpty { Text(unit).foregroundStyle(.secondary).font(.caption) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Ergebnis

    private func ergebnisBereich(_ r: GroundplaneErgebnis) -> some View {
        SectionCard(title: "Maße") {
            VStack(spacing: 4) {
                ResultRow(label: "Strahler (λ/4)",              value: String(format: "%.3f m", r.strahler_m), highlight: true)
                ResultRow(label: "Radial-Länge (je)",           value: String(format: "%.3f m", r.radial_m))
                ResultRow(label: "Gesamtlänge Radiale (\(r.anzahlRadiale)×)", value: String(format: "%.3f m", r.radial_m * Double(r.anzahlRadiale)))
                ResultRow(label: "Radiale-Neigung",             value: "\(r.radialWinkel)° unter horizontal")
                ResultRow(label: "Speisepunkt-Impedanz",        value: r.impedanz)
                ResultRow(label: "Frequenz",                    value: String(format: "%.3f MHz", r.f))
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

    private func imSimOeffnen(_ r: GroundplaneErgebnis) {
        let lambda = 300.0 / r.f
        let h = max(lambda * 0.1, 3.0)
        let winkelRad = Double(r.radialWinkel) * .pi / 180.0
        let radialDz = -sin(winkelRad) * r.radial_m
        let radialDr =  cos(winkelRad) * r.radial_m
        var wires: [[String: Any]] = []
        wires.append([
            "tag": 1, "segments": 11,
            "x1": 0.0, "y1": 0.0, "z1": h,
            "x2": 0.0, "y2": 0.0, "z2": h + r.strahler_m,
            "radius_mm": 2.0,
        ])
        for i in 0..<r.anzahlRadiale {
            let a = (Double(i) / Double(r.anzahlRadiale)) * 2.0 * .pi
            wires.append([
                "tag": 2 + i, "segments": 9,
                "x1": 0.0, "y1": 0.0, "z1": h,
                "x2": cos(a) * radialDr, "y2": sin(a) * radialDr, "z2": h + radialDz,
                "radius_mm": 1.0,
            ])
        }
        let model: [String: Any] = [
            "name": "Groundplane \(String(format: "%.2f", r.strahler_m))m @ \(r.f) MHz (\(r.anzahlRadiale) Radials)",
            "freq": r.f, "ground": "average", "height": h,
            "wires": wires,
            "excitation": ["wire_tag": 1, "segment": 1],
        ]
        simBridge.openInSim(model: model)
    }

    // MARK: Skizze

    private func skizzeBereich(_ r: GroundplaneErgebnis) -> some View {
        SectionCard(title: "Skizze") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let cx = W / 2
                let topY: CGFloat = 20
                let feedY: CGFloat = H * 0.55
                let strahlerPx = feedY - topY

                // Strahler (vertikal)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx, y: feedY))
                    p.addLine(to: CGPoint(x: cx, y: topY))
                }, with: .color(.blue), lineWidth: 4)

                // Radiale mit Neigungswinkel
                let radialPx: CGFloat = strahlerPx * 0.9
                let neigungrad = Double(r.radialWinkel) * .pi / 180.0
                let radialDx = radialPx * cos(neigungrad)
                let radialDy = radialPx * sin(neigungrad) // positiv = nach unten

                let winkel = [0.0, 90.0, 180.0, 270.0]
                for (i, angDeg) in winkel.prefix(r.anzahlRadiale).enumerated() {
                    let ang = angDeg * .pi / 180.0
                    let dx = radialDx * cos(ang)
                    let dy = radialDy + radialDx * sin(ang) * 0.3  // perspective hint
                    let _ = i
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: cx, y: feedY))
                        p.addLine(to: CGPoint(x: cx + dx, y: feedY + dy))
                    }, with: .color(.gray), lineWidth: 2.5)
                }

                // Speisepunkt
                ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: feedY-5, width: 10, height: 10)), with: .color(.accentColor))
                ctx.draw(Text("50Ω").font(.system(size: 11)).bold().foregroundStyle(Color.accentColor),
                         at: CGPoint(x: cx + 14, y: feedY), anchor: .leading)

                // Bemaßung Strahler
                ctx.draw(Text(String(format: "λ/4 = %.3f m", r.strahler_m)).font(.system(size: 11)).foregroundStyle(.secondary),
                         at: CGPoint(x: cx - 14, y: (topY + feedY) / 2), anchor: .trailing)

                // Radial-Label
                ctx.draw(Text(String(format: "\(r.anzahlRadiale)× %.3f m", r.radial_m)).font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: cx, y: H - 8), anchor: .center)
            }
            .frame(height: 200)
        }
    }

    // MARK: Hinweis

    private var hinweisBereich: some View {
        SectionCard(title: "Hinweis") {
            Text("λ/4 Groundplane: Strahler vertikal, Radiale horizontal oder geneigt. Bei 0° Neigung: Impedanz ≈ 36 Ω (λ/4 Stub oder Anpassnetzwerk nötig). Bei 45° Neigung: ≈ 52 Ω (direkt 50 Ω Koax). Mindestens 3–4 Radiale empfohlen. Mehr Radiale verbessern den Wirkungsgrad.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
