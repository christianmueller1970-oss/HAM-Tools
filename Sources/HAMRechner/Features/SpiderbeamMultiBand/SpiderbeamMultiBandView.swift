import SwiftUI

// MARK: - Model

private struct SBElement: Identifiable {
    let id = UUID()
    let typ: String
    let Lel: Double    // elektrische Drahtlänge m
    let LcutArm: Int   // Zuschnitt Arm mm
    let S: Double      // Boom-Position m (+ = Direktor-Seite)
}

private struct SBBandData {
    let band: String
    let freq: Double
    let color: Color
    let elements: [SBElement]
}

private struct SBVersion: Identifiable {
    let id: String
    let label: String
    let name: String
    let desc: String
    let bands: [String]
    let data: [String: [SBElement]]
}

private let SB_VERSIONS: [SBVersion] = [
    SBVersion(id: "v3band", label: "3-Band", name: "3-Band Version (20/15/10m)",
              desc: "Klassische Original-Version. 3-Element auf 20/15m, 4-Element auf 10m.",
              bands: ["20m", "15m", "10m"],
              data: [
                "20m": [
                    .init(typ: "Strahler",   Lel: 9.80,  LcutArm: 547, S: -0.40),
                    .init(typ: "Reflektor",  Lel: 10.24, LcutArm: 516, S: -5.00),
                    .init(typ: "Direktor 1", Lel: 9.51,  LcutArm: 480, S: +5.00),
                ],
                "15m": [
                    .init(typ: "Strahler",   Lel: 6.66, LcutArm: 337, S:  0.00),
                    .init(typ: "Reflektor",  Lel: 6.78, LcutArm: 343, S: -2.60),
                    .init(typ: "Direktor 1", Lel: 6.29, LcutArm: 319, S: +3.30),
                ],
                "10m": [
                    .init(typ: "Strahler",   Lel: 4.80, LcutArm: 297, S: +0.50),
                    .init(typ: "Reflektor",  Lel: 5.11, LcutArm: 257, S: -1.30),
                    .init(typ: "Direktor 1", Lel: 4.70, LcutArm: 237, S: +2.00),
                    .init(typ: "Direktor 2", Lel: 4.70, LcutArm: 237, S: +4.20),
                ],
              ]),
    SBVersion(id: "v5band", label: "5-Band", name: "5-Band Version (20/17/15/12/10m)",
              desc: "Erweiterte Version mit 17m und 12m als 2-Element Yagis.",
              bands: ["20m", "17m", "15m", "12m", "10m"],
              data: [
                "20m": [
                    .init(typ: "Strahler",   Lel: 9.80,  LcutArm: 547, S: -0.40),
                    .init(typ: "Reflektor",  Lel: 10.24, LcutArm: 516, S: -5.00),
                    .init(typ: "Direktor 1", Lel: 9.51,  LcutArm: 480, S: +5.00),
                ],
                "17m": [
                    .init(typ: "Strahler",   Lel: 7.20, LcutArm: 450, S: -0.80),
                    .init(typ: "Reflektor",  Lel: 7.94, LcutArm: 399, S: -3.30),
                ],
                "15m": [
                    .init(typ: "Strahler",   Lel: 6.66, LcutArm: 337, S:  0.00),
                    .init(typ: "Reflektor",  Lel: 6.79, LcutArm: 342, S: -2.60),
                    .init(typ: "Direktor 1", Lel: 6.35, LcutArm: 320, S: +3.30),
                ],
                "12m": [
                    .init(typ: "Strahler",   Lel: 5.46, LcutArm: 324, S: +0.40),
                    .init(typ: "Reflektor",  Lel: 5.75, LcutArm: 290, S: -1.50),
                ],
                "10m": [
                    .init(typ: "Strahler",   Lel: 4.74, LcutArm: 320, S: +0.80),
                    .init(typ: "Reflektor",  Lel: 5.15, LcutArm: 259, S: -1.10),
                    .init(typ: "Direktor 1", Lel: 4.74, LcutArm: 239, S: +2.00),
                    .init(typ: "Direktor 2", Lel: 4.74, LcutArm: 239, S: +4.20),
                ],
              ]),
    SBVersion(id: "vsunspot", label: "Low-Sun", name: "Low-Sunspot Version (20/17/15m)",
              desc: "Für Sonnenflecken-Minimum optimiert. 3-Element auf 20/17/15m.",
              bands: ["20m", "17m", "15m"],
              data: [
                "20m": [
                    .init(typ: "Strahler",   Lel: 10.00, LcutArm: 500, S:  0.00),
                    .init(typ: "Reflektor",  Lel: 10.25, LcutArm: 517, S: -5.00),
                    .init(typ: "Direktor 1", Lel:  9.55, LcutArm: 481, S: +5.00),
                ],
                "17m": [
                    .init(typ: "Strahler",   Lel: 7.62, LcutArm: 438, S: -0.40),
                    .init(typ: "Reflektor",  Lel: 7.92, LcutArm: 399, S: -3.30),
                    .init(typ: "Direktor 1", Lel: 7.55, LcutArm: 381, S: +4.20),
                ],
                "15m": [
                    .init(typ: "Strahler",   Lel: 6.56, LcutArm: 385, S: +0.40),
                    .init(typ: "Reflektor",  Lel: 6.86, LcutArm: 346, S: -2.60),
                    .init(typ: "Direktor 1", Lel: 6.47, LcutArm: 326, S: +3.30),
                ],
              ]),
    SBVersion(id: "vwarc", label: "WARC", name: "WARC Version (30/17/12m)",
              desc: "WARC-Bänder. 3-Element auf 30/17m, 4-Element auf 12m. 6m lange Spreizer nötig!",
              bands: ["30m", "17m", "12m"],
              data: [
                "30m": [
                    .init(typ: "Strahler",   Lel: 13.48, LcutArm: 731, S: -0.40),
                    .init(typ: "Reflektor",  Lel: 14.13, LcutArm: 711, S: -6.00),
                    .init(typ: "Direktor 1", Lel: 13.66, LcutArm: 687, S: +6.00),
                ],
                "17m": [
                    .init(typ: "Strahler",   Lel: 7.62, LcutArm: 386, S:  0.00),
                    .init(typ: "Reflektor",  Lel: 7.89, LcutArm: 397, S: -3.00),
                    .init(typ: "Direktor 1", Lel: 7.58, LcutArm: 381, S: +3.90),
                ],
                "12m": [
                    .init(typ: "Strahler",   Lel: 5.46, LcutArm: 330, S: +0.40),
                    .init(typ: "Reflektor",  Lel: 5.83, LcutArm: 294, S: -1.90),
                    .init(typ: "Direktor 1", Lel: 5.47, LcutArm: 276, S: +2.30),
                    .init(typ: "Direktor 2", Lel: 5.40, LcutArm: 273, S: +4.80),
                ],
              ]),
]

private let SB_BAND_COLORS: [String: Color] = [
    "30m": Color(red: 0.49, green: 0.18, blue: 0.07),
    "20m": .red,
    "17m": Color(red: 0.92, green: 0.35, blue: 0.04),
    "15m": .green,
    "12m": Color(red: 0.49, green: 0.23, blue: 0.93),
    "10m": .blue,
]

// MARK: - View

struct SpiderbeamMultiBandView: View {
    @EnvironmentObject var simBridge: AntennaSimBridge
    @State private var selectedVersion = "v5band"
    @State private var enabledBands: Set<String> = ["20m","17m","15m","12m","10m"]
    @State private var excitedSpiderBand: String? = nil

    private let bandFreq: [String: Double] = [
        "30m": 10.125, "20m": 14.150, "17m": 18.118,
        "15m": 21.200, "12m": 24.940, "10m": 28.500,
    ]

    private var version: SBVersion { SB_VERSIONS.first(where: { $0.id == selectedVersion })! }
    private var activeBands: [String] { version.bands.filter { enabledBands.contains($0) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                versionWahl
                bandWahl
                skizzeBereich
                tabelleBereich
                if !activeBands.isEmpty { simExportBereich }
                hinweisBereich
                infoBereich
                RechnerBeschreibung(resourceName: "spidermulti")
            }
            .padding(24)
        }
        .navigationTitle("Spiderbeam Multi-Band")
        .onChange(of: selectedVersion) { _, newVersion in
            if let v = SB_VERSIONS.first(where: { $0.id == newVersion }) {
                enabledBands = Set(v.bands)
            }
        }
    }

    private var simExportBereich: some View {
        SectionCard(title: "Im Antennen-Simulator öffnen") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Alle aktiven Bänder werden als NEC2-Drahtmodell exportiert. Ein Band wird gespeist — die anderen wirken als passive Parasiten.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Text("Speisung Band:").font(.callout)
                    let sortedBands = activeBands.sorted { (bandFreq[$0] ?? 999) < (bandFreq[$1] ?? 999) }
                    Picker("", selection: Binding<String>(
                        get: { excitedSpiderBand ?? sortedBands.first ?? "" },
                        set: { excitedSpiderBand = $0 }
                    )) {
                        ForEach(sortedBands, id: \.self) { b in
                            Text("\(b) (\(String(format: "%.3f MHz", bandFreq[b] ?? 0)))").tag(b)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 220)
                    Spacer()
                    Button { imSimOeffnen() } label: {
                        Label("Im Sim öffnen", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func imSimOeffnen() {
        let akt = activeBands
        guard !akt.isEmpty else { return }
        let sortedBands = akt.sorted { (bandFreq[$0] ?? 999) < (bandFreq[$1] ?? 999) }
        let exBand = excitedSpiderBand ?? sortedBands.first ?? ""
        let exFreq = bandFreq[exBand] ?? 14.150
        let lambda = 300.0 / exFreq
        let h = max(8.0, lambda / 2.0)

        var wires: [[String: Any]] = []
        var tag = 0
        var excitationTag = 1
        for bandName in akt {
            let elems = version.data[bandName] ?? []
            for el in elems {
                tag += 1
                let half = el.Lel / 2
                wires.append([
                    "tag": tag, "segments": 21,
                    "x1": el.S, "y1": -half, "z1": h,
                    "x2": el.S, "y2":  half, "z2": h,
                    "radius_mm": 1.5,
                ])
                if bandName == exBand && el.typ == "Strahler" {
                    excitationTag = tag
                }
            }
        }
        let model: [String: Any] = [
            "name": "Spiderbeam \(version.label) (\(akt.joined(separator: "/"))) — Speisung \(exBand)",
            "freq": exFreq, "ground": "average", "height": h,
            "wires": wires,
            "excitation": ["wire_tag": excitationTag, "segment": 11],
        ]
        simBridge.openInSim(model: model)
    }

    // MARK: Version

    private var versionWahl: some View {
        SectionCard(title: "Version") {
            VStack(spacing: 8) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(SB_VERSIONS) { v in
                        Button {
                            selectedVersion = v.id
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.label).fontWeight(.semibold)
                                Text(v.name).font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedVersion == v.id ? .accentColor : nil)
                    }
                }
                Text(version.desc).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Band-Auswahl

    private var bandWahl: some View {
        SectionCard(title: "Bänder") {
            HStack(spacing: 10) {
                ForEach(version.bands, id: \.self) { band in
                    Toggle(isOn: Binding(
                        get: { enabledBands.contains(band) },
                        set: { if $0 { enabledBands.insert(band) } else { enabledBands.remove(band) } }
                    )) {
                        Text(band)
                            .font(.callout.bold())
                            .foregroundStyle(SB_BAND_COLORS[band] ?? .primary)
                    }
                    .toggleStyle(.button)
                    .tint(SB_BAND_COLORS[band] ?? .accentColor)
                }
            }
        }
    }

    // MARK: Skizze (Draufsicht – Boom vertikal, Elemente abgewinkelt zum Kreuz)

    private var skizzeBereich: some View {
        SectionCard(title: "Antennenskizze – Draufsicht") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let mL: CGFloat = 108, mR: CGFloat = 108
                let mT: CGFloat = 52,  mB: CGFloat = 44

                let allEls: [(band: String, el: SBElement)] = activeBands.flatMap { b in
                    (version.data[b] ?? []).map { (b, $0) }
                }
                guard !allEls.isEmpty else { return }

                // Physik: Boom vertikal (Dir oben, Ref unten), je ein Spreizer-Endpunkt
                // links und rechts auf der Horizontalen durch S=0.
                // Alle Elementarme gehen vom Boom-Befestigungspunkt zu diesen fixen Punkten.
                // Schnüre verbinden Drahtspitze mit dem Spreizer-Endpunkt.
                let spreizer_m: Double = 5.0   // Spreizer-Länge laut Bauanleitung

                let allS    = allEls.map { $0.el.S }
                let maxSabs = max(abs(allS.max() ?? 5), abs(allS.min() ?? 5), 0.1)

                let boomX   = W / 2
                let centerY = mT + (H - mT - mB) / 2
                let usableH = H - mT - mB

                // Gleicher Maßstab X/Y für korrekte Geometrie
                let scale = min(((W - mL - mR) / 2) / CGFloat(spreizer_m),
                                (usableH / 2) / CGFloat(maxSabs))

                func bY(_ s: Double) -> CGFloat { centerY - CGFloat(s) * scale }
                func bX(_ x: Double) -> CGFloat { boomX   + CGFloat(x) * scale }

                // Fixe Spreizer-Endpunkte links und rechts
                let rTip = CGPoint(x: bX(spreizer_m),  y: centerY)
                let lTip = CGPoint(x: bX(-spreizer_m), y: centerY)

                // Hilfsfunktion: Punkt von base in Richtung target, Abstand = meters
                func tipPt(from base: CGPoint, toward target: CGPoint, meters: Double) -> CGPoint {
                    let dx = target.x - base.x, dy = target.y - base.y
                    let dist = (dx*dx + dy*dy).squareRoot()
                    guard dist > 0.001 else { return base }
                    let len = CGFloat(meters) * scale
                    return CGPoint(x: base.x + dx/dist * len, y: base.y + dy/dist * len)
                }

                // ── Boom ────────────────────────────────────────────────────
                let boomTop    = bY(maxSabs + 0.25)
                let boomBottom = bY(-(maxSabs + 0.25))
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: boomX, y: boomTop))
                    p.addLine(to: CGPoint(x: boomX, y: boomBottom))
                }, with: .color(.gray.opacity(0.55)), style: StrokeStyle(lineWidth: 2.5))

                // ── Spreizer-Arme (horizontal gestrichelt, S=0-Linie) ────────
                ctx.stroke(Path { p in p.move(to: lTip); p.addLine(to: rTip) },
                           with: .color(.gray.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                for tip in [lTip, rTip] {
                    ctx.fill(Path(ellipseIn: CGRect(x: tip.x-5, y: tip.y-5, width: 10, height: 10)),
                             with: .color(.gray.opacity(0.5)))
                }

                // ── Richtungstexte ───────────────────────────────────────────
                ctx.draw(Text("▲").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.primary),
                         at: CGPoint(x: boomX, y: boomTop - 14), anchor: .center)
                ctx.draw(Text("Hauptstrahlrichtung").font(.caption2).foregroundStyle(Color.secondary),
                         at: CGPoint(x: boomX, y: boomTop - 26), anchor: .center)
                ctx.draw(Text("Reflektor-Seite").font(.caption2).foregroundStyle(Color.secondary),
                         at: CGPoint(x: boomX, y: boomBottom + 16), anchor: .center)

                // ── Maßstab (2 m) ─────────────────────────────────────────
                let barLen: CGFloat = 2.0 * scale
                let barX0: CGFloat  = 12
                let barY:  CGFloat  = boomTop - 16
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: barX0, y: barY))
                    p.addLine(to: CGPoint(x: barX0 + barLen, y: barY))
                    p.move(to: CGPoint(x: barX0, y: barY-3)); p.addLine(to: CGPoint(x: barX0, y: barY+3))
                    p.move(to: CGPoint(x: barX0+barLen, y: barY-3)); p.addLine(to: CGPoint(x: barX0+barLen, y: barY+3))
                }, with: .color(.primary), lineWidth: 1.5)
                ctx.draw(Text("2 m").font(.system(size: 9)).foregroundStyle(Color.primary),
                         at: CGPoint(x: barX0 + barLen/2, y: barY - 9), anchor: .center)

                let sorted = allEls.sorted { $0.el.S > $1.el.S }

                // ── Schnüre (dünne Linien von Drahtspitze zum Spreizer-Endpunkt) ──
                for (_, el) in sorted {
                    let base  = CGPoint(x: boomX, y: bY(el.S))
                    let rWire = tipPt(from: base, toward: rTip, meters: el.Lel / 2)
                    let lWire = tipPt(from: base, toward: lTip, meters: el.Lel / 2)
                    let schnur = StrokeStyle(lineWidth: 0.8, dash: [3, 3])
                    ctx.stroke(Path { p in p.move(to: rWire); p.addLine(to: rTip) },
                               with: .color(.gray.opacity(0.28)), style: schnur)
                    ctx.stroke(Path { p in p.move(to: lWire); p.addLine(to: lTip) },
                               with: .color(.gray.opacity(0.28)), style: schnur)
                }

                // ── Elementdrähte (farbig, vom Boom zum Drahtende) ───────────
                for (idx, (band, el)) in sorted.enumerated() {
                    let color = SB_BAND_COLORS[band] ?? .primary
                    let base  = CGPoint(x: boomX, y: bY(el.S))
                    let rWire = tipPt(from: base, toward: rTip, meters: el.Lel / 2)
                    let lWire = tipPt(from: base, toward: lTip, meters: el.Lel / 2)

                    ctx.stroke(Path { p in p.move(to: base); p.addLine(to: rWire) },
                               with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    ctx.stroke(Path { p in p.move(to: base); p.addLine(to: lWire) },
                               with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    let dr: CGFloat = el.typ == "Strahler" ? 4.5 : 3.0
                    ctx.fill(Path(ellipseIn: CGRect(x: boomX-dr, y: base.y-dr,
                                                    width: dr*2, height: dr*2)),
                             with: .color(color))

                    // Labels: alternierend links/rechts, y = Boom-Befestigungshöhe
                    let short: String
                    switch el.typ {
                    case "Strahler":  short = "Str"
                    case "Reflektor": short = "Ref"
                    default:          short = el.typ.replacingOccurrences(of: "Direktor ", with: "D")
                    }
                    let sStr = el.S == 0 ? "S=0.00 m"
                             : el.S > 0  ? "S=+\(String(format: "%.2f", el.S)) m"
                                         : "S=\(String(format: "%.2f", el.S)) m"
                    let ly = base.y
                    if idx % 2 == 0 {
                        ctx.draw(Text("\(band) \(short)").font(.system(size: 9, weight: .bold)).foregroundStyle(color),
                                 at: CGPoint(x: W - mR + 4, y: ly - 6), anchor: .leading)
                        ctx.draw(Text(sStr).font(.system(size: 8)).foregroundStyle(Color.secondary),
                                 at: CGPoint(x: W - mR + 4, y: ly + 5), anchor: .leading)
                    } else {
                        ctx.draw(Text("\(band) \(short)").font(.system(size: 9, weight: .bold)).foregroundStyle(color),
                                 at: CGPoint(x: mL - 4, y: ly - 6), anchor: .trailing)
                        ctx.draw(Text(sStr).font(.system(size: 8)).foregroundStyle(Color.secondary),
                                 at: CGPoint(x: mL - 4, y: ly + 5), anchor: .trailing)
                    }
                }

                // ── Band-Legende ───────────────────────────────────────────
                let legBands = activeBands
                let legItemW: CGFloat = 68
                var legX = (W - CGFloat(legBands.count) * legItemW) / 2
                let legY  = H - 10
                for band in legBands {
                    let col = SB_BAND_COLORS[band] ?? .primary
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: legX, y: legY - 4))
                        p.addLine(to: CGPoint(x: legX + 16, y: legY - 4))
                    }, with: .color(col), lineWidth: 3)
                    ctx.draw(Text(band).font(.system(size: 9, weight: .semibold)).foregroundStyle(col),
                             at: CGPoint(x: legX + 18, y: legY - 4), anchor: .leading)
                    legX += legItemW
                }
            }
            .frame(height: 500)
        }
    }

    // MARK: Tabelle

    private var tabelleBereich: some View {
        SectionCard(title: "Drahtlängen (DF4SA Originaldaten)") {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Band").font(.caption).fontWeight(.semibold).frame(width: 50, alignment: .leading)
                    Text("Element").font(.caption).fontWeight(.semibold).frame(width: 80, alignment: .leading)
                    Text("L_el (m)").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity)
                    Text("Zuschnitt Arm (mm)").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity)
                    Text("S (m)").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .padding(.vertical, 6).padding(.horizontal, 4)
                .background(Color.secondary.opacity(0.1))

                let allRows: [(band: String, el: SBElement)] = activeBands.flatMap { band in
                    let bandData = version.data[band] ?? []
                    let typeOrder = ["Strahler","Reflektor","Direktor 1","Direktor 2","Direktor 3"]
                    return typeOrder.compactMap { t in bandData.first(where: { $0.typ == t }) }.map { (band, $0) }
                }
                ForEach(allRows.indices, id: \.self) { idx in
                    let band = allRows[idx].band
                    let el   = allRows[idx].el
                    let bColor = SB_BAND_COLORS[band] ?? .primary
                    HStack {
                        Text(band)
                            .font(.caption.bold())
                            .foregroundStyle(bColor)
                            .frame(width: 50, alignment: .leading)
                        Text(el.typ)
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                        Text(String(format: "%.2f", el.Lel))
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity)
                        Text("\(el.LcutArm)")
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity)
                        Text(el.S == 0 ? "0.00" : (el.S > 0 ? "+\(String(format: "%.2f", el.S))" : String(format: "%.2f", el.S)))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4).padding(.horizontal, 4)
                    .background(idx % 2 == 0 ? Color.clear : Color.secondary.opacity(0.04))
                    Divider()
                }
            }
        }
    }

    // MARK: Hinweis

    private var hinweisBereich: some View {
        SectionCard(title: "Spalten-Legende") {
            VStack(spacing: 4) {
                ResultRow(label: "L_el", value: "Elektrische Drahtlänge (Strahler-Schenkel × 2, ohne Speiseleitung)")
                ResultRow(label: "Zuschnitt Arm (mm)", value: "Physikalischer Schnitt für einen Arm (L_el/2 + Toleranz)")
                ResultRow(label: "S (m)", value: "Position auf dem Boom; + = Direktor-Seite, – = Reflektor-Seite")
            }
        }
    }

    // MARK: Info

    private var infoBereich: some View {
        SectionCard(title: "Hinweis") {
            Text("Originalmaße von DF4SA Spiderbeam. Alle Werte wurden für Kupferlitze (CuLi) auf dem Original-Spiderbeam-Spreizersystem optimiert. Der Strahler wird mit einer separaten Speiseleitung (Koax-Schnitzel) versorgt. Nicht für Direktmontage auf Alurohr geeignet.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
