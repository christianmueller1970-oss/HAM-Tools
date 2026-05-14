import SwiftUI

// WWFF-Spots-Tab. Statt eigener API (gibt's nicht öffentlich) filtern wir
// den regulären DX-Cluster-Stream nach Spots mit WWFF-Pattern im Comment.
// Pattern-Erkennung läuft über LogEntryBridge.extractRefs, also dieselbe
// Logik wie beim Cluster-Spot-Click ins QSO-Form.
//
// Strukturell parallel zu SotaSpotsView / PotaSpotsView, aber arbeitet
// auf DXSpot + abgeleitetem WWFFSpot statt einer eigenen API-Quelle.
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
    @State private var sortByTime: Bool = true

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
                grid
            }
        }
        .background(theme.bgPanel)
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
        if sortByTime {
            arr.sort { $0.timeStamp > $1.timeStamp }
        } else {
            arr.sort { $0.frequencyMHz < $1.frequencyMHz }
        }
        return arr
    }

    // MARK: - Filter-Toolbar

    private var filterBar: some View {
        HStack(spacing: 8) {
            Button { sortByTime.toggle() } label: {
                HStack(spacing: 3) {
                    Image(systemName: sortByTime ? "clock" : "waveform")
                    Text(sortByTime ? "Zeit" : "Freq")
                }
                .font(.caption)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(theme.bgCard2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)

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

    // MARK: - Card Grid

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 8)],
                      spacing: 8) {
                ForEach(filtered) { spot in
                    spotCard(spot)
                }
            }
            .padding(10)
        }
    }

    private func spotCard(_ s: WWFFSpot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(s.dxCall)
                    .font(.callout.bold().monospaced())
                    .foregroundStyle(theme.textPrimary)
                Text("@").foregroundStyle(theme.textDim)
                Text(s.reference)
                    .font(.callout.monospaced())
                    .foregroundStyle(theme.colorWWFF)
                Spacer()
                Text(timeAgoText(s.timeStamp))
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.textDim)
            }

            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption2)
                    .foregroundStyle(theme.accentBlue)
                Text(String(format: "%.3f MHz", s.frequencyMHz))
                    .font(.caption.monospaced())
                if !s.mode.isEmpty {
                    Text("(\(s.mode))")
                        .font(.caption.monospaced())
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                if !s.band.isEmpty {
                    Text(s.band)
                        .font(.caption.monospaced())
                        .foregroundStyle(theme.textSecondary)
                }
            }

            if !s.spotter.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person").font(.caption2)
                    Text(s.spotter).font(.caption.monospaced())
                    if s.isAutomaticSpot {
                        Text("AUTO").font(.caption2.bold())
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .foregroundStyle(theme.textDim)
            }

            if !s.comments.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "bubble.left").font(.caption2)
                    Text(s.comments).font(.caption).lineLimit(2)
                }
                .foregroundStyle(theme.textDim)
            }

            HStack {
                Button { copyToForm(s) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Copy")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.accentBlue.opacity(0.18))
                    .foregroundStyle(theme.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgCard)
        .overlay(RoundedRectangle(cornerRadius: 6)
            .stroke(theme.separator, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func copyToForm(_ s: WWFFSpot) {
        onCopy(s)
        if qsyOnCopy, case .connected = cat.status, s.frequencyMHz > 0 {
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
