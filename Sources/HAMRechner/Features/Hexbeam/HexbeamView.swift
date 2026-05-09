import SwiftUI

// MARK: - Model

struct HexbeamBand: Identifiable {
    let id: String
    let name: String
    let fMHz: Double
    let istWARC: Bool
    var aktiv: Bool

    var lambda: Double      { 300.0 / fMHz }
    var treiber_m: Double   { lambda * 0.440 }
    var reflektor_m: Double { lambda * 0.495 }
    var arm_m: Double       { lambda * 0.260 }
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
    private var maxArm: Double               { aktiveBaender.map(\.arm_m).max() ?? 0 }

    private let bandColors: [String: Color] = [
        "40m": .purple, "30m": .indigo, "20m": .blue, "17m": .cyan,
        "15m": .green,  "12m": .yellow, "10m": .orange, "6m": .red, "2m": .pink
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                bandWahl
                if !aktiveBaender.isEmpty {
                    masseBereich
                    draufsichtBereich
                    seitenansichtBereich
                    zusammenfassungBereich
                }
                hinweisBereich
            }
            .padding(24)
        }
        .navigationTitle("Hexbeam")
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
        SectionCard(title: "Maße pro Band") {
            VStack(spacing: 0) {
                HStack {
                    Text("Band")      .font(.caption).bold().foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
                    Text("Frequenz") .font(.caption).bold().foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    Text("Treiber")  .font(.caption).bold().foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    Text("Reflektor").font(.caption).bold().foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    Text("Arm")      .font(.caption).bold().foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
                .padding(.vertical, 6)
                Divider()
                ForEach(aktiveBaender) { band in
                    HStack {
                        Text(band.name).font(.callout).bold()
                            .foregroundStyle(bandColors[band.id] ?? .primary)
                            .frame(width: 44, alignment: .leading)
                        Text(String(format: "%.3f MHz",  band.fMHz))       .font(.callout).frame(maxWidth: .infinity)
                        Text(String(format: "%.3f m",    band.treiber_m))  .font(.callout).frame(maxWidth: .infinity)
                        Text(String(format: "%.3f m",    band.reflektor_m)).font(.callout).frame(maxWidth: .infinity)
                        Text(String(format: "%.3f m",    band.arm_m))      .font(.callout).frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
    }

    // MARK: Draufsicht
    //
    // Geometry: all bands share the same 6 arm directions.
    // Each band's wires run almost completely around the hexagon (open only at front).
    // Driver (solid): front V-shape, arm0(30°) → coax-center → arm5(330°)
    // Reflector (dashed): 5-sided back polygon, arm5 → arm4 → arm3 → arm2 → arm1 → arm0
    // Bands differ only in scale (arm_m). Draw largest band first (back of stack).

    private var draufsichtBereich: some View {
        SectionCard(title: "Bauplan – Draufsicht (Vogelperspektive)") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let margin: CGFloat = 72
                let cx = W / 2
                let cy = H / 2 + 10
                let radius = min(W - 2 * margin, H - 2 * margin) / 2
                guard maxArm > 0, radius > 30 else { return }

                let armScale = radius / CGFloat(maxArm)

                // Compass bearings, clockwise from "up" (beam direction = 0°)
                // arm0=30° upper-right, arm1=90° right, arm2=150° lower-right,
                // arm3=210° lower-left, arm4=270° left, arm5=330° upper-left
                let brgs: [Double] = [30, 90, 150, 210, 270, 330]

                func pt(_ bearing: Double, _ dist: CGFloat) -> CGPoint {
                    let r = bearing * .pi / 180
                    return CGPoint(x: cx + dist * CGFloat(sin(r)),
                                   y: cy - dist * CGFloat(cos(r)))
                }

                // ── 6 Spreader arms (to max arm radius) ──
                for b in brgs {
                    let tip = pt(b, radius)
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: tip)
                    }, with: .color(.gray.opacity(0.40)), lineWidth: 2)
                    // Arm tip circle = Tip Spacer position
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: tip.x - 5, y: tip.y - 5, width: 10, height: 10)),
                        with: .color(.gray.opacity(0.45)), lineWidth: 1.5)
                }

                // ── Wire elements: largest band first so smaller bands render on top ──
                let sorted = aktiveBaender.sorted { $0.arm_m > $1.arm_m }

                for band in sorted {
                    let color = bandColors[band.id] ?? .blue
                    let r = CGFloat(band.arm_m) * armScale

                    // Reflektor: dashed 5-sided polygon going around the back
                    // arm5(330°)→arm4(270°)→arm3(210°)→arm2(150°)→arm1(90°)→arm0(30°)
                    ctx.stroke(Path { p in
                        p.move(to: pt(330, r))
                        for b in [270.0, 210.0, 150.0, 90.0, 30.0] {
                            p.addLine(to: pt(b, r))
                        }
                    }, with: .color(color.opacity(0.60)),
                               style: StrokeStyle(lineWidth: 1.8, dash: [5, 3]))

                    // Treiber: solid V, front sector → center → other front arm
                    // arm0(30°) → coax-center → arm5(330°)
                    ctx.stroke(Path { p in
                        p.move(to: pt(30, r))
                        p.addLine(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: pt(330, r))
                    }, with: .color(color), lineWidth: 2.5)

                    // Schnur (structural cord, not antenna wire): thin neutral line
                    // connecting the two front tip spacers straight across
                    ctx.stroke(Path { p in
                        p.move(to: pt(30, r))
                        p.addLine(to: pt(330, r))
                    }, with: .color(.secondary.opacity(0.45)),
                               style: StrokeStyle(lineWidth: 0.8, dash: [3, 4]))

                    // Tip spacer dots at the two front arm-tip junctions
                    for b in [30.0, 330.0] {
                        let tp = pt(b, r)
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: tp.x - 4, y: tp.y - 4, width: 8, height: 8)),
                            with: .color(color.opacity(0.85)))
                    }
                }

                // ── Band labels at right arm (90°) ──
                for band in sorted {
                    let color = bandColors[band.id] ?? .blue
                    let r = CGFloat(band.arm_m) * armScale
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
                    Text("─── Treiber (Driver)   - - - Reflektor   ● Tip Spacer")
                        .font(.system(size: 9)).foregroundStyle(.secondary),
                    at: CGPoint(x: W / 2, y: H - 10), anchor: .center)
            }
            .frame(height: 420)
        }
    }

    // MARK: Seitenansicht
    //
    // Side view matching reference Image #5:
    // Semicircular bowl outline (Bezier approximation, avoids addArc convention issues).
    // Each band = one horizontal straight line whose endpoints touch the bowl arc.
    // Largest arm (lowest freq) is at the rim (top, widest).
    // Smaller bands are lower inside the bowl.
    // Labels right of center mast.
    //
    // Geometry: bowl centered at (cx, rimY), radius R.
    // Band arm fraction f = band.arm_m / maxArm:
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

                    let maxArmCG = CGFloat(maxArm)
                    guard maxArmCG > 0 else { return }

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
                        Text(String(format: "⌀ %.0f cm", maxArm * 200))
                            .font(.system(size: 9)).foregroundStyle(.secondary),
                        at: CGPoint(x: cx, y: dimY - 9), anchor: .center)

                    // ── Center mast (full bowl height) ──
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: cx, y: rimY))
                        p.addLine(to: CGPoint(x: cx, y: rimY + R))
                    }, with: .color(.secondary), lineWidth: 3)

                    // ── Vertical height dimension (just left of bowl arc) ──
                    // Physical construction depth ≈ 0.20 × maxArm (G3TXQ typical sag ratio)
                    let physDepthM = maxArm * 0.20
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
                    let sorted = aktiveBaender.sorted { $0.arm_m > $1.arm_m }
                    for band in sorted {
                        let color = bandColors[band.id] ?? .blue
                        let f     = CGFloat(band.arm_m) / maxArmCG
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

    // MARK: Zusammenfassung

    private var zusammenfassungBereich: some View {
        SectionCard(title: "Zusammenfassung") {
            VStack(spacing: 4) {
                ResultRow(label: "Anzahl Bänder",       value: "\(aktiveBaender.count)")
                ResultRow(label: "Niedrigstes Band",     value: referenzBand.map { "\($0.name) (\(String(format: "%.3f MHz", $0.fMHz)))" } ?? "–")
                ResultRow(label: "Längster Arm",         value: String(format: "%.3f m", maxArm),      highlight: true)
                ResultRow(label: "Gesamtdurchmesser",    value: String(format: "%.3f m", maxArm * 2),  highlight: true)
                if let ref = referenzBand {
                    ResultRow(label: "Treiber \(ref.name)",   value: String(format: "%.3f m", ref.treiber_m))
                    ResultRow(label: "Reflektor \(ref.name)", value: String(format: "%.3f m", ref.reflektor_m))
                }
                ResultRow(label: "Speisepunkt-Impedanz", value: "≈ 50 Ω (direktgekoppelt)")
                ResultRow(label: "Gewinn",               value: "≈ 5–6 dBd (HF-Bänder)")
            }
        }
    }

    // MARK: Hinweis

    private var hinweisBereich: some View {
        SectionCard(title: "Hinweis") {
            Text("G3TXQ Hexbeam: 6 Speicherarme (Spreader) im 60°-Abstand. Pro Band laufen die Drähte fast vollständig um die Antenne herum – nur in Strahlungsrichtung (vorne) ist eine Lücke. Der Treiber (solid) bildet ein V zur Koax-Einspeisung hin. Der Reflektor (gestrichelt) läuft als 5-seitiger Polygonzug um den Rücken der Antenne. Formeln: Treiber = 0.44λ, Reflektor = 0.495λ, Arm = 0.26λ. Tip Spacer = kleine Isolatoren an den Armspitzen.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
