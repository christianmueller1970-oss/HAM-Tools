import SwiftUI

// Rechtes Side-Panel im Logbuch — wird im Contest-Modus statt der
// PropagationPanelView gerendert. Aufbau:
//   • Header (Template-ID)
//   • Score-Summary "Pkt × Mult = Total"
//   • Rate-Meter 10/60 min
//   • Score-Matrix: pro Band → Mult-Counts + Mode-Counts + Total
//   • Band Activity Heatmap (wiederverwendet aus DXCluster)
struct ContestStatsPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager:      LogbookManager
    @EnvironmentObject var contests:     ContestService
    @EnvironmentObject var clusterVM:    DXClusterViewModel

    @AppStorage("logbook.heatmapMinutes") private var heatmapMinutes: Int = 60

    private var theme: AppTheme { themeManager.theme }

    private var activeLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    private var template: ContestTemplate? {
        guard let id = activeLog?.contestID else { return nil }
        return contests.template(forID: id)
    }

    private var qsos: [QSO] { manager.currentQSOs }

    private var liveScore: ContestScoringEngine.Score {
        ContestScoringEngine.score(qsos: qsos, templateID: activeLog?.contestID)
    }

    // Welche Bänder zeigen wir in der Matrix? Vom Template-`defaultCategories.band`
    // abgeleitet — bei ALL die klassischen HF-Contestbänder (160/80/40/20/15/10),
    // bei 6M nur 6m, bei MIXED jedes verwendete Band. So zeigt der 50-MHz-Contest
    // keine leere HF-Tabelle und der HF-Contest keine WARC-Bänder.
    private static let hfContestBands = ["160m", "80m", "40m", "20m", "15m", "10m"]
    private var matrixBands: [String] {
        let templateBand = (template?.defaultCategories?.band ?? "ALL").uppercased()
        let baseBands: [String]
        switch templateBand {
        case "ALL":     baseBands = Self.hfContestBands
        case "MIXED":   baseBands = Self.hfContestBands + ["6m", "2m", "70cm"]
        case "160M":    baseBands = ["160m"]
        case "80M":     baseBands = ["80m"]
        case "40M":     baseBands = ["40m"]
        case "20M":     baseBands = ["20m"]
        case "15M":     baseBands = ["15m"]
        case "10M":     baseBands = ["10m"]
        case "6M":      baseBands = ["6m"]
        case "2M":      baseBands = ["2m"]
        case "70CM":    baseBands = ["70cm"]
        default:        baseBands = Self.hfContestBands
        }
        // Plus alles was tatsächlich im Log vorkommt (User könnte z.B. auf
        // WARC arbeiten obwohl Contest auf HF ist — wird dann sichtbar).
        var result = baseBands
        let used = Set(qsos.map(\.band)).filter { !$0.isEmpty }
        for b in used where !result.contains(b) {
            result.append(b)
        }
        return result.sorted { lhs, rhs in
            bandSortKey(lhs) > bandSortKey(rhs)
        }
    }

    /// Höhere Frequenz → größerer Sortier-Key. Wir sortieren danach absteigend,
    /// damit 6m/10m oben stehen (analog zum Beispiel-Screenshot).
    /// 160m hat den niedrigsten Wert, 6m den höchsten.
    private func bandSortKey(_ band: String) -> Double {
        let m = Double(band.lowercased().replacingOccurrences(of: "m", with: "")) ?? 9999
        return 1.0 / m
    }

    /// Welche Heatmap-Bänder zeigen — analog zur Score-Matrix vom Template
    /// abgeleitet. Set für O(1)-Lookup im ForEach.
    private var heatmapBandsToShow: Set<String> {
        let templateBand = (template?.defaultCategories?.band ?? "ALL").uppercased()
        switch templateBand {
        case "ALL":     return ["160m", "80m", "40m", "20m", "15m", "10m"]
        case "MIXED":   return Set(HEATMAP_BANDS)
        case "6M":      return ["6m"]
        case "2M":      return ["2m"]
        default:        // Spezifisches HF-Band → genau das
            let lc = templateBand.lowercased()
            return [lc]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                headerRow
                Divider().background(theme.separator)
                scoreSummary
                rateBox
                Divider().background(theme.separator)
                scoreMatrix
            }
            .padding(10)

            Divider().background(theme.separator)

            // Band Activity unten — informativ während des Contests.
            bandActivitySection
                .padding(10)
        }
        .frame(maxHeight: .infinity)
        .background(theme.bgPanel)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "stopwatch")
                .foregroundStyle(theme.accentBlue)
            Text("Contest-Stats")
                .font(.subheadline.bold())
            Spacer()
            if let tpl = template {
                Text(tpl.id)
                    .font(.caption2.monospaced())
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(theme.bgCard2)
                    .clipShape(Capsule())
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    // MARK: - Score Summary

    private var scoreSummary: some View {
        let s = liveScore
        return VStack(alignment: .center, spacing: 4) {
            Text("\(s.points) Punkte × \(max(s.multipliers, 1)) Mult")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            Text("= \(s.total)")
                .font(.title2.bold().monospaced())
                .foregroundStyle(theme.accentBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(theme.bgCard2)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Rate-Meter

    private var rateBox: some View {
        let r10 = rate(minutes: 10)
        let r60 = rate(minutes: 60)
        return HStack(spacing: 6) {
            rateCell(label: "Rate 10 min", value: r10)
            rateCell(label: "Rate 60 min", value: r60)
        }
    }

    private func rateCell(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value)")
                    .font(.title3.bold().monospaced())
                    .foregroundStyle(theme.textPrimary)
                Text("Q/h")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .background(theme.bgCard2)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func rate(minutes: Int) -> Int {
        let now = Date()
        let cutoff = now.addingTimeInterval(-Double(minutes) * 60)
        let recent = qsos.filter { $0.datetime >= cutoff }
        guard !recent.isEmpty else { return 0 }
        let earliest = recent.map(\.datetime).min() ?? now
        let spanSec = max(60, now.timeIntervalSince(earliest))
        return Int(Double(recent.count) * 3600 / spanSec)
    }

    // MARK: - Score-Matrix

    private struct ScoreColumn: Identifiable {
        let id: String
        let label: String
        let kind: Kind
        enum Kind { case multiplier((String, [QSO]) -> Int)
                    case mode([String])
                    case total }
    }

    /// Spaltendefinition abhängig vom Template. Erste Spalte ist immer
    /// der Multiplier (Kantone bei Helvetia, Zone bei CQ-WW etc.). Dann
    /// kommen die drei Mode-Kategorien CW/Data/SSB und das Total.
    private var columns: [ScoreColumn] {
        let primary: ScoreColumn
        switch template?.id {
        case "HELVETIA":
            primary = ScoreColumn(id: "kanton", label: "Kant", kind: .multiplier { _, qs in
                Set(qs.compactMap { ContestStatsPanel.cantonFromExchange($0.contestExchangeRecv) }).count
            })
        case "CQ-WW-CW", "CQ-WW-SSB":
            primary = ScoreColumn(id: "zone", label: "Zone", kind: .multiplier { _, qs in
                Set(qs.compactMap { $0.cqZone }).count
            })
        case "CQ-WPX-CW", "CQ-WPX-SSB":
            primary = ScoreColumn(id: "wpx", label: "Pfx",  kind: .multiplier { _, qs in
                Set(qs.compactMap { ContestScoringEngine.wpxPrefix($0.call) }).count
            })
        case "USKA-50MHZ":
            primary = ScoreColumn(id: "grid", label: "Grid", kind: .multiplier { _, qs in
                Set(qs.compactMap { ContestStatsPanel.gridSquare4($0.contestExchangeRecv) }).count
            })
        case "IARU-HF":
            primary = ScoreColumn(id: "zone", label: "Zone", kind: .multiplier { _, qs in
                Set(qs.compactMap { $0.cqZone }).count
            })
        default:
            primary = ScoreColumn(id: "dxcc", label: "DXCC", kind: .multiplier { _, qs in
                Set(qs.compactMap { $0.country }.filter { !$0.isEmpty }).count
            })
        }
        return [
            primary,
            ScoreColumn(id: "cw",    label: "CW",   kind: .mode(["CW"])),
            ScoreColumn(id: "data",  label: "Data", kind: .mode(["RTTY", "FT8", "FT4", "JT65", "JT9", "PSK31", "PSK", "JS8", "DIGI"])),
            ScoreColumn(id: "ssb",   label: "SSB",  kind: .mode(["SSB", "USB", "LSB", "AM", "FM"])),
            ScoreColumn(id: "total", label: "Tot",  kind: .total)
        ]
    }

    private func value(for col: ScoreColumn, band: String, qsos qs: [QSO]) -> Int {
        switch col.kind {
        case .multiplier(let f):    return f(band, qs)
        case .mode(let modes):      return qs.filter { modes.contains($0.mode.uppercased()) }.count
        case .total:                return qs.count
        }
    }

    private var scoreMatrix: some View {
        let bandsByName: [String: [QSO]] = Dictionary(grouping: qsos, by: \.band)
        let cols = columns
        return VStack(spacing: 0) {
            // Header-Zeile
            matrixRow(label: "Band",
                      cells: cols.map { $0.label },
                      isHeader: true)
            ForEach(matrixBands, id: \.self) { band in
                let qs = bandsByName[band] ?? []
                matrixRow(label: band,
                          cells: cols.map { String(value(for: $0, band: band, qsos: qs)) },
                          isHeader: false,
                          isActive: !qs.isEmpty)
            }
            // Footer: Sum-Zeile (Gesamtsumme aller Bänder)
            matrixRow(label: "Sum",
                      cells: cols.map { col in
                          String(value(for: col, band: "", qsos: qsos))
                      },
                      isHeader: false,
                      isFooter: true)
        }
        .background(theme.bgCard2)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func matrixRow(label: String,
                           cells: [String],
                           isHeader: Bool = false,
                           isActive: Bool = false,
                           isFooter: Bool = false) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.caption2.monospaced().weight(isHeader || isFooter ? .bold : .regular))
                .foregroundStyle(isHeader ? theme.textSecondary
                                 : isFooter ? theme.textPrimary
                                 : isActive ? theme.textPrimary
                                 : theme.textDim)
                .frame(width: 42, alignment: .leading)
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                Text(cell)
                    .font(.caption2.monospaced().weight(isHeader || isFooter ? .bold : .regular))
                    .foregroundStyle(isHeader ? theme.textSecondary
                                     : isFooter ? theme.accentBlue
                                     : (cell == "0" ? theme.textDim : theme.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(isHeader ? theme.bgPanel
                    : isFooter ? theme.bgPanel
                    : Color.clear)
        .overlay(alignment: .bottom) {
            if isHeader {
                Rectangle().fill(theme.separator).frame(height: 1)
            }
        }
    }

    // MARK: - Band Activity (DX-Cluster-Daten, wiederverwendet)

    private var bandActivitySection: some View {
        let matrix = clusterVM.bandMatrix(minutes: heatmapMinutes)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(theme.accentYellow)
                Text("Band Activity")
                    .font(.caption.bold())
                    .foregroundStyle(theme.accentYellow)
                Spacer()
                Picker("", selection: $heatmapMinutes) {
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("60 min").tag(60)
                }
                .labelsHidden()
                .controlSize(.mini)
                .frame(width: 80)
            }

            HStack(spacing: 2) {
                Text("").frame(width: 30)
                ForEach(CONTINENTS, id: \.self) { c in
                    Text(c)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(Array(HEATMAP_BANDS.enumerated()), id: \.offset) { bi, band in
                if heatmapBandsToShow.contains(band) {
                    HStack(spacing: 2) {
                        Text(band)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(bandColor(for: band))
                            .frame(width: 30, alignment: .trailing)
                        ForEach(Array(CONTINENTS.enumerated()), id: \.offset) { ci, _ in
                            let count = bi < matrix.count && ci < (matrix[bi].count) ? matrix[bi][ci] : 0
                            HeatCell(count: count, theme: theme)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Static Helpers (Mult-Extraktion)

    /// "599 ZH" → "ZH"
    static func cantonFromExchange(_ ex: String?) -> String? {
        guard let raw = ex?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        let tokens = raw.split(separator: " ").map(String.init)
        return tokens.first { t in t.count == 2 && t.allSatisfy(\.isLetter) }?.uppercased()
    }

    /// "599 JN47PN 001" → "JN47"
    static func gridSquare4(_ ex: String?) -> String? {
        guard let raw = ex?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        let tokens = raw.split(separator: " ").map(String.init)
        return tokens.first { t in
            let chars = Array(t.uppercased())
            return chars.count >= 4 && chars[0].isLetter && chars[1].isLetter
                && chars[2].isNumber && chars[3].isNumber
        }.map { String($0.prefix(4)).uppercased() }
    }
}
