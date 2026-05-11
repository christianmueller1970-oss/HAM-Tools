import SwiftUI

// Große QSO-Tabelle wie in MacLoggerDX. Color-Code:
//   grün = LoTW/eQSL bestätigt
//   gelb = upload pending
//   weiß/grau = unbestätigt, nicht hochgeladen
struct QSOTableView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager

    @State private var filterCall: String = ""
    @State private var filterBand: String = ""
    @State private var filterMode: String = ""
    @State private var filterCountry: String = ""
    @State private var editingQSO: QSO?

    private var theme: AppTheme { themeManager.theme }

    private var filteredQSOs: [QSO] {
        manager.currentQSOs
            .filter { qso in
                (filterCall.isEmpty    || qso.call.localizedCaseInsensitiveContains(filterCall)) &&
                (filterBand.isEmpty    || qso.band.localizedCaseInsensitiveContains(filterBand)) &&
                (filterMode.isEmpty    || qso.mode.localizedCaseInsensitiveContains(filterMode)) &&
                (filterCountry.isEmpty || (qso.country ?? "").localizedCaseInsensitiveContains(filterCountry))
            }
            .sorted { $0.datetime > $1.datetime }
    }

    private var statusLine: String {
        let count = manager.currentQSOs.count
        let filtered = filteredQSOs.count
        let fileName = currentLog.flatMap { manager.fileURL(for: $0)?.lastPathComponent } ?? ""
        let prefix = fileName.isEmpty ? "" : "\(fileName) · "
        if filtered == count {
            return "\(prefix)\(count) QSO\(count == 1 ? "" : "s")"
        }
        return "\(prefix)\(filtered) / \(count) QSOs (gefiltert)"
    }

    private var statusLineTooltip: String {
        currentLog.flatMap { manager.fileURL(for: $0)?.path } ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider().background(theme.separator)
            tableContent
        }
        .background(theme.bgApp)
        .sheet(item: $editingQSO) { qso in
            QSOFormSheet(qso: qso, log: currentLog ?? manager.logs[0])
                .environmentObject(themeManager)
                .environmentObject(manager)
        }
    }

    private var currentLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    private var filterBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(statusLineTooltip)
                Spacer()
            }
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(theme.textDim)
                filterField("Call Sign", text: $filterCall, width: 130, monospaced: true)
                filterField("Band",      text: $filterBand, width: 80)
                filterField("Mode",      text: $filterMode, width: 80)
                filterField("Country",   text: $filterCountry, width: 130)
                if !filterCall.isEmpty || !filterBand.isEmpty
                    || !filterMode.isEmpty || !filterCountry.isEmpty {
                    Button("Zurücksetzen") {
                        filterCall = ""; filterBand = ""
                        filterMode = ""; filterCountry = ""
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(theme.bgPanel)
    }

    private func filterField(_ placeholder: String,
                             text: Binding<String>,
                             width: CGFloat,
                             monospaced: Bool = false) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(monospaced
                  ? .system(.caption, design: .monospaced)
                  : .caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(width: width)
            .background(theme.bgCard2)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(theme.separator.opacity(0.5), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var tableContent: some View {
        Group {
            if manager.currentLogID == nil {
                emptyMessage("Kein Log aktiv", "Wähle oben links ein Log oder lege ein neues an.")
            } else if filteredQSOs.isEmpty && manager.currentQSOs.isEmpty {
                emptyMessage("Noch keine QSOs",
                             "Fülle oben das QSO-Panel aus und drücke »Log QSO« (⌘↩).")
            } else if filteredQSOs.isEmpty {
                emptyMessage("Kein Treffer im Filter", "Filter zurücksetzen oder anpassen.")
            } else {
                qsoTable
            }
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
