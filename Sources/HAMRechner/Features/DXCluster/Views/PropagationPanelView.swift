import SwiftUI

// MARK: - Propagation Panel (right sidebar)

struct PropagationPanelView: View {
    let propagation: PropagationData
    let bandMatrix:  [[Int]]       // HEATMAP_BANDS × CONTINENTS
    let theme:       AppTheme

    @State private var heatmapMinutes = 60

    private let gold = Color(red: 1.0, green: 0.82, blue: 0.2)

    var body: some View {
        VStack(spacing: 0) {
            propagationSection
            Divider()
            bandActivitySection
        }
        .background(theme.bgPanel)
    }

    // MARK: Propagation gauges

    private var propagationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "cloud.bolt.fill")
                    .foregroundStyle(gold)
                Text("Propagation")
                    .font(.headline)
                    .foregroundStyle(gold)
            }

            HStack(spacing: 4) {
                SemiCircleGauge(
                    value:    Double(propagation.sfi ?? 0),
                    maxValue: 300,
                    label:    "Solar Activity",
                    sublabel: "SFI: \(propagation.sfi.map(String.init) ?? "?")"
                )
                SemiCircleGauge(
                    value:    propagation.kp ?? 0,
                    maxValue: 9,
                    label:    "Magnetic Activity",
                    sublabel: "K: \(propagation.kp.map { String(format: "%.1f", $0) } ?? "?")  A: \(propagation.aIndex.map(String.init) ?? "?")"
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
    }

    // MARK: Band Activity heatmap

    private var bandActivitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(gold)
                Text("Band Activity")
                    .font(.headline)
                    .foregroundStyle(gold)
                Spacer()
                Picker("", selection: $heatmapMinutes) {
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("60 min").tag(60)
                }
                .pickerStyle(.menu)
                .frame(width: 80)
            }

            // Continent headers
            HStack(spacing: 2) {
                Text("").frame(width: 36)
                ForEach(CONTINENTS, id: \.self) { c in
                    Text(c)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Heatmap rows
            ForEach(Array(HEATMAP_BANDS.enumerated()), id: \.offset) { bi, band in
                HStack(spacing: 2) {
                    Text(band)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(bandColor(for: band))
                        .frame(width: 36, alignment: .trailing)
                    ForEach(Array(CONTINENTS.enumerated()), id: \.offset) { ci, _ in
                        let count = bi < bandMatrix.count && ci < (bandMatrix[bi].count) ? bandMatrix[bi][ci] : 0
                        HeatCell(count: count, theme: theme)
                    }
                }
            }
        }
        .padding(12)
    }
}

// MARK: - SemiCircle Gauge

struct SemiCircleGauge: View {
    let value:    Double
    let maxValue: Double
    let label:    String
    let sublabel: String
    var invertColors: Bool = false  // kept for API compat

    private var ratio: Double { max(0, min(1, value / maxValue)) }
    private let gold = Color(red: 1.0, green: 0.82, blue: 0.2)

    var body: some View {
        VStack(spacing: 3) {
            Canvas { ctx, size in
                let cx: CGFloat = size.width / 2
                let cy: CGFloat = size.height - 6
                let lw: CGFloat = 15
                let r:  CGFloat = min(cx - 2, cy - lw / 2 - 2)

                // Gradient arc — 80 segments green → yellow → orange → red
                for i in 0..<80 {
                    let t0 = Double(i)     / 80.0
                    let t1 = Double(i + 1) / 80.0
                    var seg = Path()
                    seg.addArc(center: CGPoint(x: cx, y: cy),
                               radius: r,
                               startAngle: .degrees(180 + t0 * 180),
                               endAngle:   .degrees(180 + t1 * 180),
                               clockwise: false)
                    ctx.stroke(seg, with: .color(arcGradientColor(t: t0)),
                               style: StrokeStyle(lineWidth: lw, lineCap: .butt))
                }

                // Tick marks (9 ticks at even intervals)
                for i in 0...8 {
                    let t = Double(i) / 8.0
                    let a = CGFloat((180 + t * 180) * .pi / 180)
                    var tick = Path()
                    tick.move(to:    CGPoint(x: cx + (r - lw / 2 - 2) * cos(a),
                                            y: cy + (r - lw / 2 - 2) * sin(a)))
                    tick.addLine(to: CGPoint(x: cx + (r + lw / 2 + 3) * cos(a),
                                            y: cy + (r + lw / 2 + 3) * sin(a)))
                    ctx.stroke(tick, with: .color(.black.opacity(0.6)), lineWidth: 2)
                }

                // Needle — white line from center to arc
                let na = CGFloat((180 + ratio * 180) * .pi / 180)
                var ndl = Path()
                ndl.move(to:    CGPoint(x: cx, y: cy))
                ndl.addLine(to: CGPoint(x: cx + r * cos(na), y: cy + r * sin(na)))
                ctx.stroke(ndl, with: .color(.white),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                // Center dot — gold
                let dr: CGFloat = 6
                let dot = Path(ellipseIn: CGRect(x: cx - dr, y: cy - dr,
                                                 width: dr * 2, height: dr * 2))
                ctx.fill(dot,   with: .color(Color(red: 1.0, green: 0.82, blue: 0.2)))
                ctx.stroke(dot, with: .color(.black.opacity(0.35)), lineWidth: 1)
            }
            .frame(width: 110, height: 72)

            Text(value > 0 ? String(format: "%.0f", value) : "–")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(gold)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(sublabel)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // Green (left/low) → Yellow → Orange → Red (right/high)
    private func arcGradientColor(t: Double) -> Color {
        switch t {
        case ..<0.25:
            let f = t / 0.25
            return Color(red: f * 0.85, green: 0.75, blue: 0.0)
        case ..<0.50:
            let f = (t - 0.25) / 0.25
            return Color(red: 0.85 + f * 0.15, green: 0.75 - f * 0.15, blue: 0.0)
        case ..<0.75:
            let f = (t - 0.50) / 0.25
            return Color(red: 1.0, green: 0.60 - f * 0.25, blue: 0.0)
        default:
            let f = (t - 0.75) / 0.25
            return Color(red: 1.0 - f * 0.25, green: 0.35 - f * 0.35, blue: 0.0)
        }
    }
}

// MARK: - Heat Cell

struct HeatCell: View {
    let count: Int
    let theme: AppTheme

    private var bg: Color {
        if count == 0  { return theme.bgSubPanel }
        if count < 5   { return Color(hex: "#FFFF88") }
        if count < 20  { return Color(hex: "#FFA500") }
        if count < 50  { return Color(hex: "#CC2200") }
        return Color(hex: "#880000")
    }
    private var fg: Color {
        count > 0 ? Color(hex: "#111111") : theme.textDim
    }

    var body: some View {
        Text(count > 0 ? "\(count)" : "")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, minHeight: 16)
            .background(bg)
            .cornerRadius(2)
    }
}
