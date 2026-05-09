import SwiftUI

// MARK: - Model

private struct EFHWErgebnis {
    let fullLen: Double       // λ/2 in m
    let diff: Double          // fehlende Länge m
    let L_uH: Double          // Induktivität µH
    let windungen: Int
    let windungenRoh: Double
    let coilLen_mm: Double    // Wickellänge mm
    let wireLen_m: Double     // Drahtlänge m
    let outerD_mm: Double     // Außen-Ø mm

    static func berechne(f: Double, h: Double, D: Double, dw: Double) -> EFHWErgebnis? {
        guard f > 0, h > 0, D > 0, dw > 0 else { return nil }
        let fullLen = 142.5 / f
        guard h < fullLen else { return nil }
        let diff   = fullLen - h
        let L_uH   = diff * 2.5
        let r_inch = (D / 2.0) / 25.4
        let n_raw  = wheeler(L_uH: L_uH, r_inch: r_inch, dw_mm: dw)
        guard n_raw > 0 else { return nil }
        let n      = Int(ceil(n_raw))
        let coilLen = Double(n) * dw
        let meanCirc = .pi * D
        let wireLen  = Double(n) * sqrt(meanCirc * meanCirc + dw * dw) / 1000.0
        return EFHWErgebnis(
            fullLen: fullLen, diff: diff, L_uH: L_uH,
            windungen: n, windungenRoh: n_raw,
            coilLen_mm: coilLen, wireLen_m: wireLen, outerD_mm: D + 2 * dw
        )
    }

    private static func wheeler(L_uH: Double, r_inch: Double, dw_mm: Double) -> Double {
        let pitch = dw_mm / 25.4
        var n = 10.0, np = 0.0
        for _ in 0..<80 {
            let l_inch = n * pitch
            n = sqrt(L_uH * (9 * r_inch + 10 * l_inch)) / r_inch
            if abs(n - np) < 0.0001 { break }
            np = n
        }
        return n
    }
}

// MARK: - View

struct EFHWVerkuerzungView: View {
    @State private var freqText  = "7.1"
    @State private var lenText   = "15.0"
    @State private var coilDText = "50.0"
    @State private var wireDText = "1.5"
    @State private var posMitte  = true

    private var f:  Double { Double(freqText.replacingOccurrences(of: ",", with: "."))  ?? 0 }
    private var h:  Double { Double(lenText.replacingOccurrences(of: ",", with: "."))   ?? 0 }
    private var D:  Double { Double(coilDText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var dw: Double { Double(wireDText.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    private var fullLen: Double { f > 0 ? 142.5 / f : 0 }
    private var ergebnis: EFHWErgebnis? { EFHWErgebnis.berechne(f: f, h: h, D: D, dw: dw) }

    private let bands: [(String, Double)] = [
        ("80m", 3.65), ("40m", 7.1), ("30m", 10.125), ("20m", 14.175),
        ("17m", 18.118), ("15m", 21.225), ("12m", 24.94), ("10m", 28.5)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if f > 0 && h > 0 && D > 0 && dw > 0 {
                    if h >= fullLen {
                        keineSpuleHinweis
                    } else if let r = ergebnis {
                        ergebnisBereich(r)
                        skizzeBereich(r)
                    }
                }
                infoBereich
            }
            .padding(24)
        }
        .navigationTitle("EFHW-Verkürzung")
    }

    // MARK: Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Eingabe") {
            VStack(alignment: .leading, spacing: 14) {
                // Band-Presets
                VStack(alignment: .leading, spacing: 6) {
                    Text("Band-Schnellwahl").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 6) {
                        ForEach(bands, id: \.0) { name, freq in
                            Button(name) {
                                freqText = String(freq)
                                lenText  = String(format: "%.1f", (142.5 / freq) * 0.7)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(abs(f - freq) < 0.5 ? .accentColor : nil)
                        }
                    }
                }
                Divider()
                HStack(spacing: 16) {
                    fieldBox(label: "Frequenz", text: $freqText, unit: "MHz")
                    fieldBox(label: "Antennenlänge h", text: $lenText, unit: "m",
                             hint: "Muss kürzer als λ/2 sein")
                }
                HStack(spacing: 16) {
                    fieldBox(label: "Spulen-Ø D", text: $coilDText, unit: "mm")
                    fieldBox(label: "Draht-Ø dw", text: $wireDText, unit: "mm")
                }
                // λ/2 Referenz
                if f > 0 {
                    Text("λ/2 Referenz: \(String(format: "%.3f", fullLen)) m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Position
                VStack(alignment: .leading, spacing: 6) {
                    Text("Spulenposition").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $posMitte) {
                        Text("Mitte des Strahlers").tag(true)
                        Text("Ende des Strahlers").tag(false)
                    }
                    .pickerStyle(.segmented)
                    Text(posMitte
                         ? "Spule teilt den Strahler in zwei gleiche Hälften"
                         : "Spule am freien Ende des Strahlers")
                    .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func fieldBox(label: String, text: Binding<String>, unit: String, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("0", text: text)
                    .textFieldStyle(.roundedBorder)
                Text(unit).foregroundStyle(.secondary).font(.caption)
            }
            if let hint {
                Text(hint).font(.caption2).foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Warnung

    private var keineSpuleHinweis: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Keine Spule nötig").fontWeight(.semibold)
                Text("Die Antenne (\(String(format: "%.2f", h)) m) ist bereits lang genug für λ/2 (\(String(format: "%.3f", fullLen)) m).")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Ergebnis

    private func ergebnisBereich(_ r: EFHWErgebnis) -> some View {
        VStack(spacing: 16) {
            SectionCard(title: "Ergebnis") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    KenngroesseKachel(wert: "\(r.windungen)", label: "Windungen", hervorheben: true, farbe: .accentColor)
                    KenngroesseKachel(wert: String(format: "%.1f µH", r.L_uH), label: "Induktivität")
                    KenngroesseKachel(wert: String(format: "%.1f mm", r.coilLen_mm), label: "Wickellänge")
                    KenngroesseKachel(wert: String(format: "%.2f m", r.wireLen_m), label: "Drahtlänge")
                    KenngroesseKachel(wert: String(format: "%.1f mm", r.outerD_mm), label: "Außen-Ø")
                    KenngroesseKachel(wert: String(format: "%.3f m", r.diff), label: "Fehlende Länge")
                }
            }
            SectionCard(title: "Details") {
                VStack(spacing: 4) {
                    ResultRow(label: "Volle λ/2 Länge", value: String(format: "%.3f m", r.fullLen))
                    ResultRow(label: "Antennenlänge h", value: String(format: "%.3f m", h))
                    ResultRow(label: "Fehlende Länge", value: String(format: "%.3f m", r.diff))
                    ResultRow(label: "Benötigte Induktivität", value: String(format: "%.2f µH", r.L_uH))
                    ResultRow(label: "Windungen (roh)", value: String(format: "%.2f", r.windungenRoh))
                    ResultRow(label: "Windungen (aufgerundet)", value: "\(r.windungen)", highlight: true)
                    ResultRow(label: "Wickellänge", value: String(format: "%.1f mm", r.coilLen_mm))
                    ResultRow(label: "Drahtlänge gesamt", value: String(format: "%.2f m", r.wireLen_m))
                    ResultRow(label: "Spulen-Außen-Ø", value: String(format: "%.1f mm", r.outerD_mm))
                }
            }
        }
    }

    // MARK: Skizze

    private func skizzeBereich(_ r: EFHWErgebnis) -> some View {
        SectionCard(title: "Skizze") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let cy = H / 2
                let marginL: CGFloat = 30, marginR: CGFloat = 30
                let availW = W - marginL - marginR
                let scale = availW / CGFloat(r.fullLen)
                let hPx = CGFloat(h) * scale
                let coilWpx: CGFloat = max(48, min(100, CGFloat(r.windungen) * 5))
                let coilX: CGFloat = posMitte ? marginL + hPx / 2 : marginL + hPx
                let wireStartX = marginL
                let antennaEndX = marginL + hPx
                let afterCoilX  = coilX + coilWpx
                let coilCenterX = coilX + coilWpx / 2
                let amp: CGFloat = 20

                // Segment 1: Anfang → Spule
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: wireStartX, y: cy))
                    p.addLine(to: CGPoint(x: coilX, y: cy))
                }, with: .color(.purple), lineWidth: 3)

                // Spulen-Symbol (Kurven-Bögen nach oben)
                let nVis = min(r.windungen, 16)
                let step = coilWpx / CGFloat(nVis)
                var spulePath = Path()
                spulePath.move(to: CGPoint(x: coilX, y: cy))
                for i in 0..<nVis {
                    let x1 = coilX + CGFloat(i) * step
                    let x3 = coilX + CGFloat(i + 1) * step
                    spulePath.addCurve(to: CGPoint(x: x3, y: cy),
                                       control1: CGPoint(x: x1, y: cy - amp),
                                       control2: CGPoint(x: x3, y: cy - amp))
                }
                ctx.stroke(Path { p in
                    p.addRoundedRect(in: CGRect(x: coilX - 2, y: cy - amp - 4, width: coilWpx + 4, height: amp + 8),
                                     cornerSize: CGSize(width: 4, height: 4))
                }, with: .color(.orange.opacity(0.3)), lineWidth: 1)
                ctx.stroke(spulePath, with: .color(.orange), lineWidth: 2.5)

                // Segment 2: Spule → Ende
                if afterCoilX < W - marginR {
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: afterCoilX, y: cy))
                        p.addLine(to: CGPoint(x: antennaEndX, y: cy))
                    }, with: .color(.purple), lineWidth: 3)
                }

                // Speisepunkt-Dot
                ctx.fill(Path(ellipseIn: CGRect(x: wireStartX - 5, y: cy - 5, width: 10, height: 10)), with: .color(.accentColor))

                // Labels – alle klar getrennt von Spule und Draht
                // 1) "50Ω" unterhalb des Feed-Dots
                ctx.draw(Text("50Ω").font(.system(size: 11)).bold().foregroundStyle(Color.accentColor),
                         at: CGPoint(x: wireStartX, y: cy + 22), anchor: .center)

                // 2) Windungen + Induktivität ÜBER der Spulen-Box (genug Abstand)
                ctx.draw(Text(String(format: "%d Wdg.  %.2f µH", r.windungen, r.L_uH))
                             .font(.system(size: 11)).bold().foregroundStyle(.orange),
                         at: CGPoint(x: coilCenterX, y: cy - amp - 22), anchor: .center)

                // 3) Bemaßungslinie für h, weit über der Spule
                let dimY: CGFloat = cy - amp - 46
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: wireStartX, y: dimY))
                    p.addLine(to: CGPoint(x: antennaEndX, y: dimY))
                }, with: .color(.secondary.opacity(0.45)), lineWidth: 1)
                for tickX in [wireStartX, antennaEndX] {
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: tickX, y: dimY - 4))
                        p.addLine(to: CGPoint(x: tickX, y: dimY + 4))
                    }, with: .color(.secondary.opacity(0.45)), lineWidth: 1)
                }
                ctx.draw(Text(String(format: "h = %.3f m", h)).font(.system(size: 11)).foregroundStyle(.secondary),
                         at: CGPoint(x: (wireStartX + antennaEndX) / 2, y: dimY - 14), anchor: .center)

                // 4) λ/2-Referenz ganz unten
                ctx.draw(Text(String(format: "λ/2 = %.3f m", r.fullLen)).font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: W / 2, y: H - 6), anchor: .center)
            }
            .frame(height: 200)
        }
    }

    // MARK: Info

    private var infoBereich: some View {
        SectionCard(title: "Hinweis") {
            Text("Berechnung nach Wheeler-Formel für einlagige Luftspulen. Die benötigte Induktivität ist eine Praxisnäherung (fehlende Länge × 2,5). Eng gewickelt (kein Windungsabstand). Tatsächliche Werte je nach Kern, Drahtmaterial und Wickelqualität variieren.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
