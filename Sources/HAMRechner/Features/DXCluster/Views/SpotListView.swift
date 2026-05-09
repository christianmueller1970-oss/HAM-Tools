import SwiftUI

struct SpotListView: View {
    let spots: [DXSpot]
    let theme: AppTheme

    @State private var sortOrder = [KeyPathComparator(\DXSpot.timestamp, order: .reverse)]
    @State private var selection: DXSpot.ID? = nil
    @State private var sortedSpots: [DXSpot] = []

    var body: some View {
        Group {
            if spots.isEmpty {
                emptyState
            } else {
                spotTable
            }
        }
        .onAppear { sortedSpots = spots.sorted(using: sortOrder) }
        .onChange(of: spots) { sortedSpots = spots.sorted(using: sortOrder) }
        .onChange(of: sortOrder) { sortedSpots = spots.sorted(using: sortOrder) }
    }

    // MARK: - Table

    private var spotTable: some View {
        Table(sortedSpots, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Zeit", value: \.spotTime) { s in
                cell(s.displayTime, s)
            }
            .width(min: 50, ideal: 60)

            TableColumn("Freq (kHz)", value: \.frequency) { s in
                cell(s.displayFreq, s).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 85)

            TableColumn("Band", value: \.band) { s in
                Text(s.band)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(bandColor(for: s.band))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .width(min: 45, ideal: 55)

            TableColumn("Mode", value: \.mode) { s in
                cell(s.mode, s).frame(maxWidth: .infinity, alignment: .center)
            }
            .width(min: 45, ideal: 55)

            TableColumn("DX-Rufz.", value: \.dxCall) { s in
                Text(s.dxCall)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(bandColor(for: s.band))
            }
            .width(min: 80, ideal: 100)

            TableColumn("Land", value: \.country) { s in
                cell(s.country, s)
            }
            .width(min: 90, ideal: 120)

            TableColumn("Kont.", value: \.continent) { s in
                cell(s.continent, s).frame(maxWidth: .infinity, alignment: .center)
            }
            .width(min: 40, ideal: 50)

            TableColumn("Kommentar", value: \.comment) { s in
                cell(String(s.comment.prefix(40)), s)
            }
            .width(min: 100, ideal: 160)

            TableColumn("Spotter", value: \.spotter) { s in
                cell(s.spotter, s)
            }
            .width(min: 70, ideal: 95)

            TableColumn("Cluster", value: \.source) { s in
                cell(s.source, s)
            }
            .width(min: 80, ideal: 120)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .font(.system(size: 12))
    }

    @ViewBuilder
    private func cell(_ text: String, _ spot: DXSpot) -> some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(bandColor(for: spot.band))
            .lineLimit(1)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundStyle(theme.textDim)
            Text("Keine Spots")
                .font(.title3)
                .foregroundStyle(theme.textSecondary)
            Text("Verbindung wird aufgebaut…")
                .font(.callout)
                .foregroundStyle(theme.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgApp)
    }
}
