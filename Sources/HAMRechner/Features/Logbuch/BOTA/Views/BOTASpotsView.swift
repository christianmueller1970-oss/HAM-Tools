import SwiftUI

// BOTA-Spots-Tab. Architektur analog WWFFSpotsView: kein eigenes API
// (bunkersontheair.com nur Stub, GMA kein BOTA-Feed). Wir filtern den
// DX-Cluster-Stream nach Refs, die in der lokalen bota_refs-DB existieren
// — das vermeidet Pattern-Konflikte mit POTA/WWFF-Refs. Anzeige als
// spalten-basierte Table (Reorder + Hide/Show via Header).
struct BOTASpotsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var clusterVM:    DXClusterViewModel
    @EnvironmentObject var bota:         BOTARefService
    @EnvironmentObject var cat:          CATController
    @EnvironmentObject var radio:        RadioState

    var onCopy: (BOTASpot) -> Void

    @State private var filterBand: String = "Alle"
    @State private var filterMode: String = "Alle"
    @State private var filterPrefix: String = ""
    @State private var qsyOnCopy: Bool = true

    @State private var sortOrder: [KeyPathComparator<BOTASpot>] = [
        KeyPathComparator(\BOTASpot.timeStamp, order: .reverse)
    ]
    @State private var selection: BOTASpot.ID? = nil
    @State private var columnCustomization = TableColumnCustomization<BOTASpot>()
    private let customizationStorageKey = "dxcluster.botaSpots.columnCustomization.v1"

    private var theme: AppTheme { themeManager.theme }

    private static let bands  = ["Alle", "160m", "80m", "60m", "40m", "30m", "20m",
                                 "17m", "15m", "12m", "10m", "6m", "2m", "70cm"]
    private static let modes  = ["Alle", "SSB", "CW", "FT8", "FT4", "RTTY", "AM", "FM", "DATA"]

    // Pattern für mögliche Bunker-Refs im Kommentar. Wir testen jeden Match
    // zusätzlich gegen die DB — nur tatsächliche bota_refs-Einträge zählen.
    private static let pattern = try! NSRegularExpression(
        pattern: #"\b([A-Z]{1,4})-(\d{3,5})\b"#)

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

    private var derived: [BOTASpot] {
        var seen: Set<UUID> = []
        var out: [BOTASpot] = []
        for dx in clusterVM.spots {
            if let ref = Self.firstBOTARef(in: dx.comment, db: bota),
               seen.insert(dx.id).inserted {
                out.append(BOTASpot(from: dx, reference: ref))
            }
        }
        return out
    }

    /// Findet die erste Ref im Comment, die tatsächlich in der bota_refs-DB
    /// existiert. Ohne DB-Lookup wäre das Pattern zu generisch (würde POTA-
    /// und WWFF-Refs mitfangen).
    private static func firstBOTARef(in comment: String, db: BOTARefService) -> String? {
        let range = NSRange(comment.startIndex..., in: comment)
        let matches = pattern.matches(in: comment, range: range)
        for m in matches {
            guard let r = Range(m.range, in: comment) else { continue }
            let candidate = String(comment[r]).uppercased()
            if db.ref(forReference: candidate) != nil {
                return candidate
            }
        }
        return nil
    }

    private var filtered: [BOTASpot] {
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
                TextField("Programm (DE, BU, F …)", text: $filterPrefix)
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
        let botaCount = derived.count
        return Text("\(botaCount) BOTA-Spots aus \(totalDX) DX-Cluster-Spots")
            .font(.caption2)
            .foregroundStyle(theme.textDim)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 40))
                .foregroundStyle(.gray.opacity(0.7))
            Text("Keine BOTA-Spots im DX-Cluster")
                .font(.callout)
                .foregroundStyle(theme.textSecondary)
            Text("BOTA-Spots werden aus DX-Cluster-Kommentaren extrahiert und gegen die lokale Bunker-DB gematcht. Falls die DB leer ist, importiere zuerst eine CSV in den Einstellungen.")
                .font(.caption)
                .foregroundStyle(theme.textDim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var spotTable: some View {
        Table(filtered,
              selection: $selection,
              sortOrder: $sortOrder,
              columnCustomization: $columnCustomization) {
            Group {
                TableColumn("Zeit", value: \BOTASpot.timeStamp) { s in
                    Text(timeAgoText(s.timeStamp))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textDim)
                }
                .width(min: 50, ideal: 60)
                .customizationID("time")

                TableColumn("Freq (MHz)", value: \BOTASpot.frequencyMHz) { s in
                    Text(String(format: "%.3f", s.frequencyMHz))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 70, ideal: 85)
                .customizationID("freq")

                TableColumn("Band", value: \BOTASpot.band) { s in
                    Text(s.band)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .width(min: 45, ideal: 55)
                .customizationID("band")

                TableColumn("Mode", value: \BOTASpot.mode) { s in
                    Text(SSBResolver.displayMode(rawMode: s.mode, frequencyMHz: s.frequencyMHz))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .width(min: 45, ideal: 60)
                .customizationID("mode")

                TableColumn("DX-Rufz.", value: \BOTASpot.dxCall) { s in
                    Text(s.dxCall)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                }
                .width(min: 80, ideal: 100)
                .customizationID("call")

                TableColumn("Ref", value: \BOTASpot.reference) { s in
                    Text(s.reference)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.gray)
                }
                .width(min: 70, ideal: 95)
                .customizationID("ref")

                TableColumn("Spotter", value: \BOTASpot.spotter) { s in
                    Text(s.spotter)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textDim)
                }
                .width(min: 70, ideal: 90)
                .customizationID("spotter")

                TableColumn("Kommentar") { (s: BOTASpot) in
                    Text(s.comments)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(theme.textDim)
                }
                .width(min: 120, ideal: 200)
                .customizationID("comment")

                TableColumn("AUTO") { (s: BOTASpot) in
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
                .help("Copy ins BOTA-Form")
            }
            .width(28)
            .customizationID("action")
            .disabledCustomizationBehavior([.visibility, .reorder])
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .font(.system(size: 12))
        .contextMenu(forSelectionType: BOTASpot.ID.self) { ids in
            if let id = ids.first, let spot = filtered.first(where: { $0.id == id }) {
                Button {
                    copyToForm(spot)
                } label: {
                    Label("Copy ins BOTA-Form", systemImage: "square.and.arrow.up.fill")
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
              let decoded = try? JSONDecoder().decode(TableColumnCustomization<BOTASpot>.self, from: data) else {
            return
        }
        columnCustomization = decoded
    }

    private func saveCustomization() {
        guard let data = try? JSONEncoder().encode(columnCustomization) else { return }
        UserDefaults.standard.set(data, forKey: customizationStorageKey)
    }

    private func copyToForm(_ s: BOTASpot) {
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
