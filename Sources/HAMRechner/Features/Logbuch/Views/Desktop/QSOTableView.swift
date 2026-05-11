import SwiftUI

// Große QSO-Tabelle mit Klick-Sortierung pro Spaltenkopf, Drag-Reorder
// und Hide/Show via Rechtsklick auf die Header-Bar. Anordnung +
// Sichtbarkeit werden persistiert (Codable JSON in UserDefaults).
struct QSOTableView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager

    @Binding var filterCall: String
    @Binding var filterBand: String
    @Binding var filterMode: String
    @Binding var filterCountry: String

    @State private var editingQSO: QSO?

    // Sortierung — initialer Default: Datum absteigend (neueste zuerst).
    @State private var sortOrder: [KeyPathComparator<QSO>] = [
        KeyPathComparator(\QSO.datetime, order: .reverse)
    ]

    // Spalten-Anpassung (Reihenfolge + Sichtbarkeit + Breite). TableColumn-
    // Customization ist Codable — wird in UserDefaults als JSON persistiert.
    @State private var columnCustomization = TableColumnCustomization<QSO>()
    private let customizationStorageKey = "logbook.qsoTable.columnCustomization"

    private var theme: AppTheme { themeManager.theme }

    var filteredQSOs: [QSO] {
        manager.currentQSOs.filter { qso in
            (filterCall.isEmpty    || qso.call.localizedCaseInsensitiveContains(filterCall)) &&
            (filterBand.isEmpty    || qso.band.localizedCaseInsensitiveContains(filterBand)) &&
            (filterMode.isEmpty    || qso.mode.localizedCaseInsensitiveContains(filterMode)) &&
            (filterCountry.isEmpty || (qso.country ?? "").localizedCaseInsensitiveContains(filterCountry))
        }
    }

    // Sortierung wird durch Klick auf Spaltenkopf gesetzt (binding gegen
    // sortOrder); hier wenden wir das Komparator-Array auf die gefilterten
    // Daten an.
    private var sortedQSOs: [QSO] {
        filteredQSOs.sorted(using: sortOrder)
    }

    private var currentLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    var body: some View {
        Group {
            if manager.currentLogID == nil {
                emptyMessage("Kein Log aktiv", "Wähle oben links ein Log oder lege ein neues an.")
            } else if sortedQSOs.isEmpty && manager.currentQSOs.isEmpty {
                emptyMessage("Noch keine QSOs",
                             "Fülle oben das QSO-Panel aus und drücke »Log QSO« (⌘↩).")
            } else if sortedQSOs.isEmpty {
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
        .onAppear(perform: loadCustomization)
        .onChange(of: columnCustomization) { _, _ in saveCustomization() }
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

    // MARK: - Tabelle

    private var qsoTable: some View {
        Table(sortedQSOs,
              sortOrder: $sortOrder,
              columnCustomization: $columnCustomization) {
            // Default-sichtbare Spalten in einer Group — sonst überschreitet
            // die Tabelle das TableColumnBuilder-10er-Limit (insgesamt haben
            // wir 15 Spalten inkl. Aktionen).
            Group {
                TableColumn("Time On (UTC)", value: \QSO.datetime) { (qso: QSO) in
                    Text(formatUTC(qso.datetime))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 140, ideal: 150)
                .customizationID("timeOn")

                TableColumn("Call Sign", value: \QSO.call) { (qso: QSO) in
                    Text(qso.call)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 90, ideal: 110)
                .customizationID("call")

                TableColumn("Name") { (qso: QSO) in
                    Text(qso.name ?? "")
                        .font(.caption)
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 100, ideal: 140)
                .customizationID("name")

                TableColumn("Country / Locator") { (qso: QSO) in
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
                .customizationID("countryLocator")

                TableColumn("Freq / Band", value: \QSO.frequencyMHz) { (qso: QSO) in
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
                .customizationID("freqBand")

                TableColumn("Mode", value: \QSO.mode) { (qso: QSO) in
                    Text(qso.mode)
                        .font(.caption)
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 50, ideal: 60)
                .customizationID("mode")

                TableColumn("Power") { (qso: QSO) in
                    Text(qso.powerW.map { String(format: "%g W", $0) } ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 55, ideal: 65)
                .customizationID("power")

                TableColumn("RST S/R") { (qso: QSO) in
                    Text("\(qso.rstSent) / \(qso.rstReceived)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 80, ideal: 90)
                .customizationID("rst")

                TableColumn("QSL-Status") { (qso: QSO) in
                    Text(statusBadgeText(for: qso))
                        .font(.caption2)
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 100, ideal: 160)
                .customizationID("qslStatus")
            }

            // Zusätzliche Spalten — default ausgeblendet, per Rechtsklick
            // auf den Header zuschaltbar.

            Group {
                TableColumn("Kontinent") { (qso: QSO) in
                    Text(qso.continent ?? "")
                        .font(.caption)
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 50, ideal: 70)
                .customizationID("continent")
                .defaultVisibility(.hidden)

                TableColumn("CQ-Zone") { (qso: QSO) in
                    Text(qso.cqZone.map(String.init) ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 50, ideal: 60)
                .customizationID("cqZone")
                .defaultVisibility(.hidden)

                TableColumn("Antenne") { (qso: QSO) in
                    Text(qso.antenna ?? "")
                        .font(.caption)
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 80, ideal: 120)
                .customizationID("antenna")
                .defaultVisibility(.hidden)

                TableColumn("Operator") { (qso: QSO) in
                    Text(qso.operatorCall ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 70, ideal: 90)
                .customizationID("operator")
                .defaultVisibility(.hidden)

                TableColumn("Bemerkung") { (qso: QSO) in
                    Text(qso.comment ?? "")
                        .font(.caption)
                        .foregroundStyle(uploadColor(for: qso))
                        .lineLimit(2)
                }
                .width(min: 120, ideal: 200)
                .customizationID("comment")
                .defaultVisibility(.hidden)
            }

            // Aktionen-Spalte — nicht customizable (immer ganz rechts)
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
            .customizationID("actions")
            .disabledCustomizationBehavior([.visibility, .reorder])
        }
        .scrollContentBackground(.hidden)
        .background(theme.bgApp)
    }

    // MARK: - Persistenz der Spalten-Anpassung

    private func loadCustomization() {
        guard let data = UserDefaults.standard.data(forKey: customizationStorageKey),
              let decoded = try? JSONDecoder().decode(TableColumnCustomization<QSO>.self, from: data)
        else { return }
        columnCustomization = decoded
    }

    private func saveCustomization() {
        guard let data = try? JSONEncoder().encode(columnCustomization) else { return }
        UserDefaults.standard.set(data, forKey: customizationStorageKey)
    }

    // MARK: - Color coding

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
