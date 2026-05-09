import SwiftUI

// MARK: - Model

enum AntennenTyp: String, CaseIterable, Identifiable {
    case dipol    = "Halbwellen-Dipol (λ/2)"
    case gp       = "Groundplane (λ/4)"
    case jpole    = "J-Pole"
    case moxon    = "Moxon Rectangle"
    case sperrtopf = "Sperrtopf"
    case slimjim  = "Slim Jim / Zepp"
    case efhw     = "EFHW (Endfed)"
    case vertikal = "Vertikal mit Verlängerungsspule"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dipol: return "antenna.radiowaves.left.and.right"
        case .gp: return "arrow.up.to.line"
        case .jpole: return "j.square"
        case .moxon: return "rectangle"
        case .sperrtopf: return "cylinder"
        case .slimjim: return "s.square"
        case .efhw: return "arrow.right.to.line.alt"
        case .vertikal: return "arrow.up.square"
        }
    }
}

struct AntennenErgebnis {
    let typ: AntennenTyp
    let f: Double       // MHz
    let vf: Double      // Verkürzungsfaktor
    let lambda: Double  // m
    let lhalf: Double   // λ/2 m
    let lquart: Double  // λ/4 m
    var werte: [(label: String, value: String, highlight: Bool)] = []
    var hinweis: String = ""
}

// MARK: - View

struct AntennenDesignerView: View {
    @State private var selectedTyp: AntennenTyp = .dipol
    @State private var freqText = "14.175"
    @State private var vfText   = "0.95"
    @State private var antennaLenText = "8.0"  // für vertikal: aktuelle Länge

    private var f:  Double { Double(freqText.replacingOccurrences(of: ",", with: "."))       ?? 14.175 }
    private var vf: Double { Double(vfText.replacingOccurrences(of: ",", with: "."))         ?? 0.95 }
    private var antennaLen: Double { Double(antennaLenText.replacingOccurrences(of: ",", with: ".")) ?? 8.0 }

    private var ergebnis: AntennenErgebnis? { berechne() }

    private let bands: [(String, Double)] = [
        ("160m", 1.85), ("80m", 3.65), ("40m", 7.1), ("30m", 10.125),
        ("20m", 14.175), ("17m", 18.118), ("15m", 21.225), ("12m", 24.94),
        ("10m", 28.5), ("6m", 50.15), ("2m", 145.0), ("70cm", 432.0)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                typWahl
                eingabeBereich
                if let r = ergebnis {
                    ergebnisBereich(r)
                    skizzeBereich(r)
                    if !r.hinweis.isEmpty { hinweisBox(r.hinweis) }
                }
            }
            .padding(24)
        }
        .navigationTitle("Antennen-Designer")
    }

    // MARK: Typ-Wahl

    private var typWahl: some View {
        SectionCard(title: "Antennen-Typ") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(AntennenTyp.allCases) { typ in
                    Button {
                        selectedTyp = typ
                    } label: {
                        Label(typ.rawValue, systemImage: typ.icon)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedTyp == typ ? .accentColor : nil)
                }
            }
        }
    }

    // MARK: Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Parameter") {
            VStack(alignment: .leading, spacing: 14) {
                // Band-Schnellwahl
                VStack(alignment: .leading, spacing: 6) {
                    Text("Band-Schnellwahl").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 4) {
                        ForEach(bands.prefix(12), id: \.0) { name, freq in
                            Button(name) { freqText = String(freq) }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .tint(abs(f - freq) < 0.5 ? .accentColor : nil)
                        }
                    }
                }
                Divider()
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Frequenz").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("MHz", text: $freqText).textFieldStyle(.roundedBorder)
                            Text("MHz").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Verkürzungsfaktor VF").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("0.95", text: $vfText).textFieldStyle(.roundedBorder).frame(width: 80)
                            Text("0.8–1.0").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                if selectedTyp == .vertikal {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aktuelle Strahler-Länge").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("m", text: $antennaLenText).textFieldStyle(.roundedBorder).frame(width: 100)
                            Text("m").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Berechnung

    private func berechne() -> AntennenErgebnis? {
        guard f > 0, vf > 0, vf <= 1.0 else { return nil }
        let lambda = 300.0 / f
        let lhalf  = 150.0 / f * vf
        let lquart = 75.0 / f * vf
        var r = AntennenErgebnis(typ: selectedTyp, f: f, vf: vf, lambda: lambda, lhalf: lhalf, lquart: lquart)

        switch selectedTyp {
        case .dipol:
            r.werte = [
                ("Gesamtlänge (λ/2)", String(format: "%.3f m", lhalf), true),
                ("Arm-Länge (λ/4)", String(format: "%.3f m", lhalf / 2), false),
                ("Speisepunkt-Impedanz", "≈ 50–75 Ω", false),
                ("Wellenlänge λ", String(format: "%.3f m", lambda), false)
            ]
            r.hinweis = "Klassischer λ/2 Dipol. Verkürzungsfaktor VF=\(String(format: "%.2f", vf)). Speisung in der Mitte mit 50Ω Koaxkabel über 1:1 Balun."

        case .gp:
            r.werte = [
                ("Strahler (λ/4)", String(format: "%.3f m", lquart), true),
                ("Radiale (4×, λ/4 je)", String(format: "%.3f m", lquart), false),
                ("Speisepunkt-Impedanz", "≈ 50 Ω", false),
                ("Wellenlänge λ", String(format: "%.3f m", lambda), false)
            ]
            r.hinweis = "Groundplane: λ/4 Strahler vertikal, 4 Radiale horizontal oder leicht nach unten geneigt (max. 45°). Neigung der Radiale erhöht die Impedanz Richtung 50Ω."

        case .jpole:
            r.werte = [
                ("Strahler (λ/2)", String(format: "%.3f m", lhalf), true),
                ("Anpassstück (λ/4)", String(format: "%.3f m", lquart), false),
                ("Speisepunkt", "≈ 5% des Anpassstücks von unten", false),
                ("Speisepunkt-Impedanz", "≈ 50 Ω am Anpasspunkt", false)
            ]
            r.hinweis = "J-Pole: λ/2 Strahler + λ/4 Anpassstück (J-Stub). Einspeisepunkt ca. 5% des Stubs von unten. Keine Erdung nötig."

        case .moxon:
            let A = 111.45 / f * vf / 0.95
            let B = 15.35  / f * vf / 0.95
            let C = 3.14   / f * vf / 0.95
            let D = 19.34  / f * vf / 0.95
            r.werte = [
                ("A – Seite (horizontal)", String(format: "%.3f m", A), true),
                ("B – Rücklauf (je)", String(format: "%.3f m", B), false),
                ("C – Lücke", String(format: "%.3f m", C), false),
                ("D – Gesamttiefe (B+C)", String(format: "%.3f m", D), false),
                ("Speisepunkt-Impedanz", "≈ 50 Ω", false)
            ]
            r.hinweis = "Moxon Rectangle: kompakte 2-Element-Antenne. Gewinn ~5 dBd, F/B ≈ 20 dB. Einfacher aufzubauen als Yagi."

        case .sperrtopf:
            let strahler = lquart
            let huelle   = lquart * 0.82
            r.werte = [
                ("Strahler (λ/4, Innenleiter)", String(format: "%.3f m", strahler), true),
                ("Hülle (λ/4 × 0.82, VF Koax)", String(format: "%.3f m", huelle), false),
                ("Speisepunkt-Impedanz", "≈ 50 Ω", false)
            ]
            r.hinweis = "Sperrtopf aus Koaxkabel: Innenleiter = λ/4 Strahler, Außenleiter durch Hülle abgeschirmt (λ/4, VF=0.82). Keine Gegengewichte nötig."

        case .slimjim:
            let gesamtSJ = lhalf * 1.5 * vf
            let strahSJ  = lhalf * vf
            let stubSJ   = lquart * vf
            r.werte = [
                ("Gesamtlänge (3/4 λ)", String(format: "%.3f m", gesamtSJ), true),
                ("Strahler (λ/2)", String(format: "%.3f m", strahSJ), false),
                ("J-Stub (λ/4)", String(format: "%.3f m", stubSJ), false),
                ("Speisepunkt", "≈ 5% des Stubs von unten", false)
            ]
            r.hinweis = "Slim Jim / J-Zepp: 3/4 λ Gesamtlänge. Omnidirektionale Vertikalantenne mit ca. 3 dB Gewinn über GP. Einspeisepunkt ca. 5% des Stubs vom unteren Ende."

        case .efhw:
            let draht    = lhalf
            let gegengew = (300.0 / f) * 0.05 * vf
            r.werte = [
                ("Drahtlänge (λ/2)", String(format: "%.3f m", draht), true),
                ("Gegengewicht (≈5% λ)", String(format: "%.3f m", gegengew), false),
                ("Eingangsimpedanz", "≈ 2450 Ω", false),
                ("Trafo", "49:1 Unun", false)
            ]
            r.hinweis = "EFHW: Hohe Eingangsimpedanz ~2450Ω, daher 49:1 Unun nötig. Trafo: 2 Primär + 14 Sekundär Windungen auf FT140-43 oder FT240-43. 100 pF NP0-Kondensator auf der Primärseite."

        case .vertikal:
            let ziel = lquart
            if antennaLen >= ziel {
                r.werte = [
                    ("Zielgröße (λ/4)", String(format: "%.3f m", ziel), false),
                    ("Aktuelle Länge", String(format: "%.3f m", antennaLen), false),
                    ("Status", "Keine Spule nötig ✓", true)
                ]
                r.hinweis = "Der Strahler ist bereits lang genug für λ/4. Keine Verlängerungsspule nötig."
            } else {
                let diff = ziel - antennaLen
                r.werte = [
                    ("Zielgröße (λ/4)", String(format: "%.3f m", ziel), false),
                    ("Aktuelle Länge", String(format: "%.3f m", antennaLen), false),
                    ("Fehlende Länge", String(format: "%.3f m", diff), true)
                ]
                r.hinweis = "Verlängerungsspule benötigt. Nutze den 'Strahler-Verlängerung' Rechner für die Spulenberechnung."
            }
        }
        return r
    }

    // MARK: Ergebnis

    private func ergebnisBereich(_ r: AntennenErgebnis) -> some View {
        SectionCard(title: "Maße") {
            VStack(spacing: 4) {
                ForEach(r.werte, id: \.label) { w in
                    ResultRow(label: w.label, value: w.value, highlight: w.highlight)
                }
                Divider().padding(.vertical, 4)
                ResultRow(label: "Wellenlänge λ", value: String(format: "%.3f m", r.lambda))
                ResultRow(label: "λ/2", value: String(format: "%.3f m", r.lhalf))
                ResultRow(label: "λ/4", value: String(format: "%.3f m", r.lquart))
            }
        }
    }

    // MARK: Skizze

    @ViewBuilder
    private func skizzeBereich(_ r: AntennenErgebnis) -> some View {
        SectionCard(title: "Skizze") {
            Canvas { ctx, size in
                drawAntenna(ctx: ctx, size: size, r: r)
            }
            .frame(height: 240)
        }
    }

    private func drawAntenna(ctx: GraphicsContext, size: CGSize, r: AntennenErgebnis) {
        let W = size.width, H = size.height
        let cx = W / 2, cy = H / 2

        switch r.typ {
        case .dipol:
            let armLen = min(W / 2 - 20, 200.0)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: cx - armLen, y: cy))
                p.addLine(to: CGPoint(x: cx + armLen, y: cy))
            }, with: .color(.blue), lineWidth: 4)
            ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: cy-5, width: 10, height: 10)), with: .color(.accentColor))
            ctx.draw(Text(String(format: "← %.3f m →", r.lhalf)).font(.caption).foregroundStyle(.secondary), at: CGPoint(x: cx, y: cy + 18), anchor: .center)

        case .gp:
            let topY: CGFloat = 20
            let botY: CGFloat = H - 20
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: cx, y: botY))
                p.addLine(to: CGPoint(x: cx, y: topY))
            }, with: .color(.blue), lineWidth: 4)
            let rl: CGFloat = 60
            for dx in [-rl, rl] {
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx, y: botY))
                    p.addLine(to: CGPoint(x: cx + dx, y: botY + 10))
                }, with: .color(.gray), lineWidth: 2)
            }
            ctx.draw(Text(String(format: "%.3f m", r.lquart)).font(.caption).foregroundStyle(.secondary), at: CGPoint(x: cx + 14, y: (topY+botY)/2), anchor: .leading)

        case .jpole:
            let topY: CGFloat = 15, botY: CGFloat = H - 15
            let totalH = botY - topY
            let halfRatio = r.lhalf / (r.lhalf + r.lquart)
            let stubTop = botY - totalH * halfRatio
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: cx + 20, y: botY))
                p.addLine(to: CGPoint(x: cx + 20, y: topY))
            }, with: .color(.blue), lineWidth: 4)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: cx - 20, y: botY))
                p.addLine(to: CGPoint(x: cx - 20, y: stubTop))
            }, with: .color(.gray), lineWidth: 3)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: cx - 20, y: botY))
                p.addLine(to: CGPoint(x: cx + 20, y: botY))
            }, with: .color(.gray), lineWidth: 2)
            ctx.fill(Path(ellipseIn: CGRect(x: cx-20-4, y: stubTop+totalH*0.05-4, width: 8, height: 8)), with: .color(.orange))
            ctx.draw(Text("λ/2").font(.caption2), at: CGPoint(x: cx + 32, y: (topY + botY)/2), anchor: .leading)
            ctx.draw(Text("λ/4").font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: cx - 32, y: (stubTop + botY)/2), anchor: .trailing)
            ctx.draw(Text("Einspeisepunkt").font(.caption2).foregroundStyle(.orange), at: CGPoint(x: cx - 26, y: stubTop + totalH*0.05), anchor: .trailing)

        case .slimjim:
            let topY: CGFloat = 10, botY: CGFloat = H - 10
            let totalH = botY - topY
            let stubRatio = r.lquart / (r.lhalf + r.lquart)
            let stubTop = botY - totalH * stubRatio
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: cx + 20, y: botY))
                p.addLine(to: CGPoint(x: cx + 20, y: topY))
            }, with: .color(.blue), lineWidth: 4)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: cx - 20, y: botY))
                p.addLine(to: CGPoint(x: cx - 20, y: stubTop))
            }, with: .color(.orange), lineWidth: 3)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: cx - 20, y: botY))
                p.addLine(to: CGPoint(x: cx + 20, y: botY))
            }, with: .color(.gray), lineWidth: 2)
            ctx.draw(Text("λ/2").font(.caption2), at: CGPoint(x: cx + 28, y: (topY+botY)/2), anchor: .leading)
            ctx.draw(Text("λ/4 J-Stub").font(.caption2).foregroundStyle(.orange), at: CGPoint(x: cx - 28, y: (stubTop+botY)/2), anchor: .trailing)

        case .moxon:
            let marginX: CGFloat = 30, marginY: CGFloat = 20
            let bw = W - 2 * marginX, bh = H - 2 * marginY
            let topY = marginY, botY = marginY + bh
            let ltX = marginX, rtX = marginX + bw
            let gapY = botY - bh * 0.25
            // Top bar
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: ltX, y: topY))
                p.addLine(to: CGPoint(x: rtX, y: topY))
            }, with: .color(.blue), lineWidth: 3)
            // Left arm down
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: ltX, y: topY))
                p.addLine(to: CGPoint(x: ltX, y: gapY))
            }, with: .color(.blue), lineWidth: 3)
            // Right arm down
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: rtX, y: topY))
                p.addLine(to: CGPoint(x: rtX, y: gapY))
            }, with: .color(.blue), lineWidth: 3)
            // Bottom bar (Reflektor)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: ltX, y: botY))
                p.addLine(to: CGPoint(x: rtX, y: botY))
            }, with: .color(.gray), lineWidth: 3)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: ltX, y: botY))
                p.addLine(to: CGPoint(x: ltX, y: gapY + 8))
            }, with: .color(.gray), lineWidth: 3)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: rtX, y: botY))
                p.addLine(to: CGPoint(x: rtX, y: gapY + 8))
            }, with: .color(.gray), lineWidth: 3)
            ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: topY-5, width: 10, height: 10)), with: .color(.accentColor))
            ctx.draw(Text("Speisepunkt").font(.caption2).foregroundStyle(Color.accentColor), at: CGPoint(x: cx, y: topY - 12), anchor: .center)

        case .sperrtopf:
            let topY: CGFloat = 20, botY: CGFloat = H - 30
            let innerH = botY - topY
            let sleeveH = innerH * 0.82
            let sleeveBot = botY, sleeveTop = botY - sleeveH
            // Innenleiter (Strahler)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: cx, y: botY))
                p.addLine(to: CGPoint(x: cx, y: topY))
            }, with: .color(.blue), lineWidth: 4)
            // Außenmantel (Hülle) links/rechts
            for dxOff: CGFloat in [-10, 10] {
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx + dxOff, y: sleeveBot))
                    p.addLine(to: CGPoint(x: cx + dxOff, y: sleeveTop))
                }, with: .color(.gray), lineWidth: 2.5)
            }
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: cx - 10, y: sleeveTop))
                p.addLine(to: CGPoint(x: cx + 10, y: sleeveTop))
            }, with: .color(.gray), lineWidth: 2)
            // Boden (Koax-Ende)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: cx - 10, y: botY))
                p.addLine(to: CGPoint(x: cx + 10, y: botY))
            }, with: .color(.gray), lineWidth: 2)
            ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: botY-5, width: 10, height: 10)), with: .color(.accentColor))
            ctx.draw(Text(String(format: "λ/4 = %.3f m", r.lquart)).font(.caption).foregroundStyle(.blue), at: CGPoint(x: cx + 16, y: (topY+botY)/2), anchor: .leading)
            ctx.draw(Text(String(format: "Hülle %.3f m", r.lquart*0.82)).font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: cx - 16, y: (sleeveTop+botY)/2), anchor: .trailing)
            ctx.draw(Text("50Ω").font(.caption2).foregroundStyle(Color.accentColor), at: CGPoint(x: cx, y: botY + 14), anchor: .center)

        case .efhw:
            let wireY = cy
            let boxW: CGFloat = 46, boxH: CGFloat = 26
            let boxX: CGFloat = 36
            let wireEnd = W - 24
            // 49:1 Unun
            ctx.stroke(Path { p in
                p.addRoundedRect(in: CGRect(x: boxX, y: wireY - boxH/2, width: boxW, height: boxH), cornerSize: CGSize(width: 5, height: 5))
            }, with: .color(.orange), lineWidth: 2)
            ctx.draw(Text("49:1").font(.system(size: 11)).bold().foregroundStyle(.orange), at: CGPoint(x: boxX + boxW/2, y: wireY - 5), anchor: .center)
            ctx.draw(Text("Unun").font(.system(size: 9)).foregroundStyle(.orange.opacity(0.8)), at: CGPoint(x: boxX + boxW/2, y: wireY + 7), anchor: .center)
            // Draht
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: boxX + boxW, y: wireY))
                p.addLine(to: CGPoint(x: wireEnd, y: wireY))
            }, with: .color(.blue), lineWidth: 4)
            // Speisepunkt
            ctx.fill(Path(ellipseIn: CGRect(x: boxX - 5, y: wireY - 5, width: 10, height: 10)), with: .color(.accentColor))
            ctx.draw(Text("50Ω").font(.caption2).foregroundStyle(Color.accentColor), at: CGPoint(x: boxX - 8, y: wireY), anchor: .trailing)
            ctx.draw(Text(String(format: "← λ/2 = %.3f m →", r.lhalf)).font(.caption).foregroundStyle(.secondary), at: CGPoint(x: (boxX + boxW + wireEnd) / 2, y: wireY - 20), anchor: .center)
            ctx.draw(Text("FT240-43 · 2:14 Wdg.").font(.caption2).foregroundStyle(.orange.opacity(0.7)), at: CGPoint(x: boxX + boxW/2, y: wireY + boxH/2 + 12), anchor: .center)

        case .vertikal:
            let topY: CGFloat = 20, botY: CGFloat = H - 30
            let coilH: CGFloat = 38
            let coilBot = botY
            let coilTop = coilBot - coilH
            let amp: CGFloat = 16
            // Spulen-Symbol
            let nVis = 6
            let stepH = coilH / CGFloat(nVis)
            var coilPath = Path()
            coilPath.move(to: CGPoint(x: cx, y: coilBot))
            for i in 0..<nVis {
                let y1 = coilBot - CGFloat(i) * stepH
                let y3 = coilBot - CGFloat(i+1) * stepH
                coilPath.addCurve(to: CGPoint(x: cx, y: y3),
                                  control1: CGPoint(x: cx + amp, y: y1),
                                  control2: CGPoint(x: cx + amp, y: y3))
            }
            ctx.stroke(Path { p in
                p.addRoundedRect(in: CGRect(x: cx - amp - 3, y: coilTop, width: amp * 2 + 6, height: coilH), cornerSize: CGSize(width: 4, height: 4))
            }, with: .color(.orange.opacity(0.3)), lineWidth: 1)
            ctx.stroke(coilPath, with: .color(.orange), lineWidth: 2.5)
            // Strahler oben
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: cx, y: coilTop))
                p.addLine(to: CGPoint(x: cx, y: topY))
            }, with: .color(.blue), lineWidth: 4)
            // Erde
            for i in 0..<4 {
                let len: CGFloat = CGFloat(18 - i * 4)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx - len, y: botY + CGFloat(i) * 5))
                    p.addLine(to: CGPoint(x: cx + len, y: botY + CGFloat(i) * 5))
                }, with: .color(.secondary), lineWidth: i == 0 ? 2 : 1)
            }
            ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: coilBot-5, width: 10, height: 10)), with: .color(.accentColor))
            ctx.draw(Text(String(format: "λ/4 = %.3f m", r.lquart)).font(.caption).foregroundStyle(.secondary), at: CGPoint(x: cx + amp + 12, y: (topY + coilTop) / 2), anchor: .leading)
            ctx.draw(Text("Verlängerungsspule").font(.caption2).foregroundStyle(.orange), at: CGPoint(x: cx - amp - 6, y: (coilTop + coilBot) / 2), anchor: .trailing)
            ctx.draw(Text("50Ω").font(.caption2).foregroundStyle(Color.accentColor), at: CGPoint(x: cx + 12, y: coilBot), anchor: .leading)
        }
    }

    // MARK: Hinweis

    private func hinweisBox(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(.yellow).font(.body)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
