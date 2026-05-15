import SwiftUI

// SOTA-Spots-Tab. Live-Feed aus api2.sota.org.uk/api/spots/50/all als
// spalten-basierte Table (SwiftUI Table mit Reorder + Hide/Show).
// Filter: Band, Mode, Assoc/Region-Prefix, "nur manuell". Copy via
// Context-Menü oder Doppelklick füllt Their Call + Their Summit ins
// SOTA-Form. Falls CAT aktiv: QSY zur Spot-Frequenz.
struct SotaSpotsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var spots:        SotaSpotsService
    @EnvironmentObject var cat:          CATController
    @EnvironmentObject var radio:        RadioState

    var onCopy: (SOTASpot) -> Void

    @State private var filterBand: String = "Alle"
    @State private var filterMode: String = "Alle"
    @State private var filterAssoc: String = ""
    @State private var qsyOnCopy: Bool = true
    @State private var hideAutomatic: Bool = false   // RBNHole / sotl.as ausblenden

    @State private var sortOrder: [KeyPathComparator<SOTASpot>] = [
        KeyPathComparator(\SOTASpot.timeStamp, order: .reverse)
    ]
    @State private var selection: SOTASpot.ID? = nil
    @State private var columnCustomization = TableColumnCustomization<SOTASpot>()
    private let customizationStorageKey = "dxcluster.sotaSpots.columnCustomization.v1"

    private var theme: AppTheme { themeManager.theme }

    private static let bands  = ["Alle", "160m", "80m", "60m", "40m", "30m", "20m",
                                 "17m", "15m", "12m", "10m", "6m", "2m", "70cm"]
    private static let modes  = ["Alle", "SSB", "CW", "FT8", "FT4", "RTTY", "AM", "FM", "DATA"]

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider().background(theme.separator)
            if spots.spots.isEmpty {
                emptyState
            } else {
                spotTable
            }
        }
        .background(theme.bgPanel)
        .onAppear {
            spots.start()
            loadCustomization()
        }
        .onDisappear { spots.stop() }
        .onChange(of: columnCustomization) { _, _ in saveCustomization() }
    }

    // MARK: - Filter-Toolbar

    private var filterBar: some View {
        HStack(spacing: 8) {
            Picker("Band", selection: $filterBand) {
                ForEach(Self.bands, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 110)

            Picker("Mode", selection: $filterMode) {
                ForEach(Self.modes, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 110)

            HStack(spacing: 3) {
                Image(systemName: "magnifyingglass").font(.caption2)
                TextField("Assoc (HB, DM, G/LD …)", text: $filterAssoc)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .onChange(of: filterAssoc) { _, n in
                        let up = n.uppercased()
                        if up != n { filterAssoc = up }
                    }
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(theme.bgCard2)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(maxWidth: 180)

            Toggle(isOn: $hideAutomatic) {
                Text("Nur manuell").font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help("Automatische Spots (RBNHole, sotl.as) ausblenden")

            Toggle(isOn: $qsyOnCopy) {
                Text("QSY bei Copy").font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help(cat.status == .connected ? "Bei Klick auf Copy springt der TRX auf die Spot-Frequenz" : "CAT nicht aktiv — QSY funktioniert nicht")
            .disabled(cat.status != .connected)

            Spacer()

            statusLine

            Button { Task { await spots.fetchOnce() } } label: {
                if spots.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .help("Manuell aktualisieren")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.bgCard2)
    }

    private var statusLine: some View {
        Group {
            if let err = spots.lastError {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(err).foregroundStyle(.orange)
                }
                .font(.caption2)
                .lineLimit(1)
            } else if let last = spots.lastFetch {
                let df = DateFormatter()
                let _ = df.timeZone = TimeZone(identifier: "UTC")
                let _ = df.dateFormat = "HH:mm:ss"
                Text("\(spots.spots.count) Spots · \(df.string(from: last))Z")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
            } else {
                Text("Lade…").font(.caption2).foregroundStyle(theme.textDim)
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mountain.2.circle")
                .font(.system(size: 40))
                .foregroundStyle(.brown.opacity(0.7))
            Text(spots.isLoading ? "Lade SOTA-Spots …" : "Noch keine Spots")
                .font(.callout)
                .foregroundStyle(theme.textSecondary)
            if let err = spots.lastError {
                Text(err).font(.caption).foregroundStyle(.orange)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Table

    private var filtered: [SOTASpot] {
        var arr = spots.spots
        if filterBand != "Alle" {
            arr = arr.filter { $0.band == filterBand }
        }
        if filterMode != "Alle" {
            let f = filterMode.uppercased()
            arr = arr.filter { $0.mode.uppercased() == f }
        }
        let prefix = filterAssoc.trimmingCharacters(in: .whitespaces)
        if !prefix.isEmpty {
            arr = arr.filter { $0.fullReference.uppercased().hasPrefix(prefix) }
        }
        if hideAutomatic {
            arr = arr.filter { !$0.isAutomaticSpot }
        }
        return arr.sorted(using: sortOrder)
    }

    private var spotTable: some View {
        Table(filtered,
              selection: $selection,
              sortOrder: $sortOrder,
              columnCustomization: $columnCustomization) {
            Group {
                TableColumn("Zeit", value: \SOTASpot.timeStamp) { s in
                    Text(timeAgoText(s.timeStamp))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textDim)
                }
                .width(min: 50, ideal: 60)
                .customizationID("time")

                TableColumn("Freq (MHz)", value: \SOTASpot.frequencyMHz) { s in
                    if s.frequencyMHz > 0 {
                        Text(String(format: "%.3f", s.frequencyMHz))
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("—")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .width(min: 70, ideal: 85)
                .customizationID("freq")

                TableColumn("Band", value: \SOTASpot.band) { s in
                    Text(s.band)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .width(min: 45, ideal: 55)
                .customizationID("band")

                TableColumn("Mode", value: \SOTASpot.mode) { s in
                    Text(SSBResolver.displayMode(rawMode: s.mode, frequencyMHz: s.frequencyMHz))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .width(min: 45, ideal: 60)
                .customizationID("mode")

                TableColumn("Aktivator", value: \SOTASpot.activatorCallsign) { s in
                    Text(s.activatorCallsign)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                }
                .width(min: 80, ideal: 110)
                .customizationID("activator")

                TableColumn("Ref", value: \SOTASpot.fullReference) { s in
                    Text(s.fullReference)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.accentBlue)
                }
                .width(min: 70, ideal: 95)
                .customizationID("ref")

                TableColumn("Summit") { (s: SOTASpot) in
                    Text(s.summitDetails ?? "")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .width(min: 100, ideal: 180)
                .customizationID("summit")

                TableColumn("Assoc", value: \SOTASpot.associationCode) { s in
                    Text(s.associationCode)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                }
                .width(min: 50, ideal: 65)
                .customizationID("assoc")
                .defaultVisibility(.hidden)

                TableColumn("Spotter", value: \SOTASpot.callsign) { s in
                    Text(s.callsign)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textDim)
                }
                .width(min: 70, ideal: 90)
                .customizationID("spotter")

                TableColumn("Name") { (s: SOTASpot) in
                    Text(s.activatorName ?? "")
                        .font(.caption)
                        .foregroundStyle(theme.textDim)
                }
                .width(min: 80, ideal: 110)
                .customizationID("name")
                .defaultVisibility(.hidden)
            }

            Group {
                TableColumn("Kommentar") { (s: SOTASpot) in
                    Text(s.comments ?? "")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(theme.textDim)
                }
                .width(min: 120, ideal: 200)
                .customizationID("comment")

                TableColumn("AUTO") { (s: SOTASpot) in
                    if s.isAutomaticSpot {
                        Text("AUTO")
                            .font(.caption2.bold())
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .width(min: 45, ideal: 55)
                .customizationID("auto")
                .defaultVisibility(.hidden)

                TableColumn("•") { (s: SOTASpot) in
                    if let hc = s.highlightColor, !hc.isEmpty {
                        Circle()
                            .fill(highlightColor(hc))
                            .frame(width: 8, height: 8)
                            .help("SOTAwatch-Markierung: \(hc)")
                    }
                }
                .width(18)
                .customizationID("highlight")

                TableColumn("") { s in
                    Button { copyToForm(s) } label: {
                        Image(systemName: "square.and.arrow.up.fill")
                            .foregroundStyle(theme.accentBlue)
                    }
                    .buttonStyle(.borderless)
                    .disabled(s.frequencyMHz <= 0)
                    .help("Copy ins SOTA-Form")
                }
                .width(28)
                .customizationID("action")
                .disabledCustomizationBehavior([.visibility, .reorder])
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .font(.system(size: 12))
        .contextMenu(forSelectionType: SOTASpot.ID.self) { ids in
            if let id = ids.first, let spot = filtered.first(where: { $0.id == id }) {
                Button {
                    copyToForm(spot)
                } label: {
                    Label("Copy ins SOTA-Form", systemImage: "square.and.arrow.up.fill")
                }
                .disabled(spot.frequencyMHz <= 0)
            }
        } primaryAction: { ids in
            if let id = ids.first, let spot = filtered.first(where: { $0.id == id }),
               spot.frequencyMHz > 0 {
                copyToForm(spot)
            }
        }
    }

    private func loadCustomization() {
        guard let data = UserDefaults.standard.data(forKey: customizationStorageKey),
              let decoded = try? JSONDecoder().decode(TableColumnCustomization<SOTASpot>.self, from: data) else {
            return
        }
        columnCustomization = decoded
    }

    private func saveCustomization() {
        guard let data = try? JSONEncoder().encode(columnCustomization) else { return }
        UserDefaults.standard.set(data, forKey: customizationStorageKey)
    }

    private func highlightColor(_ raw: String) -> Color {
        switch raw.lowercased() {
        case "green":  return .green
        case "yellow": return .yellow
        case "red":    return .red
        case "orange": return .orange
        case "blue":   return .blue
        default:       return .gray
        }
    }

    private func copyToForm(_ s: SOTASpot) {
        onCopy(s)
        if qsyOnCopy, case .connected = cat.status, s.frequencyMHz > 0 {
            let mhz = s.frequencyMHz
            let mode = SSBResolver.hamlibMode(rawMode: s.mode, frequencyMHz: mhz)
            Task {
                await cat.setFrequencyMHz(mhz)
                if let m = mode { await cat.setHamlibMode(m) }
            }
        }
    }

    private func timeAgoText(_ d: Date) -> String {
        let secs = Int(Date().timeIntervalSince(d))
        if secs < 60 { return "\(secs)s" }
        if secs < 3600 { return "\(secs/60)m" }
        if secs < 86400 { return "\(secs/3600)h" }
        return "\(secs/86400)d"
    }
}
