import SwiftUI

// MARK: - Model

private struct VerlaengerungErgebnis {
    let target: Double      // λ/4 in m
    let diff: Double        // fehlende Länge m
    let z0: Double          // Strahlerwellenwiderstand Ω
    let G_deg: Double       // elektrische Länge Grad
    let Xa: Double          // Blindwiderstand Ω
    let L_uH: Double        // benötigte Induktivität µH
    let windungen: Int
    let windungenRoh: Double
    let coilLen_mm: Double
    let wireLen_m: Double
    let outerD_mm: Double

    static func berechne(f: Double, h: Double, D: Double, dw: Double, isVertikal: Bool) -> VerlaengerungErgebnis? {
        guard f > 0, h > 0, D > 0, dw > 0 else { return nil }
        let lambda = 300.0 / f
        let target = 71.25 / f   // λ/4 mit VF = 0.95
        guard h < target * 0.98 else { return nil }

        let wireDiam_m = dw / 1000.0
        let z0  = 60.0 * (log(2.0 * h / wireDiam_m) - 1.0)
        let G   = 360.0 * h / lambda
        let Xa  = -z0 / tan(G * .pi / 180.0)
        let XL  = abs(Xa)
        let L_uH = XL / (2.0 * .pi * f)  // f in MHz → L in µH

        let r_inch = (D / 2.0) / 25.4
        let n_raw  = wheeler(L_uH: L_uH, r_inch: r_inch, dw_mm: dw)
        guard n_raw > 0 else { return nil }
        let n      = Int(ceil(n_raw))
        let coilLen = Double(n) * dw
        let meanCirc = .pi * D
        let wireLen  = Double(n) * sqrt(meanCirc * meanCirc + dw * dw) / 1000.0
        let diff = target - h

        return VerlaengerungErgebnis(
            target: target, diff: diff, z0: z0, G_deg: G, Xa: Xa, L_uH: L_uH,
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

struct VerlaengerungView: View {
    @State private var freqText  = "7.1"
    @State private var lenText   = "8.0"
    @State private var coilDText = "50.0"
    @State private var wireDText = "1.5"
    @State private var isVertikal = true

    private var f:  Double { Double(freqText.replacingOccurrences(of: ",", with: "."))  ?? 0 }
    private var h:  Double { Double(lenText.replacingOccurrences(of: ",", with: "."))   ?? 0 }
    private var D:  Double { Double(coilDText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var dw: Double { Double(wireDText.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    private var target: Double { f > 0 ? 71.25 / f : 0 }
    private var ergebnis: VerlaengerungErgebnis? { VerlaengerungErgebnis.berechne(f: f, h: h, D: D, dw: dw, isVertikal: isVertikal) }

    private let bands: [(String, Double)] = [
        ("80m", 3.65), ("40m", 7.1), ("30m", 10.125), ("20m", 14.175),
        ("17m", 18.118), ("15m", 21.225), ("12m", 24.94), ("10m", 28.5)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if f > 0 && h > 0 && D > 0 && dw > 0 {
                    if h >= target * 0.98 {
                        keineSpuleHinweis
                    } else if let r = ergebnis {
                        ergebnisBereich(r)
                        skizzeBereich(r)
                    }
                }
                infoBereich
                RechnerBeschreibung(resourceName: "strahlerverl")
            }
            .padding(24)
        }
        .navigationTitle("Strahler-Verlängerung")
    }

    // MARK: Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Eingabe") {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Antennentyp", selection: $isVertikal) {
                    Text("λ/4 Vertikal").tag(true)
                    Text("λ/2 Dipol (pro Schenkel)").tag(false)
                }
                .pickerStyle(.segmented)
                Text(isVertikal
                     ? "Zielgröße λ/4 – Spule am Fuß oder im Strahler"
                     : "Zielgröße λ/4 pro Schenkel – 2× berechnen für Dipol")
                .font(.caption2).foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Band-Schnellwahl").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 6) {
                        ForEach(bands, id: \.0) { name, freq in
                            Button(name) {
                                freqText = String(freq)
                                lenText  = String(format: "%.1f", (71.25 / freq) * 0.65)
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
                    fieldBox(label: "Strahler-Länge h", text: $lenText, unit: "m",
                             hint: "Muss kürzer als λ/4 sein")
                }
                HStack(spacing: 16) {
                    fieldBox(label: "Spulen-Ø D", text: $coilDText, unit: "mm")
                    fieldBox(label: "Draht-Ø dw", text: $wireDText, unit: "mm")
                }
                if f > 0 {
                    Text("λ/4 Referenz: \(String(format: "%.3f", target)) m")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func fieldBox(label: String, text: Binding<String>, unit: String, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("0", text: text).textFieldStyle(.roundedBorder)
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
                Text("Keine Verlängerungsspule nötig").fontWeight(.semibold)
                Text("Die Antenne (\(String(format: "%.2f", h)) m) ist bereits lang genug für λ/4 (\(String(format: "%.3f", target)) m).")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Ergebnis

    private func ergebnisBereich(_ r: VerlaengerungErgebnis) -> some View {
        VStack(spacing: 16) {
            SectionCard(title: "Ergebnis") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    KenngroesseKachel(wert: "\(r.windungen)", label: "Windungen", hervorheben: true, farbe: .accentColor)
                    KenngroesseKachel(wert: String(format: "%.2f µH", r.L_uH), label: "Induktivität")
                    KenngroesseKachel(wert: String(format: "%.1f mm", r.coilLen_mm), label: "Wickellänge")
                    KenngroesseKachel(wert: String(format: "%.2f m", r.wireLen_m), label: "Drahtlänge")
                    KenngroesseKachel(wert: String(format: "%.1f mm", r.outerD_mm), label: "Außen-Ø")
                    KenngroesseKachel(wert: String(format: "%.1f Ω", r.Xa), label: "Blindwiderstand Xa")
                }
            }
            SectionCard(title: "Zwischenwerte") {
                VStack(spacing: 4) {
                    ResultRow(label: "Zielgröße λ/4", value: String(format: "%.3f m", r.target))
                    ResultRow(label: "Fehlende Länge", value: String(format: "%.3f m", r.diff))
                    ResultRow(label: "Wellenwiderstand Z₀", value: String(format: "%.1f Ω", r.z0))
                    ResultRow(label: "Elektrische Länge G", value: String(format: "%.1f°", r.G_deg))
                    ResultRow(label: "Blindwiderstand Xa", value: String(format: "%.2f Ω", r.Xa))
                    ResultRow(label: "Benötigtes XL", value: String(format: "%.2f Ω", abs(r.Xa)))
                    ResultRow(label: "Induktivität L", value: String(format: "%.3f µH", r.L_uH), highlight: true)
                    ResultRow(label: "Windungen (roh)", value: String(format: "%.2f", r.windungenRoh))
                    ResultRow(label: "Windungen N", value: "\(r.windungen)", highlight: true)
                    ResultRow(label: "Wickellänge", value: String(format: "%.1f mm", r.coilLen_mm))
                }
            }
        }
    }

    // MARK: Skizze

    private func skizzeBereich(_ r: VerlaengerungErgebnis) -> some View {
        SectionCard(title: "Skizze") {
            if isVertikal {
                Canvas { ctx, size in
                    let W = size.width, H = size.height
                    let cx = W / 2
                    let groundY: CGFloat = H - 30
                    let topMargin: CGFloat = 30
                    // Coil: fixed height so it's clearly visible
                    let coilH: CGFloat = max(60, min(100, CGFloat(r.windungen) * 6))
                    let spuleBot = groundY
                    let spuleTop = spuleBot - coilH
                    // Remaining space for wire above coil
                    let availWire = spuleTop - topMargin
                    let hPx = min(availWire - 10, availWire * 0.95)
                    let drahtTop = spuleTop - hPx

                    // Spule (Sinuskurve vertikal)
                    let nVis = min(r.windungen, 14)
                    let stepH = coilH / CGFloat(nVis)
                    let amp: CGFloat = 22
                    var path = Path()
                    path.move(to: CGPoint(x: cx, y: spuleBot))
                    for i in 0..<nVis {
                        let y1 = spuleBot - CGFloat(i) * stepH
                        let y3 = spuleBot - CGFloat(i + 1) * stepH
                        path.addCurve(to: CGPoint(x: cx, y: y3),
                                      control1: CGPoint(x: cx + amp, y: y1),
                                      control2: CGPoint(x: cx + amp, y: y3))
                    }
                    // Spulen-Umrandung
                    ctx.stroke(Path { p in
                        p.addRoundedRect(in: CGRect(x: cx - amp - 4, y: spuleTop, width: amp * 2 + 8, height: coilH), cornerSize: CGSize(width: 4, height: 4))
                    }, with: .color(.orange.opacity(0.3)), lineWidth: 1)
                    ctx.stroke(path, with: .color(.orange), lineWidth: 2.5)

                    // Draht oben
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: cx, y: spuleTop))
                        p.addLine(to: CGPoint(x: cx, y: drahtTop))
                    }, with: .color(Color(red: 0.6, green: 0.2, blue: 0.8)), lineWidth: 4)

                    // Pfeilspitze oben
                    ctx.fill(Path { p in
                        p.move(to: CGPoint(x: cx, y: drahtTop - 8))
                        p.addLine(to: CGPoint(x: cx - 6, y: drahtTop + 4))
                        p.addLine(to: CGPoint(x: cx + 6, y: drahtTop + 4))
                        p.closeSubpath()
                    }, with: .color(Color(red: 0.6, green: 0.2, blue: 0.8)))

                    // Erde
                    for i in 0..<4 {
                        let len: CGFloat = CGFloat(20 - i * 4)
                        ctx.stroke(Path { p in
                            p.move(to: CGPoint(x: cx - len, y: groundY + CGFloat(i) * 5))
                            p.addLine(to: CGPoint(x: cx + len, y: groundY + CGFloat(i) * 5))
                        }, with: .color(.secondary), lineWidth: i == 0 ? 2.5 : 1)
                    }

                    // Speisepunkt
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - 6, y: spuleBot - 6, width: 12, height: 12)), with: .color(.accentColor))

                    // Masse-Bemaßung (Pfeil rechts)
                    let arrX = cx + amp + 20
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: arrX, y: spuleTop))
                        p.addLine(to: CGPoint(x: arrX, y: drahtTop))
                    }, with: .color(.secondary.opacity(0.5)), lineWidth: 1)
                    ctx.draw(Text(String(format: "  %.2f m", h)).font(.system(size: 12)).bold(),
                             at: CGPoint(x: arrX + 4, y: (spuleTop + drahtTop) / 2), anchor: .leading)

                    // Labels
                    ctx.draw(Text("\(r.windungen) Wdg.").font(.system(size: 12)).foregroundStyle(.orange).bold(),
                             at: CGPoint(x: cx - amp - 12, y: (spuleTop + spuleBot) / 2), anchor: .trailing)
                    ctx.draw(Text("Speisepunkt").font(.system(size: 11)).foregroundStyle(Color.accentColor),
                             at: CGPoint(x: cx + 12, y: spuleBot), anchor: .leading)
                    ctx.draw(Text("Erde").font(.system(size: 11)).foregroundStyle(.secondary),
                             at: CGPoint(x: cx + 12, y: groundY + 2), anchor: .leading)
                    ctx.draw(Text("λ/4 Vertikal mit Verlängerungsspule").font(.system(size: 11)).foregroundStyle(.secondary),
                             at: CGPoint(x: W / 2, y: H - 8), anchor: .center)
                }
                .frame(height: 280)
            } else {
                Canvas { ctx, size in
                    let W = size.width, H = size.height
                    let cy = H / 2
                    let feedX = W / 2
                    let availW = (W / 2 - 60)
                    let scale = availW / CGFloat(r.target)
                    let hPx = CGFloat(h) * scale
                    let coilW: CGFloat = max(40, min(70, CGFloat(r.windungen) * 4))
                    let coilStartX = feedX + hPx
                    let amp: CGFloat = 14

                    // Linker Schenkel
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: feedX - hPx, y: cy))
                        p.addLine(to: CGPoint(x: feedX, y: cy))
                    }, with: .color(Color(red: 0.6, green: 0.2, blue: 0.8)), lineWidth: 4)

                    // Rechter Schenkel
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: feedX, y: cy))
                        p.addLine(to: CGPoint(x: coilStartX, y: cy))
                    }, with: .color(Color(red: 0.6, green: 0.2, blue: 0.8)), lineWidth: 4)

                    // Spule rechts (Sinus horizontal)
                    let nVis = min(r.windungen, 12)
                    let stepW = coilW / CGFloat(nVis)
                    var path = Path()
                    path.move(to: CGPoint(x: coilStartX, y: cy))
                    for i in 0..<nVis {
                        let x1 = coilStartX + CGFloat(i) * stepW
                        let x3 = coilStartX + CGFloat(i + 1) * stepW
                        path.addCurve(to: CGPoint(x: x3, y: cy),
                                      control1: CGPoint(x: x1, y: cy - amp * 2),
                                      control2: CGPoint(x: x3, y: cy - amp * 2))
                    }
                    ctx.stroke(Path { p in
                        p.addRoundedRect(in: CGRect(x: coilStartX - 2, y: cy - amp * 2 - 4, width: coilW + 4, height: amp * 2 + 8), cornerSize: CGSize(width: 4, height: 4))
                    }, with: .color(.orange.opacity(0.3)), lineWidth: 1)
                    ctx.stroke(path, with: .color(.orange), lineWidth: 2.5)

                    // Speisepunkt
                    ctx.fill(Path(ellipseIn: CGRect(x: feedX - 6, y: cy - 6, width: 12, height: 12)), with: .color(.accentColor))

                    // Labels
                    ctx.draw(Text("50Ω").font(.system(size: 11)).foregroundStyle(Color.accentColor),
                             at: CGPoint(x: feedX, y: cy + 18), anchor: .center)
                    ctx.draw(Text("\(r.windungen) Wdg.").font(.system(size: 12)).foregroundStyle(.orange).bold(),
                             at: CGPoint(x: coilStartX + coilW / 2, y: cy - amp * 2 - 12), anchor: .center)
                    ctx.draw(Text(String(format: "← %.2f m →", h)).font(.system(size: 11)).foregroundStyle(.secondary),
                             at: CGPoint(x: feedX / 2 + (feedX - hPx) / 2, y: cy - 18), anchor: .center)
                    ctx.draw(Text("λ/2 Dipol – ein Schenkel").font(.system(size: 11)).foregroundStyle(.secondary),
                             at: CGPoint(x: W / 2, y: H - 8), anchor: .center)
                }
                .frame(height: 120)
            }
        }
    }

    // MARK: Info

    private var infoBereich: some View {
        SectionCard(title: "Formeln") {
            VStack(spacing: 4) {
                ResultRow(label: "Wellenwiderstand Z₀", value: "60 × (ln(2h/d) – 1)")
                ResultRow(label: "Elektr. Länge G", value: "360 × h / λ")
                ResultRow(label: "Blindwiderstand Xa", value: "–Z₀ / tan(G°)")
                ResultRow(label: "Induktivität L", value: "Xa / (2π × f)")
                ResultRow(label: "Windungen N", value: "Wheeler-Formel (einlagige Luftspule)")
            }
        }
    }
}
