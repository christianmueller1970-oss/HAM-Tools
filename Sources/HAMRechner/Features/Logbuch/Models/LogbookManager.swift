import Foundation
import Combine

// Verwaltet ALLE Logbücher unabhängig von ihrem Speicherort. Jedes
// Logbuch ist eine .htlog-Datei (SQLite). Speicherorte werden in
// LogbookSettings.knownLogPaths verwaltet — so können einzelne Logs in
// iCloud Drive, externen Platten, etc. liegen.
@MainActor
final class LogbookManager: ObservableObject {
    @Published private(set) var logs: [Log] = []
    @Published private(set) var currentLogID: UUID?
    @Published private(set) var currentQSOs: [QSO] = []
    // Mapping: Log-ID → konkrete Datei (für openLog / deleteLog / Anzeige)
    @Published private(set) var fileURLs: [UUID: URL] = [:]
    // Live-aktualisierte Award-Counter (über ALLE Logs aggregiert).
    @Published private(set) var awards: AwardCounts = AwardCounts()
    // Detail-Breakdown für den Awards-Tab — pro Country / pro CQ-Zone /
    // pro US-State. Wird zusammen mit awards aktualisiert.
    @Published private(set) var dxccBreakdown: [DXCCAwardEntry] = []
    @Published private(set) var wazBreakdown:  [WAZEntry]  = []
    @Published private(set) var wasBreakdown:  [WASEntry]  = []

    // ATNO-Live-Sets für die Spot-Markierung im DX-Cluster. Werden in
    // recomputeAwards() aus byCountry abgeleitet — Country-Strings sind
    // uppercased, Band/Mode auch, damit der Lookup im DXClusterViewModel
    // robust gegen kleine Schreibvarianten ist.
    @Published private(set) var workedCountries: Set<String> = []
    @Published private(set) var workedCountryBand: Set<String> = []
    @Published private(set) var workedCountryMode: Set<String> = []

    private let settings: LogbookSettings
    private let dataRoot: AppDataRoot
    private var openDB: LogbookDatabase?
    private var directoryObserver: AnyCancellable?

    private let lastOpenLogKey = "logbook.lastOpenLogID"

    // Pro Log-Typ wird das zuletzt offene Log gemerkt, damit die Entry-
    // Mode-Tabs (DX / POTA) beim Wechseln auf das passende Log springen
    // können statt im POTA-Log zu kleben.
    private static func lastOpenKey(for type: LogType) -> String {
        "logbook.lastOpenLogID.\(type.rawValue)"
    }

    init(settings: LogbookSettings, dataRoot: AppDataRoot) {
        self.settings = settings
        self.dataRoot = dataRoot
        reloadAll()
        ensureLebensLog()
        restoreLastOpenLog()
        recomputeAwards()

        // Bei Wechsel des Datenordners alles neu scannen.
        directoryObserver = dataRoot.$rootURL
            .dropFirst()
            .sink { [weak self] _ in
                self?.reloadAll()
                self?.recomputeAwards()
            }
    }

    /// Beim Start: das zuletzt aktive Log wiederherstellen.
    private func restoreLastOpenLog() {
        guard let raw = UserDefaults.standard.string(forKey: lastOpenLogKey),
              let id = UUID(uuidString: raw),
              let log = logs.first(where: { $0.id == id })
        else { return }
        openLog(log)
    }

    // MARK: - Public: Logs

    func openLog(_ log: Log) {
        if currentLogID == log.id, openDB != nil { return }
        guard let url = fileURLs[log.id] else { return }
        do {
            let db = try LogbookDatabase(opening: url)
            self.openDB = db
            self.currentLogID = log.id
            self.currentQSOs = db.qsos
            UserDefaults.standard.set(log.id.uuidString, forKey: lastOpenLogKey)
            UserDefaults.standard.set(log.id.uuidString,
                                      forKey: Self.lastOpenKey(for: log.type))
        } catch {
            print("openLog failed: \(error.localizedDescription)")
        }
    }

    /// Wechselt aufs zuletzt offene Log dieses Typs. Fallback: das neueste
    /// Log dieses Typs. Wenn gar keins existiert, passiert nichts (Caller
    /// kann dann z.B. den »Neue Session«-Sheet öffnen).
    @discardableResult
    func switchToLastLog(of type: LogType) -> Bool {
        if let raw = UserDefaults.standard.string(forKey: Self.lastOpenKey(for: type)),
           let id = UUID(uuidString: raw),
           let log = logs.first(where: { $0.id == id && $0.type == type }) {
            openLog(log)
            return true
        }
        if let log = logs.first(where: { $0.type == type }) {
            openLog(log)
            return true
        }
        return false
    }

    func closeLog() {
        openDB = nil
        currentLogID = nil
        currentQSOs = []
        UserDefaults.standard.removeObject(forKey: lastOpenLogKey)
    }

    /// Legt ein neues Logbuch an. Wenn `targetDirectory == nil` wird der
    /// globale Default-Ordner genutzt.
    func createLog(_ log: Log, in targetDirectory: URL? = nil) {
        let dir = targetDirectory ?? settings.logbookDirectory
        try? FileManager.default.createDirectory(at: dir,
                                                 withIntermediateDirectories: true)
        let url = uniqueFileURL(for: log, in: dir)
        do {
            let db = try LogbookDatabase(creating: url, log: log)
            settings.addKnownLog(url)
            fileURLs[db.log.id] = url
            logs.insert(db.log, at: 0)
            self.openDB = db
            self.currentLogID = db.log.id
            self.currentQSOs = []
            recomputeAwards()
        } catch {
            print("createLog failed: \(error.localizedDescription)")
        }
    }

    func deleteLog(_ log: Log) {
        guard let url = fileURLs[log.id] else { return }
        // Vor dem Löschen automatisches ADIF-Backup ins Backups/-Verzeichnis.
        // Wenn das Log leer ist, passiert nichts (kein leeres Backup).
        backupLogAsADIF(logID: log.id, tag: "pre-delete")

        if currentLogID == log.id {
            openDB = nil
            currentLogID = nil
            currentQSOs = []
            UserDefaults.standard.removeObject(forKey: lastOpenLogKey)
        }
        if UserDefaults.standard.string(forKey: Self.lastOpenKey(for: log.type))
            == log.id.uuidString {
            UserDefaults.standard.removeObject(forKey: Self.lastOpenKey(for: log.type))
        }
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
        try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
        settings.removeKnownLog(url)
        fileURLs[log.id] = nil
        logs.removeAll { $0.id == log.id }
        recomputeAwards()
    }

    /// Bestehendes .htlog importieren (nur Pfad merken, Datei bleibt wo sie ist).
    func importLog(at url: URL) {
        do {
            let db = try LogbookDatabase(opening: url)
            if logs.contains(where: { $0.id == db.log.id }) { return }
            settings.addKnownLog(url)
            fileURLs[db.log.id] = url
            logs.insert(db.log, at: 0)
        } catch {
            print("importLog failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Public: QSOs

    // Lizenz-Gate: optional vom App-Root gesetzt. Wenn `licenseAllowsMoreQSOs`
    // false zurückgibt, wird das QSO NICHT persistiert und `onLicenseBlocked`
    // aufgerufen (für UI-Toast). Nach erfolgreichem Add wird `onQSOLogged`
    // gerufen — der License-Service zählt damit den Demo-Counter hoch.
    var licenseAllowsMoreQSOs: (() -> Bool)?
    var onLicenseBlocked:      (() -> Void)?
    var onQSOLogged:           (() -> Void)?

    // Vom App-Root nach Init gesetzt (siehe HAMRechnerApp). Wird für den
    // QRZ-Auto-Upload-Hook in addQSO und die bulkUploadToQRZ-Methode
    // gebraucht. Weak nicht nötig — UploadServicesSettings lebt die ganze
    // App-Lifetime.
    var uploadServices: UploadServicesSettings?

    // Vom App-Root injiziert. Wird in recomputeAwards für die Activator-
    // Punkte-Berechnung (Summit-Lookup + Lat für Winterbonus) gebraucht.
    // Optional, weil LogbookManager ohne Service-Setup initialisiert wird;
    // fehlt der Service zur Aggregations-Zeit, bleibt sotaActivatorPoints
    // einfach 0 (alle anderen Counter funktionieren weiter).
    var sotaSummits: SotaSummitService?

    func addQSO(_ qso: QSO) {
        guard let db = openDB else { return }
        if let gate = licenseAllowsMoreQSOs, !gate() {
            onLicenseBlocked?()
            return
        }
        var local = qso
        recomputeGeometry(&local)
        do {
            try db.addQSO(local); currentQSOs = db.qsos
            recomputeAwards()
            onQSOLogged?()
            scheduleQRZAutoUpload(for: local)
            scheduleClubLogAutoUpload(for: local)
        } catch { print("addQSO failed: \(error.localizedDescription)") }
    }

    func updateQSO(_ qso: QSO) {
        guard let db = openDB else { return }
        var local = qso
        recomputeGeometry(&local)
        do {
            try db.updateQSO(local); currentQSOs = db.qsos
            recomputeAwards()
        } catch { print("updateQSO failed: \(error.localizedDescription)") }
    }

    /// Setzt `distanceKm` und `bearingDeg` aus dem eigenen QTH-Locator
    /// (`AppStorage("qthLocator")`) und dem QSO-Locator. Behutsam:
    /// — fehlt einer der beiden Locatoren, bleiben bestehende Werte
    ///   unangetastet (wichtig für ADIF-Import, der eine DISTANCE
    ///   vom Original-Logger schon mitgebracht haben kann).
    /// — sind beide da, wird überschrieben (Locator-Änderung soll auch
    ///   die Geometrie aktualisieren).
    private func recomputeGeometry(_ qso: inout QSO) {
        let ownLoc = (UserDefaults.standard.string(forKey: "qthLocator") ?? "")
            .trimmingCharacters(in: .whitespaces)
        guard !ownLoc.isEmpty else { return }
        guard let qsoLoc = qso.locator?.trimmingCharacters(in: .whitespaces),
              !qsoLoc.isEmpty else { return }
        if let geo = QSO.computeGeometry(from: ownLoc, to: qsoLoc) {
            qso.distanceKm = geo.distance
            qso.bearingDeg = geo.bearing
        }
    }

    struct GeometryBackfillResult: Equatable {
        var updated: Int      // QSOs mit neuen/geänderten Werten
        var unchanged: Int    // QSOs mit gültigem Locator, Werte stimmten schon
        var skipped: Int      // ohne QSO-Locator → nicht berechenbar
        var totalChecked: Int { updated + unchanged + skipped }
    }

    /// Bulk-Backfill: läuft durch alle QSOs des aktiven Logs und berechnet
    /// `distanceKm`/`bearingDeg` neu, wo möglich. Nützlich für ältere QSOs
    /// (vor der Auto-Berechnung geloggt) oder nach Wechsel des eigenen QTHs.
    /// Liefert ein Ergebnis-Triple für UI-Feedback. Gibt nil zurück, wenn
    /// kein Log offen ist oder der eigene QTH-Locator nicht gesetzt ist.
    func recomputeGeometryForAllQSOs() -> GeometryBackfillResult? {
        guard let db = openDB else { return nil }
        let ownLoc = (UserDefaults.standard.string(forKey: "qthLocator") ?? "")
            .trimmingCharacters(in: .whitespaces)
        guard !ownLoc.isEmpty else { return nil }

        var updated = 0
        var unchanged = 0
        var skipped = 0
        for q in currentQSOs {
            guard let qsoLoc = q.locator?.trimmingCharacters(in: .whitespaces),
                  !qsoLoc.isEmpty,
                  let geo = QSO.computeGeometry(from: ownLoc, to: qsoLoc)
            else {
                skipped += 1
                continue
            }
            // Float-Vergleich mit Epsilon (DB-Roundtrip kann minimale
            // Differenzen erzeugen, die wir nicht als "geändert" zählen).
            let same = (q.distanceKm.map { abs($0 - geo.distance) < 0.5 } ?? false)
                    && (q.bearingDeg.map { abs($0 - geo.bearing)  < 0.1 } ?? false)
            if same {
                unchanged += 1
                continue
            }
            var local = q
            local.distanceKm = geo.distance
            local.bearingDeg = geo.bearing
            do { try db.updateQSO(local); updated += 1 }
            catch { print("recomputeGeometryForAllQSOs update failed: \(error)") }
        }
        if updated > 0 {
            currentQSOs = db.qsos
            recomputeAwards()
        }
        return GeometryBackfillResult(updated: updated,
                                       unchanged: unchanged,
                                       skipped: skipped)
    }

    // MARK: - QRZ Logbook Upload

    /// Fire-and-forget Auto-Upload nach `addQSO`. Greift nur:
    ///   • wenn UploadServicesSettings injiziert ist und Auto-Toggle an
    ///   • API-Key gesetzt
    ///   • Log-Typ Standard (DX) — Outdoor-Programme nutzen eigene
    ///     Upload-Pfade, dort schiesst Auto nichts hoch
    private func scheduleQRZAutoUpload(for qso: QSO) {
        guard let settings = uploadServices,
              settings.qrzAutoUploadOnLog,
              !settings.qrzLogbookApiKey.trimmingCharacters(in: .whitespaces).isEmpty,
              let log = logs.first(where: { $0.id == qso.logID }),
              log.type == .standard
        else { return }

        let key = settings.qrzLogbookApiKey
        Task { [weak self] in
            let service = QRZLogbookService()
            let outcome = await service.upload(qso: qso, apiKey: key)
            await MainActor.run {
                self?.applyQRZUploadOutcome(outcome, to: qso.id)
            }
        }
    }

    /// Schreibt das QRZ-Status-Flag an einem QSO zurück. Wird vom Auto-
    /// Upload-Hook und vom Bulk-Upload-Pfad gleichermaßen genutzt.
    private func applyQRZUploadOutcome(_ outcome: QRZLogbookService.UploadOutcome,
                                        to qsoID: UUID) {
        guard let db = openDB,
              var q = currentQSOs.first(where: { $0.id == qsoID })
        else { return }
        let newStatus = outcome.statusCode
        guard q.qrzLogbookStatus != newStatus else { return }
        q.qrzLogbookStatus = newStatus
        do {
            try db.updateQSO(q)
            currentQSOs = db.qsos
        } catch {
            print("QRZ status persist failed: \(error.localizedDescription)")
        }
    }

    struct QRZBulkResult: Equatable {
        var uploaded:  Int      // RESULT=OK (neu in QRZ)
        var duplicate: Int      // RESULT=FAIL/duplicate (war schon drin)
        var failed:    Int      // Auth-, Network-, sonstige Fehler
        var total: Int { uploaded + duplicate + failed }
    }

    struct QRZFetchSyncResult: Equatable {
        var serverTotal:      Int    // Anzahl QSOs auf QRZ
        var matchedLocal:     Int    // davon konnten wir lokal zuordnen
        var newConfirmations: Int    // QSOs, bei denen wir Bestätigungs-Flags neu gesetzt haben
        var serverOnly:       Int    // auf QRZ, aber nicht lokal (informativ)
    }
    enum QRZFetchSyncError: LocalizedError {
        case notConfigured
        case service(String)
        var errorDescription: String? {
            switch self {
            case .notConfigured:    return "QRZ-Logbook-API-Key fehlt in den Einstellungen."
            case .service(let m):   return m
            }
        }
    }

    /// Holt alle QSOs von QRZ via ACTION=FETCH und merged die
    /// Bestätigungs-Felder (lotwConfirmed, eqslConfirmed, qslReceivedDate,
    /// qslReceivedVia) **additiv** in unsere lokalen Datensätze:
    ///   • setzt nur dann, wenn Server-true und lokal noch false (bzw.
    ///     Datum lokal nil).
    ///   • überschreibt niemals einen lokal manuell gesetzten Status.
    /// Match-Schlüssel: Call|YYYYMMDDHHMM|Band|Mode (case-normalisiert).
    /// Bei Multi-Match ungewöhnlich, aber theoretisch möglich → wir
    /// updaten alle Treffer (würde nur passieren wenn der lokale Log
    /// Duplikate enthält).
    func fetchQRZConfirmations() async throws -> QRZFetchSyncResult {
        guard let settings = uploadServices,
              !settings.qrzLogbookApiKey.trimmingCharacters(in: .whitespaces).isEmpty
        else { throw QRZFetchSyncError.notConfigured }
        let key = settings.qrzLogbookApiKey

        // Index der lokalen QSOs für O(1)-Match. Wir bauen den einmal vor
        // der Pagination-Schleife — und referenzieren die QSO-IDs, damit
        // wir nach dem Page-Update immer die aktuelle Version aus
        // currentQSOs holen können (Updates aus der vorigen Page könnten
        // den lokalen Stand verändert haben).
        var localIndex: [String: [UUID]] = [:]
        for q in currentQSOs {
            let mk = Self.qrzMatchKey(call: q.call,
                                       datetime: q.datetime,
                                       band: q.band,
                                       mode: q.mode)
            localIndex[mk, default: []].append(q.id)
        }

        let service = QRZLogbookService()
        var serverTotal = 0
        var matchedLocal = 0
        var newConfirmations = 0
        var serverOnly = 0

        // Pagination: solange QRZ ein volles Batch liefert (= 250), gibt's
        // mehr; sobald weniger kommen, sind wir am Ende. Sicherheits-Cap
        // auf 200 Iterationen = 50 000 QSOs.
        var afterLogId = 0
        var iteration = 0
        let maxIterations = 200

        outer: while iteration < maxIterations {
            iteration += 1
            // QRZ-Rate-Limit-Schutz: kurze Pause zwischen Pages.
            // 8 Requests in 12 s waren empirisch zu schnell — Page 8 kam
            // mit 0 Bytes zurück (2026-05-16). 400 ms Delay ab der 2. Page
            // gibt dem Server Luft, bleibt aber UX-tolerabel
            // (~11 s extra für 28 Pages bei 7000 QSOs).
            if iteration > 1 {
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            let result = await service.fetchAll(apiKey: key, afterLogId: afterLogId)
            let payload: QRZLogbookService.FetchResult
            switch result {
            case .success(let r):
                payload = r
            case .failure(let err):
                if iteration == 1 {
                    throw QRZFetchSyncError.service(err.errorDescription ?? "FETCH fehlgeschlagen")
                }
                // Spätere Pages mit Fehler: einmal kurz warten und nochmal
                // versuchen — Rate-Limits sind oft transient. Bleibt's
                // hartnäckig, brechen wir mit dem bisher Gesammelten ab.
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                let retry = await service.fetchAll(apiKey: key, afterLogId: afterLogId)
                switch retry {
                case .success(let r): payload = r
                case .failure:        break outer
                }
            }

            let records = ADIFCodec.parse(payload.adif)
            serverTotal += records.count

            // Höchste app_qrzlog_logid in diesem Batch — wird zur Vorgabe
            // für den nächsten AFTERLOGID.
            var highestLogId = afterLogId

            for rec in records {
                if let logIdStr = rec["app_qrzlog_logid"] ?? rec["APP_QRZLOG_LOGID"],
                   let logId = Int(logIdStr.trimmingCharacters(in: .whitespaces)) {
                    if logId > highestLogId { highestLogId = logId }
                }

                guard let mk = Self.qrzMatchKey(fromADIF: rec),
                      let candidateIDs = localIndex[mk], !candidateIDs.isEmpty else {
                    serverOnly += 1
                    continue
                }
                matchedLocal += candidateIDs.count

                for id in candidateIDs {
                    guard let original = currentQSOs.first(where: { $0.id == id }) else { continue }
                    var updated = original
                    var didChange = false

                    // Additiv: nur setzen, wenn lokal noch nicht gesetzt
                    // UND Server-true.
                    if !updated.lotwConfirmed,
                       let v = rec["LOTW_QSLRDATE"], !v.isEmpty {
                        updated.lotwConfirmed = true
                        didChange = true
                    }
                    if !updated.eqslConfirmed,
                       let v = rec["EQSL_QSLRDATE"], !v.isEmpty {
                        updated.eqslConfirmed = true
                        didChange = true
                    }
                    if updated.qslReceivedDate == nil {
                        if let rcvd = rec["QSL_RCVD"]?.uppercased(), rcvd == "Y" {
                            if let dateStr = rec["QSL_RCVDDATE"],
                               let date = Self.parseADIFDate(dateStr) {
                                updated.qslReceivedDate = date
                                didChange = true
                            }
                        } else if let dateStr = rec["QSL_RCVDDATE"], !dateStr.isEmpty,
                                  let date = Self.parseADIFDate(dateStr) {
                            updated.qslReceivedDate = date
                            didChange = true
                        }
                    }
                    if (updated.qslReceivedVia ?? "").isEmpty,
                       let via = rec["QSL_RCVD_VIA"]?.trimmingCharacters(in: .whitespaces),
                       !via.isEmpty {
                        updated.qslReceivedVia = via
                        didChange = true
                    }

                    if didChange, let db = openDB {
                        do {
                            try db.updateQSO(updated)
                            newConfirmations += 1
                        } catch {
                            print("QRZ confirm-sync update failed: \(error.localizedDescription)")
                        }
                    }
                }
            }

            // currentQSOs refresh, damit der next-Page-Loop die frischen
            // Werte sieht.
            if newConfirmations > 0, let db = openDB {
                currentQSOs = db.qsos
            }

            // Abbruch-Bedingungen:
            //   • leere Page → fertig
            //   • Server-COUNT < MAX → letzte Page
            //   • highestLogId hat sich nicht erhöht → keine neuen Daten
            if records.isEmpty || payload.count < 250 || highestLogId == afterLogId {
                break
            }
            afterLogId = highestLogId + 1
        }

        if newConfirmations > 0 {
            recomputeAwards()
        }
        return QRZFetchSyncResult(serverTotal: serverTotal,
                                   matchedLocal: matchedLocal,
                                   newConfirmations: newConfirmations,
                                   serverOnly: serverOnly)
    }

    // MARK: - QRZ-Match-Schlüssel

    /// Normalisierter Match-Key für QSO-Equality über Logger-Grenzen:
    /// Call|YYYYMMDDHHMM|Band|Mode (alle uppercased/lowercased).
    private static func qrzMatchKey(call: String,
                                     datetime: Date,
                                     band: String,
                                     mode: String) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMddHHmm"
        let c = call.uppercased().trimmingCharacters(in: .whitespaces)
        let b = band.lowercased().trimmingCharacters(in: .whitespaces)
        let m = mode.uppercased().trimmingCharacters(in: .whitespaces)
        return "\(c)|\(f.string(from: datetime))|\(b)|\(m)"
    }

    private static func qrzMatchKey(fromADIF dict: [String: String]) -> String? {
        guard let callRaw = dict["CALL"]?.trimmingCharacters(in: .whitespaces),
              !callRaw.isEmpty,
              let dateStr = dict["QSO_DATE"],
              let timeStr = dict["TIME_ON"],
              let band = dict["BAND"]?.trimmingCharacters(in: .whitespaces),
              let mode = dict["MODE"]?.trimmingCharacters(in: .whitespaces)
        else { return nil }
        // ADIF TIME_ON kann HHmm oder HHmmss sein — wir matchen auf Minute.
        let timeOnly = String(timeStr.prefix(4))
        return "\(callRaw.uppercased())|\(dateStr)\(timeOnly)|\(band.lowercased())|\(mode.uppercased())"
    }

    private static func parseADIFDate(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 8 else { return nil }
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd"
        return f.date(from: String(trimmed.prefix(8)))
    }

    /// Bulk-Upload für eine Auswahl QSOs. Parallel via TaskGroup, max 6
    /// gleichzeitige Requests (QRZ hat keine offizielle Rate-Limit, aber
    /// freundlich bleiben). Status-Flags werden pro QSO direkt in der DB
    /// nachgeführt.
    func bulkUploadToQRZ(ids: Set<UUID>) async -> QRZBulkResult? {
        guard let settings = uploadServices,
              !settings.qrzLogbookApiKey.trimmingCharacters(in: .whitespaces).isEmpty
        else { return nil }
        let key = settings.qrzLogbookApiKey
        let qsos = currentQSOs.filter { ids.contains($0.id) }
        guard !qsos.isEmpty else { return QRZBulkResult(uploaded: 0, duplicate: 0, failed: 0) }

        let service = QRZLogbookService()
        var uploaded = 0
        var duplicate = 0
        var failed = 0

        await withTaskGroup(of: (UUID, QRZLogbookService.UploadOutcome).self) { group in
            // Concurrency-Limit: 6 parallel. Beim Lebens-Log mit 300+ QSOs
            // wären 300 gleichzeitige Verbindungen unhöflich gegenüber QRZ.
            var queued = 0
            for q in qsos {
                if queued >= 6 {
                    if let (id, outcome) = await group.next() {
                        self.applyQRZUploadOutcome(outcome, to: id)
                        switch outcome {
                        case .accepted:  uploaded += 1
                        case .duplicate: duplicate += 1
                        default:         failed += 1
                        }
                        queued -= 1
                    }
                }
                group.addTask {
                    let outcome = await service.upload(qso: q, apiKey: key)
                    return (q.id, outcome)
                }
                queued += 1
            }
            for await (id, outcome) in group {
                self.applyQRZUploadOutcome(outcome, to: id)
                switch outcome {
                case .accepted:  uploaded += 1
                case .duplicate: duplicate += 1
                default:         failed += 1
                }
            }
        }
        return QRZBulkResult(uploaded: uploaded, duplicate: duplicate, failed: failed)
    }

    // MARK: - Club Log Upload

    struct ClubLogBulkResult: Equatable {
        var uploaded: Int     // erfolgreiche Uploads
        var failed:   Int     // Fehler (auch Auth — wir stoppen dann)
        var stoppedDueToAuth: Bool
        var firstError: String?
        var total: Int { uploaded + failed }
    }

    /// Fire-and-forget Auto-Upload für Club Log nach `addQSO`. Greift nur:
    ///   • Auto-Toggle an + Email + Password gesetzt
    ///   • Log-Typ Standard (DX) — Programm-Logs nutzen ihre eigenen Pfade
    /// Bei Auth-Fail wird der Auto-Toggle automatisch deaktiviert, damit
    /// Club Log uns nicht wegen wiederholter Fehler die IP firewallt.
    private func scheduleClubLogAutoUpload(for qso: QSO) {
        guard let settings = uploadServices,
              settings.clublogAutoUpload,
              !settings.clublogEmail.trimmingCharacters(in: .whitespaces).isEmpty,
              !settings.clublogPassword.trimmingCharacters(in: .whitespaces).isEmpty,
              let log = logs.first(where: { $0.id == qso.logID }),
              log.type == .standard
        else { return }

        let email = settings.clublogEmail
        let password = settings.clublogPassword
        let opCall = qso.operatorCall?.trimmingCharacters(in: CharacterSet.whitespaces) ?? ""
        let ownCall = UserDefaults.standard.string(forKey: "callsign") ?? ""
        let callsign = opCall.isEmpty ? ownCall : opCall
        guard !callsign.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty else { return }
        let markQsl = settings.clublogMarkQslSent

        Task { [weak self] in
            let service = ClubLogService()
            let outcome = await service.uploadSingle(qso: qso,
                                                     email: email,
                                                     password: password,
                                                     callsign: callsign)
            await MainActor.run {
                self?.applyClubLogUploadOutcome(outcome, to: qso.id, markQsl: markQsl)
                if case .authFailed = outcome {
                    self?.uploadServices?.clublogAutoUpload = false
                }
            }
        }
    }

    /// Schreibt das Club-Log-Status-Flag am QSO zurück. Bei Erfolg wird
    /// `clublogSent = true` gesetzt. `markQsl` ist die User-Einstellung
    /// (»QSL via Club Log gesendet« markieren) — wird nur bei .accepted
    /// angewandt.
    private func applyClubLogUploadOutcome(_ outcome: ClubLogService.UploadOutcome,
                                            to qsoID: UUID,
                                            markQsl: Bool) {
        guard let db = openDB,
              var q = currentQSOs.first(where: { $0.id == qsoID })
        else { return }
        switch outcome {
        case .accepted:
            guard !q.clublogSent else { return }
            q.clublogSent = true
            if markQsl { /* bereits via clublogSent abgedeckt — QSL-Sent-Flag ist clublogSent */ }
            do {
                try db.updateQSO(q)
                currentQSOs = db.qsos
            } catch {
                print("Club Log status persist failed: \(error.localizedDescription)")
            }
        case .authFailed, .rejected, .network:
            // Keine Persistenz nötig — der Aufrufer entscheidet was passiert
            // (Auto-Upload deaktivieren, Bulk-Counter hochzählen, …).
            break
        }
    }

    /// Bulk-Upload für eine Auswahl QSOs an Club Log via putlogs.php.
    /// **Sequenziell, nicht parallel** — Club Log toleriert nur einen
    /// putlogs-Request am Stück und firewallt bei wiederholten Fehlern.
    /// Bei Auth-Fail brechen wir sofort ab.
    func bulkUploadToClubLog(ids: Set<UUID>) async -> ClubLogBulkResult? {
        guard let settings = uploadServices,
              !settings.clublogEmail.trimmingCharacters(in: .whitespaces).isEmpty,
              !settings.clublogPassword.trimmingCharacters(in: .whitespaces).isEmpty
        else { return nil }
        let qsos = currentQSOs.filter { ids.contains($0.id) }
        guard !qsos.isEmpty else {
            return ClubLogBulkResult(uploaded: 0, failed: 0,
                                      stoppedDueToAuth: false, firstError: nil)
        }
        let email = settings.clublogEmail
        let ownCall = UserDefaults.standard.string(forKey: "callsign") ?? ""
        let opCall = qsos.first?.operatorCall?.trimmingCharacters(in: CharacterSet.whitespaces) ?? ""
        let callsign = opCall.isEmpty ? ownCall : opCall
        guard !callsign.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty else {
            return ClubLogBulkResult(uploaded: 0, failed: qsos.count,
                                      stoppedDueToAuth: false,
                                      firstError: "Eigenes Rufzeichen fehlt in den Einstellungen.")
        }

        let logName = "HAM-Tools-Bulk-\(ISO8601DateFormatter().string(from: Date()))"
        let service = ClubLogService()
        let outcome = await service.uploadBatch(qsos: qsos,
                                                 logName: logName,
                                                 email: email,
                                                 callsign: callsign)

        switch outcome {
        case .accepted:
            // Alle QSOs als clublogSent markieren.
            for q in qsos {
                applyClubLogUploadOutcome(.accepted, to: q.id,
                                           markQsl: settings.clublogMarkQslSent)
            }
            return ClubLogBulkResult(uploaded: qsos.count, failed: 0,
                                      stoppedDueToAuth: false, firstError: nil)
        case .authFailed(let msg):
            uploadServices?.clublogAutoUpload = false
            return ClubLogBulkResult(uploaded: 0, failed: qsos.count,
                                      stoppedDueToAuth: true, firstError: msg)
        case .rejected(let msg), .network(let msg):
            return ClubLogBulkResult(uploaded: 0, failed: qsos.count,
                                      stoppedDueToAuth: false, firstError: msg)
        }
    }

    func deleteQSO(_ qso: QSO) {
        guard let db = openDB else { return }
        do {
            try db.deleteQSO(qso); currentQSOs = db.qsos
            recomputeAwards()
        } catch { print("deleteQSO failed: \(error.localizedDescription)") }
    }

    func qsoCount(for log: Log) -> Int {
        if log.id == currentLogID { return currentQSOs.count }
        guard let url = fileURLs[log.id] else { return 0 }
        return (try? LogbookDatabase(opening: url).qsoCount) ?? 0
    }

    func fileURL(for log: Log) -> URL? {
        fileURLs[log.id]
    }

    // MARK: - ADIF Export / Import

    // MARK: - Auto-Backup

    /// Schreibt das angegebene Log als ADIF in den Backups-Ordner mit einem
    /// Kontext-Tag (z.B. »pre-delete«, »pre-import«). Wird vor riskanten
    /// Aktionen automatisch aufgerufen damit man im Notfall den Stand
    /// wiederherstellen kann.
    @discardableResult
    func backupLogAsADIF(logID: UUID, tag: String) -> URL? {
        guard let log = logs.first(where: { $0.id == logID }) else { return nil }
        let qsos: [QSO]
        if logID == currentLogID {
            qsos = currentQSOs
        } else if let url = fileURLs[logID],
                  let db = try? LogbookDatabase(opening: url) {
            qsos = db.qsos
        } else {
            qsos = []
        }
        guard !qsos.isEmpty else { return nil }  // leeres Log braucht kein Backup
        let text = ADIFCodec.encode(qsos: qsos, logName: log.name)
        let stamp: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmmss"
            return f.string(from: Date())
        }()
        let safeName = log.name.replacingOccurrences(of: "/", with: "_")
        let fileName = "\(safeName)-\(stamp)-\(tag).adi"
        let url = dataRoot.backupsDir.appendingPathComponent(fileName)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Backup fehlgeschlagen: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - ADIF Export

    /// Schreibt das aktive Log als Cabrillo V3 in den Exports-Ordner.
    /// Der Header kommt aus dem Cabrillo-Export-Dialog.
    func exportActiveLogAsCabrillo(header: CabrilloHeader) -> URL? {
        guard let logID = currentLogID,
              let log = logs.first(where: { $0.id == logID }) else { return nil }
        let text = CabrilloExporter.encode(qsos: currentQSOs, header: header)
        let stamp: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmmss"
            return f.string(from: Date())
        }()
        let contestSlug = header.contestID
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        let safeName = log.name.replacingOccurrences(of: "/", with: "_")
        let fileName = "\(safeName)-\(contestSlug)-\(stamp).cbr"
        let url = dataRoot.exportsDir.appendingPathComponent(fileName)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Cabrillo Export fehlgeschlagen: \(error.localizedDescription)")
            return nil
        }
    }

    /// Schreibt das aktive Log als ADIF in den Exports-Ordner. Bei einem
    /// POTA-Log mit Multi-Park-Hopping wird automatisch pro Park ein
    /// eigenes File geschrieben, weil pota.app Komma-Listen in
    /// MY_SIG_INFO nicht akzeptiert. Sonst ein einzelnes File.
    func exportActiveLogAsADIF() -> [URL] {
        guard let logID = currentLogID,
              let log = logs.first(where: { $0.id == logID }) else { return [] }

        let parks = potaParksForSplit(log: log, qsos: currentQSOs)
        if parks.count >= 2 {
            return exportPotaSplitPerPark(log: log, qsos: currentQSOs, parks: parks)
        }
        return exportSingleADIF(log: log, qsos: currentQSOs)
    }

    /// Findet alle eigenen POTA-Parks im aktiven Log (Log-Setup + QSO-
    /// Refs, deduped, Reihenfolge erhalten). Liefert leeres Array für
    /// Nicht-POTA-Logs oder Single-Park.
    private func potaParksForSplit(log: Log, qsos: [QSO]) -> [String] {
        guard log.type == .pota else { return [] }
        var seen = Set<String>()
        var out: [String] = []
        func append(_ s: String?) {
            guard let s = s?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return }
            if seen.insert(s).inserted { out.append(s) }
        }
        append(log.potaParkRef)
        for part in (log.potaParkRefs ?? "").split(separator: ",") {
            append(String(part))
        }
        for q in qsos {
            append(q.myPotaRef)
            for part in (q.myPotaRefs ?? "").split(separator: ",") {
                append(String(part))
            }
        }
        return out
    }

    private func exportSingleADIF(log: Log, qsos: [QSO]) -> [URL] {
        let text = ADIFCodec.encode(qsos: qsos, logName: log.name)
        let stamp: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmmss"
            return f.string(from: Date())
        }()
        let safeName = log.name.replacingOccurrences(of: "/", with: "_")
        let fileName = "\(safeName)-\(stamp).adi"
        let url = dataRoot.exportsDir.appendingPathComponent(fileName)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return [url]
        } catch {
            print("ADIF Export fehlgeschlagen: \(error.localizedDescription)")
            return []
        }
    }

    /// POTA-Multi-Park-Split: pro Park ein eigenes File, die QSO-Kopie
    /// hat nur diesen einen Park in myPotaRef (Komma-Liste in myPotaRefs
    /// wird auf nil gesetzt). Filename folgt der pota.app-Konvention
    /// `{call}@{park} YYYYMMDD.adi`, damit das Upload-Tool den Park
    /// automatisch erkennt.
    private func exportPotaSplitPerPark(log: Log, qsos: [QSO], parks: [String]) -> [URL] {
        let call: String = {
            if let c = log.usedCallsign?.trimmingCharacters(in: .whitespaces),
               !c.isEmpty { return c.uppercased() }
            if let c = UserDefaults.standard.string(forKey: "callsign")?
                .trimmingCharacters(in: .whitespaces), !c.isEmpty {
                return c.uppercased()
            }
            return "UNKNOWN"
        }()
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        let dateString = df.string(from: log.startDate)
        var written: [URL] = []
        for park in parks {
            let parkQSOs: [QSO] = qsos.compactMap { q in
                let qsoParks = qsoPotaSet(q)
                let activatesThisPark = qsoParks.contains(park)
                    || (qsoParks.isEmpty && log.potaParkRef == park)
                guard activatesThisPark else { return nil }
                var copy = q
                copy.myPotaRef  = park
                copy.myPotaRefs = nil
                return copy
            }
            guard !parkQSOs.isEmpty else { continue }
            let safeCall = call.replacingOccurrences(of: "/", with: "_")
            let safePark = park.replacingOccurrences(of: "/", with: "_")
            let fileName = "\(safeCall)@\(safePark) \(dateString).adi"
            let url = dataRoot.exportsDir.appendingPathComponent(fileName)
            let text = ADIFCodec.encode(qsos: parkQSOs, logName: "\(log.name) — \(park)")
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                written.append(url)
            } catch {
                print("POTA-Split-Export fehlgeschlagen (\(park)): \(error.localizedDescription)")
            }
        }
        return written
    }

    private func qsoPotaSet(_ q: QSO) -> Set<String> {
        var s = Set<String>()
        if let p = q.myPotaRef?.trimmingCharacters(in: .whitespaces), !p.isEmpty {
            s.insert(p)
        }
        for part in (q.myPotaRefs ?? "").split(separator: ",") {
            let r = part.trimmingCharacters(in: .whitespaces)
            if !r.isEmpty { s.insert(r) }
        }
        return s
    }

    /// Programm-spezifischer Export für das aktive Log (POTA/WWFF/WWBOTA).
    /// Liefert die Liste der geschriebenen Files — POTA kann mehrere File
    /// erzeugen (eines pro Park). Gibt nil zurück, wenn das aktuelle Log
    /// keinen passenden Programm-Exporter hat (z.B. Standard/Contest).
    func exportActiveLogForProgram() -> [URL]? {
        guard let logID = currentLogID,
              let log = logs.first(where: { $0.id == logID }),
              let exporter = ProgramExporterFactory.exporter(for: log.type) else {
            return nil
        }
        do {
            return try exporter.export(qsos: currentQSOs,
                                       log: log,
                                       exportsDir: dataRoot.exportsDir)
        } catch {
            print("Programm-Export fehlgeschlagen: \(error.localizedDescription)")
            return nil
        }
    }

    /// Importiert eine ADIF-Datei und liefert die parsierten QSOs zurück
    /// (noch ohne sie zu schreiben — Caller entscheidet was er damit macht).
    func parseADIF(at url: URL, targetLogID: UUID) -> [QSO] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let records = ADIFCodec.parse(text)
        return records.compactMap { ADIFCodec.qso(from: $0, logID: targetLogID) }
    }

    /// Importiert eine Liste von QSOs ins angegebene Log. Wenn das Log
    /// gerade offen ist, geht das über die DB; sonst wird kurz geöffnet.
    /// Liefert die Anzahl tatsächlich geschriebener QSOs. Vor dem
    /// Import wird automatisch ein ADIF-Backup nach Backups/ geschrieben
    /// (falls das Ziel-Log nicht leer ist).
    func importQSOs(_ qsos: [QSO], into logID: UUID) -> Int {
        backupLogAsADIF(logID: logID, tag: "pre-import")

        var count = 0
        if logID == currentLogID, let db = openDB {
            for q in qsos {
                if (try? db.addQSO(q)) != nil { count += 1 }
            }
            currentQSOs = db.qsos
        } else if let url = fileURLs[logID],
                  let db = try? LogbookDatabase(opening: url) {
            for q in qsos {
                if (try? db.addQSO(q)) != nil { count += 1 }
            }
        }
        recomputeAwards()
        return count
    }

    /// Duplikat-Erkennung für Merge: zählt wie viele der QSOs schon im
    /// Ziel-Log existieren (gleicher Call, Band, Mode, Zeit ±5min).
    func detectDuplicates(_ qsos: [QSO], in logID: UUID) -> (new: [QSO], duplicates: [QSO]) {
        let existing: [QSO]
        if logID == currentLogID {
            existing = currentQSOs
        } else if let url = fileURLs[logID],
                  let db = try? LogbookDatabase(opening: url) {
            existing = db.qsos
        } else {
            existing = []
        }
        let tolerance: TimeInterval = 5 * 60
        var new: [QSO] = []
        var dupes: [QSO] = []
        for q in qsos {
            let dup = existing.contains { e in
                e.call == q.call
                    && e.band == q.band
                    && e.mode == q.mode
                    && abs(e.datetime.timeIntervalSince(q.datetime)) <= tolerance
            }
            if dup { dupes.append(q) } else { new.append(q) }
        }
        return (new, dupes)
    }

    // MARK: - Award-Aggregation

    /// Aggregiert über ALLE Logs:
    ///   - Counter (DXCC/WAZ/WAS) für die Tab-Bar
    ///   - Breakdown pro Country/Zone/State für den Awards-Tab
    /// Wird nach jeder QSO/Log-Mutation aufgerufen.
    func recomputeAwards() {
        // Akkumulatoren pro Entity
        var byCountry: [String: DXCCAccumulator] = [:]
        var byZone:    [Int: WAZAccumulator]    = [:]
        var byState:   [String: WASAccumulator] = [:]
        var totalQSOs = 0
        var potaActivatorQSOs = 0
        var potaHunterQSOs = 0
        var potaP2P = 0
        var potaActivatorParks: Set<String> = []
        var potaHunterParks:    Set<String> = []
        var sotaActivatorQSOs = 0
        var sotaChaserQSOs    = 0
        var sotaS2S           = 0
        var sotaChaserPoints  = 0
        var sotaActivatorSummits: Set<String> = []
        var sotaChaserSummits:    Set<String> = []
        // Für Activator-Punkte: pro (Summit, UTC-Tag) zählen. Ab 4 QSOs zählt
        // die Aktivierung — Base-Punkte + ggf. Winterbonus (Summit-Lookup
        // gegen sotaSummits-DB nach dem Loop).
        var sotaActivatorQSOsBySummitDay: [SummitDayKey: Int] = [:]
        var wwffActivatorQSOs = 0
        var wwffHunterQSOs    = 0
        var wwffR2R           = 0
        var wwffActivatorRefs: Set<String> = []
        var wwffHunterRefs:    Set<String> = []
        var wwffPrograms:      Set<String> = []  // "DLFF", "HBFF", "KFF", …
        var botaActivatorQSOs = 0
        var botaHunterQSOs    = 0
        var botaB2B           = 0
        var botaActivatorRefs: Set<String> = []
        var botaHunterRefs:    Set<String> = []
        var botaPrograms:      Set<String> = []

        for log in logs {
            let qsos: [QSO]
            if log.id == currentLogID {
                qsos = currentQSOs
            } else if let url = fileURLs[log.id],
                      let db = try? LogbookDatabase(opening: url) {
                qsos = db.qsos
            } else {
                continue
            }
            totalQSOs += qsos.count
            for qso in qsos {
                let confirmed = qso.lotwConfirmed || qso.eqslConfirmed
                let dt = qso.datetime

                // POTA-Counts
                let myParks = potaRefSet(qso.myPotaRef, qso.myPotaRefs)
                let theirParks = potaRefSet(qso.theirPotaRef, nil)
                if !myParks.isEmpty {
                    potaActivatorQSOs += 1
                    potaActivatorParks.formUnion(myParks)
                }
                if !theirParks.isEmpty {
                    potaHunterQSOs += 1
                    potaHunterParks.formUnion(theirParks)
                }
                if !myParks.isEmpty && !theirParks.isEmpty {
                    potaP2P += 1
                }

                // SOTA-Counts — gleiche Logik wie POTA, plus Chaser-Punkte.
                let mySummits    = potaRefSet(qso.mySotaRef, qso.mySotaRefs)
                let theirSummits = potaRefSet(qso.theirSotaRef, nil)
                if !mySummits.isEmpty {
                    sotaActivatorQSOs += 1
                    sotaActivatorSummits.formUnion(mySummits)
                    // Pro Hopping-Summit eigene 4-QSO-Aktivierungs-Zählung.
                    // Tag bezieht sich auf UTC, damit Aktivierungen, die um
                    // Mitternacht stattfinden, korrekt einem Datum zugeordnet
                    // werden (SOTA-Regel = UTC).
                    let dayKey = Self.utcDayString(qso.datetime)
                    for ref in mySummits {
                        let key = SummitDayKey(summit: ref, day: dayKey)
                        sotaActivatorQSOsBySummitDay[key, default: 0] += 1
                    }
                }
                if !theirSummits.isEmpty {
                    sotaChaserQSOs += 1
                    sotaChaserSummits.formUnion(theirSummits)
                }
                if !mySummits.isEmpty && !theirSummits.isEmpty {
                    sotaS2S += 1
                }
                if let pts = qso.theirSotaPoints, pts > 0 {
                    sotaChaserPoints += pts
                }

                // WWFF-Counts — gleiche Logik wie POTA/SOTA. Programme aus
                // Ref-Prefix abgeleitet (DLFF-0001 → "DLFF").
                let myWwffSet    = potaRefSet(qso.myWwffRef, qso.myWwffRefs)
                let theirWwffSet = potaRefSet(qso.theirWwffRef, nil)
                if !myWwffSet.isEmpty {
                    wwffActivatorQSOs += 1
                    wwffActivatorRefs.formUnion(myWwffSet)
                    for ref in myWwffSet {
                        if let dash = ref.firstIndex(of: "-") {
                            wwffPrograms.insert(String(ref[..<dash]))
                        }
                    }
                }
                if !theirWwffSet.isEmpty {
                    wwffHunterQSOs += 1
                    wwffHunterRefs.formUnion(theirWwffSet)
                    for ref in theirWwffSet {
                        if let dash = ref.firstIndex(of: "-") {
                            wwffPrograms.insert(String(ref[..<dash]))
                        }
                    }
                }
                if !myWwffSet.isEmpty && !theirWwffSet.isEmpty {
                    wwffR2R += 1
                }

                // BOTA-Counts — gleiche Logik wie WWFF, aber Programm-Code
                // via BOTAReference.programFromRef (strippt den WWBOTA-
                // `B/`-Präfix bevor der Programm-Code extrahiert wird).
                let myBotaSet    = potaRefSet(qso.myBotaRef, qso.myBotaRefs)
                let theirBotaSet = potaRefSet(qso.theirBotaRef, nil)
                if !myBotaSet.isEmpty {
                    botaActivatorQSOs += 1
                    botaActivatorRefs.formUnion(myBotaSet)
                    for ref in myBotaSet {
                        botaPrograms.insert(BOTAReference.programFromRef(ref))
                    }
                }
                if !theirBotaSet.isEmpty {
                    botaHunterQSOs += 1
                    botaHunterRefs.formUnion(theirBotaSet)
                    for ref in theirBotaSet {
                        botaPrograms.insert(BOTAReference.programFromRef(ref))
                    }
                }
                if !myBotaSet.isEmpty && !theirBotaSet.isEmpty {
                    botaB2B += 1
                }

                if let c = qso.country?.trimmingCharacters(in: .whitespaces),
                   !c.isEmpty {
                    byCountry[c, default: DXCCAccumulator(country: c)]
                        .add(band: qso.band, mode: qso.mode,
                             confirmed: confirmed, date: dt)
                }
                if let z = qso.cqZone, z > 0 {
                    byZone[z, default: WAZAccumulator(zone: z)]
                        .add(confirmed: confirmed, date: dt)
                }
                if let s = qso.country?.trimmingCharacters(in: .whitespaces),
                   s.localizedCaseInsensitiveContains("United States") || s == "USA",
                   let st = qso.qth?.trimmingCharacters(in: .whitespaces),
                   !st.isEmpty {
                    // US-State pragmatisch aus QTH-Feld (kein dediziertes
                    // state-Feld bis ADIF-Import in Phase 2 existiert).
                    byState[st, default: WASAccumulator(state: st)]
                        .add(confirmed: confirmed, date: dt)
                }
            }
        }

        // In Entries umwandeln + sortieren
        dxccBreakdown = byCountry.values
            .map { $0.entry }
            .sorted { $0.qsoCount > $1.qsoCount }
        wazBreakdown = byZone.values
            .map { $0.entry }
            .sorted { $0.zone < $1.zone }
        wasBreakdown = byState.values
            .map { $0.entry }
            .sorted { $0.state < $1.state }

        // ATNO-Sets aus byCountry ableiten. Country/Band/Mode uppercased,
        // damit der Live-Lookup im DXClusterViewModel robust ist gegen
        // gemischte Schreibvarianten aus den verschiedenen Quellen.
        var wCountries = Set<String>()
        var wCB = Set<String>()
        var wCM = Set<String>()
        for (country, acc) in byCountry {
            let cKey = country.uppercased()
            wCountries.insert(cKey)
            for b in acc.bands { wCB.insert("\(cKey)|\(b.uppercased())") }
            for m in acc.modes { wCM.insert("\(cKey)|\(m.uppercased())") }
        }
        workedCountries   = wCountries
        workedCountryBand = wCB
        workedCountryMode = wCM

        let confirmedCountries = dxccBreakdown.filter(\.confirmed).count
        let confirmedZones     = wazBreakdown.filter(\.confirmed).count
        let confirmedStates    = wasBreakdown.filter(\.confirmed).count

        // SOTA-Activator-Punkte: nur gültige Aktivierungen (≥4 QSOs auf
        // demselben Summit am selben UTC-Tag) zählen. Base-Punkte aus
        // Summit-DB, Winterbonus über SOTAPointsCalculator (Halbkugel-aware).
        // Fehlt der Service oder ist der Summit nicht in der DB, fällt der
        // Eintrag aus der Zählung — kein Crash, kein Half-Match.
        var sotaActivatorPoints = 0
        if let sotaDB = sotaSummits?.db {
            for (key, count) in sotaActivatorQSOsBySummitDay where count >= 4 {
                guard let summit = sotaDB.summit(reference: key.summit) else { continue }
                let activationDate = Self.parseUTCDay(key.day) ?? Date()
                let p = SOTAPointsCalculator.activatorPoints(for: summit,
                                                              on: activationDate)
                sotaActivatorPoints += p.base + p.bonus
            }
        }

        awards = AwardCounts(
            dxccWorked:    dxccBreakdown.count,
            dxccConfirmed: confirmedCountries,
            wazWorked:     wazBreakdown.count,
            wazConfirmed:  confirmedZones,
            wasWorked:     wasBreakdown.count,
            wasConfirmed:  confirmedStates,
            totalQSOs:     totalQSOs,
            potaActivatorQSOs:  potaActivatorQSOs,
            potaActivatorParks: potaActivatorParks.count,
            potaHunterQSOs:     potaHunterQSOs,
            potaHunterParks:    potaHunterParks.count,
            potaP2P:            potaP2P,
            sotaActivatorQSOs:    sotaActivatorQSOs,
            sotaActivatorSummits: sotaActivatorSummits.count,
            sotaActivatorPoints:  sotaActivatorPoints,
            sotaChaserQSOs:       sotaChaserQSOs,
            sotaChaserSummits:    sotaChaserSummits.count,
            sotaS2S:              sotaS2S,
            sotaChaserPoints:     sotaChaserPoints,
            wwffActivatorQSOs:    wwffActivatorQSOs,
            wwffActivatorRefs:    wwffActivatorRefs.count,
            wwffHunterQSOs:       wwffHunterQSOs,
            wwffHunterRefs:       wwffHunterRefs.count,
            wwffR2R:              wwffR2R,
            wwffPrograms:         wwffPrograms.count,
            botaActivatorQSOs:    botaActivatorQSOs,
            botaActivatorRefs:    botaActivatorRefs.count,
            botaHunterQSOs:       botaHunterQSOs,
            botaHunterRefs:       botaHunterRefs.count,
            botaB2B:              botaB2B,
            botaPrograms:         botaPrograms.count
        )
    }

    /// Live-ATNO-Lookup für einen Cluster-Spot. Reihenfolge der Checks
    /// gibt die Priorität vor: ATNO > NEW BAND > NEW MODE > worked.
    /// Leere country → .worked (kein Highlight ohne Information).
    func atnoStatus(country: String, band: String, mode: String) -> ATNOStatus {
        let c = country.trimmingCharacters(in: .whitespaces).uppercased()
        guard !c.isEmpty else { return .worked }
        if !workedCountries.contains(c) { return .atno }
        let b = band.uppercased()
        if !b.isEmpty && !workedCountryBand.contains("\(c)|\(b)") { return .newBand }
        let m = mode.uppercased()
        if !m.isEmpty && !workedCountryMode.contains("\(c)|\(m)") { return .newMode }
        return .worked
    }

    /// Parst myPotaRef + myPotaRefs (oder theirPotaRef alleine) in eine
    /// Set eindeutiger Park-Refs. Komma-Listen werden gesplittet.
    private func potaRefSet(_ single: String?, _ multi: String?) -> Set<String> {
        var out: Set<String> = []
        if let s = single?.trimmingCharacters(in: .whitespaces), !s.isEmpty {
            for r in s.split(separator: ",") {
                let u = r.trimmingCharacters(in: .whitespaces).uppercased()
                if !u.isEmpty { out.insert(u) }
            }
        }
        if let m = multi?.trimmingCharacters(in: .whitespaces), !m.isEmpty {
            for r in m.split(separator: ",") {
                let u = r.trimmingCharacters(in: .whitespaces).uppercased()
                if !u.isEmpty { out.insert(u) }
            }
        }
        return out
    }

    // MARK: - Cross-Log-Suche

    /// Sucht alle QSOs zu einem Call über ALLE bekannten Logs.
    /// Aktives Log nutzt den in-memory Cache, andere werden lazy geöffnet.
    func findQSOs(forCall call: String) -> [QSOMatch] {
        let upper = call.uppercased().trimmingCharacters(in: .whitespaces)
        guard !upper.isEmpty else { return [] }

        var results: [QSOMatch] = []
        for log in logs {
            let matches: [QSO]
            if log.id == currentLogID, let db = openDB {
                matches = db.findQSOs(matching: upper)
            } else if let url = fileURLs[log.id],
                      let db = try? LogbookDatabase(opening: url) {
                matches = db.findQSOs(matching: upper)
            } else {
                continue
            }
            for qso in matches {
                results.append(QSOMatch(qso: qso, logName: log.name, logID: log.id))
            }
        }
        return results.sorted { $0.qso.datetime > $1.qso.datetime }
    }

    // MARK: - Scan / Reload

    /// Lädt alle Logs aus der `knownLogPaths`-Liste plus auto-discovery
    /// der .htlog-Dateien im aktuellen Default-Ordner (z.B. wenn der User
    /// dort eine Datei manuell hinkopiert hat).
    func reloadAll() {
        var foundLogs: [Log] = []
        var newURLMap: [UUID: URL] = [:]

        // 1) Aus dem Default-Ordner alles aufsammeln → in knownLogPaths übernehmen
        let dir = settings.logbookDirectory
        if let items = try? FileManager.default
                .contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for url in items where url.pathExtension == LogbookDatabase.fileExtension {
                if !settings.knownLogPaths.contains(url) {
                    settings.addKnownLog(url)
                }
            }
        }

        // 2) Alle bekannten URLs öffnen (Default + extra Pfade)
        var validPaths: [URL] = []
        for url in settings.knownLogPaths {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            if let db = try? LogbookDatabase(opening: url) {
                foundLogs.append(db.log)
                newURLMap[db.log.id] = url
                validPaths.append(url)
            }
        }
        // Aufräumen: Pfade die nicht mehr existieren oder kaputt sind, raus.
        if validPaths.count != settings.knownLogPaths.count {
            settings.knownLogPaths = validPaths
        }

        self.logs = foundLogs.sorted { $0.createdAt > $1.createdAt }
        self.fileURLs = newURLMap
    }

    private func ensureLebensLog() {
        guard logs.isEmpty else { return }
        createLog(Log(
            name: "Lebens-Log",
            type: .standard,
            notes: "Allgemeines Log — automatisch beim ersten Start angelegt."
        ))
    }

    // MARK: - Dateinamen

    private func uniqueFileURL(for log: Log, in directory: URL) -> URL {
        let base = slug(log.name)
        var url = directory
            .appendingPathComponent("\(base).\(LogbookDatabase.fileExtension)")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = directory
                .appendingPathComponent("\(base) (\(n)).\(LogbookDatabase.fileExtension)")
            n += 1
        }
        return url
    }

    private func slug(_ s: String) -> String {
        let allowed: Set<Character> = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _-äöüÄÖÜß()")
        let cleaned = s.map { allowed.contains($0) ? $0 : "_" }
        var result = String(cleaned).trimmingCharacters(in: .whitespaces)
        if result.isEmpty { result = "Logbuch" }
        return result
    }

    // MARK: - SOTA-Helpers (Activator-Punkte)

    fileprivate struct SummitDayKey: Hashable {
        let summit: String   // SOTA-Ref, z.B. "HB/BE-001"
        let day: String      // UTC-Tag im Format "yyyyMMdd"
    }

    fileprivate static func utcDayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    fileprivate static func parseUTCDay(_ s: String) -> Date? {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd"
        return f.date(from: s)
    }
}

// Treffer aus der Cross-Log-Suche: QSO + Log-Name (woher).
struct QSOMatch: Identifiable {
    var id: UUID { qso.id }
    let qso: QSO
    let logName: String
    let logID: UUID
}

// Live-Award-Zähler aus allen Logs. "Worked" = mindestens 1 QSO mit dieser
// Entity, "Confirmed" = mindestens 1 QSO mit dieser Entity bestätigt (LoTW
// oder eQSL). Wird nach jeder QSO-Mutation neu berechnet.
struct AwardCounts {
    var dxccWorked: Int    = 0
    var dxccConfirmed: Int = 0
    var wazWorked: Int     = 0
    var wazConfirmed: Int  = 0
    var wasWorked: Int     = 0
    var wasConfirmed: Int  = 0
    var totalQSOs: Int     = 0

    // POTA — lokal aggregiert über alle Logs. Wird mit den pota.app-Werten
    // verglichen, um Upload-Lücken sichtbar zu machen.
    var potaActivatorQSOs:  Int = 0    // QSOs mit myPotaRef gesetzt
    var potaActivatorParks: Int = 0    // eindeutige Park-Refs (auch aus myPotaRefs)
    var potaHunterQSOs:     Int = 0    // QSOs mit theirPotaRef gesetzt
    var potaHunterParks:    Int = 0    // eindeutige fremde Park-Refs
    var potaP2P:            Int = 0    // QSOs mit beiden Feldern gesetzt

    // SOTA — lokal aggregiert. Aktivierungs-Punkte (Base + Bonus) werden
    // pro (Summit, Tag) gezählt — pragmatisch, weil mehrtägige Aktivierungen
    // pro Tag einen neuen Aktivierungs-Eintrag bekommen. Chaser-Punkte
    // direkt aus theirSotaPoints summiert (1× pro QSO).
    var sotaActivatorQSOs:    Int = 0
    var sotaActivatorSummits: Int = 0
    var sotaActivatorPoints:  Int = 0  // Σ Base+Winterbonus aller gültigen Aktivierungen (≥4 QSOs / Summit-Tag)
    var sotaChaserQSOs:       Int = 0
    var sotaChaserSummits:    Int = 0
    var sotaS2S:              Int = 0  // QSOs mit mySotaRef + theirSotaRef
    var sotaChaserPoints:     Int = 0  // Σ theirSotaPoints

    // WWFF — lokal aggregiert. Honor-Roll-System: jede unique Ref = 1 Punkt,
    // sowohl für Activator als auch Hunter. R2R (Reference-to-Reference) ist
    // analog POTA-P2P / SOTA-S2S.
    var wwffActivatorQSOs:   Int = 0
    var wwffActivatorRefs:   Int = 0   // eindeutige Refs aus myWwffRef + myWwffRefs
    var wwffHunterQSOs:      Int = 0
    var wwffHunterRefs:      Int = 0   // eindeutige theirWwffRef
    var wwffR2R:             Int = 0
    var wwffPrograms:        Int = 0   // einzigartige Country-Programme (DLFF, HBFF, …)

    // BOTA — analog WWFF, ohne strikte Aktivierungsregel.
    var botaActivatorQSOs:   Int = 0
    var botaActivatorRefs:   Int = 0
    var botaHunterQSOs:      Int = 0
    var botaHunterRefs:      Int = 0
    var botaB2B:             Int = 0   // Bunker-to-Bunker
    var botaPrograms:        Int = 0
}

// Detail-Eintrag pro DXCC-Country (für die Awards-Tab-Liste).
struct DXCCAwardEntry: Identifiable {
    var id: String { country }
    let country: String
    let qsoCount: Int
    let bands: [String]
    let modes: [String]
    let confirmed: Bool
    let firstQSO: Date
    let lastQSO: Date
}

struct WAZEntry: Identifiable {
    var id: Int { zone }
    let zone: Int
    let qsoCount: Int
    let confirmed: Bool
    let firstQSO: Date
}

struct WASEntry: Identifiable {
    var id: String { state }
    let state: String
    let qsoCount: Int
    let confirmed: Bool
}

// Akku-Helper — sammelt QSO-Infos pro Entity, baut am Ende den Entry.
struct DXCCAccumulator {
    let country: String
    var count: Int = 0
    var bands: Set<String> = []
    var modes: Set<String> = []
    var confirmed: Bool = false
    var first: Date = .distantFuture
    var last: Date = .distantPast

    mutating func add(band: String, mode: String, confirmed: Bool, date: Date) {
        count += 1
        if !band.isEmpty { bands.insert(band) }
        if !mode.isEmpty { modes.insert(mode) }
        self.confirmed = self.confirmed || confirmed
        if date < first { first = date }
        if date > last  { last = date }
    }

    var entry: DXCCAwardEntry {
        DXCCAwardEntry(country: country, qsoCount: count,
                  bands: Array(bands).sorted(),
                  modes: Array(modes).sorted(),
                  confirmed: confirmed,
                  firstQSO: first, lastQSO: last)
    }
}

struct WAZAccumulator {
    let zone: Int
    var count: Int = 0
    var confirmed: Bool = false
    var first: Date = .distantFuture

    mutating func add(confirmed: Bool, date: Date) {
        count += 1
        self.confirmed = self.confirmed || confirmed
        if date < first { first = date }
    }

    var entry: WAZEntry {
        WAZEntry(zone: zone, qsoCount: count, confirmed: confirmed, firstQSO: first)
    }
}

struct WASAccumulator {
    let state: String
    var count: Int = 0
    var confirmed: Bool = false

    mutating func add(confirmed: Bool, date: Date) {
        count += 1
        self.confirmed = self.confirmed || confirmed
    }

    var entry: WASEntry {
        WASEntry(state: state, qsoCount: count, confirmed: confirmed)
    }
}
