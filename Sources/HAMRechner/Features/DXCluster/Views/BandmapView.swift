import SwiftUI

// MARK: - Mode colors

private let MODE_COLORS: [String: Color] = [
    "FT8":  Color(hex: "#00ff88"),
    "FT4":  Color(hex: "#00ccff"),
    "CW":   Color(hex: "#ff6600"),
    "SSB":  Color(hex: "#ffcc00"),
    "RTTY": Color(hex: "#ff44ff"),
    "PSK31":Color(hex: "#44ffff"),
    "PSK63":Color(hex: "#44ffff"),
    "WSPR": Color(hex: "#aaaaff"),
    "JS8":  Color(hex: "#88ff44"),
    "FM":   Color(hex: "#ff8888"),
    "AM":   Color(hex: "#ffaa44"),
]
private let MODE_COLOR_DEFAULT = Color(hex: "#cccccc")
private func modeColor(_ mode: String) -> Color { MODE_COLORS[mode] ?? MODE_COLOR_DEFAULT }

// MARK: - BandmapView

struct BandmapView: View {
    let spots:  [DXSpot]
    let theme:  AppTheme
    /// Wenn gesetzt: Band ist fest, Band-Switcher in der Toolbar wird
    /// ausgeblendet. Wird von BandmapWindowView (Pop-up-Fenster) genutzt,
    /// damit ein "20m"-Fenster auch 20m bleibt.
    var fixedBand: String? = nil

    @State private var selectedBand   = "20m"
    @State private var timeMinutes    = 30
    @State private var selectedModes  = Set<String>()   // empty = all
    @State private var selectedSpot:  DXSpot? = nil

    private let quickBands = ["160m","80m","40m","20m","17m","15m","10m","6m"]
    private let padX:    CGFloat = 60
    private let dotR:    CGFloat = 5
    private let stepY:   CGFloat = 18
    private let minGap:  CGFloat = 54

    // Spots filtered to current band + time + mode
    private var filteredSpots: [DXSpot] {
        let cutoff = Date().addingTimeInterval(-Double(timeMinutes) * 60)
        return spots.filter {
            $0.band == selectedBand &&
            $0.timestamp >= cutoff &&
            (selectedModes.isEmpty || selectedModes.contains($0.mode))
        }
    }

    // Find band frequency range
    private var bandRange: (Double, Double) {
        BANDS.first(where: { $0.name == selectedBand }).map { ($0.low, $0.high) }
            ?? (14000, 14350)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ZStack(alignment: .topTrailing) {
                canvasArea
                legendOverlay
                    .padding(10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.bgApp)
            infoBar
        }
        .background(theme.bgApp)
        .onAppear {
            if let fb = fixedBand, !fb.isEmpty {
                selectedBand = fb
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Band-Switcher: nur im Hauptfenster sichtbar. In den
                // Pop-up-Bandmaps ist das Band fest (fixedBand != nil) —
                // dort zeigen wir stattdessen das aktive Band als Label.
                if let fb = fixedBand {
                    Text(fb)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.accentBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(theme.bgCard)
                        .cornerRadius(4)
                        .padding(.leading, 8)
                } else {
                    Text("Band:")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .padding(.leading, 8)

                    ForEach(quickBands, id: \.self) { band in
                        Button(band) { selectedBand = band }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedBand == band ? theme.accentBlue : theme.bgCard)
                            .foregroundStyle(selectedBand == band ? .white : theme.textPrimary)
                            .font(.system(size: 11, weight: .bold))
                            .cornerRadius(4)
                    }
                }

                Divider().frame(height: 20).padding(.horizontal, 4)

                Picker("", selection: $timeMinutes) {
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("60 min").tag(60)
                    Text("Alle").tag(9999)
                }
                .pickerStyle(.menu)
                .frame(width: 100)

                Spacer()

                Text("\(filteredSpots.count) Spots")
                    .font(.caption.bold())
                    .foregroundStyle(theme.accentBlue)
                    .padding(.trailing, 8)
            }
            .padding(.vertical, 4)
        }
        .background(theme.bgPanel)
    }

    // MARK: - Canvas area

    private var canvasArea: some View {
        GeometryReader { geo in
            let size   = geo.size
            let axisY  = size.height - 55
            let (fMin, fMax) = bandRange
            let span   = max(fMax - fMin, 1)
            let drawW  = size.width - 2 * padX
            let maxLvl = max(6, Int((axisY - 25) / stepY))
            let f2x    = { (f: Double) -> CGFloat in padX + CGFloat((f - fMin) / span) * drawW }

            let sorted = filteredSpots.sorted { $0.frequency < $1.frequency }
            let xs     = sorted.map { f2x($0.frequency) }
            let levels = assignLevels(xs, maxLevels: maxLvl)
            let tStep  = tickStep(fMax - fMin)

            Canvas { ctx, sz in
                // Grid lines + axis
                let axisPath = Path { p in
                    p.move(to: CGPoint(x: padX, y: axisY))
                    p.addLine(to: CGPoint(x: sz.width - padX, y: axisY))
                }
                ctx.stroke(axisPath, with: .color(.gray.opacity(0.5)), lineWidth: 2)

                // Ticks
                var f = (fMin / tStep + 1).rounded(.down) * tStep
                while f <= fMax {
                    let x = f2x(f)
                    var tick = Path()
                    tick.move(to: CGPoint(x: x, y: axisY))
                    tick.addLine(to: CGPoint(x: x, y: axisY + 7))
                    ctx.stroke(tick, with: .color(.gray.opacity(0.4)), lineWidth: 1)

                    var grid = Path()
                    grid.move(to: CGPoint(x: x, y: 10))
                    grid.addLine(to: CGPoint(x: x, y: axisY))
                    ctx.stroke(grid, with: .color(.gray.opacity(0.08)),
                               style: StrokeStyle(lineWidth: 1, dash: [3, 5]))

                    ctx.draw(Text(String(Int(f)))
                                .font(.system(size: 8))
                                .foregroundStyle(Color.gray.opacity(0.7)),
                             at: CGPoint(x: x, y: axisY + 16), anchor: .center)
                    f += tStep
                }

                // Axis label
                ctx.draw(Text("Frequenz (kHz)  —  \(selectedBand)  —  \(sorted.count) Spots")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.gray.opacity(0.6)),
                         at: CGPoint(x: sz.width / 2, y: axisY + 34), anchor: .center)

                // Empty state
                if sorted.isEmpty {
                    ctx.draw(Text("Keine Spots auf \(selectedBand)")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.gray.opacity(0.4)),
                             at: CGPoint(x: sz.width / 2, y: axisY / 2), anchor: .center)
                    return
                }

                // Spots
                for (i, spot) in sorted.enumerated() {
                    let sx     = xs[i]
                    let lvl    = levels[i]
                    let color  = modeColor(spot.mode)
                    let labelY = max(14, axisY - dotR - 8 - CGFloat(lvl) * stepY)

                    // Dashed line dot → label
                    var line = Path()
                    line.move(to: CGPoint(x: sx, y: axisY - dotR - 1))
                    line.addLine(to: CGPoint(x: sx, y: labelY + 2))
                    ctx.stroke(line, with: .color(color.opacity(0.5)),
                               style: StrokeStyle(lineWidth: 1, dash: [2, 3]))

                    // Dot
                    let dotRect = CGRect(x: sx - dotR, y: axisY - dotR,
                                         width: dotR*2, height: dotR*2)
                    let isSelected = selectedSpot?.id == spot.id
                    ctx.fill(Path(ellipseIn: dotRect), with: .color(color))
                    if isSelected {
                        ctx.stroke(Path(ellipseIn: dotRect.insetBy(dx: -2, dy: -2)),
                                   with: .color(.white), lineWidth: 2)
                    }

                    // Call label
                    ctx.draw(Text(spot.dxCall)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(color),
                             at: CGPoint(x: sx, y: labelY), anchor: .bottom)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { val in
                    let tap = val.location
                    var best: (DXSpot, CGFloat)? = nil
                    for (i, spot) in sorted.enumerated() {
                        let dx = abs(tap.x - xs[i])
                        let dotDy = abs(tap.y - axisY)
                        if dx < 20 && (dotDy < 15 || abs(tap.y - (axisY - CGFloat(levels[i]) * stepY - 20)) < 15) {
                            if best == nil || dx < best!.1 { best = (spot, dx) }
                        }
                    }
                    selectedSpot = best?.0
                }
            )
        }
    }

    // MARK: - Legend

    private var legendOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(MODE_COLORS.keys.sorted()), id: \.self) { mode in
                HStack(spacing: 4) {
                    Circle()
                        .fill(MODE_COLORS[mode] ?? MODE_COLOR_DEFAULT)
                        .frame(width: 8, height: 8)
                    Text(mode)
                        .font(.system(size: 9))
                        .foregroundStyle(MODE_COLORS[mode] ?? MODE_COLOR_DEFAULT)
                }
            }
        }
        .padding(6)
        .background(theme.bgCard.opacity(0.85))
        .cornerRadius(6)
    }

    // MARK: - Info bar

    private var infoBar: some View {
        HStack {
            if let spot = selectedSpot {
                Group {
                    Text("DX: ").bold() + Text(spot.dxCall)
                    Text("  |  \(spot.displayFreq) kHz")
                    Text("  |  \(spot.mode)")
                    Text("  |  \(spot.country)")
                    Text("  |  \(spot.comment.prefix(40))")
                    Text("  |  Spotter: \(spot.spotter)")
                    if !spot.spotTime.isEmpty { Text("  |  \(spot.spotTime)") }
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.accentBlue)
            } else {
                Text("Klicke auf einen Spot für Details")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textDim)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.bgApp)
    }

    // MARK: - Helpers

    private func assignLevels(_ xs: [CGFloat], maxLevels: Int) -> [Int] {
        var levels = [Int](repeating: 0, count: xs.count)
        for i in xs.indices {
            var lvl = 0
            while lvl < maxLevels {
                let conflict = (0..<i).contains { j in
                    levels[j] == lvl && abs(xs[i] - xs[j]) < minGap
                }
                if !conflict { break }
                lvl += 1
            }
            levels[i] = min(lvl, maxLevels - 1)
        }
        return levels
    }

    private func tickStep(_ range: Double) -> Double {
        for step in [1.0, 2, 5, 10, 25, 50, 100, 200, 500] {
            if range / step <= 25 { return step }
        }
        return 500
    }
}
