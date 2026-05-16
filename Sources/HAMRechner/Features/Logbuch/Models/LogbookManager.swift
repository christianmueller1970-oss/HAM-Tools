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

    /// Schreibt das aktive Log als ADIF in den Exports-Ordner.
    /// Liefert die geschriebene URL bei Erfolg, sonst nil.
    func exportActiveLogAsADIF() -> URL? {
        guard let logID = currentLogID,
              let log = logs.first(where: { $0.id == logID }) else { return nil }
        let text = ADIFCodec.encode(qsos: currentQSOs, logName: log.name)
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
            return url
        } catch {
            print("ADIF Export fehlgeschlagen: \(error.localizedDescription)")
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

                // BOTA-Counts — gleiche Logik wie WWFF.
                let myBotaSet    = potaRefSet(qso.myBotaRef, qso.myBotaRefs)
                let theirBotaSet = potaRefSet(qso.theirBotaRef, nil)
                if !myBotaSet.isEmpty {
                    botaActivatorQSOs += 1
                    botaActivatorRefs.formUnion(myBotaSet)
                    for ref in myBotaSet {
                        if let dash = ref.firstIndex(of: "-") {
                            botaPrograms.insert(String(ref[..<dash]))
                        }
                    }
                }
                if !theirBotaSet.isEmpty {
                    botaHunterQSOs += 1
                    botaHunterRefs.formUnion(theirBotaSet)
                    for ref in theirBotaSet {
                        if let dash = ref.firstIndex(of: "-") {
                            botaPrograms.insert(String(ref[..<dash]))
                        }
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

        let confirmedCountries = dxccBreakdown.filter(\.confirmed).count
        let confirmedZones     = wazBreakdown.filter(\.confirmed).count
        let confirmedStates    = wasBreakdown.filter(\.confirmed).count

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
