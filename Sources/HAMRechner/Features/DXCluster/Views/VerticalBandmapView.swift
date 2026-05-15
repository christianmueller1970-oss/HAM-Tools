import SwiftUI

// Klassische N1MM/Skookum-Style-Bandmap für die Pop-up-Fenster:
// Vertikale Frequenz-Skala links, Tick-Marks, Spots als farbiger Strich
// + Call-Text rechts daneben. Zoombar (px/kHz), filterbar nach Zeit + Mode,
// scrollbar wenn das Fenster nicht den ganzen Band-Range fasst.
//
// Default Mode-Filter ist "SSB" (User-Wunsch). Mode-Filter "Alle" zeigt
// jeden Spot unabhängig vom Mode.
struct VerticalBandmapView: View {
    let spots: [DXSpot]
    let theme: AppTheme
    let band:  String

    @State private var timeMinutes:   Int    = 15
    @State private var selectedMode:  String = "SSB"
    @State private var pxPerKHz:      Double = 2.0
    @State private var selectedSpot:  DXSpot.ID? = nil

    private let modes      = ["Alle", "SSB", "CW", "FT8", "FT4", "RTTY", "FM", "AM", "DIGI"]
    private let zoomLevels: [Double] = [1, 2, 4, 8, 16]
    private let timeOpts:   [(label: String, min: Int)] = [
        ("5 min", 5), ("15 min", 15), ("30 min", 30),
        ("60 min", 60), ("2 h", 120), ("6 h", 360), ("Alle", 99_999)
    ]

    private let axisX:        CGFloat = 64      // Achse + Label-Bereich
    private let tickShort:    CGFloat = 3
    private let tickLong:     CGFloat = 7
    private let spotStrokeLen: CGFloat = 14
    private let callTextX:    CGFloat = 12       // Abstand Call-Text zu Strich

    private var bandRange: (low: Double, high: Double) {
        let r = BANDS.first(where: { $0.name == band }) ?? BANDS[0]
        return (r.low, r.high)
    }

    private var contentHeight: CGFloat {
        let (low, high) = bandRange
        return CGFloat((high - low) * pxPerKHz) + 20  // +20pt Polster oben/unten
    }

    private var filteredSpots: [DXSpot] {
        let cutoff = Date().addingTimeInterval(-Double(timeMinutes) * 60)
        return spots
            .filter { $0.band == band && $0.timestamp >= cutoff }
            .filter { matchesMode($0) }
    }

    private func matchesMode(_ spot: DXSpot) -> Bool {
        if selectedMode == "Alle" { return true }
        let m = spot.mode.uppercased()
        switch selectedMode {
        case "SSB":  return ["SSB", "USB", "LSB"].contains(m)
        case "DIGI": return ["FT8","FT4","RTTY","PSK","PSK31","PSK63","PSK125",
                              "JS8","MFSK","OLIVIA","VARA","DIGI","DATA"].contains(m)
        default:     return m == selectedMode.uppercased()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                ZStack(alignment: .topLeading) {
                    bandCanvas
                    spotOverlay
                }
                .frame(width: 320, height: contentHeight, alignment: .topLeading)
            }
            .background(theme.bgApp)

            Divider().background(theme.separator)
            toolbar
        }
        .background(theme.bgApp)
    }

    // MARK: - Frequenz-Skala (Canvas)

    private var bandCanvas: some View {
        Canvas { ctx, size in
            let (low, high) = bandRange
            let topPadding: CGFloat = 10

            // Vertikale Achsen-Linie
            var axis = Path()
            axis.move(to:    CGPoint(x: axisX, y: topPadding))
            axis.addLine(to: CGPoint(x: axisX, y: size.height - 10))
            ctx.stroke(axis, with: .color(theme.textDim), lineWidth: 1)

            // Tick-Marks alle 1 kHz (kurz) + alle 10 kHz (lang + Label)
            let lowK = Int(low.rounded())
            let highK = Int(high.rounded())
            for kHz in lowK...highK {
                let y = topPadding + CGFloat(Double(kHz - lowK) * pxPerKHz)
                let isMajor = (kHz % 10 == 0)
                let isMid   = (kHz % 5 == 0)
                let len: CGFloat = isMajor ? tickLong : (isMid ? tickShort + 1 : tickShort)

                var tick = Path()
                tick.move(to:    CGPoint(x: axisX - len, y: y))
                tick.addLine(to: CGPoint(x: axisX,       y: y))
                ctx.stroke(tick,
                           with: .color(isMajor ? theme.textPrimary : theme.textDim),
                           lineWidth: 0.7)

                if isMajor {
                    let label = formatKHz(kHz)
                    let textRect = CGRect(x: 0, y: y - 8, width: axisX - tickLong - 4, height: 16)
                    let attr = AttributedString(label,
                                                attributes: AttributeContainer([
                                                    .font: NSFont.systemFont(ofSize: 11,
                                                                              weight: .regular),
                                                    .foregroundColor: NSColor(theme.textSecondary)
                                                ]))
                    ctx.draw(Text(attr), in: textRect)
                }
            }
        }
    }

    private func formatKHz(_ kHz: Int) -> String {
        // 14'060-Format mit Apostroph als Tausender-Trenner (CH-Konvention).
        let mhz = kHz / 1000
        let rest = kHz % 1000
        return String(format: "%d'%03d", mhz, rest)
    }

    // MARK: - Spots als Overlay (Striche + Call-Text)

    private var spotOverlay: some View {
        let (low, _) = bandRange
        let topPadding: CGFloat = 10
        return ForEach(layoutedSpots, id: \.spot.id) { entry in
            let y = topPadding
                + CGFloat((entry.spot.frequency - low) * pxPerKHz)
            let color = modeColor(entry.spot.mode)
            let xStart = axisX
            let xLine  = xStart + spotStrokeLen
            let xText  = xLine + 4 + CGFloat(entry.column) * 80   // 80pt pro Spalte
            let isSel  = (selectedSpot == entry.spot.id)

            // Strich von der Achse
            Path { p in
                p.move(to:    CGPoint(x: xStart, y: y))
                p.addLine(to: CGPoint(x: xLine,  y: y))
            }
            .stroke(color, lineWidth: 2.5)

            // Call-Text rechts daneben
            Text(entry.spot.dxCall)
                .font(.system(size: 11, weight: isSel ? .bold : .semibold,
                              design: .monospaced))
                .foregroundStyle(color)
                .position(x: xText + 30, y: y)
                .onTapGesture {
                    selectedSpot = entry.spot.id
                    LogEntryBridge.shared.openInLog(from: entry.spot)
                }
        }
    }

    // Einfache Spaltenzuweisung um Call-Overlap bei nahen Frequenzen zu reduzieren:
    // wir gehen Spots aufsteigend nach Frequenz durch und schieben sie in die
    // nächste freie Spalte wenn der vertikale Mindestabstand unterschritten wird.
    private struct LayoutEntry {
        let spot:   DXSpot
        let column: Int
    }

    private var layoutedSpots: [LayoutEntry] {
        let sorted = filteredSpots.sorted { $0.frequency < $1.frequency }
        let minDy: CGFloat = 14
        var lastYInColumn: [Int: CGFloat] = [:]
        var result: [LayoutEntry] = []
        let (low, _) = bandRange

        for s in sorted {
            let y = CGFloat((s.frequency - low) * pxPerKHz)
            // Erste Spalte versuchen, dann nach rechts ausweichen.
            var col = 0
            while let last = lastYInColumn[col], y - last < minDy {
                col += 1
            }
            lastYInColumn[col] = y
            result.append(LayoutEntry(spot: s, column: col))
        }
        return result
    }

    private func modeColor(_ rawMode: String) -> Color {
        switch rawMode.uppercased() {
        case "SSB", "USB", "LSB": return Color(red: 1.0, green: 0.78, blue: 0.0)  // gelb-gold
        case "CW":                return Color(red: 1.0, green: 0.45, blue: 0.0)  // orange
        case "FT8":               return Color(red: 0.20, green: 0.85, blue: 0.45) // grün
        case "FT4":               return Color(red: 0.30, green: 0.65, blue: 1.0)  // blau
        case "RTTY":              return Color(red: 0.95, green: 0.30, blue: 0.60) // pink
        case "FM":                return Color(red: 0.85, green: 0.55, blue: 0.85) // lila
        case "AM":                return Color(red: 0.95, green: 0.65, blue: 0.40) // peach
        case "JS8":               return Color(red: 0.60, green: 0.95, blue: 0.30) // lemon
        case "PSK", "PSK31", "PSK63", "PSK125",
             "DIGI", "DATA",
             "MFSK", "OLIVIA", "VARA":
            return Color(red: 0.85, green: 0.50, blue: 0.95) // magenta
        default: return Color.gray
        }
    }

    // MARK: - Bottom-Toolbar

    private var toolbar: some View {
        HStack(spacing: 6) {
            Text(band)
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(theme.bgCard2)
                .cornerRadius(4)

            Picker("", selection: $pxPerKHz) {
                ForEach(zoomLevels, id: \.self) { z in
                    Text("\(Int(z)) px/kHz").tag(z)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)

            Picker("", selection: $timeMinutes) {
                ForEach(timeOpts, id: \.min) { opt in
                    Text(opt.label).tag(opt.min)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 90)

            Picker("", selection: $selectedMode) {
                ForEach(modes, id: \.self) { m in Text(m).tag(m) }
            }
            .pickerStyle(.menu)
            .frame(width: 90)

            Spacer()

            Text("\(filteredSpots.count)")
                .font(.caption.monospaced().bold())
                .foregroundStyle(theme.accentBlue)
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(theme.bgPanel)
    }
}
