import SwiftUI

// MARK: - Model

private struct YagiBand {
    let name: String
    let min: Double
    let max: Double
    let cw: Double
    let ssb: Double
    let ft8: Double
    var mid: Double { (min + max) / 2 }
}

private struct YagiDesign {
    let refl: Double
    let drv: Double
    let dir: [Double]
    let spacings: [Double]  // Refl→Drv, Drv→D1, D1→D2, ...
    let gain: Double
    let fb: Int
    let impedance: Int
}

private struct YagiElement: Identifiable {
    let id = UUID()
    let name: String
    let length: Double   // m
    let position: Double // m vom Reflektor
}

private struct YagiErgebnis {
    let band: YagiBand
    let freq: Double
    let lambda: Double
    let numEle: Int
    let material: String
    let vf: Double
    let design: YagiDesign
    let elements: [YagiElement]
    let boomLength: Double
}

private let YAGI_BANDS: [String: YagiBand] = [
    "40": .init(name: "40 m", min: 7.000, max: 7.200, cw: 7.030, ssb: 7.130, ft8: 7.074),
    "30": .init(name: "30 m", min: 10.100, max: 10.150, cw: 10.120, ssb: 10.130, ft8: 10.136),
    "20": .init(name: "20 m", min: 14.000, max: 14.350, cw: 14.030, ssb: 14.200, ft8: 14.074),
    "17": .init(name: "17 m", min: 18.068, max: 18.168, cw: 18.080, ssb: 18.140, ft8: 18.100),
    "15": .init(name: "15 m", min: 21.000, max: 21.450, cw: 21.030, ssb: 21.250, ft8: 21.074),
    "12": .init(name: "12 m", min: 24.890, max: 24.990, cw: 24.900, ssb: 24.960, ft8: 24.915),
    "10": .init(name: "10 m", min: 28.000, max: 29.700, cw: 28.030, ssb: 28.400, ft8: 28.074),
]

private let YAGI_DESIGNS: [Int: YagiDesign] = [
    2: .init(refl: 0.501, drv: 0.470, dir: [],                         spacings: [0.15],                    gain: 6.0, fb: 10, impedance: 35),
    3: .init(refl: 0.500, drv: 0.470, dir: [0.446],                    spacings: [0.15, 0.15],              gain: 7.5, fb: 20, impedance: 28),
    4: .init(refl: 0.500, drv: 0.469, dir: [0.444, 0.440],             spacings: [0.15, 0.17, 0.20],        gain: 8.5, fb: 22, impedance: 25),
    5: .init(refl: 0.500, drv: 0.469, dir: [0.442, 0.438, 0.434],      spacings: [0.15, 0.18, 0.22, 0.25],  gain: 9.8, fb: 25, impedance: 22),
]

private func calculateYagi(bandKey: String, numEle: Int, preset: String, material: String) -> YagiErgebnis? {
    guard let band = YAGI_BANDS[bandKey], let design = YAGI_DESIGNS[numEle] else { return nil }
    let freq: Double
    switch preset {
    case "cw":  freq = band.cw
    case "ssb": freq = band.ssb
    case "ft8": freq = band.ft8
    default:    freq = band.mid
    }
    let lambda = 299.792458 / freq
    let vf = material == "alu" ? 0.95 : 0.96

    let reflLen = lambda * design.refl * vf
    let drvLen  = lambda * design.drv  * vf
    let dirLens = design.dir.map { lambda * $0 * vf }
    let spacings = design.spacings.map { lambda * $0 }

    var positions: [Double] = [0]
    var pos = 0.0
    for sp in spacings { pos += sp; positions.append(pos) }
    let boom = positions.last ?? 0

    var elements: [YagiElement] = []
    elements.append(.init(name: "Reflektor", length: reflLen, position: positions[0]))
    elements.append(.init(name: "Strahler",  length: drvLen,  position: positions[1]))
    for (i, l) in dirLens.enumerated() {
        elements.append(.init(name: "Direktor \(i+1)", length: l, position: positions[2+i]))
    }
    return YagiErgebnis(band: band, freq: freq, lambda: lambda,
                        numEle: numEle, material: material, vf: vf,
                        design: design, elements: elements, boomLength: boom)
}

// MARK: - View

struct YagiRechnerView: View {
    @EnvironmentObject var simBridge: AntennaSimBridge
    @State private var selectedBand = "20"
    @State private var numElements  = 3
    @State private var preset       = "ssb"
    @State private var material     = "alu"

    private var ergebnis: YagiErgebnis? { calculateYagi(bandKey: selectedBand, numEle: numElements, preset: preset, material: material) }

    private let bandOrder = ["40","30","20","17","15","12","10"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if let r = ergebnis {
                    zusammenfassungBereich(r)
                    tabelleBereich(r)
                    skizzeBereich(r)
                    stuecklisteBereich(r)
                }
                RechnerBeschreibung(resourceName: "yagi")
            }
            .padding(24)
        }
        .navigationTitle("Yagi-Rechner")
    }

    // MARK: Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Parameter") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Band").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                        ForEach(bandOrder, id: \.self) { key in
                            Button(YAGI_BANDS[key]?.name ?? key) {
                                selectedBand = key
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(selectedBand == key ? .accentColor : nil)
                        }
                    }
                }
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Elemente").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $numElements) {
                            Text("2 Ele").tag(2)
                            Text("3 Ele").tag(3)
                            Text("4 Ele").tag(4)
                            Text("5 Ele").tag(5)
                        }
                        .pickerStyle(.segmented)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Frequenz-Preset").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $preset) {
                            Text("Mitte").tag("mid")
                            Text("CW").tag("cw")
                            Text("SSB").tag("ssb")
                            Text("FT8").tag("ft8")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bauweise").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $material) {
                            Text("Alurohr").tag("alu")
                            Text("Draht/Spiderbeam").tag("draht")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                if let r = ergebnis {
                    HStack(spacing: 20) {
                        Label(String(format: "%.3f MHz", r.freq), systemImage: "waveform")
                            .font(.caption).foregroundStyle(.secondary)
                        Label(String(format: "λ = %.3f m", r.lambda), systemImage: "ruler")
                            .font(.caption).foregroundStyle(.secondary)
                        Label("VF = \(String(format: "%.2f", r.vf))", systemImage: "speedometer")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Zusammenfassung

    private func zusammenfassungBereich(_ r: YagiErgebnis) -> some View {
        SectionCard(title: "Übersicht") {
            VStack(spacing: 12) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    KenngroesseKachel(wert: "\(r.numEle) Ele", label: "Elemente", hervorheben: true, farbe: .accentColor)
                    KenngroesseKachel(wert: String(format: "%.3f m", r.boomLength), label: "Boom-Länge")
                    KenngroesseKachel(wert: String(format: "%.1f dBi", r.design.gain), label: "Gewinn (ca.)")
                    KenngroesseKachel(wert: "\(r.design.fb) dB", label: "F/B (ca.)")
                    KenngroesseKachel(wert: "\(r.design.impedance) Ω", label: "Impedanz (ca.)")
                    KenngroesseKachel(wert: r.material == "alu" ? "Alurohr" : "Draht", label: "Bauweise")
                    KenngroesseKachel(wert: r.band.name, label: "Band")
                    KenngroesseKachel(wert: String(format: "%.3f MHz", r.freq), label: "Frequenz")
                }
                HStack {
                    Spacer()
                    Button { imSimOeffnen(r) } label: {
                        Label("Im Sim öffnen", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    /// Yagi → NEC2-Drahtmodell (analog YagiRechner.vue buildYagiModel)
    private func imSimOeffnen(_ r: YagiErgebnis) {
        let h = max(10.0, r.lambda / 2.0)
        let radius_mm = r.material == "alu" ? 5.0 : 1.5
        let segs = 21

        var wires: [[String: Any]] = []
        for (idx, el) in r.elements.enumerated() {
            let half = el.length / 2.0
            wires.append([
                "tag": idx + 1, "segments": segs,
                "x1": el.position, "y1": -half, "z1": h,
                "x2": el.position, "y2": half,  "z2": h,
                "radius_mm": radius_mm,
            ])
        }
        let drvTag = 2  // Element-Index 1 (Reflector=0, Driver=1)
        let model: [String: Any] = [
            "name": "\(r.numEle)-Element Yagi \(r.band.name) (\(String(format: "%.3f", r.freq)) MHz)",
            "freq": r.freq,
            "ground": "average",
            "height": h,
            "wires": wires,
            "excitation": ["wire_tag": drvTag, "segment": Int(ceil(Double(segs) / 2.0))],
        ]
        simBridge.openInSim(model: model)
    }

    // MARK: Tabelle

    private func tabelleBereich(_ r: YagiErgebnis) -> some View {
        SectionCard(title: "Elementmaße") {
            VStack(spacing: 0) {
                HStack {
                    Text("Element").font(.caption).fontWeight(.semibold).frame(width: 90, alignment: .leading)
                    Text("Länge").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity)
                    Text("Halbe Seite").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity)
                    Text("Position").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity)
                    Text("Abstand").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .background(Color.secondary.opacity(0.1))

                ForEach(r.elements) { el in
                    let idx = r.elements.firstIndex(where: { $0.id == el.id }) ?? 0
                    let prevDist = idx == 0 ? "—" : String(format: "%.0f mm", (el.position - r.elements[idx-1].position) * 1000)
                    HStack {
                        Text(el.name)
                            .font(.system(.caption, design: .default).bold())
                            .foregroundStyle(elementColor(el.name))
                            .frame(width: 90, alignment: .leading)
                        Text(String(format: "%.0f mm", el.length * 1000))
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity)
                        Text(String(format: "%.0f mm", el.length / 2 * 1000))
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity)
                        Text(String(format: "%.0f mm", el.position * 1000))
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity)
                        Text(prevDist)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 4)
                    .background(idx % 2 == 0 ? Color.clear : Color.secondary.opacity(0.04))
                    Divider()
                }
            }
        }
    }

    private func elementColor(_ name: String) -> Color {
        if name == "Reflektor" { return .red }
        if name == "Strahler"  { return .blue }
        return .green
    }

    // MARK: Skizze (Canvas)

    private func skizzeBereich(_ r: YagiErgebnis) -> some View {
        SectionCard(title: "Draufsicht") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let marginL: CGFloat = 40, marginR: CGFloat = 80
                let marginT: CGFloat = 40, marginB: CGFloat = 60
                let usableW = W - marginL - marginR
                let usableH = H - marginT - marginB

                guard r.boomLength > 0 else { return }
                let maxLen = r.elements.map { $0.length }.max() ?? 1
                let scaleX = usableW / CGFloat(r.boomLength)
                let scaleY = usableH / CGFloat(maxLen)
                let scale  = min(scaleX, scaleY)
                let centerY = marginT + CGFloat(maxLen) * scale / 2

                // Boom
                let boomStartX = marginL
                let boomEndX   = marginL + CGFloat(r.boomLength) * scale
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: boomStartX, y: centerY))
                    p.addLine(to: CGPoint(x: boomEndX, y: centerY))
                }, with: .color(.gray.opacity(0.6)), lineWidth: 3)

                // Richtungspfeil
                let arrowX = boomEndX + 20
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: boomEndX, y: centerY))
                    p.addLine(to: CGPoint(x: arrowX, y: centerY))
                }, with: .color(.blue.opacity(0.6)), lineWidth: 1.5)
                ctx.draw(Text("▶").font(.caption2).foregroundStyle(.blue.opacity(0.7)), at: CGPoint(x: arrowX + 6, y: centerY), anchor: .leading)

                // Elemente
                for (idx, el) in r.elements.enumerated() {
                    let x = marginL + CGFloat(el.position) * scale
                    let half = CGFloat(el.length / 2) * scale
                    let color = elementColor(el.name)

                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: x, y: centerY - half))
                        p.addLine(to: CGPoint(x: x, y: centerY + half))
                    }, with: .color(color), lineWidth: 3)

                    ctx.draw(Text(el.name.replacingOccurrences(of: "Direktor ", with: "D")).font(.caption2).bold().foregroundStyle(color),
                             at: CGPoint(x: x, y: centerY - half - 10), anchor: .center)
                    ctx.draw(Text(String(format: "%.0f mm", el.length*1000)).font(.caption2).foregroundStyle(.secondary),
                             at: CGPoint(x: x, y: centerY + half + 14), anchor: .center)

                    // Abstandsmaß
                    if idx > 0 {
                        let prevX = marginL + CGFloat(r.elements[idx-1].position) * scale
                        let dimY = H - marginB + 18
                        ctx.stroke(Path { p in
                            p.move(to: CGPoint(x: prevX, y: dimY))
                            p.addLine(to: CGPoint(x: x, y: dimY))
                        }, with: .color(.gray.opacity(0.5)), lineWidth: 1)
                        let mid = (prevX + x) / 2
                        let dist = el.position - r.elements[idx-1].position
                        ctx.draw(Text(String(format: "%.0f mm", dist*1000)).font(.caption2).foregroundStyle(.secondary),
                                 at: CGPoint(x: mid, y: dimY - 8), anchor: .center)
                    }
                }

                // Boom-Gesamtmaß
                let totalDimY: CGFloat = marginT - 18
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: boomStartX, y: totalDimY))
                    p.addLine(to: CGPoint(x: boomEndX, y: totalDimY))
                }, with: .color(.blue.opacity(0.6)), lineWidth: 1.2)
                ctx.draw(Text(String(format: "Boom: %.0f mm", r.boomLength*1000)).font(.caption2).bold().foregroundStyle(.blue.opacity(0.7)),
                         at: CGPoint(x: (boomStartX + boomEndX) / 2, y: totalDimY - 8), anchor: .center)
            }
            .frame(height: 320)
        }
    }

    // MARK: Stückliste

    private func stuecklisteBereich(_ r: YagiErgebnis) -> some View {
        SectionCard(title: "Stückliste") {
            let totalEleLen = r.elements.reduce(0.0) { $0 + $1.length }
            VStack(spacing: 4) {
                if r.material == "alu" {
                    ResultRow(label: "Boom (Alurohr)", value: String(format: "%.2f m (inkl. Überstand)", r.boomLength + 0.2))
                    ResultRow(label: "Alurohr Elemente gesamt", value: String(format: "%.2f m", totalEleLen + 0.5))
                    ResultRow(label: "Element-Halterungen", value: "\(r.numEle) Stück")
                    ResultRow(label: "Balun / Mantelwellensperre", value: "1:1, am Strahler")
                    ResultRow(label: "Isolator Strahler-Mitte", value: "1 Stück")
                } else {
                    let maxHalf = (r.elements.map { $0.length }.max() ?? 0) / 2
                    ResultRow(label: "Fiberglas-Boom/GFK-Rohr", value: String(format: "%.2f m", r.boomLength + 0.3))
                    ResultRow(label: "Fiberglas-Spreizer (je Element)", value: String(format: "je %.2f m × 2, total %d Stück", maxHalf + 0.3, r.numEle * 2))
                    ResultRow(label: "Kupferlitze / CuLi-Draht", value: String(format: "%.1f m gesamt", totalEleLen + 1.0))
                    ResultRow(label: "Zentral-Nabe / Spinne", value: "1 Stück")
                    ResultRow(label: "Balun / Mantelwellensperre", value: "1:1, am Strahler")
                }
                ResultRow(label: "Koax-Kabel", value: "nach Mast-Länge")
            }
        }
    }
}
