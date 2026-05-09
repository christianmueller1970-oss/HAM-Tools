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
    @State private var selectedVersion = "v5band"
    @State private var enabledBands: Set<String> = ["20m","17m","15m","12m","10m"]

    private var version: SBVersion { SB_VERSIONS.first(where: { $0.id == selectedVersion })! }
    private var activeBands: [String] { version.bands.filter { enabledBands.contains($0) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                versionWahl
                bandWahl
                skizzeBereich
                tabelleBereich
                hinweisBereich
                infoBereich
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

    // MARK: Skizze (Boom-Draufsicht)

    private var skizzeBereich: some View {
        SectionCard(title: "Boom-Draufsicht (Schematisch)") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let marginL: CGFloat = 54, marginR: CGFloat = 54
                let marginT: CGFloat = 22, marginB: CGFloat = 22

                let allEls: [(band: String, el: SBElement)] = activeBands.flatMap { band in
                    (version.data[band] ?? []).map { (band, $0) }
                }
                guard !allEls.isEmpty else { return }

                let sVals = allEls.map { $0.el.S }
                let minS = sVals.min() ?? -6
                let maxS = sVals.max() ?? 6
                let maxLel = allEls.map { $0.el.Lel }.max() ?? 10
                let rangeS = max(maxS - minS, 1.0)

                let usableW = W - marginL - marginR
                let usableH = H - marginT - marginB
                let scaleX = usableW / CGFloat(rangeS)
                let scaleY = usableH / CGFloat(maxLel)
                let scale = min(scaleX, scaleY * 0.85)
                let cy = H / 2

                // Boom
                let boomStartX = marginL
                let boomEndX   = marginL + CGFloat(rangeS) * scale
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: boomStartX, y: cy))
                    p.addLine(to: CGPoint(x: boomEndX, y: cy))
                }, with: .color(.gray.opacity(0.6)), lineWidth: 3)

                // Richtungspfeil
                ctx.draw(Text("▶ Dir.").font(.system(size: 10)).foregroundStyle(.blue.opacity(0.7)),
                         at: CGPoint(x: boomEndX + 6, y: cy), anchor: .leading)
                ctx.draw(Text("Ref. ◀").font(.system(size: 10)).foregroundStyle(.gray.opacity(0.7)),
                         at: CGPoint(x: boomStartX - 6, y: cy), anchor: .trailing)

                // Elemente
                for (band, el) in allEls {
                    let color = SB_BAND_COLORS[band] ?? .primary
                    let x = marginL + CGFloat(el.S - minS) * scale
                    let half = CGFloat(el.Lel / 2) * scale

                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: x, y: cy - half))
                        p.addLine(to: CGPoint(x: x, y: cy + half))
                    }, with: .color(color), lineWidth: 2.5)

                    let shortTyp: String
                    switch el.typ {
                    case "Strahler":   shortTyp = "Str"
                    case "Reflektor":  shortTyp = "Ref"
                    default:           shortTyp = el.typ.replacingOccurrences(of: "Direktor ", with: "D")
                    }
                    ctx.draw(Text(shortTyp).font(.system(size: 9)).bold().foregroundStyle(color),
                             at: CGPoint(x: x, y: cy - half - 10), anchor: .center)
                    ctx.draw(Text(band).font(.system(size: 9)).foregroundStyle(color.opacity(0.85)),
                             at: CGPoint(x: x, y: cy + half + 10), anchor: .center)
                }

                // Legende (Bänder)
                var legX: CGFloat = marginL
                let legY: CGFloat = H - 6
                for band in activeBands {
                    let col = SB_BAND_COLORS[band] ?? .primary
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: legX, y: legY - 4))
                        p.addLine(to: CGPoint(x: legX + 14, y: legY - 4))
                    }, with: .color(col), lineWidth: 3)
                    ctx.draw(Text(band).font(.system(size: 9)).foregroundStyle(col),
                             at: CGPoint(x: legX + 16, y: legY - 4), anchor: .leading)
                    legX += 46
                }
            }
            .frame(height: 260)
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
