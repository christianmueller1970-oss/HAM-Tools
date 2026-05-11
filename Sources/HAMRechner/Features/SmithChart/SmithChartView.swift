import SwiftUI

// MARK: - Smith-Chart Rechner

struct SmithChartView: View {
    @AppStorage("smith_freq") private var freqMHz: String = "14.200"
    @AppStorage("smith_R")    private var rText:   String = "75"
    @AppStorage("smith_X")    private var xText:   String = "25"
    @AppStorage("smith_Z0")   private var z0:      Double = 50

    @State private var showVSWRCircle: Bool = true
    @State private var showAdmittance: Bool = false
    @State private var selectedSolution: Int = 0

    private var rVal: Double { Double(rText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var xVal: Double { Double(xText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var fVal: Double { Double(freqMHz.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    // Normierte Impedanz z = Z/Z0
    private var zN: (re: Double, im: Double) { (rVal / z0, xVal / z0) }

    // Reflexionsfaktor Γ = (Z - Z0) / (Z + Z0)
    private var gamma: (re: Double, im: Double) {
        let num_re = rVal - z0
        let num_im = xVal
        let den_re = rVal + z0
        let den_im = xVal
        let mag2  = den_re * den_re + den_im * den_im
        guard mag2 > 0 else { return (0, 0) }
        let re = (num_re * den_re + num_im * den_im) / mag2
        let im = (num_im * den_re - num_re * den_im) / mag2
        return (re, im)
    }
    private var gammaMag: Double { sqrt(gamma.re * gamma.re + gamma.im * gamma.im) }
    private var gammaDeg: Double { atan2(gamma.im, gamma.re) * 180 / .pi }
    private var swr: Double {
        let g = gammaMag
        if g >= 0.999 { return .infinity }
        return (1 + g) / (1 - g)
    }
    private var returnLossDB: Double { gammaMag <= 0 ? .infinity : -20 * log10(gammaMag) }
    private var mismatchLossDB: Double {
        let g2 = gammaMag * gammaMag
        return g2 >= 0.999 ? .infinity : -10 * log10(1 - g2)
    }
    // Admittance Y = 1/Z
    private var admittance: (g_mS: Double, b_mS: Double) {
        let mag2 = rVal * rVal + xVal * xVal
        guard mag2 > 0 else { return (0, 0) }
        return (rVal / mag2 * 1000, -xVal / mag2 * 1000)   // S → mS
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                smithChartBereich
                if !lMatchSolutions.isEmpty {
                    lMatchBereich
                }
                ergebnisBereich
                hinweisBereich
                RechnerBeschreibung(resourceName: "smithchart")
            }
            .padding(24)
        }
        .navigationTitle("Smith-Chart")
        .onChange(of: lMatchSolutions.count) { _, newCount in
            if selectedSolution >= newCount { selectedSolution = 0 }
        }
    }

    // MARK: - L-Network Berechnung

    enum LComponent {
        case L(Double)   // Henry
        case C(Double)   // Farad
        var symbol: String { switch self { case .L: return "L"; case .C: return "C" } }
        var displayValue: String {
            switch self {
            case .L(let h):
                let nH = h * 1e9
                if nH >= 1000 { return String(format: "%.3f µH", nH / 1000) }
                if nH >= 1    { return String(format: "%.1f nH", nH) }
                return String(format: "%.2f nH", nH)
            case .C(let f):
                let pF = f * 1e12
                if pF >= 1000 { return String(format: "%.3f nF", pF / 1000) }
                if pF >= 1    { return String(format: "%.1f pF", pF) }
                return String(format: "%.2f pF", pF)
            }
        }
    }

    struct LMatchSolution: Identifiable {
        let id = UUID()
        let name: String              // z.B. "Lösung 1: Tiefpass"
        let topology: String          // z.B. "Shunt-C → Series-L"
        let shuntFirst: Bool          // true: Shunt am Last-Ende, dann Series Richtung Quelle
        let shuntComponent: LComponent
        let seriesComponent: LComponent
        // Pfad-Punkte (im Z-Bereich, normalisiert wird in der View gemacht)
        let intermediateR: Double     // Real-Teil der Zwischen-Impedanz
        let intermediateX: Double     // Imag-Teil
    }

    private var lMatchSolutions: [LMatchSolution] {
        guard fVal > 0, rVal > 0 else { return [] }
        let omega = 2 * .pi * fVal * 1e6
        let R_L = rVal, X_L = xVal, R_S = z0
        let R_L_eq = (R_L * R_L + X_L * X_L) / R_L
        var sols: [LMatchSolution] = []

        // Fall A: Shunt am Last-Ende, Series Richtung Quelle  (R_L_eq > R_S)
        if R_L_eq > R_S {
            let Q = sqrt(R_L_eq / R_S - 1)
            let G_L = R_L / (R_L * R_L + X_L * X_L)
            let B_L = -X_L / (R_L * R_L + X_L * X_L)
            for sign: Double in [+1, -1] {
                let Bp_target = sign * G_L * Q
                let B_p = Bp_target - B_L
                let denom = G_L * G_L + Bp_target * Bp_target
                let X_int = -Bp_target / denom
                let X_s = -X_int

                let shuntC: LComponent = B_p > 0 ? .C(B_p / omega) : .L(1 / (omega * abs(B_p)))
                let seriesC: LComponent = X_s > 0 ? .L(X_s / omega) : .C(1 / (omega * abs(X_s)))
                let isLP = shuntC.symbol == "C" && seriesC.symbol == "L"
                sols.append(LMatchSolution(
                    name: "Shunt-zuerst (\(isLP ? "Tiefpass" : (shuntC.symbol == "L" && seriesC.symbol == "C" ? "Hochpass" : "gemischt")))",
                    topology: "Shunt-\(shuntC.symbol) ‖ Last  →  Series-\(seriesC.symbol)  →  Quelle",
                    shuntFirst: true,
                    shuntComponent: shuntC,
                    seriesComponent: seriesC,
                    intermediateR: R_S,
                    intermediateX: X_int
                ))
            }
        }

        // Fall B: Series am Last-Ende, Shunt Richtung Quelle  (R_L < R_S)
        if R_L < R_S {
            let Q = sqrt(R_S / R_L - 1)
            for sign: Double in [+1, -1] {
                let X_s = -X_L + sign * R_L * Q
                let X_after = X_L + X_s
                let B_int = -X_after / (R_L * R_L + X_after * X_after)
                let B_p = -B_int

                let shuntC: LComponent = B_p > 0 ? .C(B_p / omega) : .L(1 / (omega * abs(B_p)))
                let seriesC: LComponent = X_s > 0 ? .L(X_s / omega) : .C(1 / (omega * abs(X_s)))
                let isLP = seriesC.symbol == "L" && shuntC.symbol == "C"
                sols.append(LMatchSolution(
                    name: "Series-zuerst (\(isLP ? "Tiefpass" : (seriesC.symbol == "C" && shuntC.symbol == "L" ? "Hochpass" : "gemischt")))",
                    topology: "Last  →  Series-\(seriesC.symbol)  →  Shunt-\(shuntC.symbol) ‖  →  Quelle",
                    shuntFirst: false,
                    shuntComponent: shuntC,
                    seriesComponent: seriesC,
                    intermediateR: R_L,
                    intermediateX: X_after
                ))
            }
        }

        return sols
    }

    // MARK: - L-Network Section

    private var lMatchBereich: some View {
        SectionCard(title: "L-Network Anpassung auf \(Int(z0)) Ω bei \(String(format: "%.3f", fVal)) MHz") {
            VStack(alignment: .leading, spacing: 12) {
                // Lösungs-Picker
                Picker("Lösung", selection: $selectedSolution) {
                    ForEach(Array(lMatchSolutions.enumerated()), id: \.offset) { idx, sol in
                        Text("Lösung \(idx + 1): \(sol.name)").tag(idx)
                    }
                }
                .pickerStyle(.segmented)

                if selectedSolution < lMatchSolutions.count {
                    let sol = lMatchSolutions[selectedSolution]
                    VStack(alignment: .leading, spacing: 6) {
                        ResultRow(label: "Topologie", value: sol.topology)
                        ResultRow(label: "Shunt-Komponente", value: "\(sol.shuntComponent.symbol) = \(sol.shuntComponent.displayValue)", highlight: true)
                        ResultRow(label: "Series-Komponente", value: "\(sol.seriesComponent.symbol) = \(sol.seriesComponent.displayValue)", highlight: true)
                        ResultRow(label: "Zwischen-Impedanz",
                                  value: String(format: "%.2f %@ %.2fj Ω", sol.intermediateR, sol.intermediateX >= 0 ? "+" : "−", abs(sol.intermediateX)))
                    }
                    Text("Pfad auf der Smith-Karte (oben): grüner Bogen = erste Komponente vom Last-Punkt, oranger Bogen = zweite Komponente bis zum Match.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Last-Impedanz") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    feld(label: "Frequenz", text: $freqMHz, suffix: "MHz", width: 110)
                    feld(label: "R (Resistanz)", text: $rText, suffix: "Ω", width: 110)
                    feld(label: "X (Reaktanz)",  text: $xText, suffix: "Ω", width: 110)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Z₀ (System)").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $z0) {
                            Text("50 Ω").tag(50.0)
                            Text("75 Ω").tag(75.0)
                            Text("300 Ω").tag(300.0)
                            Text("450 Ω").tag(450.0)
                            Text("600 Ω").tag(600.0)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 110)
                    }
                    Spacer()
                }
                HStack(spacing: 12) {
                    Toggle("VSWR-Kreis anzeigen",  isOn: $showVSWRCircle)
                    Toggle("Admittanz-Karte (Y)",  isOn: $showAdmittance)
                    Spacer()
                }
                Text("Hinweis: positives X = induktiv, negatives X = kapazitiv. Beispiel: Dipol-Resonanz: R≈73, X≈0. Kapazitive Last: X negativ.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func feld(label: String, text: Binding<String>, suffix: String, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: width)
                Text(suffix).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Smith-Chart Canvas

    private var smithChartBereich: some View {
        SectionCard(title: "Smith-Karte (Z-Karte, normiert auf \(Int(z0)) Ω)") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let margin: CGFloat = 24
                let R: CGFloat = (min(W, H) - 2 * margin) / 2
                let cx = W / 2
                let cy = H / 2

                // Helper: Γ-Coord (gx, gy) → Pixel
                func pt(_ gx: Double, _ gy: Double) -> CGPoint {
                    CGPoint(x: cx + CGFloat(gx) * R, y: cy - CGFloat(gy) * R)
                }

                // Einheitskreis (außen) als Clip-Pfad
                let unitRect = CGRect(x: cx - R, y: cy - R, width: 2 * R, height: 2 * R)
                let unitPath = Path(ellipseIn: unitRect)

                // Hintergrund Smith-Disk
                ctx.fill(unitPath, with: .color(Color(white: 0.96)))
                ctx.stroke(unitPath, with: .color(.gray.opacity(0.7)), lineWidth: 1.5)

                // Alles innerhalb des Einheitskreises clippen
                ctx.drawLayer { layer in
                    layer.clip(to: unitPath)

                    // ── Konstante-r-Kreise (Z-Karte, blau) ──
                    let rValues: [(r: Double, hi: Bool)] = [
                        (0.2, false), (0.5, false), (1.0, true), (2.0, false), (5.0, false)
                    ]
                    for (r, hi) in rValues {
                        let cxR = r / (r + 1)
                        let radR = 1 / (r + 1)
                        let pixCenter = pt(cxR, 0)
                        let pixR = CGFloat(radR) * R
                        let circle = Path(ellipseIn: CGRect(
                            x: pixCenter.x - pixR, y: pixCenter.y - pixR,
                            width: 2 * pixR, height: 2 * pixR))
                        layer.stroke(circle,
                            with: .color(hi ? Color.blue.opacity(0.9) : Color.blue.opacity(0.35)),
                            lineWidth: hi ? 1.3 : 0.8)
                    }

                    // ── Konstante-x-Bögen (Z-Karte, lila) ──
                    let xValues: [(x: Double, hi: Bool)] = [
                        (0.2, false), (0.5, false), (1.0, true), (2.0, false), (5.0, false)
                    ]
                    for (x, hi) in xValues {
                        for sign: Double in [+1, -1] {
                            let xs = x * sign
                            let cyX = 1.0 / xs
                            let radX = abs(1.0 / xs)
                            let pixCenter = pt(1.0, cyX)
                            let pixR = CGFloat(radX) * R
                            let circle = Path(ellipseIn: CGRect(
                                x: pixCenter.x - pixR, y: pixCenter.y - pixR,
                                width: 2 * pixR, height: 2 * pixR))
                            layer.stroke(circle,
                                with: .color(hi ? Color.purple.opacity(0.85) : Color.purple.opacity(0.30)),
                                lineWidth: hi ? 1.3 : 0.8)
                        }
                    }

                    // ── Optional: Admittanz-Karte (Y, gespiegelt = orange/gestrichelt) ──
                    if showAdmittance {
                        for (g, hi) in rValues {
                            let cxR = -g / (g + 1)
                            let radR = 1 / (g + 1)
                            let pixCenter = pt(cxR, 0)
                            let pixR = CGFloat(radR) * R
                            let circle = Path(ellipseIn: CGRect(
                                x: pixCenter.x - pixR, y: pixCenter.y - pixR,
                                width: 2 * pixR, height: 2 * pixR))
                            layer.stroke(circle,
                                with: .color(hi ? Color.orange.opacity(0.9) : Color.orange.opacity(0.35)),
                                style: StrokeStyle(lineWidth: hi ? 1.3 : 0.8, dash: [3, 3]))
                        }
                        for (b, hi) in xValues {
                            for sign: Double in [+1, -1] {
                                let bs = b * sign
                                let cyX = -1.0 / bs
                                let radX = abs(1.0 / bs)
                                let pixCenter = pt(-1.0, cyX)
                                let pixR = CGFloat(radX) * R
                                let circle = Path(ellipseIn: CGRect(
                                    x: pixCenter.x - pixR, y: pixCenter.y - pixR,
                                    width: 2 * pixR, height: 2 * pixR))
                                layer.stroke(circle,
                                    with: .color(hi ? Color.orange.opacity(0.85) : Color.orange.opacity(0.30)),
                                    style: StrokeStyle(lineWidth: hi ? 1.3 : 0.8, dash: [3, 3]))
                            }
                        }
                    }

                    // ── Reine-resistive Achse (x = 0) ──
                    layer.stroke(Path { p in
                        p.move(to: pt(-1, 0))
                        p.addLine(to: pt(1, 0))
                    }, with: .color(.gray.opacity(0.6)), lineWidth: 1)
                }

                // ── Mittelpunkt (Z₀ Match) ──
                let centerPx = pt(0, 0)
                ctx.fill(Path(ellipseIn: CGRect(x: centerPx.x - 4, y: centerPx.y - 4, width: 8, height: 8)),
                         with: .color(.green))
                ctx.draw(Text("\(Int(z0)) Ω").font(.system(size: 9, weight: .bold)).foregroundStyle(.green),
                         at: CGPoint(x: centerPx.x + 6, y: centerPx.y - 10), anchor: .leading)

                // ── Open / Short ──
                let openPx  = pt(1, 0)
                let shortPx = pt(-1, 0)
                ctx.draw(Text("OPEN (∞)").font(.system(size: 8)).foregroundStyle(.secondary),
                         at: CGPoint(x: openPx.x + 4, y: openPx.y + 8), anchor: .leading)
                ctx.draw(Text("SHORT (0 Ω)").font(.system(size: 8)).foregroundStyle(.secondary),
                         at: CGPoint(x: shortPx.x - 4, y: shortPx.y + 8), anchor: .trailing)

                // ── VSWR-Kreis (durch den Eingabepunkt) ──
                if showVSWRCircle && gammaMag > 0 && gammaMag < 1 {
                    let radSWR = CGFloat(gammaMag) * R
                    let circle = Path(ellipseIn: CGRect(
                        x: cx - radSWR, y: cy - radSWR,
                        width: 2 * radSWR, height: 2 * radSWR))
                    ctx.stroke(circle, with: .color(.red.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    ctx.draw(
                        Text(swr.isFinite ? String(format: "VSWR %.2f", swr) : "VSWR ∞")
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(.red),
                        at: CGPoint(x: cx, y: cy - radSWR - 8), anchor: .center)
                }

                // ── L-Network-Pfad zeichnen (wenn Lösung verfügbar) ──
                if !lMatchSolutions.isEmpty,
                   selectedSolution < lMatchSolutions.count,
                   let loadGamma = gammaCheck() {
                    let sol = lMatchSolutions[selectedSolution]
                    let intermediateGamma = zToGamma(r: sol.intermediateR, x: sol.intermediateX, z0: z0)
                    let matchGamma = (re: 0.0, im: 0.0)

                    // Pfad 1 (Last → Zwischen): grün — erste Komponente
                    drawArcPath(ctx: ctx, cx: cx, cy: cy, R: R,
                                from: loadGamma, to: intermediateGamma,
                                isShunt: sol.shuntFirst,
                                color: Color.green.opacity(0.85))
                    // Pfad 2 (Zwischen → Match): orange — zweite Komponente
                    drawArcPath(ctx: ctx, cx: cx, cy: cy, R: R,
                                from: intermediateGamma, to: matchGamma,
                                isShunt: !sol.shuntFirst,
                                color: Color.orange.opacity(0.9))

                    // Zwischen-Punkt als kleiner blauer Kreis
                    let ip = pt(intermediateGamma.re, intermediateGamma.im)
                    ctx.fill(Path(ellipseIn: CGRect(x: ip.x - 4, y: ip.y - 4, width: 8, height: 8)),
                             with: .color(.blue))
                    ctx.stroke(Path(ellipseIn: CGRect(x: ip.x - 4, y: ip.y - 4, width: 8, height: 8)),
                               with: .color(.white), lineWidth: 1)
                }

                // ── Eingabepunkt ──
                let g = gamma
                if abs(g.re) <= 1.05 && abs(g.im) <= 1.05 {
                    let px = pt(g.re, g.im)
                    ctx.fill(Path(ellipseIn: CGRect(x: px.x - 6, y: px.y - 6, width: 12, height: 12)),
                             with: .color(.red))
                    ctx.stroke(Path(ellipseIn: CGRect(x: px.x - 6, y: px.y - 6, width: 12, height: 12)),
                               with: .color(.white), lineWidth: 1.5)
                    let label = String(format: "%.0f%+.0fj Ω", rVal, xVal)
                    ctx.draw(Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(.red),
                             at: CGPoint(x: px.x + 9, y: px.y - 10), anchor: .leading)
                }

                // ── Legende unten ──
                let legY = H - 12
                ctx.draw(Text("─── R/Z₀ konstant   ─── X/Z₀ konstant   ● Last")
                            .font(.system(size: 9)).foregroundStyle(.secondary),
                         at: CGPoint(x: cx, y: legY), anchor: .center)
            }
            .frame(height: 480)
        }
    }

    // MARK: - Ergebnisse

    private var ergebnisBereich: some View {
        SectionCard(title: "Berechnete Werte") {
            VStack(spacing: 4) {
                ResultRow(label: "Z (Last)",
                          value: String(format: "%.2f %@ %.2fj  Ω", rVal, xVal >= 0 ? "+" : "−", abs(xVal)))
                ResultRow(label: "z (normiert)",
                          value: String(format: "%.3f %@ %.3fj", zN.re, zN.im >= 0 ? "+" : "−", abs(zN.im)))
                ResultRow(label: "Γ (Reflexionsfaktor)",
                          value: String(format: "%.3f %@ %.3fj", gamma.re, gamma.im >= 0 ? "+" : "−", abs(gamma.im)))
                ResultRow(label: "|Γ|",
                          value: String(format: "%.4f", gammaMag),
                          highlight: true)
                ResultRow(label: "∠Γ",
                          value: String(format: "%.1f °", gammaDeg))
                ResultRow(label: "VSWR",
                          value: swr.isFinite ? String(format: "%.3f : 1", swr) : "∞ : 1",
                          highlight: true)
                ResultRow(label: "Return Loss",
                          value: returnLossDB.isFinite ? String(format: "%.2f dB", returnLossDB) : "∞ dB")
                ResultRow(label: "Mismatch Loss",
                          value: mismatchLossDB.isFinite ? String(format: "%.3f dB", mismatchLossDB) : "∞ dB")
                ResultRow(label: "Y (Admittanz)",
                          value: String(format: "%.2f %@ %.2fj  mS", admittance.g_mS, admittance.b_mS >= 0 ? "+" : "−", abs(admittance.b_mS)))
                if fVal > 0 {
                    let omega = 2 * .pi * fVal * 1e6
                    if xVal > 0 {
                        let L_uH = xVal / omega * 1e6
                        ResultRow(label: "Äquivalent (Serie)",
                                  value: String(format: "L = %.3f µH (induktiv)", L_uH))
                    } else if xVal < 0 {
                        let C_pF = -1.0 / (omega * xVal) * 1e12
                        ResultRow(label: "Äquivalent (Serie)",
                                  value: String(format: "C = %.2f pF (kapazitiv)", C_pF))
                    } else {
                        ResultRow(label: "Reaktanz", value: "0 (rein resistiv → Resonanz)")
                    }
                }
            }
        }
    }

    // MARK: - Helper für Smith-Pfad

    private func gammaCheck() -> (re: Double, im: Double)? {
        let g = gamma
        if abs(g.re) > 1.05 || abs(g.im) > 1.05 { return nil }
        return g
    }

    private func zToGamma(r: Double, x: Double, z0: Double) -> (re: Double, im: Double) {
        let num_re = r - z0
        let num_im = x
        let den_re = r + z0
        let den_im = x
        let mag2 = den_re * den_re + den_im * den_im
        if mag2 == 0 { return (0, 0) }
        return (
            (num_re * den_re + num_im * den_im) / mag2,
            (num_im * den_re - num_re * den_im) / mag2
        )
    }

    /// Zeichnet einen Bogen auf der Smith-Karte vom Punkt `from` zu `to` entlang
    /// eines konstanten-R-Kreises (Series-Komp.) oder konstanten-G-Kreises (Shunt).
    /// `from`, `to` sind Γ-Koordinaten. cx/cy/R sind die Pixel-Center und Radius der Smith-Karte.
    private func drawArcPath(
        ctx: GraphicsContext,
        cx: CGFloat, cy: CGFloat, R: CGFloat,
        from: (re: Double, im: Double),
        to:   (re: Double, im: Double),
        isShunt: Bool,
        color: Color
    ) {
        // Zurückrechnen von Γ → Z am Startpunkt
        let num_re = 1 + from.re,  num_im =  from.im
        let den_re = 1 - from.re,  den_im = -from.im
        let mag2 = den_re * den_re + den_im * den_im
        guard mag2 > 0 else { return }
        let z_re = (num_re * den_re + num_im * den_im) / mag2 * z0
        let z_im = (num_im * den_re - num_re * den_im) / mag2 * z0

        // Center + Radius im Γ-Bereich
        let centerGx: Double
        let radius: Double
        if isShunt {
            let denom = z_re * z_re + z_im * z_im
            guard denom > 0 else { return }
            let g_norm = (z_re / denom) * z0
            centerGx = -g_norm / (g_norm + 1)
            radius   =  1.0 / (g_norm + 1)
        } else {
            let r_norm = z_re / z0
            guard r_norm >= 0 else { return }
            centerGx = r_norm / (r_norm + 1)
            radius   = 1.0 / (r_norm + 1)
        }

        // Winkel vom Center zu from und to
        let a1 = atan2(from.im,  from.re - centerGx)
        let a2 = atan2(to.im,    to.re   - centerGx)
        var diff = a2 - a1
        while diff >  .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }

        // Bogen mit 64 Segmenten parametrisieren
        var path = Path()
        let steps = 64
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let angle = a1 + diff * t
            let gx = centerGx + radius * cos(angle)
            let gy = radius * sin(angle)
            let px = CGPoint(x: cx + CGFloat(gx) * R, y: cy - CGFloat(gy) * R)
            if i == 0 { path.move(to: px) } else { path.addLine(to: px) }
        }
        ctx.stroke(path, with: .color(color),
                   style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    // MARK: - Hinweise

    private var hinweisBereich: some View {
        SectionCard(title: "Lese-Hilfe") {
            VStack(alignment: .leading, spacing: 6) {
                Text("• **Mitte (grüner Punkt)** = Z₀ Match, perfekt angepasst (VSWR 1:1).")
                Text("• **Rechter Rand (1, 0)** = Open (Leerlauf, ∞ Ω).")
                Text("• **Linker Rand (−1, 0)** = Short (Kurzschluss, 0 Ω).")
                Text("• **Obere Halbebene** = induktive Last (X > 0).")
                Text("• **Untere Halbebene** = kapazitive Last (X < 0).")
                Text("• **Roter VSWR-Kreis** = alle Impedanzen mit gleichem VSWR wie die Last.")
                Text("• **R-Kreise (blau)** = konstanter Real-Anteil. **X-Bögen (lila)** = konstanter Imaginär-Anteil.")
                Text("• **Admittanz-Karte (orange, gestrichelt)** = gespiegelte Y-Karte für Parallel-Komponenten.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}
