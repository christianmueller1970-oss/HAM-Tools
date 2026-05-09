import SwiftUI

// MARK: - Model

enum LoopVariant: String, CaseIterable, Identifiable {
    case delta110    = "Delta-Loop 110Ω"
    case delta50     = "Delta-Loop 50Ω (40/30/30)"
    case delta50apex = "Delta-Loop 50Ω (Apex 18/41/41)"
    case quad        = "Quad-Loop 110Ω"
    var id: String { rawValue }
}

private struct LoopErgebnis {
    let f: Double
    let vf: Double
    let total: Double    // Gesamtumfang m
    let variant: LoopVariant
    let matchLen: Double // λ/4 Anpassleitung m (für 110Ω Varianten)
    let coaxVF: Double   // 0.67 für 75Ω Koax

    // Geometriedaten
    var basis: Double = 0
    var schenkel: Double = 0
    var seite: Double = 0

    static func berechne(f: Double, vf: Double, variant: LoopVariant, coaxVF: Double) -> LoopErgebnis? {
        guard f > 0, vf > 0 else { return nil }
        let total    = (306.3 / f) * (vf / 0.98)
        let matchLen = (300.0 / f / 4.0) * coaxVF
        var r = LoopErgebnis(f: f, vf: vf, total: total, variant: variant, matchLen: matchLen, coaxVF: coaxVF)
        switch variant {
        case .delta110:    r.seite = total / 3
        case .delta50:     r.basis = total * 0.40; r.schenkel = total * 0.30
        case .delta50apex: r.basis = total * 0.18; r.schenkel = total * 0.41
        case .quad:        r.seite = total / 4
        }
        return r
    }
}

// MARK: - View

struct LoopRechnerView: View {
    @State private var selectedVariant: LoopVariant = .delta110
    @State private var freqText = "7.1"
    @State private var vfText   = "0.98"
    @State private var coaxVF   = 0.67

    private var f:  Double { Double(freqText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var vf: Double { Double(vfText.replacingOccurrences(of: ",", with: "."))   ?? 0.98 }
    private var ergebnis: LoopErgebnis? { LoopErgebnis.berechne(f: f, vf: vf, variant: selectedVariant, coaxVF: coaxVF) }

    private let bands: [(String, Double)] = [
        ("160m", 1.85), ("80m", 3.65), ("60m", 5.36), ("40m", 7.1),
        ("30m", 10.125), ("20m", 14.175), ("17m", 18.118), ("15m", 21.225)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                variantWahl
                eingabeBereich
                if let r = ergebnis {
                    ergebnisBereich(r)
                    skizzeBereich(r)
                    anpassungBereich(r)
                }
                infoBereich
            }
            .padding(24)
        }
        .navigationTitle("Loop-Antenne")
    }

    // MARK: Varianten-Wahl

    private var variantWahl: some View {
        SectionCard(title: "Loop-Variante") {
            VStack(spacing: 8) {
                ForEach(LoopVariant.allCases) { v in
                    let isSelected = selectedVariant == v
                    Button {
                        selectedVariant = v
                    } label: {
                        HStack {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            Text(v.rawValue).font(.callout)
                            Spacer()
                            variantImpedanzLabel(v)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func variantImpedanzLabel(_ v: LoopVariant) -> some View {
        let text: String
        switch v {
        case .delta110:    text = "≈ 110Ω → 50Ω via λ/4"
        case .delta50:     text = "≈ 50Ω direkt"
        case .delta50apex: text = "≈ 50Ω direkt"
        case .quad:        text = "≈ 110Ω → 50Ω via λ/4"
        }
        return Text(text).font(.caption).foregroundStyle(.secondary)
    }

    // MARK: Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Eingabe") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Band-Schnellwahl").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 6) {
                        ForEach(bands, id: \.0) { name, freq in
                            Button(name) { freqText = String(freq) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
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
                            TextField("0.98", text: $vfText).textFieldStyle(.roundedBorder).frame(width: 80)
                            Text("(Draht ≈ 0.98)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if selectedVariant == .delta110 || selectedVariant == .quad {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Koax VF für Anpassleitung (75Ω)").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $coaxVF) {
                            Text("0.66 (Foam)").tag(0.66)
                            Text("0.67 (typ.)").tag(0.67)
                            Text("0.70 (Luft)").tag(0.70)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    // MARK: Ergebnis

    private func ergebnisBereich(_ r: LoopErgebnis) -> some View {
        SectionCard(title: "Maße") {
            VStack(spacing: 4) {
                ResultRow(label: "Gesamtumfang", value: String(format: "%.3f m", r.total), highlight: true)
                Divider().padding(.vertical, 2)
                switch r.variant {
                case .delta110:
                    ResultRow(label: "Seite (3×, gleichseitig)", value: String(format: "%.3f m", r.seite))
                case .delta50:
                    ResultRow(label: "Basis (40%, horizontal)", value: String(format: "%.3f m", r.basis))
                    ResultRow(label: "Schenkel (2×, je 30%)", value: String(format: "%.3f m", r.schenkel))
                case .delta50apex:
                    ResultRow(label: "Basis (18%, kurze Seite)", value: String(format: "%.3f m", r.basis))
                    ResultRow(label: "Schenkel (2×, je 41%)", value: String(format: "%.3f m", r.schenkel))
                case .quad:
                    ResultRow(label: "Seite (4×, Quadrat)", value: String(format: "%.3f m", r.seite))
                }
                Divider().padding(.vertical, 2)
                ResultRow(label: "Wellenlänge λ", value: String(format: "%.3f m", 300.0 / r.f))
                ResultRow(label: "Frequenz", value: String(format: "%.3f MHz", r.f))
            }
        }
    }

    // MARK: Skizze

    @ViewBuilder
    private func skizzeBereich(_ r: LoopErgebnis) -> some View {
        SectionCard(title: "Skizze") {
            Canvas { ctx, size in
                switch r.variant {
                case .delta110:    drawDelta(ctx: ctx, size: size, seite: r.seite, apex: false, label: "110Ω")
                case .delta50:     drawDeltaFlach(ctx: ctx, size: size, r: r)
                case .delta50apex: drawDeltaAp(ctx: ctx, size: size, r: r)
                case .quad:        drawQuad(ctx: ctx, size: size, seite: r.seite)
                }
            }
            .frame(height: 260)
        }
    }

    private func drawDelta(ctx: GraphicsContext, size: CGSize, seite: Double, apex: Bool, label: String) {
        let W = size.width, H = size.height
        let marginX: CGFloat = 40, marginT: CGFloat = 22, marginB: CGFloat = 50
        let availW = W - 2 * marginX
        let availH = H - marginT - marginB

        // Gleichseitiges Dreieck: h = Seite × sqrt(3)/2, Basis = Seite
        let hRatio: CGFloat = sqrt(3.0) / 2.0
        let bPx = CGFloat(min(Double(availW), Double(availH) / Double(hRatio)))
        let hPx = bPx * hRatio

        let cx = W / 2
        let botY = marginT + (availH + hPx) / 2
        let topY = botY - hPx
        let lX = cx - bPx / 2, rX = cx + bPx / 2

        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: lX, y: botY))
            p.addLine(to: CGPoint(x: rX, y: botY))
            p.addLine(to: CGPoint(x: cx, y: topY))
            p.closeSubpath()
        }, with: .color(.blue), lineWidth: 2.5)

        ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: botY-5, width: 10, height: 10)), with: .color(.accentColor))
        ctx.draw(Text("50Ω").font(.caption2).bold().foregroundStyle(Color.accentColor),
                 at: CGPoint(x: cx, y: botY + 15), anchor: .center)
        ctx.draw(Text("\(label)  ·  Seite: \(String(format: "%.3f m", seite))").font(.caption).foregroundStyle(.secondary),
                 at: CGPoint(x: W / 2, y: H - 8), anchor: .center)
    }

    private func drawDeltaFlach(ctx: GraphicsContext, size: CGSize, r: LoopErgebnis) {
        let W = size.width, H = size.height
        let b = r.basis, l = r.schenkel
        let triH = sqrt(l * l - (b / 2) * (b / 2))

        let marginX: CGFloat = 40, marginT: CGFloat = 22, marginB: CGFloat = 50
        let availW = W - 2 * marginX
        let availH = H - marginT - marginB

        let scale = min(availW / CGFloat(b), availH / CGFloat(triH)) * 0.9
        let bPx = CGFloat(b) * scale
        let hPx = CGFloat(triH) * scale

        let cx = W / 2
        let botY = marginT + (availH + hPx) / 2
        let topY = botY - hPx
        let lX = cx - bPx / 2, rX = cx + bPx / 2

        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: lX, y: botY))
            p.addLine(to: CGPoint(x: rX, y: botY))
            p.addLine(to: CGPoint(x: cx, y: topY))
            p.closeSubpath()
        }, with: .color(.blue), lineWidth: 2.5)

        ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: botY-5, width: 10, height: 10)), with: .color(.accentColor))
        ctx.draw(Text("50Ω").font(.caption2).bold().foregroundStyle(Color.accentColor),
                 at: CGPoint(x: cx, y: botY + 15), anchor: .center)
        ctx.draw(Text("Basis: \(String(format: "%.3f m", r.basis)) (40%)   ·   Schenkel: \(String(format: "%.3f m", r.schenkel)) (30%)").font(.caption).foregroundStyle(.secondary),
                 at: CGPoint(x: W / 2, y: H - 8), anchor: .center)
    }

    private func drawDeltaAp(ctx: GraphicsContext, size: CGSize, r: LoopErgebnis) {
        let W = size.width, H = size.height
        let b = r.basis, l = r.schenkel
        let triH = sqrt(l * l - (b / 2) * (b / 2))

        let marginX: CGFloat = 40, marginT: CGFloat = 30, marginB: CGFloat = 50
        let availW = W - 2 * marginX
        let availH = H - marginT - marginB

        let scale = min(availW / CGFloat(b), availH / CGFloat(triH)) * 0.9
        let bPx = CGFloat(b) * scale
        let hPx = CGFloat(triH) * scale

        let cx = W / 2
        // Spitze zeigt NACH UNTEN: kurze Basis oben, Apex unten
        let topY = marginT + (availH - hPx) / 2
        let botY = topY + hPx
        let lX = cx - bPx / 2, rX = cx + bPx / 2

        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: lX, y: topY))      // Basis links (oben)
            p.addLine(to: CGPoint(x: rX, y: topY))   // Basis rechts (oben)
            p.addLine(to: CGPoint(x: cx, y: botY))   // Apex (unten)
            p.closeSubpath()
        }, with: .color(.blue), lineWidth: 2.5)

        // Speisepunkt am Apex (unten)
        ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: botY-5, width: 10, height: 10)), with: .color(.accentColor))
        ctx.draw(Text("50Ω (Apex)").font(.caption2).bold().foregroundStyle(Color.accentColor),
                 at: CGPoint(x: cx, y: botY + 15), anchor: .center)
        ctx.draw(Text("Basis: \(String(format: "%.3f m", r.basis)) (18%)").font(.caption).foregroundStyle(.secondary),
                 at: CGPoint(x: cx, y: topY - 14), anchor: .center)
        ctx.draw(Text("Schenkel: \(String(format: "%.3f m", r.schenkel)) (41%)").font(.caption).foregroundStyle(.secondary),
                 at: CGPoint(x: W / 2, y: H - 8), anchor: .center)
    }

    private func drawQuad(ctx: GraphicsContext, size: CGSize, seite: Double) {
        let W = size.width, H = size.height
        let marginX: CGFloat = 40, marginT: CGFloat = 22, marginB: CGFloat = 44
        let availW = W - 2 * marginX
        let availH = H - marginT - marginB
        let side = min(availW, availH)
        let x0 = (W - side) / 2, y0 = marginT + (availH - side) / 2
        let feedX = x0 + side / 2, feedY = y0 + side

        ctx.stroke(Path { p in
            p.addRect(CGRect(x: x0, y: y0, width: side, height: side))
        }, with: .color(.blue), lineWidth: 2.5)

        ctx.fill(Path(ellipseIn: CGRect(x: feedX-5, y: feedY-5, width: 10, height: 10)), with: .color(.accentColor))
        ctx.draw(Text("50Ω via λ/4").font(.caption2).bold().foregroundStyle(Color.accentColor),
                 at: CGPoint(x: feedX, y: feedY + 15), anchor: .center)
        ctx.draw(Text("Seite: \(String(format: "%.3f m", seite))").font(.caption).foregroundStyle(.secondary),
                 at: CGPoint(x: W / 2, y: H - 8), anchor: .center)
    }

    // MARK: Anpassung

    @ViewBuilder
    private func anpassungBereich(_ r: LoopErgebnis) -> some View {
        if r.variant == .delta110 || r.variant == .quad {
            SectionCard(title: "Anpassleitung") {
                VStack(spacing: 4) {
                    ResultRow(label: "Typ", value: "λ/4 aus 75Ω Koaxkabel")
                    ResultRow(label: "Länge (phys.)", value: String(format: "%.3f m  (%.0f cm)", r.matchLen, r.matchLen * 100), highlight: true)
                    ResultRow(label: "Koax VF", value: String(format: "%.2f", r.coaxVF))
                    Text("Transformiert ~110Ω → 50Ω. Zwischen Speisepunkt und 50Ω Koaxkabel einschleifen.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } else {
            SectionCard(title: "Speisung") {
                Text("Direkte 50Ω Einspeisung am Speisepunkt. Kein zusätzlicher Trafo nötig.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Info

    private var infoBereich: some View {
        SectionCard(title: "Hinweis") {
            Text("Gesamtumfang nach Formel: 306.3 / f × (VF / 0.98). VF = Verkürzungsfaktor des Drahtes (Isoliert ≈ 0.95–0.97, blank ≈ 0.98). Breitbandige Ganswellen-Loops sind robuster als Dipole bei leichter Fehlanpassung.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
