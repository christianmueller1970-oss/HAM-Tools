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

    private let settings: LogbookSettings
    private var openDB: LogbookDatabase?
    private var directoryObserver: AnyCancellable?

    init(settings: LogbookSettings) {
        self.settings = settings
        reloadAll()
        ensureLebensLog()

        directoryObserver = settings.$logbookDirectory
            .dropFirst()
            .sink { [weak self] _ in
                self?.reloadAll()
            }
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
        } catch {
            print("openLog failed: \(error.localizedDescription)")
        }
    }

    func closeLog() {
        openDB = nil
        currentLogID = nil
        currentQSOs = []
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
        } catch {
            print("createLog failed: \(error.localizedDescription)")
        }
    }

    func deleteLog(_ log: Log) {
        guard let url = fileURLs[log.id] else { return }
        if currentLogID == log.id {
            openDB = nil
            currentLogID = nil
            currentQSOs = []
        }
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
        try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
        settings.removeKnownLog(url)
        fileURLs[log.id] = nil
        logs.removeAll { $0.id == log.id }
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

    func addQSO(_ qso: QSO) {
        guard let db = openDB else { return }
        do { try db.addQSO(qso); currentQSOs = db.qsos }
        catch { print("addQSO failed: \(error.localizedDescription)") }
    }

    func updateQSO(_ qso: QSO) {
        guard let db = openDB else { return }
        do { try db.updateQSO(qso); currentQSOs = db.qsos }
        catch { print("updateQSO failed: \(error.localizedDescription)") }
    }

    func deleteQSO(_ qso: QSO) {
        guard let db = openDB else { return }
        do { try db.deleteQSO(qso); currentQSOs = db.qsos }
        catch { print("deleteQSO failed: \(error.localizedDescription)") }
    }

    func qsoCount(for log: Log) -> Int {
        if log.id == currentLogID { return currentQSOs.count }
        guard let url = fileURLs[log.id] else { return 0 }
        return (try? LogbookDatabase(opening: url).qsoCount) ?? 0
    }

    func fileURL(for log: Log) -> URL? {
        fileURLs[log.id]
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
