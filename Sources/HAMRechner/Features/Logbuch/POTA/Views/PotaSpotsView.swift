import SwiftUI

// POTA-Spots-Tab. Live-Feed aus api.pota.app/spot/activator als spaltenbasierte
// Tabelle (SwiftUI Table mit Reorder + Hide/Show per Header-Rechtsklick).
// Filter: Band, Mode, Ref-Prefix. Copy via Context-Menü oder Doppelklick
// füllt Their Call + Their Park ins POTA-Form. Falls CAT aktiv: QSY zur
// Spot-Frequenz.
struct PotaSpotsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var spots:        PotaSpotsService
    @EnvironmentObject var cat:          CATController
    @EnvironmentObject var radio:        RadioState

    // Inputs vom Parent (POTAEntryForm) für Copy-Aktion.
    var onCopy: (POTASpot) -> Void

    @State private var filterBand: String = "Alle"
    @State private var filterMode: String = "Alle"
    @State private var filterRef: String = ""
    @State private var qsyOnCopy: Bool = true

    @State private var sortOrder: [KeyPathComparator<POTASpot>] = [
        KeyPathComparator(\POTASpot.spotTime, order: .reverse)
    ]
    @State private var selection: POTASpot.ID? = nil
    @State private var columnCustomization = TableColumnCustomization<POTASpot>()
    private let customizationStorageKey = "dxcluster.potaSpots.columnCustomization.v1"

    private var theme: AppTheme { themeManager.theme }

    private static let bands  = ["Alle", "160m", "80m", "60m", "40m", "30m", "20m",
                                 "17m", "15m", "12m", "10m", "6m", "2m"]
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
                TextField("Ref (US, US-W, CH-…)", text: $filterRef)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .onChange(of: filterRef) { _, n in
                        let up = n.uppercased()
                        if up != n { filterRef = up }
                    }
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(theme.bgCard2)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(maxWidth: 180)

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
            Image(systemName: "tree.circle")
                .font(.system(size: 40))
                .foregroundStyle(.green.opacity(0.7))
            Text(spots.isLoading ? "Lade POTA-Spots …" : "Noch keine Spots")
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

    private var filtered: [POTASpot] {
        var arr = spots.spots
        if filterBand != "Alle" {
            arr = arr.filter { $0.band == filterBand }
        }
        if filterMode != "Alle" {
            let f = filterMode.uppercased()
            arr = arr.filter { $0.mode.uppercased() == f }
        }
        let ref = filterRef.trimmingCharacters(in: .whitespaces)
        if !ref.isEmpty {
            arr = arr.filter { $0.reference.uppercased().hasPrefix(ref) }
        }
        return arr.sorted(using: sortOrder)
    }

    private var spotTable: some View {
        Table(filtered,
              selection: $selection,
              sortOrder: $sortOrder,
              columnCustomization: $columnCustomization) {
            Group {
                TableColumn("Zeit", value: \POTASpot.spotTime) { s in
                    Text(timeAgoText(s.spotTime))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textDim)
                }
                .width(min: 50, ideal: 60)
                .customizationID("time")

                TableColumn("Freq (kHz)", value: \POTASpot.frequencyKhz) { s in
                    Text(String(format: "%.1f", s.frequencyKhz))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 70, ideal: 85)
                .customizationID("freq")

                TableColumn("Band", value: \POTASpot.band) { s in
                    Text(s.band)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .width(min: 45, ideal: 55)
                .customizationID("band")

                TableColumn("Mode", value: \POTASpot.mode) { s in
                    Text(s.mode)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .width(min: 45, ideal: 60)
                .customizationID("mode")

                TableColumn("Aktivator", value: \POTASpot.activator) { s in
                    Text(s.activator)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                }
                .width(min: 80, ideal: 100)
                .customizationID("activator")

                TableColumn("Ref", value: \POTASpot.reference) { s in
                    Text(s.reference)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.accentBlue)
                }
                .width(min: 70, ideal: 90)
                .customizationID("ref")

                TableColumn("Park") { (s: POTASpot) in
                    Text(s.parkName ?? "")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .width(min: 100, ideal: 180)
                .customizationID("park")

                TableColumn("Location") { (s: POTASpot) in
                    Text(s.locationDesc ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                }
                .width(min: 60, ideal: 80)
                .customizationID("location")

                TableColumn("Spotter") { (s: POTASpot) in
                    Text(s.spotter ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textDim)
                }
                .width(min: 70, ideal: 90)
                .customizationID("spotter")

                TableColumn("Kommentar") { (s: POTASpot) in
                    Text(s.comments ?? "")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(theme.textDim)
                }
                .width(min: 120, ideal: 200)
                .customizationID("comment")
            }

            TableColumn("Source") { (s: POTASpot) in
                Text(s.source ?? "")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
            }
            .width(min: 70, ideal: 100)
            .customizationID("source")
            .defaultVisibility(.hidden)

            TableColumn("") { s in
                Button { copyToForm(s) } label: {
                    Image(systemName: "square.and.arrow.up.fill")
                        .foregroundStyle(theme.accentBlue)
                }
                .buttonStyle(.borderless)
                .help("Copy ins POTA-Form")
            }
            .width(28)
            .customizationID("action")
            .disabledCustomizationBehavior([.visibility, .reorder])
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .font(.system(size: 12))
        .contextMenu(forSelectionType: POTASpot.ID.self) { ids in
            if let id = ids.first, let spot = filtered.first(where: { $0.id == id }) {
                Button {
                    copyToForm(spot)
                } label: {
                    Label("Copy ins POTA-Form", systemImage: "square.and.arrow.up.fill")
                }
            }
        } primaryAction: { ids in
            if let id = ids.first, let spot = filtered.first(where: { $0.id == id }) {
                copyToForm(spot)
            }
        }
    }

    private func loadCustomization() {
        guard let data = UserDefaults.standard.data(forKey: customizationStorageKey),
              let decoded = try? JSONDecoder().decode(TableColumnCustomization<POTASpot>.self, from: data) else {
            return
        }
        columnCustomization = decoded
    }

    private func saveCustomization() {
        guard let data = try? JSONEncoder().encode(columnCustomization) else { return }
        UserDefaults.standard.set(data, forKey: customizationStorageKey)
    }

    private func copyToForm(_ s: POTASpot) {
        onCopy(s)
        if qsyOnCopy, case .connected = cat.status {
            Task { await cat.setFrequencyMHz(s.frequencyMHz) }
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
