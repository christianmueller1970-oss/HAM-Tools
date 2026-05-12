import SwiftUI

// POTA-Spots-Tab. Live-Feed aus api.pota.app/spot/activator, Card-Grid.
// Filter: Band, Mode, Ref-Prefix. Copy-Button füllt Their Call + Their
// Park ins POTA-Form. Falls CAT aktiv: QSY zur Spot-Frequenz.
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
    @State private var sortByTime: Bool = true   // sonst Frequenz

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
                grid
            }
        }
        .background(theme.bgPanel)
        .onAppear { spots.start() }
        .onDisappear { spots.stop() }
    }

    // MARK: - Filter-Toolbar

    private var filterBar: some View {
        HStack(spacing: 8) {
            // Sort
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

    // MARK: - Card Grid

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
        if sortByTime {
            arr.sort { $0.spotTime > $1.spotTime }
        } else {
            arr.sort { $0.frequencyMHz < $1.frequencyMHz }
        }
        return arr
    }

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

    private func spotCard(_ s: POTASpot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(s.activator)
                    .font(.callout.bold().monospaced())
                    .foregroundStyle(theme.textPrimary)
                Text("@").foregroundStyle(theme.textDim)
                Text(s.reference)
                    .font(.callout.monospaced())
                    .foregroundStyle(theme.accentBlue)
                Spacer()
                Text(timeAgoText(s.spotTime))
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.textDim)
            }

            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption2)
                    .foregroundStyle(theme.accentBlue)
                Text(String(format: "%.3f MHz", s.frequencyMHz))
                    .font(.caption.monospaced())
                Text("(\(s.mode))")
                    .font(.caption.monospaced())
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if let loc = s.locationDesc, !loc.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "globe").font(.caption2)
                        Text(loc).font(.caption.monospaced())
                    }
                    .foregroundStyle(theme.textSecondary)
                }
            }

            if let name = s.parkName, !name.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle").font(.caption2)
                    Text(name).font(.caption).lineLimit(1)
                }
                .foregroundStyle(theme.textSecondary)
            }

            if let sp = s.spotter, !sp.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person").font(.caption2)
                    Text(sp).font(.caption.monospaced())
                }
                .foregroundStyle(theme.textDim)
            }

            if let comments = s.comments, !comments.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "bubble.left").font(.caption2)
                    Text(comments).font(.caption).lineLimit(2)
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
                Text(s.source ?? "")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgCard)
        .overlay(RoundedRectangle(cornerRadius: 6)
            .stroke(theme.separator, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func copyToForm(_ s: POTASpot) {
        onCopy(s)
        // Optional QSY ans Radio wenn CAT verbunden
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
