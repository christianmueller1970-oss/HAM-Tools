import SwiftUI

// MARK: - Model

private struct SBEElement: Identifiable {
    let id = UUID()
    let typ: String
    let L: Double        // Gesamtlänge m
    let S: Double        // Boom-Position m
    let delta_pct: Double // Abweichung vom Strahler %

    var halbSchenkel: Double { L / 2 }
    var zuschnittCm: Double  { L / 2 * 100 + 4 }  // +4 cm Toleranz
}

private let STRAHLER_FAKTOR = 0.466

private let ELEMENT_TABLE: [(typ: String, lenFactor: Double, boomLambda: Double)] = [
    ("Reflektor",   1.050, -0.180),
    ("Strahler",    1.000,  0.000),
    ("Direktor 1",  0.965, +0.150),
    ("Direktor 2",  0.955, +0.300),
    ("Direktor 3",  0.945, +0.480),
    ("Direktor 4",  0.935, +0.680),
]

private struct SBEErgebnis {
    let freq: Double
    let lambda: Double
    let strahlerLen: Double
    let elements: [SBEElement]
    let boomLength: Double
    let maxHalfLen: Double  // benötigte Spreizer-Halbseite m
    let nElements: Int

    var spreizerWarnung: String? {
        if maxHalfLen > 6.0 {
            return "Längste Elemente brauchen \(String(format: "%.2f", maxHalfLen)) m Halbspreizer. Das überschreitet die WARC-Spreizer (6 m). Sonderspreizer oder weniger Elemente nötig."
        }
        if maxHalfLen > 5.0 {
            return "Längste Elemente brauchen \(String(format: "%.2f", maxHalfLen)) m Halbspreizer. WARC-Spreizer (6 m) erforderlich."
        }
        return nil
    }

    static func berechne(freq: Double, nElements: Int) -> SBEErgebnis? {
        guard freq > 0, nElements >= 2, nElements <= 6 else { return nil }
        let lambda = 300.0 / freq
        let strahlerLen = STRAHLER_FAKTOR * lambda

        let types: [String]
        switch nElements {
        case 2: types = ["Reflektor", "Strahler"]
        case 3: types = ["Reflektor", "Strahler", "Direktor 1"]
        case 4: types = ["Reflektor", "Strahler", "Direktor 1", "Direktor 2"]
        case 5: types = ["Reflektor", "Strahler", "Direktor 1", "Direktor 2", "Direktor 3"]
        default: types = ["Reflektor", "Strahler", "Direktor 1", "Direktor 2", "Direktor 3", "Direktor 4"]
        }

        let elements: [SBEElement] = types.compactMap { typ in
            guard let entry = ELEMENT_TABLE.first(where: { $0.typ == typ }) else { return nil }
            let L = entry.lenFactor * strahlerLen
            let S = entry.boomLambda * lambda
            let delta = (entry.lenFactor - 1.0) * 100
            return SBEElement(typ: typ, L: L, S: S, delta_pct: delta)
        }

        let minS = elements.map { $0.S }.min() ?? 0
        let maxS = elements.map { $0.S }.max() ?? 0
        let boom = maxS - minS
        let maxHalf = (elements.map { $0.L }.max() ?? 0) / 2

        return SBEErgebnis(freq: freq, lambda: lambda, strahlerLen: strahlerLen,
                           elements: elements, boomLength: boom,
                           maxHalfLen: maxHalf, nElements: nElements)
    }
}

// MARK: - View

struct SpiderbeamEinzelbandView: View {
    @State private var selectedBandIdx = 6   // 10m Default
    @State private var freqText   = "28.400"
    @State private var nElements  = 3

    private let bands: [(name: String, freq: Double, color: Color)] = [
        ("40m", 7.100,  Color(red: 0.49, green: 0.18, blue: 0.07)),
        ("30m", 10.125, Color(red: 0.71, green: 0.33, blue: 0.04)),
        ("20m", 14.150, .red),
        ("17m", 18.118, Color(red: 0.92, green: 0.35, blue: 0.04)),
        ("15m", 21.200, .green),
        ("12m", 24.940, Color(red: 0.49, green: 0.23, blue: 0.93)),
        ("10m", 28.400, .blue),
        ("6m",  50.150, .cyan),
    ]

    private var freq: Double { Double(freqText.replacingOccurrences(of: ",", with: ".")) ?? 28.4 }
    private var ergebnis: SBEErgebnis? { SBEErgebnis.berechne(freq: freq, nElements: nElements) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                bandWahl
                eingabeBereich
                if let r = ergebnis {
                    if let warn = r.spreizerWarnung { spreizerWarnung(warn) }
                    statistikBereich(r)
                    tabelleBereich(r)
                    skizzeBereich(r)
                }
                infoBereich
            }
            .padding(24)
        }
        .navigationTitle("Spiderbeam Einzelband")
    }

    // MARK: Band-Wahl

    private var bandWahl: some View {
        SectionCard(title: "Band") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 6) {
                ForEach(bands.indices, id: \.self) { i in
                    Button {
                        selectedBandIdx = i
                        freqText = String(bands[i].freq)
                    } label: {
                        Text(bands[i].name)
                            .foregroundStyle(selectedBandIdx == i ? .white : bands[i].color)
                    }
                    .buttonStyle(.bordered)
                    .tint(bands[i].color)
                    .background(selectedBandIdx == i ? bands[i].color : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Parameter") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Design-Frequenz").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("MHz", text: $freqText).textFieldStyle(.roundedBorder)
                            Text("MHz").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Anzahl Elemente").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $nElements) {
                            Text("2 Ele").tag(2)
                            Text("3 Ele").tag(3)
                            Text("4 Ele").tag(4)
                            Text("5 Ele").tag(5)
                            Text("6 Ele").tag(6)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                if freq > 0 {
                    HStack(spacing: 16) {
                        Label(String(format: "λ = %.3f m", 300.0 / freq), systemImage: "ruler").font(.caption).foregroundStyle(.secondary)
                        Label(String(format: "Strahler = %.3f m", STRAHLER_FAKTOR * 300.0 / freq), systemImage: "antenna.radiowaves.left.and.right").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Spreizer-Warnung

    private func spreizerWarnung(_ msg: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.title3)
            Text(msg).font(.callout).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Statistik

    private func statistikBereich(_ r: SBEErgebnis) -> some View {
        SectionCard(title: "Übersicht") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                KenngroesseKachel(wert: String(format: "%.3f m", r.lambda), label: "Wellenlänge λ")
                KenngroesseKachel(wert: String(format: "%.3f m", r.strahlerLen), label: "Strahler L_el", hervorheben: true, farbe: .accentColor)
                KenngroesseKachel(wert: String(format: "%.3f m", r.boomLength), label: "Boomlänge")
                KenngroesseKachel(wert: "\(r.nElements) Ele", label: "Elemente")
                KenngroesseKachel(wert: String(format: "%.2f m", r.maxHalfLen), label: "Benötigter Halbspreizer")
                KenngroesseKachel(wert: r.maxHalfLen <= 5.0 ? "Klassisch (5m)" : "WARC (6m)", label: "Spreizer-Typ")
            }
        }
    }

    // MARK: Tabelle

    private func tabelleBereich(_ r: SBEErgebnis) -> some View {
        SectionCard(title: "Elementmaße") {
            VStack(spacing: 0) {
                HStack {
                    Text("Element").font(.caption).fontWeight(.semibold).frame(width: 80, alignment: .leading)
                    Text("L_el (m)").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity)
                    Text("½ Schenkel (cm)").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity)
                    Text("Zuschnitt (cm)").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity)
                    Text("S (m)").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity)
                    Text("Δ Str.").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .padding(.vertical, 6).padding(.horizontal, 4)
                .background(Color.secondary.opacity(0.1))

                ForEach(r.elements.sorted(by: { $0.S < $1.S }).indices, id: \.self) { i in
                    let el = r.elements.sorted(by: { $0.S < $1.S })[i]
                    HStack {
                        Text(el.typ)
                            .font(.caption.bold())
                            .foregroundStyle(elementColor(el.typ))
                            .frame(width: 80, alignment: .leading)
                        Text(String(format: "%.3f", el.L))
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity)
                        Text(String(format: "%.1f", el.halbSchenkel * 100))
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity)
                        Text(String(format: "%.1f", el.zuschnittCm))
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity)
                        Text(el.S == 0 ? "0.00" : (el.S > 0 ? "+\(String(format: "%.2f", el.S))" : String(format: "%.2f", el.S)))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                        Text(el.typ == "Strahler" ? "–" : String(format: "%+.1f %%", el.delta_pct))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 4)
                    .background(i % 2 == 0 ? Color.clear : Color.secondary.opacity(0.04))
                    Divider()
                }
            }
        }
    }

    private func elementColor(_ typ: String) -> Color {
        if typ == "Reflektor" { return .red }
        if typ == "Strahler"  { return .blue }
        return .green
    }

    // MARK: Skizze

    private func skizzeBereich(_ r: SBEErgebnis) -> some View {
        SectionCard(title: "Antennenskizze – Draufsicht") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let mL: CGFloat = 100, mR: CGFloat = 100
                let mT: CGFloat = 48,  mB: CGFloat = 36
                guard r.boomLength > 0 else { return }

                // Physikalischer Spreizer: 5 m (Standard) oder 6 m (WARC)
                let spreizer_m: Double = r.maxHalfLen <= 5.0 ? 5.0 : 6.0

                let allS    = r.elements.map { $0.S }
                let maxSabs = max(abs(allS.max() ?? 1), abs(allS.min() ?? 1), 0.1)

                let boomX   = W / 2
                let centerY = mT + (H - mT - mB) / 2
                let usableH = H - mT - mB

                let scale = min(((W - mL - mR) / 2) / CGFloat(spreizer_m),
                                (usableH / 2) / CGFloat(maxSabs))

                func bY(_ s: Double) -> CGFloat { centerY - CGFloat(s) * scale }
                func bX(_ x: Double) -> CGFloat { boomX   + CGFloat(x) * scale }

                let rTip = CGPoint(x: bX( spreizer_m), y: centerY)
                let lTip = CGPoint(x: bX(-spreizer_m), y: centerY)

                func tipPt(from base: CGPoint, toward target: CGPoint, meters: Double) -> CGPoint {
                    let dx = target.x - base.x, dy = target.y - base.y
                    let dist = (dx*dx + dy*dy).squareRoot()
                    guard dist > 0.001 else { return base }
                    let len = CGFloat(meters) * scale
                    return CGPoint(x: base.x + dx/dist * len, y: base.y + dy/dist * len)
                }

                // ── Boom ────────────────────────────────────────────────────
                let boomTop    = bY(maxSabs + 0.3)
                let boomBottom = bY(-(maxSabs + 0.3))
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: boomX, y: boomTop))
                    p.addLine(to: CGPoint(x: boomX, y: boomBottom))
                }, with: .color(.gray.opacity(0.55)), style: StrokeStyle(lineWidth: 2.5))

                // ── Spreizer-Linie (gestrichelt, horizontal) ─────────────────
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

                // ── Maßstab ─────────────────────────────────────────────────
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

                let sorted = r.elements.sorted { $0.S > $1.S }

                // ── Schnüre (dünne Linien von Drahtspitze zum Spreizer-Endpunkt) ──
                for el in sorted {
                    let base  = CGPoint(x: boomX, y: bY(el.S))
                    let rWire = tipPt(from: base, toward: rTip, meters: el.L / 2)
                    let lWire = tipPt(from: base, toward: lTip, meters: el.L / 2)
                    let schnur = StrokeStyle(lineWidth: 0.8, dash: [3, 3])
                    ctx.stroke(Path { p in p.move(to: rWire); p.addLine(to: rTip) },
                               with: .color(.gray.opacity(0.28)), style: schnur)
                    ctx.stroke(Path { p in p.move(to: lWire); p.addLine(to: lTip) },
                               with: .color(.gray.opacity(0.28)), style: schnur)
                }

                // ── Elementdrähte (farbig) ───────────────────────────────────
                for (idx, el) in sorted.enumerated() {
                    let col  = elementColor(el.typ)
                    let base = CGPoint(x: boomX, y: bY(el.S))
                    let rWire = tipPt(from: base, toward: rTip, meters: el.L / 2)
                    let lWire = tipPt(from: base, toward: lTip, meters: el.L / 2)

                    ctx.stroke(Path { p in p.move(to: base); p.addLine(to: rWire) },
                               with: .color(col), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    ctx.stroke(Path { p in p.move(to: base); p.addLine(to: lWire) },
                               with: .color(col), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    let dr: CGFloat = el.typ == "Strahler" ? 4.5 : 3.0
                    ctx.fill(Path(ellipseIn: CGRect(x: boomX-dr, y: base.y-dr,
                                                    width: dr*2, height: dr*2)),
                             with: .color(col))

                    let short = el.typ.replacingOccurrences(of: "Direktor ", with: "D")
                    let sStr  = el.S == 0 ? "S=0.00 m"
                               : el.S > 0 ? "S=+\(String(format: "%.2f", el.S)) m"
                                           : "S=\(String(format: "%.2f", el.S)) m"
                    let ly = base.y
                    if idx % 2 == 0 {
                        ctx.draw(Text(short).font(.system(size: 9, weight: .bold)).foregroundStyle(col),
                                 at: CGPoint(x: W - mR + 4, y: ly - 6), anchor: .leading)
                        ctx.draw(Text(sStr).font(.system(size: 8)).foregroundStyle(Color.secondary),
                                 at: CGPoint(x: W - mR + 4, y: ly + 5), anchor: .leading)
                    } else {
                        ctx.draw(Text(short).font(.system(size: 9, weight: .bold)).foregroundStyle(col),
                                 at: CGPoint(x: mL - 4, y: ly - 6), anchor: .trailing)
                        ctx.draw(Text(sStr).font(.system(size: 8)).foregroundStyle(Color.secondary),
                                 at: CGPoint(x: mL - 4, y: ly + 5), anchor: .trailing)
                    }
                }

                // ── Spreizer-Beschriftung ─────────────────────────────────────
                let sprLabel = "\(spreizer_m == 5.0 ? "5" : "6") m Spreizer"
                ctx.draw(Text(sprLabel).font(.system(size: 8)).foregroundStyle(Color.secondary),
                         at: CGPoint(x: rTip.x + 4, y: rTip.y - 12), anchor: .leading)
            }
            .frame(height: 420)
        }
    }

    // MARK: Info

    private var infoBereich: some View {
        SectionCard(title: "Hinweis") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Strahler-Länge: \(String(format: "%.3f", STRAHLER_FAKTOR)) × λ (DF4SA-Formel). Weitere Elemente skalieren relativ zum Strahler.")
                    .font(.callout).foregroundStyle(.secondary)
                Text("Zuschnitt = Halbschenkel + 4 cm Toleranz für Befestigung/Abschluss. Feinabgleich nach Aufbau empfohlen.")
                    .font(.callout).foregroundStyle(.secondary)
                Text("Klassische Spreizer: 5 m. WARC-Spreizer: 6 m. Für 40m/30m sind Sonderspreizer nötig.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}
