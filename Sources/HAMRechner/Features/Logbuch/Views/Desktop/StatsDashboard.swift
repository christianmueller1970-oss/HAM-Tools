import SwiftUI
import Charts

// Statistik-Dashboard für das aktive Log. MVP-Scope (Phase 8 angefangen):
//   • Header mit 4 Kennzahl-Karten (Total / Unique Calls / Best DX / DXCC)
//   • 4 Charts im 2×2-Grid: QSOs pro Jahr / Band / Mode / Kontinent
//   • 2 Listen: Top-10 DXCC-Länder, Top-5 längste DX-QSOs
//
// Alles aus den bereits berechneten Datenquellen — manager.currentQSOs +
// manager.awards. Keine eigene Persistenz, keine async Loads — alles
// rendert direkt aus dem In-Memory-Stand.
struct StatsDashboard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager

    private var theme: AppTheme { themeManager.theme }

    private var qsos: [QSO] { manager.currentQSOs }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerCards
                chartGrid
                bottomLists
            }
            .padding(14)
        }
        .background(theme.bgApp)
        .overlay(alignment: .center) {
            if qsos.isEmpty { emptyOverlay }
        }
    }

    private var emptyOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40))
                .foregroundStyle(theme.textDim)
            Text("Keine QSOs im aktiven Log")
                .font(.callout.bold())
                .foregroundStyle(theme.textSecondary)
            Text("Sobald QSOs angelegt sind, füllt sich das Dashboard automatisch.")
                .font(.caption)
                .foregroundStyle(theme.textDim)
        }
        .padding(40)
        .background(theme.bgPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Header (4 Karten)

    private var headerCards: some View {
        HStack(spacing: 10) {
            kpiCard(title: "QSOs",
                    value: "\(qsos.count)",
                    sub:   uniqueCallsSummary,
                    icon:  "antenna.radiowaves.left.and.right",
                    tint:  theme.accentBlue)
            kpiCard(title: "Best DX",
                    value: bestDistance.map { String(format: "%.0f km", $0) } ?? "—",
                    sub:   bestDistanceCall.map { "\($0)" } ?? "kein Locator",
                    icon:  "globe",
                    tint:  theme.accentGreen)
            kpiCard(title: "DXCC",
                    value: "\(manager.awards.dxccWorked)",
                    sub:   "\(manager.awards.dxccConfirmed) bestätigt",
                    icon:  "flag.checkered",
                    tint:  theme.accentYellow)
            kpiCard(title: "Jahre",
                    value: "\(activeYears)",
                    sub:   firstQSO.map { "seit \(yearOf($0))" } ?? "—",
                    icon:  "clock.arrow.circlepath",
                    tint:  theme.accentRed)
        }
    }

    private func kpiCard(title: String, value: String, sub: String,
                         icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textDim)
            }
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(theme.textPrimary)
            Text(sub)
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgCard2)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Charts (2×2 Grid)

    private var chartGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)],
                  spacing: 10) {
            chartCard(title: "QSOs pro Jahr",
                      subtitle: "über die ganze Log-Historie") {
                yearChart
            }
            chartCard(title: "QSOs pro Band",
                      subtitle: "sortiert nach Frequenz") {
                bandChart
            }
            chartCard(title: "QSOs pro Mode",
                      subtitle: "Top 8 Modes") {
                modeChart
            }
            chartCard(title: "QSOs pro Kontinent",
                      subtitle: "aus QRZ/HamQTH-Lookup") {
                continentChart
            }
        }
    }

    private func chartCard<Content: View>(title: String,
                                          subtitle: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(theme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
                Spacer()
            }
            content()
                .frame(height: 180)
        }
        .padding(12)
        .background(theme.bgPanel)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Charts

    @ViewBuilder
    private var yearChart: some View {
        let data = qsosPerYear()
        if data.isEmpty {
            chartPlaceholder
        } else {
            Chart(data, id: \.label) { row in
                BarMark(x: .value("Jahr", row.label),
                        y: .value("QSOs", row.count))
                    .foregroundStyle(theme.accentBlue.gradient)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(data.count, 8))) {
                    AxisValueLabel().font(.caption2)
                }
            }
            .chartYAxis { AxisMarks { AxisValueLabel().font(.caption2) } }
        }
    }

    @ViewBuilder
    private var bandChart: some View {
        let data = qsosPerBand()
        if data.isEmpty {
            chartPlaceholder
        } else {
            Chart(data, id: \.label) { row in
                BarMark(x: .value("Band", row.label),
                        y: .value("QSOs", row.count))
                    .foregroundStyle(theme.accentGreen.gradient)
            }
            .chartXAxis { AxisMarks { AxisValueLabel().font(.caption2) } }
            .chartYAxis { AxisMarks { AxisValueLabel().font(.caption2) } }
        }
    }

    @ViewBuilder
    private var modeChart: some View {
        let data = qsosPerMode()
        if data.isEmpty {
            chartPlaceholder
        } else {
            Chart(data, id: \.label) { row in
                BarMark(x: .value("Mode", row.label),
                        y: .value("QSOs", row.count))
                    .foregroundStyle(theme.accentYellow.gradient)
            }
            .chartXAxis { AxisMarks { AxisValueLabel().font(.caption2) } }
            .chartYAxis { AxisMarks { AxisValueLabel().font(.caption2) } }
        }
    }

    @ViewBuilder
    private var continentChart: some View {
        let data = qsosPerContinent()
        if data.isEmpty {
            chartPlaceholder
        } else {
            Chart(data, id: \.label) { row in
                BarMark(x: .value("Kontinent", row.label),
                        y: .value("QSOs", row.count))
                    .foregroundStyle(theme.accentRed.gradient)
            }
            .chartXAxis { AxisMarks { AxisValueLabel().font(.caption2) } }
            .chartYAxis { AxisMarks { AxisValueLabel().font(.caption2) } }
        }
    }

    private var chartPlaceholder: some View {
        VStack(spacing: 4) {
            Image(systemName: "chart.bar")
                .font(.title3)
                .foregroundStyle(theme.textDim)
            Text("Keine Daten")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Listen unten

    private var bottomLists: some View {
        HStack(alignment: .top, spacing: 10) {
            listCard(title: "Top 10 DXCC-Länder",
                     icon: "flag.checkered",
                     rows: topCountries(10).map { ($0.label, "\($0.count)") },
                     emptyHint: "Keine Country-Daten vorhanden")
            listCard(title: "Top 5 DX-Strecken",
                     icon: "arrow.up.right",
                     rows: topDistances(5).map {
                         ($0.call, String(format: "%.0f km", $0.km))
                     },
                     emptyHint: "Keine Distanz-Daten vorhanden — Locator + eigenen QTH eintragen")
        }
    }

    private func listCard(title: String,
                          icon: String,
                          rows: [(String, String)],
                          emptyHint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(theme.accentBlue)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(theme.textPrimary)
                Spacer()
            }
            if rows.isEmpty {
                Text(emptyHint)
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
                    .padding(.vertical, 4)
            } else {
                ForEach(0..<rows.count, id: \.self) { i in
                    HStack {
                        Text("\(i + 1).")
                            .font(.caption2.monospaced())
                            .foregroundStyle(theme.textDim)
                            .frame(width: 22, alignment: .trailing)
                        Text(rows[i].0)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text(rows[i].1)
                            .font(.caption.monospaced())
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgPanel)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Aggregations (rein in-memory, kein Cache nötig bei den
    //         typischen Log-Größen — 5000 QSOs sind in <1ms aggregiert)

    private struct Row { let label: String; let count: Int }
    private struct DXRow { let call: String; let km: Double }

    private var uniqueCallsSummary: String {
        let set = Set(qsos.map { $0.call.uppercased() })
        return "\(set.count) unique Calls"
    }

    private var bestDistance: Double? {
        qsos.compactMap { $0.distanceKm }.max()
    }

    private var bestDistanceCall: String? {
        guard let best = bestDistance,
              let q = qsos.first(where: { $0.distanceKm == best })
        else { return nil }
        return q.call
    }

    private var firstQSO: Date? { qsos.map(\.datetime).min() }

    private var activeYears: Int {
        guard let first = firstQSO, let last = qsos.map(\.datetime).max()
        else { return 0 }
        let cal = Calendar(identifier: .gregorian)
        let y1 = cal.component(.year, from: first)
        let y2 = cal.component(.year, from: last)
        return y2 - y1 + 1
    }

    private func yearOf(_ d: Date) -> Int {
        Calendar(identifier: .gregorian).component(.year, from: d)
    }

    private func qsosPerYear() -> [Row] {
        let cal = Calendar(identifier: .gregorian)
        var bucket: [Int: Int] = [:]
        for q in qsos {
            let y = cal.component(.year, from: q.datetime)
            bucket[y, default: 0] += 1
        }
        return bucket.keys.sorted().map { Row(label: "\($0)", count: bucket[$0] ?? 0) }
    }

    private func qsosPerBand() -> [Row] {
        // BAND-Sortierung: nach Frequenz, fallback alphabetisch. Aus BandData
        // gibt's BANDS-Liste; falls dort nicht enthalten, ans Ende.
        let bandsOrder = BANDS.map(\.name)
        var bucket: [String: Int] = [:]
        for q in qsos where !q.band.isEmpty {
            bucket[q.band, default: 0] += 1
        }
        return bucket.keys.sorted { a, b in
            let ia = bandsOrder.firstIndex(of: a) ?? Int.max
            let ib = bandsOrder.firstIndex(of: b) ?? Int.max
            if ia != ib { return ia < ib }
            return a < b
        }.map { Row(label: $0, count: bucket[$0] ?? 0) }
    }

    private func qsosPerMode() -> [Row] {
        var bucket: [String: Int] = [:]
        for q in qsos where !q.mode.isEmpty {
            bucket[q.mode.uppercased(), default: 0] += 1
        }
        // Top 8 nach Anzahl absteigend, dann alphabetisch
        return bucket.map { Row(label: $0.key, count: $0.value) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.label < b.label
            }
            .prefix(8)
            .map { $0 }
    }

    private func qsosPerContinent() -> [Row] {
        let order = ["EU", "NA", "SA", "AS", "AF", "OC", "AN"]
        var bucket: [String: Int] = [:]
        for q in qsos {
            let c = (q.continent ?? "").uppercased().trimmingCharacters(in: .whitespaces)
            guard !c.isEmpty else { continue }
            bucket[c, default: 0] += 1
        }
        return bucket.keys.sorted { a, b in
            let ia = order.firstIndex(of: a) ?? Int.max
            let ib = order.firstIndex(of: b) ?? Int.max
            if ia != ib { return ia < ib }
            return a < b
        }.map { Row(label: $0, count: bucket[$0] ?? 0) }
    }

    private func topCountries(_ n: Int) -> [Row] {
        var bucket: [String: Int] = [:]
        for q in qsos {
            let c = (q.country ?? "").trimmingCharacters(in: .whitespaces)
            guard !c.isEmpty else { continue }
            bucket[c, default: 0] += 1
        }
        return bucket.map { Row(label: $0.key, count: $0.value) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.label < b.label
            }
            .prefix(n)
            .map { $0 }
    }

    private func topDistances(_ n: Int) -> [DXRow] {
        qsos.compactMap { q in
            guard let d = q.distanceKm, d > 0 else { return nil }
            return DXRow(call: q.call, km: d)
        }
        .sorted { $0.km > $1.km }
        .prefix(n)
        .map { $0 }
    }
}
