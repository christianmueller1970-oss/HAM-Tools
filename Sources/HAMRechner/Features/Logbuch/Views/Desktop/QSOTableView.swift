import SwiftUI

// Große QSO-Tabelle mit Klick-Sortierung pro Spaltenkopf, Drag-Reorder
// und Hide/Show via Rechtsklick auf die Header-Bar. Anordnung +
// Sichtbarkeit werden persistiert (Codable JSON in UserDefaults).
struct QSOTableView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var potaService: PotaParkService
    @EnvironmentObject var callbookManager: CallbookManager
    @EnvironmentObject var uploadSettings: UploadServicesSettings
    @ObservedObject var columnStore: QSOColumnVisibilityStore

    @Binding var filterCall: String
    @Binding var filterBand: String
    @Binding var filterMode: String
    @Binding var filterCountry: String
    @Binding var selectedQSOs: Set<UUID>

    @State private var editingQSO: QSO?

    // POTA-Dupe-Markierung: QSO-IDs, die mit einem anderen QSO im gleichen
    // Log (selber Call, selbes Band) kollidieren. In nicht-POTA-Logs ist die
    // Set leer, weil dort Call+Band-Dupes legitime Wiederholungen über Jahre
    // sein können (Lebens-Log).
    @State private var dupeQSOIDs: Set<UUID> = []

    // QRZ-Retry läuft asynchron: in dieser Set merken wir QSO-IDs, für die
    // gerade ein Lookup läuft, damit die Zeile einen Spinner statt des
    // ?-Buttons zeigt.
    @State private var lookupInFlight: Set<UUID> = []

    // QRZ-Logbook-Bulk-Upload-State.
    @State private var qrzUploadInFlight: Bool = false
    @State private var qrzBulkAlert: QRZBulkAlert?

    struct QRZBulkAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private var qrzLogbookConfigured: Bool {
        !uploadSettings.qrzLogbookApiKey
            .trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Club-Log-Bulk-Upload-State.
    @State private var clubLogUploadInFlight: Bool = false
    @State private var clubLogBulkAlert: QRZBulkAlert?

    private var clubLogConfigured: Bool {
        !uploadSettings.clublogEmail
            .trimmingCharacters(in: .whitespaces).isEmpty
        && !uploadSettings.clublogApiKey
            .trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Sortierung — initialer Default: Datum absteigend (neueste zuerst).
    @State private var sortOrder: [KeyPathComparator<QSO>] = [
        KeyPathComparator(\QSO.datetime, order: .reverse)
    ]

    // Performance: bei 7000+ QSOs liefen filteredQSOs/sortedQSOs/
    // chronologicalIndex bisher pro View-Render mehrfach — das hat
    // beim Scrollen merklich gelagt. Wir halten sie jetzt als @State-
    // Caches und recompute nur bei tatsächlichen Daten-/Filter-/Sort-
    // Änderungen (siehe .onAppear / .onChange-Modifier am body).
    @State private var sortedRows: [QSO] = []
    @State private var chronoIndex: [UUID: Int] = [:]
    @State private var filteredCount: Int = 0

    private var theme: AppTheme { themeManager.theme }

    /// Rechnet alle drei Caches in einem Durchgang aus dem aktuellen
    /// Stand von currentQSOs + Filter-Strings + sortOrder neu.
    private func recomputeRows() {
        let qsos = manager.currentQSOs

        // 1) Chronologischer Index — bewusst aus *currentQSOs* gebaut
        //    (nicht aus sortedRows), damit die Nummer dem QSO erhalten
        //    bleibt, egal in welcher Sortierung die Tabelle gerade steht.
        var idx: [UUID: Int] = [:]
        idx.reserveCapacity(qsos.count)
        let byDate = qsos.sorted { $0.datetime < $1.datetime }
        for (i, q) in byDate.enumerated() { idx[q.id] = i + 1 }
        chronoIndex = idx

        // 2) Filter (4 Spalten — Call/Band/Mode/Country)
        let filtered = qsos.filter { qso in
            (filterCall.isEmpty    || qso.call.localizedCaseInsensitiveContains(filterCall)) &&
            (filterBand.isEmpty    || qso.band.localizedCaseInsensitiveContains(filterBand)) &&
            (filterMode.isEmpty    || qso.mode.localizedCaseInsensitiveContains(filterMode)) &&
            (filterCountry.isEmpty || (qso.country ?? "").localizedCaseInsensitiveContains(filterCountry))
        }
        filteredCount = filtered.count

        // 3) Sort gemäß aktuellem sortOrder (KeyPathComparator-Array).
        sortedRows = filtered.sorted(using: sortOrder)
    }

    private var currentLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    var body: some View {
        Group {
            if manager.currentLogID == nil {
                emptyMessage("Kein Log aktiv", "Wähle oben links ein Log oder lege ein neues an.")
            } else if sortedRows.isEmpty && manager.currentQSOs.isEmpty {
                emptyMessage("Noch keine QSOs",
                             "Fülle oben das QSO-Panel aus und drücke »Log QSO« (⌘↩).")
            } else if sortedRows.isEmpty {
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
        .alert(item: $qrzBulkAlert) { entry in
            Alert(title: Text(entry.title),
                  message: Text(entry.message),
                  dismissButton: .default(Text("OK")))
        }
        .alert(item: $clubLogBulkAlert) { entry in
            Alert(title: Text(entry.title),
                  message: Text(entry.message),
                  dismissButton: .default(Text("OK")))
        }
        .onAppear {
            recomputeRows()
            recomputeDupes()
        }
        .onChange(of: manager.currentQSOs) { _, _ in
            recomputeRows()
            recomputeDupes()
        }
        .onChange(of: manager.currentLogID) { _, _ in
            recomputeRows()
            recomputeDupes()
        }
        .onChange(of: filterCall)    { _, _ in recomputeRows() }
        .onChange(of: filterBand)    { _, _ in recomputeRows() }
        .onChange(of: filterMode)    { _, _ in recomputeRows() }
        .onChange(of: filterCountry) { _, _ in recomputeRows() }
        .onChange(of: sortOrder)     { _, _ in recomputeRows() }
    }

    /// Berechnet die Menge der Dupe-QSO-IDs im aktiven Log neu.
    /// • POTA: gleicher Call + gleiches Band (Mode egal — POTA-Spec).
    /// • Contest: gleicher Call + gleiches Band + gleicher Mode (Cabrillo-Standard).
    /// • Standard-Log: keine Markierung — Wiederholungen mit demselben Call sind
    ///   legitime QSOs über Jahre.
    private func recomputeDupes() {
        let kind = currentLog?.type
        guard kind == .pota || kind == .contest else {
            if !dupeQSOIDs.isEmpty { dupeQSOIDs = [] }
            return
        }
        var groups: [String: [UUID]] = [:]
        for q in manager.currentQSOs {
            let key: String
            switch kind {
            case .contest: key = "\(q.call.uppercased())|\(q.band)|\(q.mode.uppercased())"
            default:       key = "\(q.call.uppercased())|\(q.band)"
            }
            groups[key, default: []].append(q.id)
        }
        var result: Set<UUID> = []
        for (_, ids) in groups where ids.count > 1 {
            for id in ids { result.insert(id) }
        }
        if dupeQSOIDs != result { dupeQSOIDs = result }
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
        Table(sortedRows,
              selection: $selectedQSOs,
              sortOrder: $sortOrder,
              columnCustomization: $columnStore.customization) {
            // Default-sichtbare Spalten in einer Group — sonst überschreitet
            // die Tabelle das TableColumnBuilder-10er-Limit (insgesamt haben
            // wir 15 Spalten inkl. Aktionen).
            Group {
                // Laufende Nummer (chronologisch) — in allen Log-Typen sichtbar.
                // Der User sieht damit beim Loggen sofort, wie viele QSOs er
                // schon hat. Sortier-Value zeigt auf datetime, damit der Builder
                // Sort-Typ-konsistent zu den anderen Spalten bleibt.
                TableColumn("#", value: \QSO.datetime) { (qso: QSO) in
                    let idx = chronoIndex[qso.id]
                    let label: String = idx.map { String($0) } ?? ""
                    Text(label)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(theme.textDim)
                }
                .width(min: 36, ideal: 42)
                .customizationID("rowNumber")

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
                .defaultVisibility(.hidden)

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
                .defaultVisibility(.hidden)

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
                .defaultVisibility(.hidden)
            }

            // Programm-Refs — Spalten-Titel und -Inhalt folgen dem Log-Typ:
            //   POTA  → "State"   / "Their Park"      (theirPotaRef)
            //   SOTA  → "Region"  / "Their Summit"    (theirSotaRef)
            //   WWFF  → "Country" / "Their Reference" (theirWwffRef)
            //   Standard / Contest → wie POTA
            Group {
                TableColumn("\(regionalColumnLabel)") { (qso: QSO) in
                    Text(regionalValue(for: qso))
                        .font(.caption)
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 60, ideal: 80)
                .customizationID("state")

                TableColumn("\(theirRefColumnLabel)") { (qso: QSO) in
                    Text(theirRefValue(for: qso))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 80, ideal: 100)
                .customizationID("theirPark")
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

                // Contest-spezifische Spalten: bei Standard- und POTA-Logs
                // default versteckt, bei Contest-Logs wird die Sichtbarkeit
                // über applyDefaultsForCurrentLogType() angeschaltet.
                TableColumn("S-Nr") { (qso: QSO) in
                    Text(qso.contestSerial.map { String(format: "%03d", $0) } ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 50, ideal: 60)
                .customizationID("contestSerial")
                .defaultVisibility(.hidden)

                TableColumn("Sent Exch") { (qso: QSO) in
                    Text(qso.contestExchangeSent ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 80, ideal: 110)
                .customizationID("contestExchSent")
                .defaultVisibility(.hidden)

                TableColumn("Recv Exch") { (qso: QSO) in
                    Text(qso.contestExchangeRecv ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 80, ideal: 110)
                .customizationID("contestExchRecv")
                .defaultVisibility(.hidden)
            }

            // Zusätzliche QSO-Felder — alle default-hidden, per
            // Spalten-Menü zuschaltbar.
            Group {
                TableColumn("QTH") { (qso: QSO) in
                    Text(qso.qth ?? "")
                        .font(.caption)
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 80, ideal: 120)
                .customizationID("qth")
                .defaultVisibility(.hidden)

                TableColumn("ITU-Zone") { (qso: QSO) in
                    Text(qso.ituZone.map(String.init) ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 50, ideal: 60)
                .customizationID("ituZone")
                .defaultVisibility(.hidden)

                TableColumn("Distanz (km)") { (qso: QSO) in
                    Text(qso.distanceKm.map { String(format: "%.0f", $0) } ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 70, ideal: 90)
                .customizationID("distance")
                .defaultVisibility(.hidden)

                TableColumn("Peil (°)") { (qso: QSO) in
                    Text(qso.bearingDeg.map { String(format: "%.0f°", $0) } ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 60, ideal: 75)
                .customizationID("bearing")
                .defaultVisibility(.hidden)

                TableColumn("Station-Call") { (qso: QSO) in
                    Text(qso.stationCall ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 70, ideal: 90)
                .customizationID("stationCall")
                .defaultVisibility(.hidden)

                TableColumn("QSL Via") { (qso: QSO) in
                    Text(qso.qslSentVia ?? qso.qslReceivedVia ?? "")
                        .font(.caption)
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 60, ideal: 80)
                .customizationID("qslVia")
                .defaultVisibility(.hidden)

                TableColumn("My POTA") { (qso: QSO) in
                    Text(qso.myPotaRefs ?? qso.myPotaRef ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 80, ideal: 100)
                .customizationID("myPota")
                .defaultVisibility(.hidden)

                TableColumn("My SOTA") { (qso: QSO) in
                    Text(qso.mySotaRefs ?? qso.mySotaRef ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 80, ideal: 100)
                .customizationID("mySota")
                .defaultVisibility(.hidden)

                TableColumn("My WWFF") { (qso: QSO) in
                    Text(qso.myWwffRefs ?? qso.myWwffRef ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 80, ideal: 100)
                .customizationID("myWwff")
                .defaultVisibility(.hidden)

                TableColumn("My BOTA") { (qso: QSO) in
                    Text(qso.myBotaRefs ?? qso.myBotaRef ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(uploadColor(for: qso))
                }
                .width(min: 80, ideal: 100)
                .customizationID("myBota")
                .defaultVisibility(.hidden)
            }

            // QRZ-Status — grüner Haken wenn Call via Callbook irgendwas
            // geliefert hat (Name oder Locator oder Country). Bei US-Calls
            // ohne Namens-Eintrag bringt QRZ trotzdem Locator/Country —
            // das gilt auch als "aufgelöst". Bei Fehlen: Klick auf das
            // Fragezeichen triggert einen neuen Lookup-Versuch.
            TableColumn("QRZ") { (qso: QSO) in
                let resolved = !(qso.name ?? "").isEmpty
                            || !(qso.locator ?? "").isEmpty
                            || !(qso.country ?? "").isEmpty
                if resolved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .help(qso.name ?? qso.locator ?? qso.country ?? "")
                } else if lookupInFlight.contains(qso.id) {
                    ProgressView().controlSize(.small)
                } else {
                    Button { retryCallbookLookup(for: qso) } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.borderless)
                    .help("Callbook-Lookup nochmal versuchen")
                }
            }
            .width(min: 32, ideal: 40)
            .customizationID("qrzStatus")

            // QRZ Logbook Upload-Status — default-hidden, einblendbar via
            // Spalten-Menü. Zeigt den persistierten qrzLogbookStatus:
            //   0 = nicht versucht: leerer Pfeil-up (Tooltip „nicht hochgeladen")
            //   1 = OK: grüner Haken
            //   2 = duplicate: grauer Haken (war schon drin)
            //   3 = fail: rotes ⚠ — Klick → Bulk-Upload für genau diese Zeile
            TableColumn("QRZ-LB") { (qso: QSO) in
                qrzLogbookStatusCell(qso: qso)
            }
            .width(min: 40, ideal: 50)
            .customizationID("qrzLogbookStatus")
            .defaultVisibility(.hidden)

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
        // Rechtsklick auf Zeile(n): Mehrfach-Selektion + Single-Row beide
        // unterstützt — SwiftUI füllt `items` automatisch entweder mit der
        // aktiven Selektion (Rechtsklick AUF selektierte Zeile) oder mit der
        // geklickten Einzel-Zeile (sonst).
        .contextMenu(forSelectionType: UUID.self) { items in
            qsoContextMenu(for: items)
        }
    }

    // MARK: - Context-Menu

    @ViewBuilder
    private func qsoContextMenu(for ids: Set<UUID>) -> some View {
        if !ids.isEmpty {
            Button {
                bulkCallbookLookup(for: ids)
            } label: {
                let n = ids.count
                Label(n == 1
                      ? "Aus QRZ/HamQTH vervollständigen"
                      : "\(n) QSOs aus QRZ/HamQTH vervollständigen",
                      systemImage: "wand.and.stars")
            }
            Button {
                bulkUploadToQRZLogbook(for: ids)
            } label: {
                let n = ids.count
                Label(n == 1
                      ? "An QRZ Logbook hochladen"
                      : "\(n) QSOs an QRZ Logbook hochladen",
                      systemImage: "arrow.up.doc")
            }
            .disabled(!qrzLogbookConfigured || qrzUploadInFlight)
            Button {
                bulkUploadToClubLog(for: ids)
            } label: {
                let n = ids.count
                Label(n == 1
                      ? "An Club Log hochladen"
                      : "\(n) QSOs an Club Log hochladen",
                      systemImage: "arrow.up.doc.on.clipboard")
            }
            .disabled(!clubLogConfigured || clubLogUploadInFlight)
            if ids.count == 1, let id = ids.first,
               let qso = manager.currentQSOs.first(where: { $0.id == id }) {
                Divider()
                Button {
                    editingQSO = qso
                } label: {
                    Label("Bearbeiten…", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    manager.deleteQSO(qso)
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Bulk-Callbook

    /// Mehrfach-Lookup für die selektierten QSOs. Pro QSO wird die bestehende
    /// `applyFillingEmpty`-Logik aus dem Single-Retry wiederverwendet —
    /// existierende Felder werden NIE überschrieben, nur leere befüllt.
    ///
    /// `forceRefresh: false` ist hier bewusst gesetzt: bei einer Bulk-Aktion
    /// nutzen wir den 30-Tage-Cache, um QRZ/HamQTH nicht mit z. B. 50
    /// parallelen identischen Anfragen zu fluten. Wer einen einzelnen Call
    /// frisch nachladen will, hat dafür den `?`-Button in der QRZ-Spalte.
    private func bulkCallbookLookup(for ids: Set<UUID>) {
        let qsos = manager.currentQSOs.filter { ids.contains($0.id) }
        guard !qsos.isEmpty else { return }
        for q in qsos { lookupInFlight.insert(q.id) }
        Task {
            await withTaskGroup(of: (UUID, CallbookResult?).self) { group in
                for qso in qsos {
                    group.addTask {
                        let r = await callbookManager.lookup(call: qso.call,
                                                              forceRefresh: false)
                        return (qso.id, r)
                    }
                }
                for await (id, result) in group {
                    await MainActor.run {
                        lookupInFlight.remove(id)
                        guard let r = result,
                              let original = manager.currentQSOs.first(where: { $0.id == id })
                        else { return }
                        var updated = original
                        r.applyFillingEmpty(to: &updated)
                        if updated != original {
                            manager.updateQSO(updated)
                        }
                    }
                }
            }
        }
    }

    // MARK: - QRZ-Logbook-Status-Zelle

    @ViewBuilder
    private func qrzLogbookStatusCell(qso: QSO) -> some View {
        switch qso.qrzLogbookStatus {
        case 1:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .help("QRZ Logbook: hochgeladen")
        case 2:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(theme.textSecondary)
                .help("QRZ Logbook: war bereits hochgeladen")
        case 3:
            Button {
                bulkUploadToQRZLogbook(for: [qso.id])
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("QRZ-Upload fehlgeschlagen — Klick: nochmal versuchen")
            .disabled(qrzUploadInFlight)
        default:
            // 0 = nicht versucht — Klick lädt manuell hoch
            Button {
                bulkUploadToQRZLogbook(for: [qso.id])
            } label: {
                Image(systemName: "arrow.up.circle")
                    .foregroundStyle(theme.textDim)
            }
            .buttonStyle(.borderless)
            .help("Noch nicht hochgeladen — Klick: jetzt hochladen")
            .disabled(!qrzLogbookConfigured || qrzUploadInFlight)
        }
    }

    // MARK: - Bulk-Upload an QRZ Logbook

    private func bulkUploadToQRZLogbook(for ids: Set<UUID>) {
        guard !ids.isEmpty, qrzLogbookConfigured, !qrzUploadInFlight else { return }
        qrzUploadInFlight = true
        Task {
            let result = await manager.bulkUploadToQRZ(ids: ids)
            await MainActor.run {
                qrzUploadInFlight = false
                guard let r = result else {
                    qrzBulkAlert = QRZBulkAlert(
                        title: "QRZ-Upload nicht konfiguriert",
                        message: "Trag in den Einstellungen → Lookup & Upload → QRZ.com den Logbook-API-Key ein.")
                    return
                }
                qrzBulkAlert = QRZBulkAlert(
                    title: r.uploaded > 0
                        ? "\(r.uploaded) QSOs an QRZ hochgeladen"
                        : "Nichts neu hochgeladen",
                    message: "Neu: \(r.uploaded) · bereits in QRZ: \(r.duplicate) · Fehler: \(r.failed)")
            }
        }
    }

    // MARK: - Bulk-Upload an Club Log

    private func bulkUploadToClubLog(for ids: Set<UUID>) {
        guard !ids.isEmpty, clubLogConfigured, !clubLogUploadInFlight else { return }
        clubLogUploadInFlight = true
        Task {
            let result = await manager.bulkUploadToClubLog(ids: ids)
            await MainActor.run {
                clubLogUploadInFlight = false
                guard let r = result else {
                    clubLogBulkAlert = QRZBulkAlert(
                        title: "Club-Log-Upload nicht konfiguriert",
                        message: "Trag in den Einstellungen → Lookup & Upload → Club Log Email und Application-Password ein.")
                    return
                }
                if r.stoppedDueToAuth {
                    clubLogBulkAlert = QRZBulkAlert(
                        title: "Club-Log-Login fehlgeschlagen",
                        message: "Auto-Upload wurde pausiert, damit Club Log die IP nicht firewallt. Prüfe Email/Application-Password in den Einstellungen.\n\n\(r.firstError ?? "")")
                } else if r.uploaded > 0 {
                    clubLogBulkAlert = QRZBulkAlert(
                        title: "\(r.uploaded) QSOs an Club Log hochgeladen",
                        message: "Club Log hat den Batch akzeptiert.")
                } else {
                    clubLogBulkAlert = QRZBulkAlert(
                        title: "Upload fehlgeschlagen",
                        message: r.firstError ?? "Unbekannter Fehler — siehe Konsole.")
                }
            }
        }
    }

    // MARK: - State aus POTA-Park-DB
    //
    // MARK: - Programm-abhängige Spalten-Beschriftung

    // Linke Programm-Spalte (regional info): bei POTA der US-State o.ä.
    // aus der Park-DB, bei SOTA die Region (aus Ref-Mittelteil), bei WWFF
    // das Country aus dem QSO.
    private var regionalColumnLabel: String {
        switch currentLog?.type {
        case .sota: return "Region"
        case .wwff: return "Country"
        default:    return "State"
        }
    }

    private func regionalValue(for qso: QSO) -> String {
        switch currentLog?.type {
        case .sota:
            // SOTA-Ref-Format "HB/BE-001" → "BE" als Region
            guard let ref = qso.theirSotaRef, !ref.isEmpty else { return "" }
            if let slash = ref.firstIndex(of: "/"),
               let dash = ref.firstIndex(of: "-"),
               slash < dash {
                return String(ref[ref.index(after: slash)..<dash])
            }
            return ""
        case .wwff:
            return qso.country ?? ""
        default:
            return stateForQSO(qso)
        }
    }

    // Rechte Programm-Spalte (their reference): zeigt die Gegen-Ref des
    // jeweiligen Programms.
    private var theirRefColumnLabel: String {
        switch currentLog?.type {
        case .sota: return "Their Summit"
        case .wwff: return "Their Reference"
        default:    return "Their Park"
        }
    }

    private func theirRefValue(for qso: QSO) -> String {
        switch currentLog?.type {
        case .sota: return qso.theirSotaRef ?? ""
        case .wwff: return qso.theirWwffRef ?? ""
        default:    return qso.theirPotaRef ?? ""
        }
    }

    // Hamlib-CSV speichert in locationDesc "US-ME" / "DA-NW" / "CH-AG,CH-ZG".
    // Wir extrahieren den State (Teil nach dem Bindestrich) und joinen
    // Mehrfach-Refs mit Komma. Bei Parks ohne locationDesc → leer.
    private func stateForQSO(_ qso: QSO) -> String {
        guard let parkRef = qso.theirPotaRef, !parkRef.isEmpty,
              let park = potaService.park(forReference: parkRef),
              let loc = park.locationDesc, !loc.isEmpty
        else { return "" }
        let parts = loc.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let states: [String] = parts.map { part in
            if let dash = part.firstIndex(of: "-") {
                return String(part[part.index(after: dash)...])
            }
            return part
        }
        return states.joined(separator: ",")
    }

    // MARK: - QRZ-Retry

    /// Triggert einen frischen Callbook-Lookup für ein QSO. Im Gegensatz zur
    /// vorherigen Implementation füllen wir ALLE leeren QSO-Felder über
    /// applyFillingEmpty — Name, Locator, Country, Continent, QTH, Zones —
    /// nicht nur `name`. So wirkt der Retry auch wenn QRZ z.B. nur Locator
    /// liefert (typisch bei US-Calls ohne Namens-Eintrag).
    private func retryCallbookLookup(for qso: QSO) {
        let qsoID = qso.id
        lookupInFlight.insert(qsoID)
        Task {
            let result = await callbookManager.lookup(call: qso.call,
                                                      forceRefresh: true)
            await MainActor.run {
                lookupInFlight.remove(qsoID)
                guard let r = result else { return }
                var updated = qso
                r.applyFillingEmpty(to: &updated)
                if updated != qso {
                    manager.updateQSO(updated)
                }
            }
        }
    }

    // MARK: - Color coding

    private func uploadColor(for qso: QSO) -> Color {
        // POTA-Dupe gewinnt über Upload-Farben: roter Vermerk hat Vorrang.
        if dupeQSOIDs.contains(qso.id) { return .red }
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
