import SwiftUI

// WWFF-Spots-Tab. Statt eigener API (gibt's nicht öffentlich) filtern wir
// den regulären DX-Cluster-Stream nach Spots mit WWFF-Pattern im Comment.
// Pattern-Erkennung läuft über LogEntryBridge.extractRefs, also dieselbe
// Logik wie beim Cluster-Spot-Click ins QSO-Form. Anzeige als
// spalten-basierte Table (Reorder + Hide/Show via Header).
struct WWFFSpotsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var clusterVM:    DXClusterViewModel
    @EnvironmentObject var cat:          CATController
    @EnvironmentObject var radio:        RadioState

    var onCopy: (WWFFSpot) -> Void

    @State private var filterBand: String = "Alle"
    @State private var filterMode: String = "Alle"
    @State private var filterPrefix: String = ""
    @State private var qsyOnCopy: Bool = true

    @State private var sortOrder: [KeyPathComparator<WWFFSpot>] = [
        KeyPathComparator(\WWFFSpot.timeStamp, order: .reverse)
    ]
    @State private var selection: WWFFSpot.ID? = nil
    @State private var columnCustomization = TableColumnCustomization<WWFFSpot>()
    private let customizationStorageKey = "dxcluster.wwffSpots.columnCustomization.v1"

    private var theme: AppTheme { themeManager.theme }

    private static let bands  = ["Alle", "160m", "80m", "60m", "40m", "30m", "20m",
                                 "17m", "15m", "12m", "10m", "6m", "2m", "70cm"]
    private static let modes  = ["Alle", "SSB", "CW", "FT8", "FT4", "RTTY", "AM", "FM", "DATA"]

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider().background(theme.separator)
            if derived.isEmpty {
                emptyState
            } else {
                spotTable
            }
        }
        .background(theme.bgPanel)
        .onAppear { loadCustomization() }
        .onChange(of: columnCustomization) { _, _ in saveCustomization() }
    }

    // MARK: - Derivation

    /// Filtert clusterVM.spots auf Einträge mit WWFF-Ref im Comment. Pro
    /// Spot wird der erste WWFF-Treffer als Ref übernommen.
    private var derived: [WWFFSpot] {
        var seen: Set<UUID> = []
        var out: [WWFFSpot] = []
        for dx in clusterVM.spots {
            let refs = LogEntryBridge.extractRefs(from: dx.comment,
                                                  sourceType: dx.sourceType)
            guard let ref = refs.wwff, !ref.isEmpty else { continue }
            if seen.insert(dx.id).inserted {
                out.append(WWFFSpot(from: dx, reference: ref))
            }
        }
        return out
    }

    private var filtered: [WWFFSpot] {
        var arr = derived
        if filterBand != "Alle" {
            arr = arr.filter { $0.band == filterBand }
        }
        if filterMode != "Alle" {
            let f = filterMode.uppercased()
            arr = arr.filter { $0.mode.uppercased() == f }
        }
        let prefix = filterPrefix.trimmingCharacters(in: .whitespaces)
        if !prefix.isEmpty {
            arr = arr.filter { $0.reference.uppercased().hasPrefix(prefix) }
        }
        return arr.sorted(using: sortOrder)
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
                TextField("Programm (DLFF, HBFF, KFF …)", text: $filterPrefix)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .onChange(of: filterPrefix) { _, n in
                        let up = n.uppercased()
                        if up != n { filterPrefix = up }
                    }
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(theme.bgCard2)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(maxWidth: 200)

            Toggle(isOn: $qsyOnCopy) {
                Text("QSY bei Copy").font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help(cat.status == .connected ? "Bei Klick auf Copy springt der TRX auf die Spot-Frequenz" : "CAT nicht aktiv — QSY funktioniert nicht")
            .disabled(cat.status != .connected)

            Spacer()

            statusLine
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.bgCard2)
    }

    private var statusLine: some View {
        let totalDX = clusterVM.spots.count
        let wwffCount = derived.count
        return Text("\(wwffCount) WWFF-Spots aus \(totalDX) DX-Cluster-Spots")
            .font(.caption2)
            .foregroundStyle(theme.textDim)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 40))
                .foregroundStyle(theme.colorWWFF.opacity(0.7))
            Text("Keine WWFF-Spots im DX-Cluster")
                .font(.callout)
                .foregroundStyle(theme.textSecondary)
            Text("WWFF-Spots werden aus den DX-Cluster-Kommentaren extrahiert (Pattern: XXFF-NNNN). Wenn keiner spotted oder der Cluster gerade ruhig ist, ist die Liste leer.")
                .font(.caption)
                .foregroundStyle(theme.textDim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Table

    private var spotTable: some View {
        Table(filtered,
              selection: $selection,
              sortOrder: $sortOrder,
              columnCustomization: $columnCustomization) {
            Group {
                TableColumn("Zeit", value: \WWFFSpot.timeStamp) { s in
                    Text(timeAgoText(s.timeStamp))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textDim)
                }
                .width(min: 50, ideal: 60)
                .customizationID("time")

                TableColumn("Freq (MHz)", value: \WWFFSpot.frequencyMHz) { s in
                    Text(String(format: "%.3f", s.frequencyMHz))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 70, ideal: 85)
                .customizationID("freq")

                TableColumn("Band", value: \WWFFSpot.band) { s in
                    Text(s.band)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .width(min: 45, ideal: 55)
                .customizationID("band")

                TableColumn("Mode", value: \WWFFSpot.mode) { s in
                    Text(SSBResolver.displayMode(rawMode: s.mode, frequencyMHz: s.frequencyMHz))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .width(min: 45, ideal: 60)
                .customizationID("mode")

                TableColumn("DX-Rufz.", value: \WWFFSpot.dxCall) { s in
                    Text(s.dxCall)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                }
                .width(min: 80, ideal: 100)
                .customizationID("call")

                TableColumn("Ref", value: \WWFFSpot.reference) { s in
                    Text(s.reference)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.colorWWFF)
                }
                .width(min: 70, ideal: 95)
                .customizationID("ref")

                TableColumn("Spotter", value: \WWFFSpot.spotter) { s in
                    Text(s.spotter)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textDim)
                }
                .width(min: 70, ideal: 90)
                .customizationID("spotter")

                TableColumn("Kommentar") { (s: WWFFSpot) in
                    Text(s.comments)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(theme.textDim)
                }
                .width(min: 120, ideal: 200)
                .customizationID("comment")

                TableColumn("AUTO") { (s: WWFFSpot) in
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
            }

            TableColumn("") { s in
                Button { copyToForm(s) } label: {
                    Image(systemName: "square.and.arrow.up.fill")
                        .foregroundStyle(theme.accentBlue)
                }
                .buttonStyle(.borderless)
                .disabled(s.frequencyMHz <= 0)
                .help("Copy ins WWFF-Form")
            }
            .width(28)
            .customizationID("action")
            .disabledCustomizationBehavior([.visibility, .reorder])
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .font(.system(size: 12))
        .contextMenu(forSelectionType: WWFFSpot.ID.self) { ids in
            if let id = ids.first, let spot = filtered.first(where: { $0.id == id }) {
                Button {
                    copyToForm(spot)
                } label: {
                    Label("Copy ins WWFF-Form", systemImage: "square.and.arrow.up.fill")
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
              let decoded = try? JSONDecoder().decode(TableColumnCustomization<WWFFSpot>.self, from: data) else {
            return
        }
        columnCustomization = decoded
    }

    private func saveCustomization() {
        guard let data = try? JSONEncoder().encode(columnCustomization) else { return }
        UserDefaults.standard.set(data, forKey: customizationStorageKey)
    }

    private func copyToForm(_ s: WWFFSpot) {
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
