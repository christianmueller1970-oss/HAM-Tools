import SwiftUI

// MARK: - Model

struct HexbeamBand: Identifiable {
    let id: String
    let name: String
    let fMHz: Double
    let istWARC: Bool
    var aktiv: Bool

    var lambda: Double { 300.0 / fMHz }

    // G3TXQ Broadband Hexbeam (Steve Hunt, lizenziert in der WiMo EAntenna HEX6B).
    // Faktoren abgeleitet aus den 20m-Referenzmaßen (G3TXQ Original-Diagramm "20 Meter
    // Broadband Hex Wires and Spacers"):
    //   ½ Driver = 214"  = 5.44 m  →  0.2570 × λ   (Drahtlänge, 3D entlang Spreader-Bogen)
    //   Reflector = 404" = 10.26 m →  0.4849 × λ   (Drahtlänge, Gesamtdraht)
    //   Tip Spacer = 24" = 0.61 m  →  0.0288 × λ   (PVC-Isolator zw. Driver-Tip und Reflector)
    //   Spreader-Radius (horizontal) ≈ 3.46 m für 20m → 0.1635 × λ
    var driver_half_m: Double  { lambda * 0.2570 }
    var driver_full_m: Double  { lambda * 0.5140 }
    var reflector_m:   Double  { lambda * 0.4849 }
    var tip_spacer_m:  Double  { lambda * 0.0288 }
    /// Horizontaler Eyelet-Radius (Top-View-Projektion). Der echte Pole ist länger
    /// (Schüssel-Krümmung), das Wire läuft entlang dem gebogenen Spreader.
    var radius_m:      Double  { lambda * 0.1635 }
}

// MARK: - View

struct HexbeamView: View {
    @State private var baender: [HexbeamBand] = [
        HexbeamBand(id: "40m",  name: "40m",  fMHz:  7.100, istWARC: false, aktiv: false),
        HexbeamBand(id: "30m",  name: "30m",  fMHz: 10.125, istWARC: true,  aktiv: false),
        HexbeamBand(id: "20m",  name: "20m",  fMHz: 14.175, istWARC: false, aktiv: true),
        HexbeamBand(id: "17m",  name: "17m",  fMHz: 18.118, istWARC: true,  aktiv: false),
        HexbeamBand(id: "15m",  name: "15m",  fMHz: 21.225, istWARC: false, aktiv: true),
        HexbeamBand(id: "12m",  name: "12m",  fMHz: 24.940, istWARC: true,  aktiv: false),
        HexbeamBand(id: "10m",  name: "10m",  fMHz: 28.500, istWARC: false, aktiv: true),
        HexbeamBand(id: "6m",   name: "6m",   fMHz: 50.150, istWARC: false, aktiv: false),
        HexbeamBand(id: "2m",   name: "2m",   fMHz: 145.00, istWARC: false, aktiv: false),
    ]

    private var aktiveBaender: [HexbeamBand] { baender.filter(\.aktiv) }
    private var referenzBand: HexbeamBand?   { aktiveBaender.min(by: { $0.fMHz < $1.fMHz }) }
    /// Größter horizontaler Eyelet-Radius (= Spreader-Tip-Radius des niedrigsten aktiven Bands).
    private var maxRadius: Double            { aktiveBaender.map(\.radius_m).max() ?? 0 }

    private let bandColors: [String: Color] = [
        "40m": .purple, "30m": .indigo, "20m": .blue, "17m": .cyan,
        "15m": .green,  "12m": .yellow, "10m": .orange, "6m": .red, "2m": .pink
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ueberarbeitungsHinweis
                bandWahl
                if !aktiveBaender.isEmpty {
                    masseBereich
                    draufsichtBereich
                    seitenansichtBereich
                    einspeisungBereich
                    zusammenfassungBereich
                }
                hinweisBereich
                RechnerBeschreibung(resourceName: "hexbeam")
            }
            .padding(24)
        }
        .navigationTitle("Hexbeam")
    }

    // MARK: G3TXQ-Quellen-Hinweis

    private var ueberarbeitungsHinweis: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("G3TXQ Broadband Hexbeam")
                    .font(.callout).bold()
                Text("Werte und Geometrie nach Steve Hunt G3TXQ — referenziert über die lizenzierte WiMo EAntenna HEX6B Bauanleitung. 20m-Referenz: ½ Driver 214″ · Reflector 404″ · Tip Spacer 24″ · Spreader-Radius ≈ 11′4″. Andere Bänder linear mit λ skaliert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Danke an Markus, HB9EIZ, für den Hinweis und die Bauanleitung.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.green.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Band-Wahl

    private var bandWahl: some View {
        SectionCard(title: "Bänder auswählen  (W = WARC)") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach($baender) { $band in
                    Toggle(isOn: $band.aktiv) {
                        HStack(spacing: 4) {
                            Text(band.name).bold()
                            if band.istWARC {
                                Text("W").font(.caption2).foregroundStyle(.orange)
                            }
                        }
                    }
                    .toggleStyle(.button)
                    .tint(bandColors[band.id] ?? .accentColor)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: Maße-Tabelle

    private var masseBereich: some View {
        SectionCard(title: "Maße pro Band (Drahtlängen)") {
            VStack(spacing: 0) {
                HStack {
                    Text("Band")       .font(.caption).bold().foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
                    Text("Frequenz")   .font(.caption).bold().foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    Text("½ Driver")   .font(.caption).bold().foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    Text("Driver ges.").font(.caption).bold().foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    Text("Reflektor")  .font(.caption).bold().foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    Text("Tip Spacer") .font(.caption).bold().foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
                .padding(.vertical, 6)
                Divider()
                ForEach(aktiveBaender) { band in
                    HStack {
                        Text(band.name).font(.callout).bold()
                            .foregroundStyle(bandColors[band.id] ?? .primary)
                            .frame(width: 44, alignment: .leading)
                        Text(String(format: "%.3f MHz", band.fMHz))          .font(.callout).frame(maxWidth: .infinity)
                        Text(String(format: "%.3f m",   band.driver_half_m)) .font(.callout).bold().frame(maxWidth: .infinity)
                        Text(String(format: "%.3f m",   band.driver_full_m)) .font(.callout).frame(maxWidth: .infinity)
                        Text(String(format: "%.3f m",   band.reflector_m))   .font(.callout).frame(maxWidth: .infinity)
                        Text(String(format: "%.3f m",   band.tip_spacer_m))  .font(.callout).frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
                Text("Drahtlängen sind 3D entlang dem Spreader-Bogen (so wie das Wire durch die Eyelets läuft). Driver pro Band = 2× ½ Driver; Reflector ist eine durchgehende Schleife durch die 4 hinteren Spreader-Tips; Tip Spacer ist der PVC-Isolator zwischen Driver-Tip und Reflector-Ende am selben Spreader.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }
        }
    }

    // MARK: Draufsicht
    //
    // G3TXQ-Topologie (Top View, horizontale Projektion, nach Original G3TXQ-Bild):
    // - 6 Spreader bei 30°, 90°, 150°, 210°, 270°, 330° (im Uhrzeigersinn ab "vorne")
    // - 30° und 330° sind die FRONT-Spreader (Driver-Seite)
    // - 90°, 150°, 210°, 270° sind die 4 hinteren Spreader (Reflector-Seite)
    // Pro Band entlang der Sehnen 30°→90° und 330°→270°:
    //   Driver-Tail (solid)  | Tip Spacer (dashed) | Reflector-Shoulder (solid)
    //   →  vom 30°-Tip ein Stück Richtung 90° (Driver-Wire läuft "weiter nach unten")
    //   →  kurzer Tip Spacer (PVC-Isolator, gestrichelt mit kleinen Pfeilen)
    //   →  Reflector beginnt und läuft via 90°→150°→210°→270° → symmetrisch zur 330°-Seite
    // Reflector ist SOLID; nur der Tip Spacer ist gestrichelt.

    private var draufsichtBereich: some View {
        SectionCard(title: "Bauplan – Draufsicht (Vogelperspektive)") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let margin: CGFloat = 72
                let cx = W / 2
                let cy = H / 2 + 10
                let radius = min(W - 2 * margin, H - 2 * margin) / 2
                guard maxRadius > 0, radius > 30 else { return }

                let scale = radius / CGFloat(maxRadius)

                // Compass bearings, clockwise from "up" (beam direction = 0°)
                let brgs: [Double] = [30, 90, 150, 210, 270, 330]

                func pt(_ bearing: Double, _ dist: CGFloat) -> CGPoint {
                    let r = bearing * .pi / 180
                    return CGPoint(x: cx + dist * CGFloat(sin(r)),
                                   y: cy - dist * CGFloat(cos(r)))
                }

                // ── 6 Spreader arms ──
                for b in brgs {
                    let tip = pt(b, radius)
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: tip)
                    }, with: .color(.gray.opacity(0.40)), lineWidth: 2)
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: tip.x - 5, y: tip.y - 5, width: 10, height: 10)),
                        with: .color(.gray.opacity(0.45)), lineWidth: 1.5)
                }

                // ── Wire elements: längstes Band zuerst (Hintergrund), kürzeste oben ──
                let sorted = aktiveBaender.sorted { $0.radius_m > $1.radius_m }

                // Sehnen-Fraktionen für Driver-Tail | Tip Spacer | Reflector-Shoulder
                // Markus HB9EIZ (Mai 2026): "Driver läuft viel länger nach unten bis er auf den
                // Reflector trifft, kurz über der horizontalen Mittelachse — Tip-Spacer-Schnur
                // etwas länger zeichnen damit man sie gut sieht."
                // Tip-Spacer-Anteil 18% entspricht dem echten G3TXQ-Verhältnis (24″ / 11′4″).
                let fDriverTail: CGFloat   = 0.75   // Driver-Wire 75% der Sehne über Spreader-Tip hinaus
                let fTipSpacerEnd: CGFloat = 0.93   // Tip Spacer 18% lang (gut sichtbar)

                for band in sorted {
                    let color = bandColors[band.id] ?? .blue
                    let r = CGFloat(band.radius_m) * scale

                    // Hilfspunkte für Tail-Verlängerungen (jeweils Front-Tip → entlang Sehne zum hinteren Nachbarn)
                    let frontL  = pt(30, r)           // Driver-Endpunkt-Ansatz links (im Bild: rechts oben)
                    let frontR  = pt(330, r)          // rechts
                    let backL   = pt(90, r)
                    let backR   = pt(270, r)
                    let driverTailL    = CGPoint(x: frontL.x + (backL.x - frontL.x) * fDriverTail,
                                                 y: frontL.y + (backL.y - frontL.y) * fDriverTail)
                    let driverTailR    = CGPoint(x: frontR.x + (backR.x - frontR.x) * fDriverTail,
                                                 y: frontR.y + (backR.y - frontR.y) * fDriverTail)
                    let reflectorTipL  = CGPoint(x: frontL.x + (backL.x - frontL.x) * fTipSpacerEnd,
                                                 y: frontL.y + (backL.y - frontL.y) * fTipSpacerEnd)
                    let reflectorTipR  = CGPoint(x: frontR.x + (backR.x - frontR.x) * fTipSpacerEnd,
                                                 y: frontR.y + (backR.y - frontR.y) * fTipSpacerEnd)

                    // Treiber: SOLID V, Center → Front-Spreader-Tip → Driver-Tail-Endpunkt
                    // (V mit "Schwanz" auf beiden Seiten — Markus: "Driver laufen weiter nach unten")
                    ctx.stroke(Path { p in
                        p.move(to: driverTailL)
                        p.addLine(to: frontL)
                        p.addLine(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: frontR)
                        p.addLine(to: driverTailR)
                    }, with: .color(color), lineWidth: 2.5)

                    // Reflector: SOLID, 5-Segment-Polylinie:
                    //   reflectorTipL → 90°-Tip → 150°-Tip → 210°-Tip → 270°-Tip → reflectorTipR
                    // (Reflector "läuft auch noch etwas weiter wenige cm" — die zwei Front-Schultern)
                    ctx.stroke(Path { p in
                        p.move(to: reflectorTipL)
                        p.addLine(to: backL)
                        for b in [150.0, 210.0, 270.0] {
                            p.addLine(to: pt(b, r))
                        }
                        p.addLine(to: reflectorTipR)
                    }, with: .color(color), lineWidth: 2.0)

                    // Tip Spacer: SHORT DASHED zwischen Driver-Tail-End und Reflector-Tip
                    // (die einzige gestrichelte Linie in der Skizze)
                    for (a, b) in [(driverTailL, reflectorTipL), (driverTailR, reflectorTipR)] {
                        ctx.stroke(Path { p in
                            p.move(to: a)
                            p.addLine(to: b)
                        }, with: .color(.secondary.opacity(0.85)),
                                   style: StrokeStyle(lineWidth: 1.4, dash: [2, 2]))
                    }

                    // Marker: Driver-Tail-Endpunkt (gefüllt) + Reflector-Tip (offen)
                    for p in [driverTailL, driverTailR] {
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)),
                            with: .color(color.opacity(0.95)))
                    }
                    for p in [reflectorTipL, reflectorTipR] {
                        ctx.stroke(
                            Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)),
                            with: .color(color.opacity(0.85)), lineWidth: 1.3)
                    }
                }

                // ── Band labels at right arm (90°) ──
                for band in sorted {
                    let color = bandColors[band.id] ?? .blue
                    let r = CGFloat(band.radius_m) * scale
                    let lp = pt(90, r)
                    ctx.draw(
                        Text(band.name).font(.system(size: 10, weight: .bold)).foregroundStyle(color),
                        at: CGPoint(x: lp.x + 14, y: lp.y), anchor: .leading)
                }

                // ── Center hub (coax feed point) ──
                let hubR: CGFloat = 8
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - hubR, y: cy - hubR, width: hubR * 2, height: hubR * 2)),
                    with: .color(.accentColor))
                ctx.draw(
                    Text("Koax-Einspeisung").font(.system(size: 8, weight: .bold)).foregroundStyle(Color.accentColor),
                    at: CGPoint(x: cx, y: cy + hubR + 12), anchor: .center)

                // ── Beam direction arrow ──
                let arrowBase = pt(0, radius + 8)
                let arrowTip  = pt(0, radius + 36)
                ctx.stroke(Path { p in
                    p.move(to: arrowBase)
                    p.addLine(to: arrowTip)
                }, with: .color(.red), lineWidth: 2.5)
                ctx.fill(Path { p in
                    p.move(to: arrowTip)
                    p.addLine(to: CGPoint(x: arrowTip.x - 7, y: arrowTip.y + 13))
                    p.addLine(to: CGPoint(x: arrowTip.x + 7, y: arrowTip.y + 13))
                    p.closeSubpath()
                }, with: .color(.red))
                ctx.draw(
                    Text("Strahlungsrichtung").font(.system(size: 10, weight: .bold)).foregroundStyle(.red),
                    at: CGPoint(x: cx, y: arrowTip.y - 12), anchor: .center)

                // ── Annotations ──
                ctx.draw(
                    Text("Spreader").font(.system(size: 9)).foregroundStyle(.secondary),
                    at: CGPoint(x: (cx + pt(90, radius * 0.55).x) / 2,
                                y: pt(90, radius * 0.55).y - 11), anchor: .center)
                ctx.draw(
                    Text("Tip Spacer").font(.system(size: 9)).foregroundStyle(.secondary),
                    at: CGPoint(x: pt(30, radius).x + 14, y: pt(30, radius).y - 10),
                    anchor: .leading)
                ctx.draw(
                    Text("Zentralpfosten").font(.system(size: 8)).foregroundStyle(.secondary),
                    at: CGPoint(x: cx - radius * 0.38, y: cy + 2), anchor: .center)

                // ── Legend ──
                ctx.draw(
                    Text("─── Driver (V vorne)   ─── Reflektor (5-Sehnen-Bogen hinten)   - - - Non-Metallic Tip Spacer (PVC)")
                        .font(.system(size: 8)).foregroundStyle(.secondary),
                    at: CGPoint(x: W / 2, y: H - 10), anchor: .center)
            }
            .frame(height: 420)
        }
    }

    // MARK: Seitenansicht
    //
    // Side view (G3TXQ "bowl" Schüsselform, vgl. WiMo HEX6B Bauanleitung Seite 4/13):
    // Halbkreis-Schüsselrand, pro Band eine horizontale Drahtlinie. 20m am Rand (oben/breit),
    // 6m am Boden (unten/schmal). Band-Radius (horizontal) = band.radius_m, λ-skaliert.
    //
    // Geometry: bowl centered at (cx, rimY), radius R (visuell, nicht maßstabstreu zur Tiefe).
    // Band fraction f = band.radius_m / maxRadius:
    //   lineY     = rimY + R × √(1 − f²)
    //   halfWidth = R × f

    private var seitenansichtBereich: some View {
        SectionCard(title: "Bauplan – Seitenansicht") {
            GeometryReader { geo in
                Canvas { ctx, size in
                    guard !aktiveBaender.isEmpty else { return }
                    let W = size.width, H = size.height
                    let marginL: CGFloat = 60   // left space for vertical dimension arrow
                    let marginR: CGFloat = 72   // right space for band labels
                    let marginT: CGFloat = 28
                    let marginB: CGFloat = 14

                    let maxRadCG = CGFloat(maxRadius)
                    guard maxRadCG > 0 else { return }

                    // Bowl fits the available rectangle
                    let availW = W - marginL - marginR
                    let availH = H - marginT - marginB
                    let R      = min(availW / 2, availH)
                    let cx     = marginL + availW / 2
                    let rimY   = marginT

                    // ── Bowl arc (Bezier semicircle, bottom half) ──
                    // Using cubic Bezier approximation: k = R × 4/3 × tan(π/4) ≈ 0.5523
                    let k = R * 0.5523
                    var bowl = Path()
                    bowl.move(to: CGPoint(x: cx - R, y: rimY))
                    bowl.addCurve(
                        to:       CGPoint(x: cx,     y: rimY + R),
                        control1: CGPoint(x: cx - R, y: rimY + k),
                        control2: CGPoint(x: cx - k, y: rimY + R))
                    bowl.addCurve(
                        to:       CGPoint(x: cx + R, y: rimY),
                        control1: CGPoint(x: cx + k, y: rimY + R),
                        control2: CGPoint(x: cx + R, y: rimY + k))
                    ctx.stroke(bowl, with: .color(.primary.opacity(0.65)), lineWidth: 3)

                    // ── Rim (horizontal closing line at top) ──
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: cx - R, y: rimY))
                        p.addLine(to: CGPoint(x: cx + R, y: rimY))
                    }, with: .color(.primary.opacity(0.65)), lineWidth: 3)

                    // ── Arm-span dimension above the rim ──
                    let dimY = rimY - 12
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: cx - R, y: dimY))
                        p.addLine(to: CGPoint(x: cx + R, y: dimY))
                    }, with: .color(.secondary.opacity(0.45)), lineWidth: 1)
                    for xTick in [cx - R, cx + R] {
                        ctx.stroke(Path { p in
                            p.move(to: CGPoint(x: xTick, y: dimY - 4))
                            p.addLine(to: CGPoint(x: xTick, y: dimY + 4))
                        }, with: .color(.secondary.opacity(0.45)), lineWidth: 1)
                    }
                    ctx.draw(
                        Text(String(format: "⌀ %.0f cm", maxRadius * 200))
                            .font(.system(size: 9)).foregroundStyle(.secondary),
                        at: CGPoint(x: cx, y: dimY - 9), anchor: .center)

                    // ── Center mast (full bowl height) ──
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: cx, y: rimY))
                        p.addLine(to: CGPoint(x: cx, y: rimY + R))
                    }, with: .color(.secondary), lineWidth: 3)

                    // ── Vertical height dimension (just left of bowl arc) ──
                    // Schüssel-Tiefe (vertikaler Sag) ≈ 0.20 × maxRadius (G3TXQ-typische Krümmung)
                    let physDepthM = maxRadius * 0.20
                    let bowlLeft   = cx - R
                    let dimX       = bowlLeft - 14   // 14 px left of bowl edge
                    let dimTop     = rimY
                    let dimBot     = rimY + R

                    // Vertical arrow line
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: dimX, y: dimTop))
                        p.addLine(to: CGPoint(x: dimX, y: dimBot))
                    }, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
                    // Arrowheads (inward-pointing)
                    for (y, dy): (CGFloat, CGFloat) in [(dimTop, 8), (dimBot, -8)] {
                        ctx.stroke(Path { p in
                            p.move(to: CGPoint(x: dimX - 4, y: y + dy))
                            p.addLine(to: CGPoint(x: dimX, y: y))
                            p.addLine(to: CGPoint(x: dimX + 4, y: y + dy))
                        }, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
                    }
                    // Short horizontal tick lines connecting arrow to bowl edge
                    for yTick in [dimTop, dimBot] {
                        ctx.stroke(Path { p in
                            p.move(to: CGPoint(x: dimX, y: yTick))
                            p.addLine(to: CGPoint(x: bowlLeft, y: yTick))
                        }, with: .color(.secondary.opacity(0.35)), lineWidth: 1)
                    }
                    // Label to the left of the arrow at mid-height
                    ctx.draw(
                        Text(String(format: "ca. %.0f cm", physDepthM * 100))
                            .font(.system(size: 9)).foregroundStyle(.secondary),
                        at: CGPoint(x: dimX - 5, y: (dimTop + dimBot) / 2), anchor: .trailing)

                    // ── "band" header ──
                    ctx.draw(
                        Text("band").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary),
                        at: CGPoint(x: cx + 8, y: rimY - 12), anchor: .leading)

                    // ── Horizontal wire lines ──
                    let sorted = aktiveBaender.sorted { $0.radius_m > $1.radius_m }
                    for band in sorted {
                        let color = bandColors[band.id] ?? .blue
                        let f     = CGFloat(band.radius_m) / maxRadCG
                        let lineY = rimY + R * sqrt(max(0, 1 - f * f))
                        let halfW = R * f

                        // Wire line (touches bowl arc on both sides)
                        ctx.stroke(Path { p in
                            p.move(to: CGPoint(x: cx - halfW, y: lineY))
                            p.addLine(to: CGPoint(x: cx + halfW, y: lineY))
                        }, with: .color(color), lineWidth: 1.5)

                        // Label just to the right of the wire endpoint (no overlap)
                        ctx.draw(
                            Text(band.name).font(.system(size: 10, weight: .bold)).foregroundStyle(color),
                            at: CGPoint(x: cx + halfW + 7, y: lineY), anchor: .leading)
                    }
                }
            }
            .frame(height: 320)
        }
    }

    // MARK: Einspeisung (Detail-Skizze + Multiband-Verschaltung)

    private var einspeisungBereich: some View {
        SectionCard(title: "Einspeisung — Center Post mit Band-Anschlüssen") {
            VStack(alignment: .leading, spacing: 12) {
                Canvas { ctx, size in
                    let W = size.width, H = size.height
                    let cx = W / 2

                    // Sortiert: längstes Band oben (niedrigste Frequenz), höchstes unten
                    let sorted = aktiveBaender.sorted { $0.fMHz < $1.fMHz }
                    let n = max(sorted.count, 1)

                    // Center Post Geometrie
                    let postWidth: CGFloat = 22
                    let postTop: CGFloat = 30
                    let postBot: CGFloat = H - 90        // Platz für Choke + Koax-Label
                    let postHeight = postBot - postTop
                    let bandSpacing = postHeight / CGFloat(n + 1)

                    // ── Center Post (Aluminium-Vierkant) ──
                    let postRect = CGRect(x: cx - postWidth/2, y: postTop, width: postWidth, height: postHeight)
                    ctx.fill(Path(roundedRect: postRect, cornerRadius: 2),
                             with: .color(.gray.opacity(0.35)))
                    ctx.stroke(Path(roundedRect: postRect, cornerRadius: 2),
                               with: .color(.gray.opacity(0.7)), lineWidth: 1.5)

                    // ── Pro Band: horizontaler Anschluss + Treiber-V-Schenkel ──
                    for (idx, band) in sorted.enumerated() {
                        let color = bandColors[band.id] ?? .blue
                        let yBand = postTop + bandSpacing * CGFloat(idx + 1)

                        // Schraubposten links/rechts (180° gegenüberliegend)
                        let leftBolt  = CGPoint(x: cx - postWidth/2 - 6, y: yBand)
                        let rightBolt = CGPoint(x: cx + postWidth/2 + 6, y: yBand)

                        // V-Schenkel kommen schräg von oben außen
                        let armSpread: CGFloat = 90 + CGFloat(idx) * 18
                        let armUp: CGFloat     = 18 + CGFloat(idx) * 4
                        let leftEnd  = CGPoint(x: cx - armSpread, y: yBand - armUp)
                        let rightEnd = CGPoint(x: cx + armSpread, y: yBand - armUp)

                        // Treiber-Drähte
                        ctx.stroke(Path { p in
                            p.move(to: leftEnd)
                            p.addLine(to: leftBolt)
                        }, with: .color(color), lineWidth: 2)
                        ctx.stroke(Path { p in
                            p.move(to: rightEnd)
                            p.addLine(to: rightBolt)
                        }, with: .color(color), lineWidth: 2)

                        // Schraubposten als kleine Kreise
                        ctx.fill(Path(ellipseIn: CGRect(x: leftBolt.x - 4, y: leftBolt.y - 4, width: 8, height: 8)),
                                 with: .color(.gray))
                        ctx.stroke(Path(ellipseIn: CGRect(x: leftBolt.x - 4, y: leftBolt.y - 4, width: 8, height: 8)),
                                   with: .color(.primary.opacity(0.6)), lineWidth: 1)
                        ctx.fill(Path(ellipseIn: CGRect(x: rightBolt.x - 4, y: rightBolt.y - 4, width: 8, height: 8)),
                                 with: .color(.gray))
                        ctx.stroke(Path(ellipseIn: CGRect(x: rightBolt.x - 4, y: rightBolt.y - 4, width: 8, height: 8)),
                                   with: .color(.primary.opacity(0.6)), lineWidth: 1)

                        // Band-Label rechts vom Post (im freien Bereich)
                        ctx.draw(
                            Text(band.name).font(.system(size: 11, weight: .bold)).foregroundStyle(color),
                            at: CGPoint(x: rightBolt.x + 12, y: yBand), anchor: .leading)
                    }

                    // ── Koax-Standoffs am Post (kleine Striche links neben dem Post) ──
                    let coaxX = cx - postWidth/2 - 18
                    let standoffY1 = postTop + postHeight * 0.22
                    let standoffY2 = postTop + postHeight * 0.55
                    let standoffY3 = postTop + postHeight * 0.85
                    for sy in [standoffY1, standoffY2, standoffY3] {
                        ctx.stroke(Path { p in
                            p.move(to: CGPoint(x: cx - postWidth/2, y: sy))
                            p.addLine(to: CGPoint(x: coaxX, y: sy))
                        }, with: .color(.gray.opacity(0.7)), lineWidth: 1)
                        ctx.fill(Path(ellipseIn: CGRect(x: coaxX - 3, y: sy - 3, width: 6, height: 6)),
                                 with: .color(.gray))
                    }
                    ctx.draw(Text("Koax-Standoffs").font(.system(size: 8)).foregroundStyle(.secondary),
                             at: CGPoint(x: coaxX - 5, y: standoffY2 - 14), anchor: .trailing)

                    // ── Koax läuft am Post hoch (links neben Post) ──
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: coaxX, y: postTop + 8))
                        p.addLine(to: CGPoint(x: coaxX, y: postBot))
                    }, with: .color(.primary), lineWidth: 4)
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: coaxX, y: postTop + 8))
                        p.addLine(to: CGPoint(x: coaxX, y: postBot))
                    }, with: .color(.gray.opacity(0.7)), lineWidth: 2)

                    // Koax kreuzt unter Post zur Choke-Box mittig
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: coaxX, y: postBot))
                        p.addLine(to: CGPoint(x: cx, y: postBot))
                    }, with: .color(.gray.opacity(0.7)), lineWidth: 2)

                    // ── Mantelwellensperre (Choke) unten am Post ──
                    let chokeY = postBot + 4
                    let chokeRect = CGRect(x: cx - 32, y: chokeY, width: 64, height: 22)
                    ctx.fill(Path(roundedRect: chokeRect, cornerRadius: 4),
                             with: .color(.orange.opacity(0.18)))
                    ctx.stroke(Path(roundedRect: chokeRect, cornerRadius: 4),
                               with: .color(.orange), lineWidth: 1.8)
                    ctx.draw(Text("1:1 Choke").font(.system(size: 9, weight: .bold)).foregroundStyle(.orange),
                             at: CGPoint(x: cx, y: chokeY + 11), anchor: .center)

                    // ── Koax nach unten zum Shack ──
                    let coaxBot = H - 14
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: cx, y: chokeY + 22))
                        p.addLine(to: CGPoint(x: cx, y: coaxBot))
                    }, with: .color(.primary), lineWidth: 4)
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: cx, y: chokeY + 22))
                        p.addLine(to: CGPoint(x: cx, y: coaxBot))
                    }, with: .color(.gray.opacity(0.7)), lineWidth: 2)
                    ctx.draw(Text("50 Ω Koax → Shack").font(.system(size: 10, weight: .semibold)).foregroundStyle(.primary),
                             at: CGPoint(x: cx + 8, y: coaxBot - 5), anchor: .leading)

                    // ── Center Post Beschriftung ──
                    ctx.draw(Text("Center Post").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary),
                             at: CGPoint(x: cx, y: postTop - 12), anchor: .center)
                    ctx.draw(Text("Aluminium-Vierkant").font(.system(size: 8)).foregroundStyle(.secondary),
                             at: CGPoint(x: cx, y: postTop - 2), anchor: .center)

                    // ── Hinweis "Bolzen 180°" ──
                    if let firstBand = sorted.first {
                        let yFirst = postTop + bandSpacing
                        ctx.draw(Text("Schraubposten")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary),
                                 at: CGPoint(x: cx - postWidth/2 - 80, y: yFirst), anchor: .leading)
                        ctx.draw(Text("(180° gegenüberliegend)")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.secondary),
                                 at: CGPoint(x: cx - postWidth/2 - 80, y: yFirst + 9), anchor: .leading)
                        _ = firstBand
                    }
                }
                .frame(height: 360)

                Text("**Center Post mit Band-Anschlüssen:** Vertikaler Aluminium-Vierkant-Post mit pro Band einem horizontalen Anschluss aus zwei Schraubposten (180° gegenüberliegend). Die beiden Treiber-Schenkel jedes Bands werden direkt an diese Schrauben angeschraubt — kein zentraler Knoten am Hub. Das **Koax läuft seitlich am Post hoch** (mit Standoffs zur Vermeidung kapazitiver Kopplung zum Mast) und ist intern an alle Band-Anschlüsse parallel geführt. **Mantelwellensperre (1:1 Choke)** sitzt unten am Post-Fuß. Im Resonanzfall ist nur das aktive Band niederohmig (~50 Ω), andere Bänder sind off-resonance hochohmig und stören kaum.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Zusammenfassung

    private var zusammenfassungBereich: some View {
        SectionCard(title: "Zusammenfassung") {
            VStack(spacing: 4) {
                ResultRow(label: "Anzahl Bänder",         value: "\(aktiveBaender.count)")
                ResultRow(label: "Niedrigstes Band",      value: referenzBand.map { "\($0.name) (\(String(format: "%.3f MHz", $0.fMHz)))" } ?? "–")
                ResultRow(label: "Spreader-Radius (horiz.)", value: String(format: "%.2f m × 6 Stück", maxRadius), highlight: true)
                ResultRow(label: "Pole-Länge (Bogen)",    value: String(format: "ca. %.2f m (≈ π/2 × Radius, Schüsselform)", maxRadius * .pi / 2))
                ResultRow(label: "Material-Empfehlung",   value: spreizerEmpfehlung)
                ResultRow(label: "Hexagon-Durchmesser",   value: String(format: "%.2f m (horizontal)", maxRadius * 2))
                if let ref = referenzBand {
                    ResultRow(label: "½ Driver \(ref.name)",   value: String(format: "%.3f m (Drahtlänge)", ref.driver_half_m))
                    ResultRow(label: "Reflektor \(ref.name)",  value: String(format: "%.3f m (Drahtlänge)", ref.reflector_m))
                    ResultRow(label: "Tip Spacer \(ref.name)", value: String(format: "%.3f m (PVC-Isolator)", ref.tip_spacer_m))
                }
                ResultRow(label: "Speisepunkt-Impedanz",  value: "≈ 50 Ω (direktgekoppelt)")
                ResultRow(label: "Mantelwellensperre",    value: "1:1 Choke-Balun direkt am Speisepunkt")
                ResultRow(label: "Gewinn",                value: "≈ 3,5–3,8 dBd (laut WiMo HEX6B Datenblatt)")
            }
        }
    }

    private var spreizerEmpfehlung: String {
        // Physische Pole-Länge entlang dem Bogen (≈ π/2 × Horizontal-Radius bei Halbkreis-Schüssel).
        let poleM = maxRadius * .pi / 2
        if poleM <= 5.5 {
            return "5,4 m konische Glasfaserstäbe (Spiderbeam-Lieferant) — passend für 20m+"
        } else if poleM <= 6.5 {
            return "6 m Glasfaserstäbe (Verstärkung am Knick empfohlen)"
        } else if poleM <= 8.0 {
            return "7,8 m konische Stäbe (z. B. 40m-Hexbeam-Set)"
        } else {
            return "Maßanfertigung erforderlich"
        }
    }

    // MARK: Hinweis

    private var hinweisBereich: some View {
        SectionCard(title: "Hinweis") {
            Text("G3TXQ Broadband Hexbeam: 6 Spreader im 60°-Abstand, alle gleich lang (dimensioniert für das niedrigste Band). Pro Band ein eigenes Wire-Set (Driver + Reflector) auf einem eigenen Eyelet entlang dem Spreader — niedere Frequenz = größerer Radius (am Spreader-Tip), höhere Frequenz = kleinerer Radius (innen). Driver: V vorne (Apex am Center-Post), beide Enden laufen am Front-Spreader-Tip 30°/330° noch ein Stück Richtung hinterem Nachbar-Spreader weiter. Reflector: durchgehender 5-Sehnen-Bogen hinten — beginnt knapp vor dem rechten Driver-Ende, läuft via 90°→150°→210°→270° um die Rückseite, endet knapp vor dem linken Driver-Ende. Tip Spacer (PVC-Isolator, 24″): kurze gestrichelte Verbindung zwischen Driver-Ende und Reflector-Anfang an jedem Front-Spreader, mechanisch verbunden, elektrisch isoliert. Werte G3TXQ-konform (referenziert aus WiMo EAntenna HEX6B Bauanleitung, 20m-Maße: ½ Driver 214″, Reflector 404″, Tip Spacer 24″).")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
