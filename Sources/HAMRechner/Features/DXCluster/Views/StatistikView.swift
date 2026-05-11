import SwiftUI
import Charts

struct StatistikView: View {
    let spots: [DXSpot]
    let theme: AppTheme

    // MARK: - Computed stats

    private var bandStats: [(band: String, count: Int)] {
        var counts: [String: Int] = [:]
        for s in spots { counts[s.band, default: 0] += 1 }
        return counts.map { (band: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(12).map { $0 }
    }

    private var modeStats: [(mode: String, count: Int)] {
        var counts: [String: Int] = [:]
        for s in spots { counts[s.mode, default: 0] += 1 }
        return counts.map { (mode: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(8).map { $0 }
    }

    private var topDX: [(call: String, count: Int)] {
        var counts: [String: Int] = [:]
        for s in spots { counts[s.dxCall, default: 0] += 1 }
        return counts.map { (call: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(15).map { $0 }
    }

    private var hourlyHistory: [(label: String, count: Int)] {
        let now = Date()
        let f = DateFormatter()
        f.dateFormat = "HH"
        f.timeZone = TimeZone(identifier: "UTC")
        return (0..<24).map { i in
            let end   = now.addingTimeInterval(-Double(23 - i) * 3600)
            let start = end.addingTimeInterval(-3600)
            let count = spots.filter { $0.timestamp > start && $0.timestamp <= end }.count
            return (f.string(from: end) + "h", count)
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            if spots.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 12) {
                    chartCard("Spots pro Band", height: 320) {
                        Chart(bandStats, id: \.band) { item in
                            BarMark(x: .value("Spots", item.count),
                                    y: .value("Band",  item.band))
                                .foregroundStyle(BAND_COLORS[item.band] ?? theme.accentBlue)
                                .annotation(position: .trailing) {
                                    Text("\(item.count)")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(theme.textSecondary)
                                        .padding(.leading, 4)
                                }
                        }
                        .chartYAxis {
                            AxisMarks(preset: .extended, position: .leading) { value in
                                AxisValueLabel {
                                    if let s = value.as(String.self) {
                                        Text(s)
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(theme.textPrimary)
                                    }
                                }
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYScale(domain: bandStats.map(\.band).reversed())
                    }

                    chartCard("Spots pro Mode") {
                        Chart(modeStats, id: \.mode) { item in
                            BarMark(x: .value("Mode",  item.mode),
                                    y: .value("Spots", item.count))
                                .foregroundStyle(by: .value("Mode", item.mode))
                                .annotation(position: .top) {
                                    Text("\(item.count)")
                                        .font(.system(size: 9))
                                        .foregroundStyle(theme.textDim)
                                }
                        }
                        .chartLegend(.hidden)
                        .chartXAxis { AxisMarks { AxisValueLabel() } }
                        .chartYAxis { AxisMarks { AxisGridLine() } }
                    }

                    chartCard("Top-15 DX-Rufzeichen", height: 380) {
                        Chart(topDX, id: \.call) { item in
                            BarMark(x: .value("Spots", item.count),
                                    y: .value("Call",  item.call))
                                .foregroundStyle(theme.accentGreen)
                                .annotation(position: .trailing) {
                                    Text("\(item.count)")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(theme.textSecondary)
                                        .padding(.leading, 4)
                                }
                        }
                        .chartYAxis {
                            AxisMarks(preset: .extended, position: .leading) { value in
                                AxisValueLabel {
                                    if let s = value.as(String.self) {
                                        Text(s)
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(theme.textPrimary)
                                    }
                                }
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYScale(domain: topDX.map(\.call).reversed())
                    }

                    chartCard("Verlauf letzte 24h (UTC)") {
                        Chart(hourlyHistory, id: \.label) { item in
                            AreaMark(x: .value("Stunde", item.label),
                                     y: .value("Spots",  item.count))
                                .foregroundStyle(theme.accentBlue.opacity(0.2))
                            LineMark(x: .value("Stunde", item.label),
                                     y: .value("Spots",  item.count))
                                .foregroundStyle(theme.accentBlue)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: 6)) {
                                AxisGridLine()
                                AxisValueLabel()
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(theme.bgApp)
    }

    // MARK: - Helpers

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundStyle(theme.textDim)
            Text("Noch keine Spots empfangen")
                .foregroundStyle(theme.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    private func chartCard<C: View>(_ title: String,
                                    height: CGFloat = 200,
                                    @ViewBuilder chart: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(theme.textSecondary)
            chart()
                .frame(height: height)
        }
        .padding(10)
        .background(theme.bgCard)
        .cornerRadius(8)
    }
}
