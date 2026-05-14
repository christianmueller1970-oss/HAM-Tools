import SwiftUI

// SOTA-Spots-Tab. Live-Feed aus api2.sota.org.uk/api/spots/50/all, Card-Grid.
// Filter: Band, Mode, Assoc/Region-Prefix. Copy-Button füllt Their Call +
// Their Summit ins SOTA-Form. Falls CAT aktiv: QSY zur Spot-Frequenz.
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
    @State private var sortByTime: Bool = true
    @State private var hideAutomatic: Bool = false   // RBNHole / sotl.as ausblenden

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

    // MARK: - Card Grid

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
            // Filtere auf Assoc-Code ("HB") oder vollständige Region ("HB/BE")
            arr = arr.filter { $0.fullReference.uppercased().hasPrefix(prefix) }
        }
        if hideAutomatic {
            arr = arr.filter { !$0.isAutomaticSpot }
        }
        if sortByTime {
            arr.sort { $0.timeStamp > $1.timeStamp }
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

    private func spotCard(_ s: SOTASpot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(s.activatorCallsign)
                    .font(.callout.bold().monospaced())
                    .foregroundStyle(theme.textPrimary)
                Text("@").foregroundStyle(theme.textDim)
                Text(s.fullReference)
                    .font(.callout.monospaced())
                    .foregroundStyle(theme.accentBlue)
                Spacer()
                Text(timeAgoText(s.timeStamp))
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.textDim)
            }

            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption2)
                    .foregroundStyle(theme.accentBlue)
                if s.frequencyMHz > 0 {
                    Text(String(format: "%.3f MHz", s.frequencyMHz))
                        .font(.caption.monospaced())
                } else {
                    Text("— MHz").font(.caption.monospaced()).foregroundStyle(.orange)
                }
                if !s.mode.isEmpty {
                    Text("(\(s.mode))")
                        .font(.caption.monospaced())
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                if !s.associationCode.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "globe").font(.caption2)
                        Text(s.associationCode).font(.caption.monospaced())
                    }
                    .foregroundStyle(theme.textSecondary)
                }
            }

            if let details = s.summitDetails, !details.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mountain.2").font(.caption2)
                    Text(details).font(.caption).lineLimit(1)
                }
                .foregroundStyle(theme.textSecondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "person").font(.caption2)
                Text(s.callsign).font(.caption.monospaced())
                if let name = s.activatorName, !name.isEmpty {
                    Text("· \(name)").font(.caption)
                }
                if s.isAutomaticSpot {
                    Text("AUTO").font(.caption2.bold())
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .foregroundStyle(theme.textDim)

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
                .disabled(s.frequencyMHz <= 0)
                Spacer()
                if let hc = s.highlightColor, !hc.isEmpty {
                    Circle()
                        .fill(highlightColor(hc))
                        .frame(width: 8, height: 8)
                        .help("SOTAwatch-Markierung: \(hc)")
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgCard)
        .overlay(RoundedRectangle(cornerRadius: 6)
            .stroke(theme.separator, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
