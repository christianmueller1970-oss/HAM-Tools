import SwiftUI

struct SpotListView: View {
    let spots:     [DXSpot]
    let theme:     AppTheme
    var watchList: WatchListStore? = nil
    /// Optional pro-Spot-Farbe (override) für Contest-Kontext: dupe → rot, mult → grün.
    var rowAccent: ((DXSpot) -> Color?)? = nil

    /// ATNO-Pille links vom Call (»ATNO«/»NEW BAND«/»NEW MODE«). Soll nur
    /// im DX-Kontext erscheinen — im Contest- oder Outdoor-Log lenkt das
    /// nur ab, weil dort andere Match-Kriterien zählen (Dupe-Färbung etc.).
    var showATNO: Bool = true

    @EnvironmentObject var manager: LogbookManager

    @State private var sortOrder = [KeyPathComparator(\DXSpot.timestamp, order: .reverse)]
    @State private var selection: DXSpot.ID? = nil
    @State private var sortedSpots: [DXSpot] = []

    // Spalten-Reihenfolge + Sichtbarkeit (per Header-Rechtsklick / Drag),
    // persistiert in UserDefaults.
    @State private var columnCustomization = TableColumnCustomization<DXSpot>()
    private let customizationStorageKey = "dxcluster.spotList.columnCustomization.v1"

    var body: some View {
        Group {
            if spots.isEmpty {
                emptyState
            } else {
                spotTable
            }
        }
        .onAppear {
            sortedSpots = spots.sorted(using: sortOrder)
            loadCustomization()
        }
        .onChange(of: spots) { sortedSpots = spots.sorted(using: sortOrder) }
        .onChange(of: sortOrder) { sortedSpots = spots.sorted(using: sortOrder) }
        .onChange(of: columnCustomization) { _, _ in saveCustomization() }
    }

    private func loadCustomization() {
        guard let data = UserDefaults.standard.data(forKey: customizationStorageKey),
              let decoded = try? JSONDecoder().decode(TableColumnCustomization<DXSpot>.self, from: data) else {
            return
        }
        columnCustomization = decoded
    }

    private func saveCustomization() {
        guard let data = try? JSONEncoder().encode(columnCustomization) else { return }
        UserDefaults.standard.set(data, forKey: customizationStorageKey)
    }

    // MARK: - Table

    private var spotTable: some View {
        // @TableColumnBuilder unterstützt nur 10 Spalten — mit der neuen
        // ATNO-Spalte haben wir die Grenze erreicht. Kontinent wurde
        // deshalb mit »Land« zusammengeführt (»Germany (EU)«); für
        // continent-spezifische Sortierung gibt's den Filter in der
        // Top-Bar.
        Table(sortedSpots,
              selection: $selection,
              sortOrder: $sortOrder,
              columnCustomization: $columnCustomization) {
            TableColumn("") { s in
                if watchList?.matches(s.dxCall) == true {
                    Text("★")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.yellow)
                }
            }
            .width(18)
            .customizationID("watch")
            .disabledCustomizationBehavior(.reorder)

            TableColumn("Zeit", value: \.spotTime) { s in
                cell(s.displayTime, s)
            }
            .width(min: 50, ideal: 60)
            .customizationID("time")

            TableColumn("Freq (kHz)", value: \.frequency) { s in
                cell(s.displayFreq, s).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 85)
            .customizationID("freq")

            TableColumn("Band", value: \.band) { s in
                Text(s.band)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(bandColor(for: s.band))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .width(min: 45, ideal: 55)
            .customizationID("band")

            TableColumn("Mode", value: \.mode) { s in
                cell(s.displayMode, s).frame(maxWidth: .infinity, alignment: .center)
            }
            .width(min: 45, ideal: 55)
            .customizationID("mode")

            TableColumn("ATNO") { s in
                let status: ATNOStatus = showATNO
                    ? manager.atnoStatus(country: s.country,
                                          band: s.band,
                                          mode: s.displayMode)
                    : .worked
                if status.isHighlight {
                    Text(status.label)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(status.textColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(status.color)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .width(min: 60, ideal: 78)
            .customizationID("atno")

            TableColumn("DX-Rufz.", value: \.dxCall) { s in
                let watched = watchList?.matches(s.dxCall) == true
                let accent = rowAccent?(s)
                let color: Color = accent
                    ?? (watched ? Color(red: 1, green: 0.8, blue: 0) : bandColor(for: s.band))
                Text(s.dxCall)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
            }
            .width(min: 80, ideal: 130)
            .customizationID("call")

            // Kontinent früher eigene Spalte — wegen Builder-Limit (10) jetzt
            // angeflanscht in Klammern, z.B. »Germany (EU)«. Continent-Filter
            // im Top-Bar bleibt davon unberührt.
            TableColumn("Land", value: \.country) { s in
                let label = s.continent.isEmpty
                    ? s.country
                    : "\(s.country) (\(s.continent))"
                cell(label, s)
            }
            .width(min: 110, ideal: 150)
            .customizationID("country")

            TableColumn("Kommentar", value: \.comment) { s in
                cell(String(s.comment.prefix(40)), s)
            }
            .width(min: 100, ideal: 160)
            .customizationID("comment")

            TableColumn("Spotter / Quelle", value: \.spotter) { s in
                HStack(spacing: 6) {
                    Text(s.spotter)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(watchList?.matches(s.dxCall) == true
                                         ? Color(red: 1, green: 0.8, blue: 0)
                                         : bandColor(for: s.band))
                    Text(s.source)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(sourceColor(s.sourceType))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    // Multi-Cluster-Confidence: »+N« wenn weitere Pool-
                    // Quellen denselben Spot innerhalb des Dedup-Fensters
                    // gemeldet haben. Tooltip listet die Quellen auf.
                    if !s.alsoSeenBy.isEmpty {
                        Text("+\(s.alsoSeenBy.count)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(theme.accentGreen.opacity(0.20))
                            .foregroundStyle(theme.accentGreen)
                            .clipShape(Capsule())
                            .help("Auch gesehen von: " + s.alsoSeenBy.joined(separator: ", "))
                    }
                }
            }
            .width(min: 130, ideal: 200)
            .customizationID("spotter")
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .font(.system(size: 12))
        .contextMenu(forSelectionType: DXSpot.ID.self) { ids in
            if let id = ids.first, let spot = sortedSpots.first(where: { $0.id == id }) {
                Button {
                    activate(spot)
                } label: {
                    Label("Ins Logbuch eintragen", systemImage: "book.closed.fill")
                }
            }
        } primaryAction: { ids in
            // Doppelklick → auch ins Log
            if let id = ids.first, let spot = sortedSpots.first(where: { $0.id == id }) {
                activate(spot)
            }
        }
    }

    /// Reaktion auf Spot-Klick: Draft ins Logbuch laden — LogEntryBridge
    /// löst zusätzlich ein QSY am TRX aus, falls in HAMRechnerApp ein
    /// onRequestQSY-Callback gesetzt wurde (zentrale Stelle, damit weder
    /// SpotListView noch die Pop-up-Bandmaps direkten CAT-Zugriff brauchen).
    private func activate(_ spot: DXSpot) {
        LogEntryBridge.shared.openInLog(from: spot)
    }

    private func sourceColor(_ type: String) -> Color {
        switch type {
        case "SOTAwatch3": return theme.colorSOTA
        case "POTA":       return theme.colorPOTA
        case "WWFF":       return theme.colorWWFF
        default:           return theme.accentBlue   // DX-Cluster
        }
    }

    @ViewBuilder
    private func cell(_ text: String, _ spot: DXSpot) -> some View {
        let watched = watchList?.matches(spot.dxCall) == true
        let accent = rowAccent?(spot)
        let color: Color = accent
            ?? (watched ? Color(red: 1, green: 0.8, blue: 0) : bandColor(for: spot.band))
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(color)
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
