import SwiftUI

// Awards-Tab im Logbuch. Zeigt aufgeschlüsselt was in den Counter-Pills
// oben in der Tab-Bar summiert ist — DXCC-Liste, WAZ-Grid (40 Zonen),
// WAS-Grid (50 US-States). Sub-Tab-Switcher oben links.
struct AwardsTab: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var potaStats: PotaStatsService
    @Binding var subTab: AwardsSubTab
    @Binding var onlyUnconfirmed: Bool

    enum AwardsSubTab: String, CaseIterable, Identifiable {
        case dxcc = "DXCC"
        case waz  = "WAZ"
        case was  = "WAS"
        case pota = "POTA"
        case sota = "SOTA"
        case wwff = "WWFF"
        case bota = "BOTA"
        case ops  = "OPs"   // Multi-Op-Statistik, nur im Contest-Modus sichtbar
        var id: String { rawValue }
    }

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        Group {
            switch subTab {
            case .dxcc: dxccView
            case .waz:  wazView
            case .was:  wasView
            case .pota: potaView
            case .sota: sotaView
            case .wwff: wwffView
            case .bota: botaView
            case .ops:  opsView
            }
        }
        .background(theme.bgApp)
    }

    // MARK: - Multi-Op-Statistik (Contest)
    //
    // Aggregiert die QSOs des aktiven Logs nach `operatorCall`. Leere/nil-
    // Operator-Felder landen unter "(kein OP gesetzt)" — so sieht man auch
    // historische Single-Op-QSOs ohne explizite Initialen.
    private struct OpStatRow: Identifiable {
        let id: String          // Operator-String (eindeutig pro Zeile)
        let op: String
        let qsoCount: Int
    }

    private var opsBreakdown: [OpStatRow] {
        var counts: [String: Int] = [:]
        for q in manager.currentQSOs {
            let key = (q.operatorCall?.trimmingCharacters(in: .whitespaces).uppercased())
                .flatMap { $0.isEmpty ? nil : $0 }
                ?? "(kein OP gesetzt)"
            counts[key, default: 0] += 1
        }
        return counts
            .map { OpStatRow(id: $0.key, op: $0.key, qsoCount: $0.value) }
            .sorted { $0.qsoCount > $1.qsoCount }
    }

    private var opsView: some View {
        let rows = opsBreakdown
        return Group {
            if rows.isEmpty {
                emptyState(
                    icon: "person.2",
                    title: "Noch keine QSOs",
                    subtitle: "Sobald Contest-QSOs eingetragen sind, zeigt diese Tabelle die Verteilung pro Operator."
                )
            } else {
                Table(rows) {
                    TableColumn("Operator") { r in
                        Text(r.op)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                    }
                    .width(min: 140, ideal: 200)

                    TableColumn("QSOs") { r in
                        Text("\(r.qsoCount)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .width(min: 60, ideal: 80)

                    TableColumn("Anteil") { r in
                        let total = rows.reduce(0) { $0 + $1.qsoCount }
                        let pct = total > 0 ? Double(r.qsoCount) / Double(total) * 100 : 0
                        Text(String(format: "%.1f %%", pct))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(theme.textDim)
                    }
                    .width(min: 70, ideal: 90)
                }
            }
        }
    }

    // MARK: - DXCC

    private var dxccView: some View {
        let entries = onlyUnconfirmed
            ? manager.dxccBreakdown.filter { !$0.confirmed }
            : manager.dxccBreakdown
        return Group {
            if entries.isEmpty {
                emptyState(
                    icon: "globe",
                    title: onlyUnconfirmed
                        ? "Keine unbestätigten Länder"
                        : "Noch keine Länder gearbeitet",
                    subtitle: "Sobald QSOs mit Country-Feld eingetragen sind, erscheinen sie hier."
                )
            } else {
                dxccTable(entries)
            }
        }
    }

    private func dxccTable(_ entries: [DXCCAwardEntry]) -> some View {
        Table(entries) {
            TableColumn("Status") { e in
                statusBadge(confirmed: e.confirmed)
            }
            .width(min: 70, ideal: 80)

            TableColumn("Country") { e in
                Text(e.country)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
            }
            .width(min: 140, ideal: 180)

            TableColumn("QSOs") { e in
                Text("\(e.qsoCount)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
            }
            .width(min: 50, ideal: 60)

            TableColumn("Bands") { e in
                Text(e.bands.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .width(min: 120, ideal: 160)

            TableColumn("Modes") { e in
                Text(e.modes.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .width(min: 100, ideal: 130)

            TableColumn("Erster QSO") { e in
                Text(formatDate(e.firstQSO))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.textDim)
            }
            .width(min: 90, ideal: 100)

            TableColumn("Letzter QSO") { e in
                Text(formatDate(e.lastQSO))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.textDim)
            }
            .width(min: 90, ideal: 100)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - WAZ (40 Zonen-Grid)

    private var wazView: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)
        let allZones = Array(1...40)
        return ScrollView {
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(allZones, id: \.self) { z in
                    zoneCell(z)
                }
            }
            .padding(14)
        }
    }

    private func zoneCell(_ zone: Int) -> some View {
        let entry = manager.wazBreakdown.first { $0.zone == zone }
        let worked = entry != nil
        let confirmed = entry?.confirmed == true
        let count = entry?.qsoCount ?? 0

        return VStack(spacing: 2) {
            Text(String(format: "%02d", zone))
                .font(.system(.body, design: .monospaced).weight(.bold))
                .foregroundStyle(
                    confirmed ? theme.accentGreen
                    : worked   ? theme.textPrimary
                               : theme.textDim
                )
            if worked {
                Text("\(count) QSO\(count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            worked ? theme.bgCard : theme.bgCard2
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(confirmed ? theme.accentGreen
                        : worked ? theme.separator
                                 : theme.separator.opacity(0.4),
                        lineWidth: confirmed ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .opacity(worked ? 1.0 : 0.55)
    }

    // MARK: - WAS (US-States)

    private var wasView: some View {
        let entries = manager.wasBreakdown
        return Group {
            if entries.isEmpty {
                emptyState(
                    icon: "map",
                    title: "Keine US-States gearbeitet",
                    subtitle: "WAS zählt US-States. Sobald QSOs mit »United States« als Country + State im QTH-Feld eingetragen sind, erscheinen sie hier."
                )
            } else {
                Table(entries) {
                    TableColumn("Status") { e in
                        statusBadge(confirmed: e.confirmed)
                    }
                    .width(min: 70, ideal: 80)

                    TableColumn("State") { e in
                        Text(e.state)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("QSOs") { e in
                        Text("\(e.qsoCount)")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 60, ideal: 80)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Helpers

    private func statusBadge(confirmed: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: confirmed ? "checkmark.circle.fill" : "circle.dashed")
                .font(.caption2)
            Text(confirmed ? "✓ bestät." : "gearbeit.")
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(confirmed ? theme.accentGreen : theme.accentYellow)
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 38))
                .foregroundStyle(theme.textDim)
            Text(title)
                .font(.callout.bold())
                .foregroundStyle(theme.textSecondary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(theme.textDim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    // MARK: - POTA

    @AppStorage("callsign") private var callsign: String = ""

    private var potaView: some View {
        let p = potaStats.profile
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                potaHeader
                potaCardGrid(profile: p)
                potaLocalDelta(profile: p)
                if case .errored(let msg) = potaStats.status {
                    Text("⚠ \(msg)")
                        .font(.caption)
                        .foregroundStyle(theme.accentOrange)
                        .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .onAppear {
            // Bei erstmaligem Öffnen oder nach 24 h einen Refresh anbieten.
            if potaStats.profile == nil || potaStats.shouldOfferRefresh,
               !callsign.isEmpty {
                Task { await potaStats.refresh(callsign: callsign) }
            }
        }
    }

    private var potaHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "tree.fill")
                .font(.title2)
                .foregroundStyle(theme.colorPOTA)
            VStack(alignment: .leading, spacing: 1) {
                Text("POTA — pota.app")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(potaStatusText)
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Button {
                Task { await potaStats.refresh(callsign: callsign) }
            } label: {
                HStack(spacing: 4) {
                    if potaStats.status == .loading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(callsign.isEmpty ? "Kein Call gesetzt" : "Aktualisieren")
                }
                .font(.caption)
            }
            .disabled(callsign.isEmpty || potaStats.status == .loading)
        }
        .padding(12)
        .background(theme.bgCard2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var potaStatusText: String {
        switch potaStats.status {
        case .unknown:           return "Noch nicht abgerufen — klick Aktualisieren"
        case .loading:           return "Lade …"
        case .ready(let date):   return "Zuletzt aktualisiert: \(formatTimestamp(date))"
        case .errored(let msg):  return "Fehler: \(msg)"
        }
    }

    private func potaCardGrid(profile p: PotaProfile?) -> some View {
        let stats = p?.stats
        return LazyVGrid(columns: [
            GridItem(.flexible()), GridItem(.flexible())
        ], spacing: 10) {
            potaStatCard(title: "Activator-Parks",
                         value: stats?.activator?.parks,
                         qsoValue: stats?.activator?.qsos,
                         qsoLabel: "QSOs",
                         icon: "tree.circle.fill")
            potaStatCard(title: "Hunter-Parks",
                         value: stats?.hunter?.parks,
                         qsoValue: stats?.hunter?.qsos,
                         qsoLabel: "QSOs",
                         icon: "binoculars.fill")
            potaStatCard(title: "Aktivierungen",
                         value: stats?.activator?.activations,
                         qsoValue: stats?.awards,
                         qsoLabel: "Awards",
                         icon: "flag.fill")
            potaStatCard(title: "Park-to-Park",
                         value: stats?.park_to_park?.parks,
                         qsoValue: stats?.park_to_park?.qsos,
                         qsoLabel: "QSOs",
                         icon: "arrow.left.arrow.right")
        }
    }

    private func potaStatCard(title: String, value: Int?,
                              qsoValue: Int?, qsoLabel: String,
                              icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(theme.colorPOTA)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            Text(value.map { "\($0)" } ?? "—")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
            if let q = qsoValue {
                Text("\(q) \(qsoLabel)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.textDim)
            } else {
                Text("—").font(.caption2).foregroundStyle(theme.textDim)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgCard)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.separator, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Vergleicht lokale POTA-QSO-Counts mit den pota.app-Werten und zeigt
    /// die Differenz — typischerweise "noch nicht hochgeladen".
    private func potaLocalDelta(profile p: PotaProfile?) -> some View {
        let a = manager.awards
        let remoteAct  = p?.stats?.activator?.qsos
        let remoteHunt = p?.stats?.hunter?.qsos
        return VStack(alignment: .leading, spacing: 6) {
            Text("Lokal vs. pota.app")
                .font(.caption.bold())
                .foregroundStyle(theme.textSecondary)
            deltaRow(label: "Activator-QSOs",
                     local: a.potaActivatorQSOs,
                     remote: remoteAct)
            deltaRow(label: "Hunter-QSOs",
                     local: a.potaHunterQSOs,
                     remote: remoteHunt)
            deltaRow(label: "Activator-Parks",
                     local: a.potaActivatorParks,
                     remote: p?.stats?.activator?.parks)
            deltaRow(label: "Hunter-Parks",
                     local: a.potaHunterParks,
                     remote: p?.stats?.hunter?.parks)
            deltaRow(label: "P2P",
                     local: a.potaP2P,
                     remote: p?.stats?.park_to_park?.qsos)
            Text("Lokal höher = noch nicht zu pota.app hochgeladen (Logbuch → ADIF-Export → pota.app/user/logs).")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgCard)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.separator, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func deltaRow(label: String, local: Int, remote: Int?) -> some View {
        let delta = remote.map { local - $0 }
        return HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.textPrimary)
                .frame(width: 140, alignment: .leading)
            Text("lokal \(local)")
                .font(.caption.monospaced())
                .foregroundStyle(theme.textSecondary)
                .frame(width: 90, alignment: .leading)
            Text("pota.app \(remote.map { String($0) } ?? "—")")
                .font(.caption.monospaced())
                .foregroundStyle(theme.textSecondary)
                .frame(width: 110, alignment: .leading)
            if let d = delta {
                Text(deltaSymbol(d))
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(deltaColor(d))
            }
            Spacer()
        }
    }

    private func deltaSymbol(_ d: Int) -> String {
        if d == 0 { return "✓ sync" }
        if d > 0  { return "+\(d) lokal" }
        return "\(d) — pota.app führt"
    }

    private func deltaColor(_ d: Int) -> Color {
        if d == 0 { return theme.accentGreen }
        if d > 0  { return theme.accentOrange }
        return theme.accentBlue
    }

    private func formatTimestamp(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: d)
    }

    // MARK: - SOTA

    // Pure-Lokal-Auswertung über alle Logs. Eine Anbindung an ein externes
    // sotadata.org.uk-Profil ist nicht implementiert (kein öffentliches User-
    // Profil-API wie pota.app); kommt ggf. mit Phase 6 (Upload-Pfad).
    private var sotaView: some View {
        let a = manager.awards
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sotaHeader
                sotaCardGrid(awards: a)
                sotaHint
            }
            .padding(16)
        }
    }

    private var sotaHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "mountain.2.fill")
                .font(.title2)
                .foregroundStyle(theme.colorSOTA)
            VStack(alignment: .leading, spacing: 1) {
                Text("SOTA — Summits on the Air")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text("Lokal aggregiert aus allen Logs · Upload nach sotadata.org.uk kommt in Phase 6")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(theme.bgCard2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sotaCardGrid(awards a: AwardCounts) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()), GridItem(.flexible())
        ], spacing: 10) {
            sotaStatCard(title: "Activator-Summits",
                         value: a.sotaActivatorSummits,
                         secondaryValue: a.sotaActivatorQSOs,
                         secondaryLabel: "QSOs",
                         icon: "mountain.2.circle.fill")
            sotaStatCard(title: "Activator-Punkte",
                         value: a.sotaActivatorPoints,
                         secondaryValue: a.sotaActivatorSummits,
                         secondaryLabel: "Summits",
                         icon: "trophy.fill")
            sotaStatCard(title: "Chaser-Summits",
                         value: a.sotaChaserSummits,
                         secondaryValue: a.sotaChaserQSOs,
                         secondaryLabel: "QSOs",
                         icon: "binoculars.fill")
            sotaStatCard(title: "Chaser-Punkte",
                         value: a.sotaChaserPoints,
                         secondaryValue: a.sotaChaserSummits,
                         secondaryLabel: "Summits",
                         icon: "star.fill")
            sotaStatCard(title: "Summit-to-Summit",
                         value: a.sotaS2S,
                         secondaryValue: nil,
                         secondaryLabel: "QSOs",
                         icon: "arrow.left.arrow.right")
        }
    }

    private func sotaStatCard(title: String, value: Int,
                              secondaryValue: Int?, secondaryLabel: String,
                              icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(theme.colorSOTA)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            Text("\(value)")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
            if let s = secondaryValue {
                Text("\(s) \(secondaryLabel)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.textDim)
            } else {
                Text("—").font(.caption2).foregroundStyle(theme.textDim)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgCard)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.separator, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var sotaHint: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hinweise zur Punkte-Logik")
                .font(.caption.bold())
                .foregroundStyle(theme.textSecondary)
            Text("• Activator-Punkte: pro Summit + UTC-Tag mit ≥ 4 QSOs zählen Base-Punkte aus der Summit-DB plus saisonaler Winterbonus (Nord 1. Dez – 15. März, Süd 1. Juni – 15. Sept).")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            Text("• Chaser-Punkte = Σ der Punkte aus Gegen-Summits (theirSotaPoints im QSO).")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            Text("• S2S = QSOs bei denen sowohl mein als auch das Gegen-Summit gesetzt ist.")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            Text("• Multi-Summit-Hopping: jeder Summit in der Komma-Liste zählt eigene 4-QSO-Aktivierung.")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgCard)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.separator, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - WWFF

    // Pure-Lokal-Auswertung. WWFF-Honor-Roll-System: jede unique Ref = 1
    // Punkt sowohl für Activator als auch Hunter, kein Punkte-Multiplier
    // wie SOTA. Upload zu wwff-cc.org bleibt manuell (ADIF-Submission an
    // den Country-Coordinator).
    private var wwffView: some View {
        let a = manager.awards
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                wwffHeader
                wwffCardGrid(awards: a)
                wwffHint
            }
            .padding(16)
        }
    }

    private var wwffHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.title2)
                .foregroundStyle(theme.colorWWFF)
            VStack(alignment: .leading, spacing: 1) {
                Text("WWFF — Worldwide Flora & Fauna")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text("Lokal aggregiert aus allen Logs · Upload nach wwff-cc.org kommt in Phase 6")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(theme.bgCard2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func wwffCardGrid(awards a: AwardCounts) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()), GridItem(.flexible())
        ], spacing: 10) {
            wwffStatCard(title: "Activator-Refs",
                         value: a.wwffActivatorRefs,
                         secondaryValue: a.wwffActivatorQSOs,
                         secondaryLabel: "QSOs",
                         icon: "leaf.circle.fill")
            wwffStatCard(title: "Hunter-Refs",
                         value: a.wwffHunterRefs,
                         secondaryValue: a.wwffHunterQSOs,
                         secondaryLabel: "QSOs",
                         icon: "binoculars.fill")
            wwffStatCard(title: "Reference-to-Reference",
                         value: a.wwffR2R,
                         secondaryValue: nil,
                         secondaryLabel: "QSOs",
                         icon: "arrow.left.arrow.right")
            wwffStatCard(title: "Country-Programme",
                         value: a.wwffPrograms,
                         secondaryValue: a.wwffActivatorRefs + a.wwffHunterRefs,
                         secondaryLabel: "Refs insgesamt",
                         icon: "globe")
        }
    }

    private func wwffStatCard(title: String, value: Int,
                              secondaryValue: Int?, secondaryLabel: String,
                              icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(theme.colorWWFF)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            Text("\(value)")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
            if let s = secondaryValue {
                Text("\(s) \(secondaryLabel)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.textDim)
            } else {
                Text("—").font(.caption2).foregroundStyle(theme.textDim)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgCard)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.separator, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - BOTA

    private var botaView: some View {
        let a = manager.awards
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                botaHeader
                botaCardGrid(awards: a)
                botaHint
            }
            .padding(16)
        }
    }

    private var botaHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.fill")
                .font(.title2)
                .foregroundStyle(.gray)
            VStack(alignment: .leading, spacing: 1) {
                Text("BOTA — Bunkers On The Air")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text("Lokal aggregiert · keine zentrale öffentliche API verfügbar")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(theme.bgCard2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func botaCardGrid(awards a: AwardCounts) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()), GridItem(.flexible())
        ], spacing: 10) {
            botaStatCard(title: "Activator-Bunker",
                         value: a.botaActivatorRefs,
                         secondaryValue: a.botaActivatorQSOs,
                         secondaryLabel: "QSOs",
                         icon: "shield.lefthalf.filled")
            botaStatCard(title: "Hunter-Bunker",
                         value: a.botaHunterRefs,
                         secondaryValue: a.botaHunterQSOs,
                         secondaryLabel: "QSOs",
                         icon: "binoculars.fill")
            botaStatCard(title: "Bunker-to-Bunker",
                         value: a.botaB2B,
                         secondaryValue: nil,
                         secondaryLabel: "QSOs",
                         icon: "arrow.left.arrow.right")
            botaStatCard(title: "Programme",
                         value: a.botaPrograms,
                         secondaryValue: a.botaActivatorRefs + a.botaHunterRefs,
                         secondaryLabel: "Refs insgesamt",
                         icon: "globe")
        }
    }

    private func botaStatCard(title: String, value: Int,
                              secondaryValue: Int?, secondaryLabel: String,
                              icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(.gray)
                Text(title).font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            Text("\(value)")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
            if let s = secondaryValue {
                Text("\(s) \(secondaryLabel)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.textDim)
            } else {
                Text("—").font(.caption2).foregroundStyle(theme.textDim)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgCard)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.separator, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var botaHint: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hinweise")
                .font(.caption.bold())
                .foregroundStyle(theme.textSecondary)
            Text("• Activator/Hunter-Bunker = eindeutige Refs aus myBotaRef/theirBotaRef.")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            Text("• B2B = QSOs zwischen zwei Bunkern (beide Refs gesetzt).")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            Text("• Programme = einzigartige Länder-Prefixe (DE, BU, F, …) aus der Ref-Liste.")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgCard)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.separator, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var wwffHint: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hinweise zur Honor-Roll-Logik")
                .font(.caption.bold())
                .foregroundStyle(theme.textSecondary)
            Text("• Activator-Refs = eindeutige Refs in myWwffRef + myWwffRefs (Hopping zählt jede Ref separat).")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            Text("• Hunter-Refs = eindeutige Refs aus theirWwffRef.")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            Text("• Aktivierung gültig ab 44 QSOs — die Auswertung pro Ref + Datum kommt mit Phase 6 (Upload zu wwff-cc.org).")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            Text("• Country-Programme = einzigartige Land-Prefixe (DLFF, HBFF, KFF, VKFF, …).")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgCard)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.separator, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
