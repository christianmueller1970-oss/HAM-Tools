import SwiftUI

// Große QSO-Tabelle. Filter-State liegt in der LogbuchView und wird per
// Binding reingereicht (damit die LogContextBar oberhalb die Filter
// kontrolliert).
struct QSOTableView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager

    @Binding var filterCall: String
    @Binding var filterBand: String
    @Binding var filterMode: String
    @Binding var filterCountry: String

    @State private var editingQSO: QSO?

    private var theme: AppTheme { themeManager.theme }

    var filteredQSOs: [QSO] {
        manager.currentQSOs
            .filter { qso in
                (filterCall.isEmpty    || qso.call.localizedCaseInsensitiveContains(filterCall)) &&
                (filterBand.isEmpty    || qso.band.localizedCaseInsensitiveContains(filterBand)) &&
                (filterMode.isEmpty    || qso.mode.localizedCaseInsensitiveContains(filterMode)) &&
                (filterCountry.isEmpty || (qso.country ?? "").localizedCaseInsensitiveContains(filterCountry))
            }
            .sorted { $0.datetime > $1.datetime }
    }

    private var currentLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    var body: some View {
        Group {
            if manager.currentLogID == nil {
                emptyMessage("Kein Log aktiv", "Wähle oben links ein Log oder lege ein neues an.")
            } else if filteredQSOs.isEmpty && manager.currentQSOs.isEmpty {
                emptyMessage("Noch keine QSOs",
                             "Fülle oben das QSO-Panel aus und drücke »Log QSO« (⌘↩).")
            } else if filteredQSOs.isEmpty {
                emptyMessage("Kein Treffer im Filter", "Filter oben zurücksetzen oder anpassen.")
            } else {
                qsoTable
            }
        }
        .background(theme.bgApp)
        .sheet(item: $editingQSO) { qso in
            QSOFormSheet(qso: qso, log: currentLog ?? manager.logs[0])
                .environmentObject(themeManager)
                .environmentObject(manager)
        }
    }

    private func emptyMessage(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(theme.textDim)
            Text(title)
                .font(.callout.bold())
                .foregroundStyle(theme.textSecondary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(theme.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var qsoTable: some View {
        Table(filteredQSOs) {
            TableColumn("Time On (UTC)") { qso in
                Text(formatUTC(qso.datetime))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(uploadColor(for: qso))
            }
            .width(min: 140, ideal: 150)

            TableColumn("Call Sign") { qso in
                Text(qso.call)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(uploadColor(for: qso))
            }
            .width(min: 90, ideal: 110)

            TableColumn("Name") { qso in
                Text(qso.name ?? "")
                    .font(.caption)
                    .foregroundStyle(uploadColor(for: qso))
            }
            .width(min: 100, ideal: 140)

            TableColumn("Country / Locator") { qso in
                VStack(alignment: .leading, spacing: 1) {
                    Text(qso.country ?? "")
                        .font(.caption)
                    if let loc = qso.locator, !loc.isEmpty {
                        Text(loc)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(theme.textDim)
                    }
                }
                .foregroundStyle(uploadColor(for: qso))
            }
            .width(min: 90, ideal: 120)

            TableColumn("Freq / Band") { qso in
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(format: "%.3f", qso.frequencyMHz))
                        .font(.system(.caption, design: .monospaced))
                    Text(qso.band)
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                }
                .foregroundStyle(uploadColor(for: qso))
            }
            .width(min: 70, ideal: 80)

            TableColumn("Mode") { qso in
                Text(qso.mode)
                    .font(.caption)
                    .foregroundStyle(uploadColor(for: qso))
            }
            .width(min: 50, ideal: 60)

            TableColumn("Power") { qso in
                Text(qso.powerW.map { String(format: "%g W", $0) } ?? "")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(uploadColor(for: qso))
            }
            .width(min: 55, ideal: 65)

            TableColumn("RST S/R") { qso in
                Text("\(qso.rstSent) / \(qso.rstReceived)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(uploadColor(for: qso))
            }
            .width(min: 80, ideal: 90)

            TableColumn("QSL-Status") { qso in
                Text(statusBadgeText(for: qso))
                    .font(.caption2)
                    .foregroundStyle(uploadColor(for: qso))
            }
            .width(min: 100, ideal: 160)

            TableColumn("") { qso in
                HStack(spacing: 4) {
                    Button {
                        editingQSO = qso
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Bearbeiten")
                    Button(role: .destructive) {
                        manager.deleteQSO(qso)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.accentRed)
                    .help("Löschen")
                }
            }
            .width(54)
        }
        .scrollContentBackground(.hidden)
        .background(theme.bgApp)
    }

    // MARK: - Color coding
    //   default = noch nicht hochgeladen
    //   gelb    = upload pending (gesendet, nicht bestätigt)
    //   grün    = bestätigt (LoTW oder eQSL)

    private func uploadColor(for qso: QSO) -> Color {
        if qso.lotwConfirmed || qso.eqslConfirmed { return theme.accentGreen }
        if qso.lotwSent || qso.eqslSent || qso.clublogSent { return theme.accentYellow }
        return theme.textPrimary
    }

    private func statusBadgeText(for qso: QSO) -> String {
        var parts: [String] = []
        if qso.lotwConfirmed { parts.append("LoTW ✓") }
        else if qso.lotwSent { parts.append("LoTW →") }
        if qso.eqslConfirmed { parts.append("eQSL ✓") }
        else if qso.eqslSent { parts.append("eQSL →") }
        if qso.clublogSent  { parts.append("ClubLog →") }
        return parts.isEmpty ? "—" : parts.joined(separator: "  ")
    }

    private func formatUTC(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }
}
