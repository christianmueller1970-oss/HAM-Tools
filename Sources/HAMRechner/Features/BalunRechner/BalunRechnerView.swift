import SwiftUI

struct BalunRechnerView: View {
    @State private var gewaehlteGruppe: String = "Amidon Ferrit Mix 43"
    @State private var gewaehlterKernID: String = "ft240_43"
    @State private var gewaehlterTypID: String = "1_1"
    @State private var lText: String = "25.0"
    @State private var drahtText: String = "1.5"

    private var gewaehlteKerne: [Ringkern] { alleKerne.filter { $0.gruppe == gewaehlteGruppe } }
    private var kern: Ringkern? { alleKerne.first { $0.id == gewaehlterKernID } }
    private var typ: BalunTyp? { alleBalunTypen.first { $0.id == gewaehlterTypID } }

    private var ergebnis: BalunErgebnis? {
        guard let k = kern, let t = typ,
              let L = Double(lText.replacingOccurrences(of: ",", with: ".")),
              let d = Double(drahtText.replacingOccurrences(of: ",", with: "."))
        else { return nil }
        return berechneBalun(kern: k, typ: t, lUH: L, drahtDmm: d)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                typAuswahlBereich
                kernAuswahlBereich
                eingabeBereich
                if let r = ergebnis {
                    RingkernSkizze(ergebnis: r)
                        .frame(maxWidth: .infinity)
                        .frame(height: 210)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    ergebnisBereich(r)
                    warnBereich(r)
                    detailBereich(r)
                }
            }
            .padding(24)
        }
        .navigationTitle("Balun / Unun Wicklungsrechner")
    }

    // MARK: - Typ-Auswahl

    private var typAuswahlBereich: some View {
        SectionCard(title: "Balun / Unun Typ") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Typ", selection: $gewaehlterTypID) {
                    ForEach(alleBalunTypen) { t in
                        Text(t.label).tag(t.id)
                    }
                }
                .labelsHidden()
                .onChange(of: gewaehlterTypID) {
                    if let t = typ {
                        lText = String(t.zielL_uH)
                    }
                }
                if let t = typ {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text(t.hinweis)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Kern-Auswahl

    private var kernAuswahlBereich: some View {
        SectionCard(title: "Ringkern") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Material / Gruppe").font(.caption).foregroundStyle(.secondary)
                        Picker("Gruppe", selection: $gewaehlteGruppe) {
                            ForEach(kernGruppen, id: \.self) { Text($0) }
                        }
                        .labelsHidden()
                        .frame(minWidth: 220)
                        .onChange(of: gewaehlteGruppe) {
                            if let erster = gewaehlteKerne.first {
                                gewaehlterKernID = erster.id
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kern").font(.caption).foregroundStyle(.secondary)
                        Picker("Kern", selection: $gewaehlterKernID) {
                            ForEach(gewaehlteKerne) { k in
                                Text("\(k.name)  (Al = \(Int(k.al)))").tag(k.id)
                            }
                        }
                        .labelsHidden()
                        .frame(minWidth: 260)
                    }
                }
                if let k = kern {
                    HStack(spacing: 16) {
                        Label(k.beschreibung, systemImage: "info.circle")
                            .font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        Text("OD \(k.od, specifier: "%.1f") · ID \(k.idMM, specifier: "%.1f") · H \(k.hoehe, specifier: "%.1f") mm")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Eingaben

    private var eingabeBereich: some View {
        SectionCard(title: "Parameter") {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ziel-Induktivität L").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        TextField("µH", text: $lText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("µH").foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drahtdurchmesser").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        TextField("mm", text: $drahtText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("mm").foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Formel").font(.caption).foregroundStyle(.secondary)
                    Text("N = √(L[nH] / Al[nH/N²])")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Ergebnisse

    private func ergebnisBereich(_ r: BalunErgebnis) -> some View {
        SectionCard(title: "Ergebnisse") {
            let isSpecial = (r.typ.id == "49_1" || r.typ.id == "64_1")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                KenngroesseKachel(
                    wert: isSpecial
                        ? (r.typ.id == "49_1" ? "2 + 14" : "1 + 7")
                        : "\(r.windungen) Wdg.",
                    label: isSpecial ? "Windungen (Prim + Sek)" : "Windungen",
                    hervorheben: true,
                    farbe: .accentColor
                )
                KenngroesseKachel(
                    wert: isSpecial ? "Prim / Sek" : String(format: "%.2f µH", r.lTatsaechlich_uH),
                    label: isSpecial ? "Wicklung" : "Erzielte Induktivität"
                )
                KenngroesseKachel(
                    wert: String(format: "%.2f m", r.drahtlaenge_m),
                    label: "Drahtlänge (ca.)"
                )
                KenngroesseKachel(
                    wert: String(format: "%.0f %%", r.auslastungProzent),
                    label: "Kernauslastung",
                    hervorheben: r.bewertung != .ok,
                    farbe: r.bewertung == .zuKlein ? .red : .orange
                )
            }
        }
    }

    // MARK: - Warnung

    @ViewBuilder
    private func warnBereich(_ r: BalunErgebnis) -> some View {
        switch r.bewertung {
        case .zuKlein:
            warnBox(
                icon: "xmark.octagon.fill", farbe: .red,
                titel: "Kern zu klein!",
                text: "\(r.windungen) Wdg. × \(drahtText) mm passen nicht in den Innenumfang (\(String(format: "%.0f", r.innenumfang_mm)) mm). Größeren Kern wählen."
            )
        case .eng:
            warnBox(
                icon: "exclamationmark.triangle.fill", farbe: .orange,
                titel: "Kern eng belegt (\(String(format: "%.0f", r.auslastungProzent)) %)",
                text: "Wickeln ist möglich, aber kein Platz für Korrekturen. Nächstgrößeren Kern erwägen."
            )
        case .ok:
            EmptyView()
        }
    }

    private func warnBox(icon: String, farbe: Color, titel: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(farbe).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).fontWeight(.semibold)
                Text(text).font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(farbe.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Details

    private func detailBereich(_ r: BalunErgebnis) -> some View {
        SectionCard(title: "Kerndaten") {
            VStack(spacing: 6) {
                ResultRow(label: "Al-Wert",           value: String(format: "%.0f", r.kern.al),           unit: "nH/N²")
                ResultRow(label: "Außendurchmesser",  value: String(format: "%.1f", r.kern.od),           unit: "mm")
                ResultRow(label: "Innendurchmesser",  value: String(format: "%.1f", r.kern.idMM),         unit: "mm")
                ResultRow(label: "Höhe",              value: String(format: "%.2f", r.kern.hoehe),        unit: "mm")
                ResultRow(label: "Innenumfang",       value: String(format: "%.1f", r.innenumfang_mm),    unit: "mm")
                ResultRow(label: "Max. Windungen",    value: "\(r.maxWindungen)",                         unit: "Wdg.")
            }
        }
    }
}

// MARK: - Ringkern-Skizze (Canvas)

struct RingkernSkizze: View {
    let ergebnis: BalunErgebnis

    var body: some View {
        Canvas { ctx, size in
            switch ergebnis.typ.wicklung {
            case .bifilarZweiKerne:  drawZweiKerne(ctx: ctx, size: size)
            case .trifilar:          drawTrifilar(ctx: ctx, size: size)
            default:                 drawStandard(ctx: ctx, size: size)
            }
        }
    }

    // MARK: Gemeinsame Helfer

    private func drawKern(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, rO: CGFloat, rI: CGFloat, uid: String = "") {
        let outer = Path(ellipseIn: CGRect(x: cx-rO, y: cy-rO, width: rO*2, height: rO*2))
        ctx.fill(outer, with: .radialGradient(
            Gradient(colors: [Color(red: 0.84, green: 0.80, blue: 0.78), Color(red: 0.48, green: 0.33, blue: 0.28)]),
            center: CGPoint(x: cx - rO*0.2, y: cy - rO*0.3), startRadius: 0, endRadius: rO))
        ctx.stroke(outer, with: .color(Color(red: 0.55, green: 0.43, blue: 0.39)), lineWidth: 1.5)
        let inner = Path(ellipseIn: CGRect(x: cx-rI, y: cy-rI, width: rI*2, height: rI*2))
        ctx.fill(inner, with: .color(Color(nsColor: .controlBackgroundColor)))
        ctx.stroke(inner, with: .color(Color(red: 0.55, green: 0.43, blue: 0.39)), lineWidth: 1)
    }

    private func drawWindung(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                              angle: Double, rO: CGFloat, rI: CGFloat,
                              wireR: CGFloat, farbe: Color, gewickelt: Bool) {
        let col = gewickelt ? farbe : Color.secondary.opacity(0.3)
        let ox = cx + (rO + wireR*0.6) * cos(angle)
        let oy = cy + (rO + wireR*0.6) * sin(angle)
        let ix = cx + (rI - wireR*0.6) * cos(angle)
        let iy = cy + (rI - wireR*0.6) * sin(angle)

        var line = Path()
        line.move(to: CGPoint(x: ox, y: oy))
        line.addLine(to: CGPoint(x: ix, y: iy))
        ctx.stroke(line, with: .color(col.opacity(0.7)), lineWidth: wireR * 1.2)

        ctx.fill(Path(ellipseIn: CGRect(x: ox-wireR, y: oy-wireR, width: wireR*2, height: wireR*2)),
                 with: .color(col))
        let innerR = wireR * 0.75
        ctx.fill(Path(ellipseIn: CGRect(x: ix-innerR, y: iy-innerR, width: innerR*2, height: innerR*2)),
                 with: .color(gewickelt ? farbe.opacity(0.5) : col))
    }

    // MARK: Standard (1:1 / Mantelwelle / frei)

    private func drawStandard(ctx: GraphicsContext, size: CGSize) {
        let W = size.width, H = size.height
        let cx: CGFloat = min(W * 0.38, 200), cy = H / 2
        let kern = ergebnis.kern
        let scale = min(130.0 / kern.od, 80.0 / kern.idMM)
        let rO = CGFloat(kern.od / 2) * scale
        let rI = CGFloat(kern.idMM / 2) * scale
        let wireR: CGFloat = max(3, min(6.5, CGFloat(ergebnis.windungen > 0 ? rI * 0.15 : 5)))

        let N = ergebnis.windungen
        let maxVis = min(N, ergebnis.maxWindungen, 60)
        let fill = ergebnis.auslastungProzent / 100.0

        ctx.fill(RoundedRectangle(cornerRadius: 10).path(in: CGRect(x: 0, y: 0, width: W, height: H)),
                 with: .color(Color(nsColor: .controlBackgroundColor)))

        drawKern(ctx: ctx, cx: cx, cy: cy, rO: rO, rI: rI)

        let angleStep = (2 * .pi) / Double(max(maxVis, 1))
        let filledN = Int((Double(maxVis) * fill).rounded())

        for i in 0..<maxVis {
            let angle = -.pi / 2 + Double(i) * angleStep
            drawWindung(ctx: ctx, cx: cx, cy: cy, angle: angle, rO: rO, rI: rI,
                        wireR: wireR, farbe: Color(red: 0.76, green: 0.23, blue: 0.17),
                        gewickelt: i < filledN)
        }

        // Bemaassung OD
        let arrY = cy - rO - 18
        drawDimH(ctx: ctx, x1: cx - rO, x2: cx + rO, y: arrY, label: "OD \(String(format: "%.0f", kern.od)) mm")

        // Infotext rechts
        let tx = cx + rO + 30
        let infos: [(String, String)] = [
            ("Kern:",       kern.name),
            ("Windungen:",  "\(N) Wdg."),
            ("Auslastung:", String(format: "%.0f %%", ergebnis.auslastungProzent)),
            ("Al-Wert:",    "\(Int(kern.al)) nH/N²"),
        ]
        for (i, (lbl, val)) in infos.enumerated() {
            let y = cy - 35 + CGFloat(i) * 20
            drawText(ctx: ctx, text: lbl, x: tx, y: y, bold: false, color: .secondary)
            drawText(ctx: ctx, text: val, x: tx + 85, y: y, bold: true, color: .primary)
        }

        // Legende
        let ly = cy + 55
        ctx.fill(Path(ellipseIn: CGRect(x: tx-5, y: ly-5, width: 10, height: 10)),
                 with: .color(Color(red: 0.76, green: 0.23, blue: 0.17)))
        drawText(ctx: ctx, text: "= gewickelt", x: tx + 14, y: ly + 1, bold: false, color: .secondary)
        ctx.fill(Path(ellipseIn: CGRect(x: tx-5, y: ly+14, width: 10, height: 10)),
                 with: .color(.secondary.opacity(0.3)))
        drawText(ctx: ctx, text: "= frei", x: tx + 14, y: ly + 16, bold: false, color: .secondary)
    }

    // MARK: 4:1 Guanella (2 Kerne, bifilar)

    private func drawZweiKerne(ctx: GraphicsContext, size: CGSize) {
        let W = size.width, H = size.height
        let rO: CGFloat = 58, rI: CGFloat = 32
        let centers = [CGPoint(x: W * 0.28, y: H * 0.5), CGPoint(x: W * 0.60, y: H * 0.5)]
        let accent1 = Color(red: 0.13, green: 0.13, blue: 0.13)
        let accent2 = Color(red: 0.10, green: 0.46, blue: 0.82)
        let nVis = min(ergebnis.windungen, 14)

        ctx.fill(RoundedRectangle(cornerRadius: 10).path(in: CGRect(x: 0, y: 0, width: W, height: H)),
                 with: .color(Color(nsColor: .controlBackgroundColor)))

        drawText(ctx: ctx, text: "4:1 Guanella Strombalun – 2 Kerne bifilar",
                 x: W/2, y: 14, bold: false, color: .secondary, centered: true)

        for (ki, c) in centers.enumerated() {
            drawKern(ctx: ctx, cx: c.x, cy: c.y, rO: rO, rI: rI)
            drawText(ctx: ctx, text: "Kern \(ki+1)", x: c.x, y: c.y + 3, bold: true,
                     color: .white.opacity(0.7), centered: true)

            let aStep = (2 * .pi) / Double(max(nVis, 1))
            let wR: CGFloat = 4.5
            for i in 0..<nVis {
                let ang = -.pi / 2 + Double(i) * aStep
                let offAng = ang + .pi / 2
                let drahtPaare: [(CGFloat, Color)] = [(-wR * 0.9, accent1), (wR * 0.9, accent2)]
                for (mult, col) in drahtPaare {
                    let ox = c.x + (rO + wR*0.55) * cos(ang) + cos(offAng) * mult
                    let oy = c.y + (rO + wR*0.55) * sin(ang) + sin(offAng) * mult
                    let ix = c.x + (rI - wR*0.55) * cos(ang) + cos(offAng) * mult
                    let iy = c.y + (rI - wR*0.55) * sin(ang) + sin(offAng) * mult
                    var line = Path(); line.move(to: CGPoint(x: ox, y: oy)); line.addLine(to: CGPoint(x: ix, y: iy))
                    ctx.stroke(line, with: .color(col.opacity(0.9)), lineWidth: 3.5)
                    ctx.fill(Path(ellipseIn: CGRect(x: ox-wR, y: oy-wR, width: wR*2, height: wR*2)), with: .color(col))
                }
            }
        }

        // Verbindungsdrähte zwischen Kernen
        let c0 = centers[0], c1 = centers[1]
        for (dy, col): (CGFloat, Color) in [(-12, accent1), (12, accent2)] {
            var dashed = Path()
            dashed.move(to: CGPoint(x: c0.x + rO + 5, y: c0.y + dy))
            dashed.addLine(to: CGPoint(x: c1.x - rO - 5, y: c1.y + dy))
            ctx.stroke(dashed, with: .color(col), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
        }

        // Anschluss-Labels
        drawText(ctx: ctx, text: "50 Ω", x: c0.x - rO - 20, y: c0.y + 5, bold: false, color: .secondary, centered: true)
        drawText(ctx: ctx, text: "200 Ω", x: c1.x + rO + 24, y: c1.y + 5, bold: false, color: .secondary, centered: true)

        // Legende
        let lx = W * 0.80, ly = H * 0.15
        ctx.fill(Path(ellipseIn: CGRect(x: lx-5, y: ly-5, width: 10, height: 10)), with: .color(accent1))
        drawText(ctx: ctx, text: "Draht 1", x: lx + 10, y: ly + 1, bold: false, color: .secondary)
        ctx.fill(Path(ellipseIn: CGRect(x: lx-5, y: ly+15, width: 10, height: 10)), with: .color(accent2))
        drawText(ctx: ctx, text: "Draht 2", x: lx + 10, y: ly + 16, bold: false, color: .secondary)
    }

    // MARK: 9:1 Trifilar

    private func drawTrifilar(ctx: GraphicsContext, size: CGSize) {
        let W = size.width, H = size.height
        let cx = W * 0.38, cy = H / 2
        let rO: CGFloat = 75, rI: CGFloat = 42
        let nVis = min(ergebnis.windungen, 9)
        let farben: [Color] = [
            Color(red: 0.75, green: 0.22, blue: 0.05),
            Color(red: 0.85, green: 0.26, blue: 0.08),
            Color(red: 1.00, green: 0.54, blue: 0.40)
        ]

        ctx.fill(RoundedRectangle(cornerRadius: 10).path(in: CGRect(x: 0, y: 0, width: W, height: H)),
                 with: .color(Color(nsColor: .controlBackgroundColor)))
        drawText(ctx: ctx, text: "9:1 Unun – trifilar (3 Drähte, \(nVis) Windungen)",
                 x: W/2, y: 14, bold: false, color: .secondary, centered: true)

        drawKern(ctx: ctx, cx: cx, cy: cy, rO: rO, rI: rI)

        let aStep = (2 * .pi) / Double(max(nVis, 1))
        let wR: CGFloat = 4.5
        for i in 0..<nVis {
            let ang = -.pi / 2 + Double(i) * aStep
            let offAng = ang + .pi / 2
            for d in 0..<3 {
                let mult = CGFloat(d - 1) * 2.0
                let ox = cx + (rO + wR*0.45) * cos(ang) + cos(offAng) * mult
                let oy = cy + (rO + wR*0.45) * sin(ang) + sin(offAng) * mult
                let ix = cx + (rI - wR*0.45) * cos(ang) + cos(offAng) * mult
                let iy = cy + (rI - wR*0.45) * sin(ang) + sin(offAng) * mult
                var line = Path(); line.move(to: CGPoint(x: ox, y: oy)); line.addLine(to: CGPoint(x: ix, y: iy))
                ctx.stroke(line, with: .color(farben[d].opacity(0.9)), lineWidth: 3.2)
                ctx.fill(Path(ellipseIn: CGRect(x: ox-wR, y: oy-wR, width: wR*2, height: wR*2)),
                         with: .color(farben[d]))
            }
        }

        // Legende
        let tx = cx + rO + 28
        for (i, (lbl, col)) in zip(["Draht 1", "Draht 2", "Draht 3"], farben).enumerated() {
            let y = cy - 20 + CGFloat(i) * 20
            ctx.fill(Path(ellipseIn: CGRect(x: tx-5, y: y-5, width: 10, height: 10)), with: .color(col))
            drawText(ctx: ctx, text: lbl, x: tx + 14, y: y + 1, bold: false, color: .secondary)
        }

        drawText(ctx: ctx, text: "450 Ω", x: cx - rO - 22, y: cy + 5, bold: false, color: .secondary, centered: true)
        drawText(ctx: ctx, text: "50 Ω",  x: cx + rO + 110, y: cy + 5, bold: false, color: .secondary, centered: true)
    }

    // MARK: Canvas-Hilfsfunktionen

    private func drawDimH(ctx: GraphicsContext, x1: CGFloat, x2: CGFloat, y: CGFloat, label: String) {
        let gray = Color.secondary
        for x in [x1, x2] {
            var p = Path(); p.move(to: CGPoint(x: x, y: y + 14)); p.addLine(to: CGPoint(x: x, y: y + 2))
            ctx.stroke(p, with: .color(gray.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [3,2]))
        }
        var arrow = Path(); arrow.move(to: CGPoint(x: x1, y: y)); arrow.addLine(to: CGPoint(x: x2, y: y))
        ctx.stroke(arrow, with: .color(gray), lineWidth: 1.5)
        drawText(ctx: ctx, text: label, x: (x1+x2)/2, y: y - 7, bold: false, color: .secondary, centered: true)
    }

    private func drawText(ctx: GraphicsContext, text: String, x: CGFloat, y: CGFloat,
                           bold: Bool, color: Color, centered: Bool = false) {
        let t = Text(text)
            .font(bold ? .system(size: 11, weight: .bold) : .system(size: 11))
            .foregroundColor(color)
        let resolved = ctx.resolve(t)
        let sz = resolved.measure(in: CGSize(width: 400, height: 30))
        let ox: CGFloat = centered ? -sz.width / 2 : 0
        ctx.draw(resolved, at: CGPoint(x: x + ox, y: y - sz.height / 2))
    }
}
