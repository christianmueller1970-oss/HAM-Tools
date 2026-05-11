import SwiftUI

// MARK: - Propagation Panel (right sidebar)

struct PropagationPanelView: View {
    let propagation: PropagationData
    let bandMatrix:  [[Int]]       // HEATMAP_BANDS × CONTINENTS
    let theme:       AppTheme
    var callsign:    String = ""
    var connected:   Bool   = false
    var spots:       [DXSpot] = []
    var onSend:      (Double, String, String) -> Void = { _, _, _ in }

    @State private var heatmapMinutes = 60
    @State private var dxCall    = ""
    @State private var frequency = ""
    @State private var mode      = "FT8"
    @State private var comment   = ""

    private let gold  = Color(red: 1.0, green: 0.82, blue: 0.2)
    private let modes = ["FT8","FT4","CW","SSB","RTTY","PSK31","JS8","WSPR","DIGI"]
    private let quickBands: [(label: String, freq: Double)] = [
        ("160m", 1840.0), ("80m", 3573.0), ("40m", 7074.0),
        ("20m", 14074.0), ("15m", 21074.0), ("10m", 28074.0)
    ]

    private var isValid: Bool {
        !dxCall.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(frequency.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                sendSpotSection
                Divider()
                propagationSection
                Divider()
                solarDetailsSection
                Divider()
                ownSpotsSection
                Divider()
                bandActivitySection
            }
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
                    sublabel: "SFI: \(propagation.sfi.map(String.init) ?? "?")",
                    invertColors: true
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

    // MARK: Solar-Details (Sonnenflecken, X-Ray, Wind, Aurora)

    private var solarDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(gold)
                Text("Solar-Daten")
                    .font(.headline)
                    .foregroundStyle(gold)
                Spacer()
                if let upd = propagation.updated {
                    Text(upd.prefix(16))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(theme.textDim)
                }
            }

            VStack(spacing: 4) {
                detailRow("Sonnenflecken (SSN)", value: propagation.ssn.map(String.init) ?? "—",
                          color: ssnColor(propagation.ssn))
                detailRow("X-Ray Flux",          value: propagation.xray ?? "—",
                          color: xrayColor(propagation.xray))
                detailRow("Solar Wind",          value: propagation.solarWind.map { "\($0) km/s" } ?? "—",
                          color: solarWindColor(propagation.solarWind))
                detailRow("Helium 304 Å",        value: propagation.helium.map { String(format: "%.1f", $0) } ?? "—")
                detailRow("Aurora ab",            value: propagation.auroraLat.map { "\($0)° N" } ?? "—")
                detailRow("Geomag. Feld",         value: propagation.geomagField?.capitalized ?? "—",
                          color: geomagColor(propagation.geomagField))
            }
        }
        .padding(12)
    }

    private func detailRow(_ label: String, value: String, color: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(color ?? theme.textPrimary)
        }
    }

    private func ssnColor(_ v: Int?) -> Color {
        guard let v else { return theme.textPrimary }
        if v >= 100 { return theme.accentGreen }
        if v >= 50  { return theme.accentYellow }
        return theme.textPrimary
    }
    private func xrayColor(_ s: String?) -> Color {
        guard let s = s?.first else { return theme.textPrimary }
        switch s {
        case "X": return theme.accentRed
        case "M": return theme.accentOrange
        case "C": return theme.accentYellow
        default:  return theme.accentGreen
        }
    }
    private func solarWindColor(_ v: Int?) -> Color {
        guard let v else { return theme.textPrimary }
        if v >= 600 { return theme.accentRed }
        if v >= 450 { return theme.accentOrange }
        return theme.textPrimary
    }
    private func geomagColor(_ s: String?) -> Color {
        switch s?.uppercased() {
        case "QUIET":     return theme.accentGreen
        case "UNSETTLED": return theme.accentYellow
        case "ACTIVE":    return theme.accentOrange
        case "STORM":     return theme.accentRed
        default:          return theme.textPrimary
        }
    }

    // MARK: Letzte 5 eigene Spots (wo ICH gespottet wurde)

    private var ownSpotsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(gold)
                Text("Eigene Spots (\(callsign.uppercased()))")
                    .font(.headline)
                    .foregroundStyle(gold)
                Spacer()
            }

            let myCall = callsign.uppercased().trimmingCharacters(in: .whitespaces)
            let mine = spots
                .filter { !myCall.isEmpty && $0.dxCall.uppercased() == myCall }
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(5)

            if mine.isEmpty {
                Text(myCall.isEmpty
                     ? "Rufzeichen in Einstellungen setzen"
                     : "Noch nicht gespottet worden")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(mine), id: \.id) { spot in
                        HStack(spacing: 6) {
                            Text(spot.displayTime)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(theme.textSecondary)
                                .frame(width: 50, alignment: .leading)
                            Text(spot.displayFreq)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(theme.accentBlue)
                                .frame(width: 60, alignment: .trailing)
                            Text(spot.spotter)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(12)
    }

    // MARK: DX-Spot senden

    private var sendSpotSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.right")
                    .foregroundStyle(gold)
                Text("DX-Spot senden")
                    .font(.headline)
                    .foregroundStyle(gold)
            }

            // DX-Call
            HStack {
                Text("DX-Call")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 56, alignment: .trailing)
                TextField("z.B. VK2AB", text: $dxCall)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            // Frequenz
            HStack {
                Text("Freq kHz")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 56, alignment: .trailing)
                TextField("z.B. 14074.0", text: $frequency)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            // Band-Schnellwahl
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(quickBands, id: \.label) { b in
                        Button(b.label) { frequency = String(b.freq) }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(.blue)
                    }
                }
            }

            // Mode + Kommentar
            HStack {
                Text("Mode")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 56, alignment: .trailing)
                Picker("", selection: $mode) {
                    ForEach(modes, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
            }

            HStack {
                Text("Komm.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 56, alignment: .trailing)
                TextField("Optional", text: $comment)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }

            // Info + Senden
            HStack {
                Text("Von: \(callsign.isEmpty ? "–" : callsign)")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
                Spacer()
                Button("Senden ▶") { sendSpot() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(theme.accentBlue)
                    .disabled(!isValid || !connected)
            }
        }
        .padding(12)
    }

    private func sendSpot() {
        let call    = dxCall.trimmingCharacters(in: .whitespaces).uppercased()
        let freqStr = frequency.replacingOccurrences(of: ",", with: ".")
        guard let freq = Double(freqStr) else { return }
        let fullComment = "\(mode) \(comment)".trimmingCharacters(in: .whitespaces)
        onSend(freq, call, fullComment)
        dxCall = ""; frequency = ""; comment = ""
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
                .frame(width: 100)
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
    var invertColors: Bool = false  // true → high value = green (good), low = red

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

    // Default: Green (left/low) → Yellow → Orange → Red (right/high)
    // invertColors=true: Red (left/low) → Orange → Yellow → Green (right/high)
    private func arcGradientColor(t: Double) -> Color {
        let u = invertColors ? (1.0 - t) : t
        switch u {
        case ..<0.25:
            let f = u / 0.25
            return Color(red: f * 0.85, green: 0.75, blue: 0.0)
        case ..<0.50:
            let f = (u - 0.25) / 0.25
            return Color(red: 0.85 + f * 0.15, green: 0.75 - f * 0.15, blue: 0.0)
        case ..<0.75:
            let f = (u - 0.50) / 0.25
            return Color(red: 1.0, green: 0.60 - f * 0.25, blue: 0.0)
        default:
            let f = (u - 0.75) / 0.25
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
