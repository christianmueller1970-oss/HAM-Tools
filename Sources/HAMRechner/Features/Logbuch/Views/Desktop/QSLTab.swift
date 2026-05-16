import SwiftUI

// QSL-Übersicht: zeigt QSOs gruppiert nach QSL-Status. MVP-Scope ist
// Read-only mit drei Filtern (Offen / Bestätigt / Alle) — kein Bulk-
// Marker, kein Auto-Upload (das wäre Phase 6). Doppelklick auf eine
// Zeile öffnet das bestehende QSOFormSheet, dort kann der User die
// xSent/xConfirmed-Flags und QSL-Daten setzen.
//
// Status-Logik (für jeden QSO):
//   • bestätigt: mindestens einer von lotwConfirmed/eqslConfirmed/
//     qslReceivedDate ist gesetzt
//   • offen:     mindestens einer der Sent-Flags ist gesetzt, aber
//     nichts bestätigt — wartet auf Confirmation
//   • leer:      noch nichts versendet (defaultet zu „Offen" in der
//     Filter-Anzeige, weil das genau die QSOs sind, bei denen man
//     noch was tun muss)
struct QSLTab: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var uploadSettings: UploadServicesSettings

    @AppStorage("logbook.qsl.filter") private var filter: Filter = .open
    @AppStorage("logbook.qsl.serviceFilter") private var serviceFilter: ServiceFilter = .all
    @AppStorage("logbook.qsl.sort") private var sortNewestFirst: Bool = false

    @State private var editingQSO: QSO?
    @State private var qrzFetchInFlight: Bool = false
    @State private var qrzFetchAlert: QRZFetchAlert?

    struct QRZFetchAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private var qrzConfigured: Bool {
        !uploadSettings.qrzLogbookApiKey
            .trimmingCharacters(in: .whitespaces).isEmpty
    }

    enum Filter: String, CaseIterable, Identifiable {
        case open      = "Offen"
        case confirmed = "Bestätigt"
        case all       = "Alle"
        var id: String { rawValue }
    }

    enum ServiceFilter: String, CaseIterable, Identifiable {
        case all     = "Alle Dienste"
        case lotw    = "LoTW"
        case eqsl    = "eQSL"
        case clublog = "Club Log"
        case direct  = "Direkt-QSL"
        var id: String { rawValue }
    }

    private var theme: AppTheme { themeManager.theme }

    private var currentLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    // Welche Confirmation-Kanäle sind für diesen QSO bestätigt?
    private func confirmedSet(_ q: QSO) -> Set<String> {
        var s: Set<String> = []
        if q.lotwConfirmed { s.insert("LoTW") }
        if q.eqslConfirmed { s.insert("eQSL") }
        if q.qslReceivedDate != nil { s.insert("Direkt") }
        return s
    }

    // Welche Kanäle sind gesendet aber nicht bestätigt?
    private func pendingSet(_ q: QSO) -> Set<String> {
        var s: Set<String> = []
        if q.lotwSent && !q.lotwConfirmed { s.insert("LoTW") }
        if q.eqslSent && !q.eqslConfirmed { s.insert("eQSL") }
        if q.clublogSent { s.insert("Club Log") }
        if q.qslSentDate != nil && q.qslReceivedDate == nil { s.insert("Direkt") }
        return s
    }

    private func isOpen(_ q: QSO) -> Bool {
        confirmedSet(q).isEmpty
    }

    private func filteredQSOs() -> [QSO] {
        let base: [QSO]
        switch filter {
        case .open:      base = manager.currentQSOs.filter(isOpen)
        case .confirmed: base = manager.currentQSOs.filter { !confirmedSet($0).isEmpty }
        case .all:       base = manager.currentQSOs
        }

        // Service-Filter feinkörnig — nur für Open + Alle sinnvoll, in
        // „Bestätigt" zeigt es nur QSOs, bei denen genau dieser Kanal
        // (mit-)bestätigt ist. Default „Alle Dienste" ist meistens
        // das Richtige.
        let filtered: [QSO]
        switch serviceFilter {
        case .all:
            filtered = base
        case .lotw:
            filtered = base.filter {
                filter == .confirmed ? $0.lotwConfirmed
                                     : $0.lotwSent || $0.lotwConfirmed
            }
        case .eqsl:
            filtered = base.filter {
                filter == .confirmed ? $0.eqslConfirmed
                                     : $0.eqslSent || $0.eqslConfirmed
            }
        case .clublog:
            filtered = base.filter { $0.clublogSent }
        case .direct:
            filtered = base.filter {
                $0.qslSentDate != nil || $0.qslReceivedDate != nil
            }
        }

        return filtered.sorted { a, b in
            sortNewestFirst ? a.datetime > b.datetime : a.datetime < b.datetime
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if manager.currentLogID == nil {
                emptyMessage("Kein Log aktiv",
                             "Wähle oben links ein Log oder lege ein neues an.")
            } else {
                content
            }
        }
        .background(theme.bgApp)
        .sheet(item: $editingQSO) { qso in
            QSOFormSheet(qso: qso, log: currentLog ?? manager.logs[0])
                .environmentObject(themeManager)
                .environmentObject(manager)
        }
        .alert(item: $qrzFetchAlert) { entry in
            Alert(title: Text(entry.title),
                  message: Text(entry.message),
                  dismissButton: .default(Text("OK")))
        }
    }

    @ViewBuilder
    private var content: some View {
        let rows = filteredQSOs()
        VStack(spacing: 0) {
            filterBar(rowCount: rows.count)
            if rows.isEmpty {
                emptyForFilter
            } else {
                table(rows: rows)
            }
        }
    }

    private func filterBar(rowCount: Int) -> some View {
        HStack(spacing: 10) {
            Picker("Status", selection: $filter) {
                ForEach(Filter.allCases) { f in Text(f.rawValue).tag(f) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 240)

            Picker("Dienst", selection: $serviceFilter) {
                ForEach(ServiceFilter.allCases) { f in Text(f.rawValue).tag(f) }
            }
            .labelsHidden()
            .frame(width: 130)

            Button {
                sortNewestFirst.toggle()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: sortNewestFirst
                          ? "arrow.down.circle"
                          : "arrow.up.circle")
                    Text(sortNewestFirst ? "Neueste oben" : "Älteste oben")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(theme.accentBlue)

            Spacer()

            // QRZ-Confirmation-Sync — additiv (überschreibt lokal-true nie).
            Button {
                runQRZFetch()
            } label: {
                HStack(spacing: 3) {
                    if qrzFetchInFlight {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.down.circle")
                    }
                    Text("QRZ-Bestätigungen abrufen")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(theme.accentBlue)
            .disabled(!qrzConfigured || qrzFetchInFlight)
            .help(qrzConfigured
                  ? "Holt alle QSOs von QRZ und ergänzt fehlende LoTW-/eQSL-/Direkt-Bestätigungen lokal."
                  : "QRZ-Logbook-API-Key in den Einstellungen eintragen.")

            Text("\(rowCount) QSO\(rowCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.bgPanel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.separator).frame(height: 1)
        }
    }

    private func runQRZFetch() {
        guard !qrzFetchInFlight else { return }
        qrzFetchInFlight = true
        Task {
            do {
                let r = try await manager.fetchQRZConfirmations()
                await MainActor.run {
                    qrzFetchInFlight = false
                    let title = r.newConfirmations > 0
                        ? "\(r.newConfirmations) neue Bestätigungen"
                        : "Nichts neu"
                    qrzFetchAlert = QRZFetchAlert(
                        title: title,
                        message: "QRZ-Log: \(r.serverTotal) QSOs · zugeordnet: \(r.matchedLocal) · neu bestätigt: \(r.newConfirmations) · nur auf QRZ: \(r.serverOnly)")
                }
            } catch {
                await MainActor.run {
                    qrzFetchInFlight = false
                    qrzFetchAlert = QRZFetchAlert(
                        title: "Sync fehlgeschlagen",
                        message: (error as? LocalizedError)?.errorDescription
                                 ?? error.localizedDescription)
                }
            }
        }
    }

    private var emptyForFilter: some View {
        let title: String
        let subtitle: String
        switch filter {
        case .open:
            title = "Keine offenen QSOs"
            subtitle = "Alle QSOs in diesem Log sind QSL-bestätigt — oder es wurde noch nichts gesendet."
        case .confirmed:
            title = "Noch keine Bestätigungen"
            subtitle = "Sobald LoTW oder eQSL ein QSO bestätigen, taucht es hier auf."
        case .all:
            title = "Keine QSOs im Log"
            subtitle = "Lege zuerst ein paar QSOs an."
        }
        return emptyMessage(title, subtitle)
    }

    private func emptyMessage(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "envelope")
                .font(.system(size: 40))
                .foregroundStyle(theme.textDim)
            Text(title)
                .font(.callout.bold())
                .foregroundStyle(theme.textSecondary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(theme.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tabelle

    private func table(rows: [QSO]) -> some View {
        Table(rows) {
            TableColumn("Datum (UTC)") { q in
                Text(formatDate(q.datetime))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
            }
            .width(min: 120, ideal: 130)

            TableColumn("Call") { q in
                Text(q.call)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(theme.textPrimary)
            }
            .width(min: 90, ideal: 110)

            TableColumn("Band/Mode") { q in
                VStack(alignment: .leading, spacing: 1) {
                    Text(q.band)
                        .font(.system(.caption, design: .monospaced))
                    Text(q.mode)
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                }
            }
            .width(min: 60, ideal: 70)

            TableColumn("Country") { q in
                Text(q.country ?? "")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .width(min: 100, ideal: 140)

            TableColumn("LoTW") { q in
                qslChannelBadge(sent: q.lotwSent,
                                confirmed: q.lotwConfirmed,
                                date: q.lotwConfirmed ? q.qslReceivedDate : nil)
            }
            .width(min: 60, ideal: 70)

            TableColumn("eQSL") { q in
                qslChannelBadge(sent: q.eqslSent,
                                confirmed: q.eqslConfirmed,
                                date: nil)
            }
            .width(min: 60, ideal: 70)

            TableColumn("Club Log") { q in
                qslChannelBadge(sent: q.clublogSent,
                                confirmed: false,
                                date: nil)
            }
            .width(min: 60, ideal: 70)

            TableColumn("Direkt-QSL") { q in
                directQSLBadge(q)
            }
            .width(min: 90, ideal: 110)

            TableColumn("") { q in
                Button {
                    editingQSO = q
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("QSO bearbeiten — QSL-Flags hier setzen")
            }
            .width(36)
        }
        .scrollContentBackground(.hidden)
        .background(theme.bgApp)
    }

    private func qslChannelBadge(sent: Bool,
                                  confirmed: Bool,
                                  date: Date?) -> some View {
        Group {
            if confirmed {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(theme.accentGreen)
                    Text("✓")
                        .font(.caption2.bold())
                        .foregroundStyle(theme.accentGreen)
                }
            } else if sent {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.circle")
                        .foregroundStyle(theme.accentYellow)
                    Text("→")
                        .font(.caption2.bold())
                        .foregroundStyle(theme.accentYellow)
                }
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
            }
        }
    }

    private func directQSLBadge(_ q: QSO) -> some View {
        Group {
            if q.qslReceivedDate != nil {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(theme.accentGreen)
                    Text(q.qslReceivedVia ?? "Direkt")
                        .font(.caption2)
                        .foregroundStyle(theme.accentGreen)
                }
            } else if q.qslSentDate != nil {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.circle")
                        .foregroundStyle(theme.accentYellow)
                    Text(q.qslSentVia ?? "Direkt")
                        .font(.caption2)
                        .foregroundStyle(theme.accentYellow)
                }
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
            }
        }
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: d)
    }
}
