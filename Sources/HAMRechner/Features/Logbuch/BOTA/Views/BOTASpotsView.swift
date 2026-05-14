import SwiftUI

// BOTA-Spots-Tab. Architektur analog WWFFSpotsView: kein eigenes API
// (bunkersontheair.com nur Stub, GMA kein BOTA-Feed). Wir filtern den
// DX-Cluster-Stream nach Refs, die in der lokalen bota_refs-DB existieren
// — das vermeidet Pattern-Konflikte mit POTA/WWFF-Refs.
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
    @State private var sortByTime: Bool = true

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
                grid
            }
        }
        .background(theme.bgPanel)
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
        if sortByTime {
            arr.sort { $0.timeStamp > $1.timeStamp }
        } else {
            arr.sort { $0.frequencyMHz < $1.frequencyMHz }
        }
        return arr
    }

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

    private func spotCard(_ s: BOTASpot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(s.dxCall)
                    .font(.callout.bold().monospaced())
                    .foregroundStyle(theme.textPrimary)
                Text("@").foregroundStyle(theme.textDim)
                Text(s.reference)
                    .font(.callout.monospaced())
                    .foregroundStyle(.gray)
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

    private func copyToForm(_ s: BOTASpot) {
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
