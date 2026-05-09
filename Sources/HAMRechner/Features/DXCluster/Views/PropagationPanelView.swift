import SwiftUI

// MARK: - Propagation Panel (right sidebar)

struct PropagationPanelView: View {
    let propagation: PropagationData
    let bandMatrix:  [[Int]]       // HEATMAP_BANDS × CONTINENTS
    let theme:       AppTheme

    @State private var heatmapMinutes = 60

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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(theme.accentBlue)
                Text("Propagation")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
            }

            HStack(spacing: 16) {
                SemiCircleGauge(
                    value: Double(propagation.sfi ?? 0),
                    maxValue: 300,
                    label: "Solar Activity",
                    sublabel: "SFI: \(propagation.sfi.map(String.init) ?? "?")",
                    theme: theme
                )
                SemiCircleGauge(
                    value: propagation.kp ?? 0,
                    maxValue: 9,
                    label: "Magnetic Activity",
                    sublabel: "K: \(propagation.kp.map { String(format: "%.1f", $0) } ?? "?")  A: \(propagation.aIndex.map(String.init) ?? "?")",
                    theme: theme,
                    invertColors: true   // low Kp = good (green)
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
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(theme.accentBlue)
                Text("Band Activity")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
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
    let value:        Double
    let maxValue:     Double
    let label:        String
    let sublabel:     String
    let theme:        AppTheme
    var invertColors: Bool = false

    private var ratio: Double { max(0, min(1, value / maxValue)) }

    private var arcColor: Color {
        let r = invertColors ? (1 - ratio) : ratio
        if r < 0.33 { return invertColors ? theme.accentGreen : theme.accentRed }
        if r < 0.66 { return theme.accentYellow }
        return invertColors ? theme.accentRed : theme.accentGreen
    }

    var body: some View {
        VStack(spacing: 4) {
            Canvas { ctx, size in
                let cx = size.width / 2
                let cy = size.height
                let r  = min(cx, cy) * 0.9

                // Background arc
                var bg = Path()
                bg.addArc(center: CGPoint(x: cx, y: cy),
                          radius: r, startAngle: .degrees(180),
                          endAngle: .degrees(0), clockwise: false)
                ctx.stroke(bg, with: .color(theme.separator), lineWidth: 8)

                // Value arc
                let endDeg = 180 + ratio * 180
                var fg = Path()
                fg.addArc(center: CGPoint(x: cx, y: cy),
                          radius: r, startAngle: .degrees(180),
                          endAngle: .degrees(endDeg), clockwise: false)
                ctx.stroke(fg, with: .color(arcColor), lineWidth: 8)

                // Needle
                let angle = (180 + ratio * 180) * .pi / 180
                let nx = cx + (r - 4) * cos(angle)
                let ny = cy + (r - 4) * sin(angle)
                var needle = Path()
                needle.move(to: CGPoint(x: cx, y: cy))
                needle.addLine(to: CGPoint(x: nx, y: ny))
                ctx.stroke(needle, with: .color(theme.textPrimary), lineWidth: 2)

                // Center dot
                let dot = Path(ellipseIn: CGRect(x: cx-4, y: cy-4, width: 8, height: 8))
                ctx.fill(dot, with: .color(theme.textPrimary))
            }
            .frame(width: 90, height: 50)

            Text(String(format: "%.0f", value))
                .font(.title3.bold())
                .foregroundStyle(arcColor)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary)
            Text(sublabel)
                .font(.system(size: 9))
                .foregroundStyle(theme.textDim)
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
