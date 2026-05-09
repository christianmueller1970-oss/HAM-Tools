import SwiftUI

struct SpulenWicklerView: View {
    @State private var lText: String      = "10"
    @State private var dText: String      = "30"
    @State private var dwText: String     = "1.0"
    @State private var sText: String      = "0"
    @State private var cText: String      = "100"

    private func parse(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: "."))
    }

    private var ergebnis: SpulenErgebnis? {
        guard let L = parse(lText), let D = parse(dText),
              let dw = parse(dwText), let s = parse(sText),
              let C = parse(cText) else { return nil }
        return SpulenErgebnis.berechne(L: L, D: D, dw: dw, s: s, C: C)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if let r = ergebnis {
                    SpulenSkizze(ergebnis: r)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    ergebnisBereich(r)
                    detailBereich(r)
                }
            }
            .padding(24)
        }
        .navigationTitle("Spulen-Wickler")
    }

    // MARK: - Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Spulenparameter") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    eingabeZeile(label: "Induktivität L", text: $lText, einheit: "µH",
                                 hint: "Gewünschter Wert")
                    eingabeZeile(label: "Körper-Ø D", text: $dText, einheit: "mm",
                                 hint: "Wickelkörper")
                }
                HStack(spacing: 16) {
                    eingabeZeile(label: "Draht-Ø d", text: $dwText, einheit: "mm",
                                 hint: "inkl. Isolierung")
                    eingabeZeile(label: "Windungsabstand", text: $sText, einheit: "mm",
                                 hint: "0 = dicht gewickelt")
                }
                HStack(spacing: 16) {
                    eingabeZeile(label: "Kapazität C", text: $cText, einheit: "pF",
                                 hint: "Für LC-Resonanz")
                    Spacer()
                }
                Text("Berechnung nach Wheeler-Formel für einlagige Luftspulen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func eingabeZeile(label: String, text: Binding<String>, einheit: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                TextField(einheit, text: text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                Text(einheit).foregroundStyle(.secondary).font(.callout)
            }
            Text(hint).font(.caption2).foregroundStyle(Color.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Ergebnisse (Kacheln)

    private func ergebnisBereich(_ r: SpulenErgebnis) -> some View {
        SectionCard(title: "Ergebnisse") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                KenngroesseKachel(
                    wert: String(format: "%.1f", r.windungen),
                    label: "Windungen",
                    hervorheben: true,
                    farbe: .accentColor
                )
                KenngroesseKachel(
                    wert: String(format: "%.1f mm", r.spulenlaenge_mm),
                    label: "Spulenlänge"
                )
                KenngroesseKachel(
                    wert: String(format: "%.2f m", r.drahtlaenge_m),
                    label: "Drahtlänge"
                )
                if let f = r.resonanzFreq_MHz {
                    KenngroesseKachel(
                        wert: f >= 1
                            ? String(format: "%.3f MHz", f)
                            : String(format: "%.1f kHz", f * 1000),
                        label: "Resonanzfreq."
                    )
                }
                if let q = r.guete {
                    KenngroesseKachel(
                        wert: String(format: "%.0f", q),
                        label: "Güte Q"
                    )
                }
            }
        }
    }

    // MARK: - Details

    private func detailBereich(_ r: SpulenErgebnis) -> some View {
        SectionCard(title: "Wickeldetails") {
            VStack(spacing: 6) {
                ResultRow(label: "Wickelschritt (Pitch)",
                          value: String(format: "%.2f", r.pitch_mm), unit: "mm")
                ResultRow(label: "Außendurchmesser",
                          value: String(format: "%.1f", r.aussenD_mm), unit: "mm")
                ResultRow(label: "Induktivität / Windung",
                          value: String(format: "%.3f", r.induktProWindung_uH), unit: "µH/Wdg.")
                ResultRow(label: "Schlankheit (L/D)",
                          value: String(format: "%.2f", r.schlankheit), unit: "")
                ResultRow(label: "Körperdurchmesser",
                          value: String(format: "%.0f", r.D_mm), unit: "mm")
            }
        }
    }
}

// MARK: - Spulen-Skizze (Canvas)

struct SpulenSkizze: View {
    let ergebnis: SpulenErgebnis

    var body: some View {
        Canvas { ctx, size in
            draw(ctx: ctx, size: size)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let W = size.width
        let H = size.height

        let maxTurnsVis = 30
        let n = ergebnis.windungen
        let nVis = min(Int(ceil(n)), maxTurnsVis)
        let D    = ergebnis.D_mm
        let dw   = ergebnis.dw_mm
        let s    = ergebnis.s_mm
        let pitch = dw + s

        // Layout
        let leadLen: CGFloat = 36
        let marginL: CGFloat = leadLen + 12
        let marginR: CGFloat = 90
        let marginT: CGFloat = 22
        let marginB: CGFloat = 38

        let availW = W - marginL - marginR
        let availH = H - marginT - marginB

        let bodyH   = min(availH * 0.55, 100.0)
        let pitchPx = availW / CGFloat(nVis)
        let wireThick = max(2, min(8, bodyH * CGFloat(dw / D) * 0.8))
        let ex      = max(3, pitchPx * 0.38)
        let ey      = bodyH / 2 + wireThick * 0.5

        let bodyX = marginL
        let bodyW = CGFloat(nVis) * pitchPx
        let cy    = marginT + availH * 0.5

        let bTop = cy - bodyH / 2
        let bBot = cy + bodyH / 2

        let accent      = Color(red: 0.83, green: 0.33, blue: 0.0)
        let accentDark  = Color(red: 0.55, green: 0.18, blue: 0.0)
        let bodyStroke  = Color(red: 0.60, green: 0.69, blue: 0.78)

        // ── Hintergrund ──
        ctx.fill(RoundedRectangle(cornerRadius: 10).path(in: CGRect(x: 0, y: 0, width: W, height: H)),
                 with: .color(Color(nsColor: .controlBackgroundColor)))

        // ── Spulenkörper ──
        let bodyRect = CGRect(x: bodyX, y: bTop, width: bodyW, height: bodyH)
        ctx.fill(Path(bodyRect), with: .linearGradient(
            Gradient(colors: [Color(red: 0.92, green: 0.95, blue: 0.98),
                               Color(red: 0.78, green: 0.87, blue: 0.94),
                               Color(red: 0.92, green: 0.95, blue: 0.98)]),
            startPoint: CGPoint(x: bodyX, y: bTop),
            endPoint:   CGPoint(x: bodyX, y: bBot)
        ))
        ctx.stroke(Path(bodyRect), with: .color(bodyStroke), lineWidth: 1.5)

        // Endkappen
        drawEllipse(ctx: ctx, cx: bodyX, cy: cy, rx: ex * 0.7, ry: bodyH / 2,
                    fill: Color(red: 0.75, green: 0.83, blue: 0.91),
                    stroke: bodyStroke, strokeWidth: 1.5)
        drawEllipse(ctx: ctx, cx: bodyX + bodyW, cy: cy, rx: ex * 0.7, ry: bodyH / 2,
                    fill: Color(red: 0.78, green: 0.87, blue: 0.94),
                    stroke: bodyStroke, strokeWidth: 1.5)

        // ── Hintere Bögen (obere Halbellipse, dunkler) ──
        for i in 0..<nVis {
            let cx = bodyX + (CGFloat(i) + 0.5) * pitchPx
            var p = Path()
            p.move(to: CGPoint(x: cx - ex, y: cy))
            p.addArc(center: CGPoint(x: cx, y: cy),
                     radius: ex,
                     startAngle: .degrees(180),
                     endAngle: .degrees(0),
                     clockwise: false)
            // Skaliere Y mit ey/ex
            let t = CGAffineTransform(scaleX: 1, y: ey / ex)
                .concatenating(CGAffineTransform(translationX: 0, y: cy - cy * (ey / ex)))
            ctx.stroke(p.applying(t), with: .color(accentDark.opacity(0.5)), lineWidth: wireThick)
        }

        // ── Verbindungslinien oben (vorne) ──
        for i in 0..<(nVis - 1) {
            let cx1 = bodyX + (CGFloat(i) + 0.5) * pitchPx + ex
            let cx2 = bodyX + (CGFloat(i) + 1.5) * pitchPx - ex
            let yTop = cy - ey
            var p = Path()
            p.move(to: CGPoint(x: cx1, y: yTop))
            p.addLine(to: CGPoint(x: cx2, y: yTop))
            ctx.stroke(p, with: .color(accent), lineWidth: wireThick)
        }

        // ── Vordere Bögen (untere Halbellipse, heller) ──
        for i in 0..<nVis {
            let cx = bodyX + (CGFloat(i) + 0.5) * pitchPx
            var p = Path()
            p.move(to: CGPoint(x: cx - ex, y: cy))
            p.addArc(center: CGPoint(x: cx, y: cy),
                     radius: ex,
                     startAngle: .degrees(180),
                     endAngle: .degrees(0),
                     clockwise: true)
            let t = CGAffineTransform(scaleX: 1, y: ey / ex)
                .concatenating(CGAffineTransform(translationX: 0, y: cy - cy * (ey / ex)))
            ctx.stroke(p.applying(t),
                       with: .linearGradient(
                           Gradient(colors: [Color(red: 0.94, green: 0.56, blue: 0.31), accent]),
                           startPoint: CGPoint(x: cx, y: cy),
                           endPoint:   CGPoint(x: cx, y: cy + ey)
                       ),
                       lineWidth: wireThick)
        }

        // ── Verbindungslinien unten (hinten, halbtransparent) ──
        for i in 0..<(nVis - 1) {
            let cx1 = bodyX + (CGFloat(i) + 0.5) * pitchPx + ex
            let cx2 = bodyX + (CGFloat(i) + 1.5) * pitchPx - ex
            let yBot = cy + ey
            var p = Path()
            p.move(to: CGPoint(x: cx1, y: yBot))
            p.addLine(to: CGPoint(x: cx2, y: yBot))
            ctx.stroke(p, with: .color(accentDark.opacity(0.4)), lineWidth: wireThick)
        }

        // ── Zuleitungen ──
        let yLead = cy - ey
        var leadL = Path()
        leadL.move(to: CGPoint(x: bodyX - leadLen, y: yLead))
        leadL.addLine(to: CGPoint(x: bodyX - ex, y: yLead))
        ctx.stroke(leadL, with: .color(accent), lineWidth: wireThick)

        var leadR = Path()
        leadR.move(to: CGPoint(x: bodyX + bodyW + ex, y: yLead))
        leadR.addLine(to: CGPoint(x: bodyX + bodyW + leadLen, y: yLead))
        ctx.stroke(leadR, with: .color(accent), lineWidth: wireThick)

        // ── Bemaassung: Länge (unten) ──
        let arrY = bBot + 16
        drawDimensionH(ctx: ctx, x1: bodyX, x2: bodyX + bodyW, y: arrY, yFrom: bBot + 4,
                       label: String(format: "%.1f mm", ergebnis.spulenlaenge_mm))

        // ── Bemaassung: Durchmesser (rechts) ──
        let dax = bodyX + bodyW + leadLen + 14
        drawDimensionV(ctx: ctx, x: dax, y1: bTop, y2: bBot, xFrom: bodyX + bodyW + 4,
                       label: String(format: "Ø %.0f mm", D))

        // ── Label oben ──
        let topLabel = "\(Int(ceil(n))) Windungen · Pitch \(String(format: "%.1f", pitch)) mm"
        drawLabel(ctx: ctx, text: topLabel, x: bodyX + bodyW / 2, y: bTop - 8, anchor: .center)

        // ── Hinweis wenn Windungen gekürzt ──
        if Int(ceil(n)) > maxTurnsVis {
            let hint = "Skizze: \(maxTurnsVis) von \(Int(ceil(n))) Windungen"
            drawLabel(ctx: ctx, text: hint, x: W / 2, y: H - 8, anchor: .center, color: .secondary)
        }
    }

    // MARK: - Canvas-Hilfsfunktionen

    private func drawEllipse(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                              rx: CGFloat, ry: CGFloat, fill: Color, stroke: Color, strokeWidth: CGFloat) {
        let r = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
        ctx.fill(Path(ellipseIn: r), with: .color(fill))
        ctx.stroke(Path(ellipseIn: r), with: .color(stroke), lineWidth: strokeWidth)
    }

    private func drawDimensionH(ctx: GraphicsContext, x1: CGFloat, x2: CGFloat,
                                 y: CGFloat, yFrom: CGFloat, label: String) {
        let gray = Color.secondary
        // Vertikale Hilfslinien
        for x in [x1, x2] {
            var p = Path()
            p.move(to: CGPoint(x: x, y: yFrom))
            p.addLine(to: CGPoint(x: x, y: y + 2))
            ctx.stroke(p, with: .color(gray.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        }
        // Pfeilline
        var p = Path()
        p.move(to: CGPoint(x: x1, y: y))
        p.addLine(to: CGPoint(x: x2, y: y))
        ctx.stroke(p, with: .color(gray), lineWidth: 1.5)
        // Pfeilspitzen
        drawArrow(ctx: ctx, at: CGPoint(x: x1, y: y), pointing: .left, color: gray)
        drawArrow(ctx: ctx, at: CGPoint(x: x2, y: y), pointing: .right, color: gray)
        drawLabel(ctx: ctx, text: label, x: (x1 + x2) / 2, y: y + 13, anchor: .center)
    }

    private func drawDimensionV(ctx: GraphicsContext, x: CGFloat, y1: CGFloat,
                                 y2: CGFloat, xFrom: CGFloat, label: String) {
        let gray = Color.secondary
        for y in [y1, y2] {
            var p = Path()
            p.move(to: CGPoint(x: xFrom, y: y))
            p.addLine(to: CGPoint(x: x - 2, y: y))
            ctx.stroke(p, with: .color(gray.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        }
        var p = Path()
        p.move(to: CGPoint(x: x, y: y1))
        p.addLine(to: CGPoint(x: x, y: y2))
        ctx.stroke(p, with: .color(gray), lineWidth: 1.5)
        drawArrow(ctx: ctx, at: CGPoint(x: x, y: y1), pointing: .up, color: gray)
        drawArrow(ctx: ctx, at: CGPoint(x: x, y: y2), pointing: .down, color: gray)
        drawLabel(ctx: ctx, text: label, x: x + 8, y: (y1 + y2) / 2, anchor: .leading)
    }

    enum ArrowDir { case left, right, up, down }
    private func drawArrow(ctx: GraphicsContext, at pt: CGPoint, pointing: ArrowDir, color: Color) {
        let s: CGFloat = 5
        var path = Path()
        switch pointing {
        case .left:
            path.move(to: CGPoint(x: pt.x + s, y: pt.y - s * 0.6))
            path.addLine(to: pt)
            path.addLine(to: CGPoint(x: pt.x + s, y: pt.y + s * 0.6))
        case .right:
            path.move(to: CGPoint(x: pt.x - s, y: pt.y - s * 0.6))
            path.addLine(to: pt)
            path.addLine(to: CGPoint(x: pt.x - s, y: pt.y + s * 0.6))
        case .up:
            path.move(to: CGPoint(x: pt.x - s * 0.6, y: pt.y + s))
            path.addLine(to: pt)
            path.addLine(to: CGPoint(x: pt.x + s * 0.6, y: pt.y + s))
        case .down:
            path.move(to: CGPoint(x: pt.x - s * 0.6, y: pt.y - s))
            path.addLine(to: pt)
            path.addLine(to: CGPoint(x: pt.x + s * 0.6, y: pt.y - s))
        }
        ctx.stroke(path, with: .color(color), lineWidth: 1.5)
    }

    enum TextAnchor { case center, leading }
    private func drawLabel(ctx: GraphicsContext, text: String, x: CGFloat, y: CGFloat,
                            anchor: TextAnchor, color: Color = Color.secondary) {
        let t = Text(text).font(.system(size: 10)).foregroundColor(color)
        let resolved = ctx.resolve(t)
        let size = resolved.measure(in: CGSize(width: 400, height: 30))
        let ox: CGFloat = anchor == .center ? -size.width / 2 : 0
        ctx.draw(resolved, at: CGPoint(x: x + ox, y: y - size.height / 2))
    }
}
