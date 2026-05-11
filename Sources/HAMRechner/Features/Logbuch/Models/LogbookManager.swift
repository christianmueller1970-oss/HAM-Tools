import Foundation
import Combine

// Verwaltet ALLE Logbücher in einem Verzeichnis. Eine .htlog-Datei =
// ein Logbuch (SQLite). Beim Auswählen wird das Logbuch geöffnet,
// QSOs in den Memory-Cache gezogen. CRUD geht durch den Manager.
@MainActor
final class LogbookManager: ObservableObject {
    // Liste aller gefundenen Logbücher im aktuellen Verzeichnis.
    @Published private(set) var logs: [Log] = []
    // Aktuell geöffnetes Logbuch (für die UI-Bindings).
    @Published private(set) var currentLogID: UUID?
    @Published private(set) var currentQSOs: [QSO] = []

    private let settings: LogbookSettings
    private var openDB: LogbookDatabase?
    private var directoryObserver: AnyCancellable?

    init(settings: LogbookSettings) {
        self.settings = settings
        rescanDirectory()
        ensureLebensLog()

        // Bei Pfad-Wechsel: Verzeichnis neu scannen.
        directoryObserver = settings.$logbookDirectory
            .dropFirst()
            .sink { [weak self] _ in
                self?.handleDirectoryChange()
            }
    }

    // MARK: - Public API: Logs

    func openLog(_ log: Log) {
        if currentLogID == log.id, openDB != nil { return }
        do {
            let url = fileURL(for: log)
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

    func createLog(_ log: Log) {
        do {
            let url = uniqueFileURL(for: log)
            let db = try LogbookDatabase(creating: url, log: log)
            self.openDB = db
            self.logs.insert(db.log, at: 0)
            self.currentLogID = db.log.id
            self.currentQSOs = []
        } catch {
            print("createLog failed: \(error.localizedDescription)")
        }
    }

    func deleteLog(_ log: Log) {
        let url = fileURL(for: log)
        if currentLogID == log.id {
            openDB = nil
            currentLogID = nil
            currentQSOs = []
        }
        try? FileManager.default.removeItem(at: url)
        // WAL/Shared-Memory-Sidecars
        try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
        try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
        logs.removeAll { $0.id == log.id }
    }

    // MARK: - Public API: QSOs

    func addQSO(_ qso: QSO) {
        guard let db = openDB else { return }
        do {
            try db.addQSO(qso)
            currentQSOs = db.qsos
        } catch {
            print("addQSO failed: \(error.localizedDescription)")
        }
    }

    func updateQSO(_ qso: QSO) {
        guard let db = openDB else { return }
        do {
            try db.updateQSO(qso)
            currentQSOs = db.qsos
        } catch {
            print("updateQSO failed: \(error.localizedDescription)")
        }
    }

    func deleteQSO(_ qso: QSO) {
        guard let db = openDB else { return }
        do {
            try db.deleteQSO(qso)
            currentQSOs = db.qsos
        } catch {
            print("deleteQSO failed: \(error.localizedDescription)")
        }
    }

    func qsoCount(for log: Log) -> Int {
        // Nur für aktuell geladenes Log genau, sonst aus DB lesen.
        if log.id == currentLogID { return currentQSOs.count }
        // Schnelle Variante: Datei kurz öffnen, count auslesen.
        let url = fileURL(for: log)
        return (try? LogbookDatabase(opening: url).qsoCount) ?? 0
    }

    // MARK: - Verzeichnis-Scan

    private func handleDirectoryChange() {
        closeLog()
        rescanDirectory()
        // Lebens-Log nicht erzwingen — der User wechselt vielleicht
        // bewusst in ein Verzeichnis mit eigenen Logs.
    }

    private func rescanDirectory() {
        let dir = settings.logbookDirectory
        let ext = LogbookDatabase.fileExtension
        guard let items = try? FileManager.default
                .contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            self.logs = []
            return
        }
        let dbFiles = items.filter { $0.pathExtension == ext }
        var found: [Log] = []
        for url in dbFiles {
            if let db = try? LogbookDatabase(opening: url) {
                found.append(db.log)
            }
        }
        self.logs = found.sorted { $0.createdAt > $1.createdAt }
    }

    private func ensureLebensLog() {
        guard logs.isEmpty else { return }
        let lebensLog = Log(
            name: "Lebens-Log",
            type: .standard,
            notes: "Allgemeines Log — automatisch beim ersten Start angelegt."
        )
        createLog(lebensLog)
    }

    // MARK: - Dateinamen

    private func fileURL(for log: Log) -> URL {
        settings.logbookDirectory
            .appendingPathComponent("\(slug(log.name)).\(LogbookDatabase.fileExtension)")
    }

    private func uniqueFileURL(for log: Log) -> URL {
        let base = slug(log.name)
        var url = settings.logbookDirectory
            .appendingPathComponent("\(base).\(LogbookDatabase.fileExtension)")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = settings.logbookDirectory
                .appendingPathComponent("\(base) (\(n)).\(LogbookDatabase.fileExtension)")
            n += 1
        }
        return url
    }

    // Macht aus "Field Day 2026 / 24h" einen Datei-Namen.
    private func slug(_ s: String) -> String {
        let allowed: Set<Character> = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _-äöüÄÖÜß()")
        let cleaned = s.map { allowed.contains($0) ? $0 : "_" }
        var result = String(cleaned).trimmingCharacters(in: .whitespaces)
        if result.isEmpty { result = "Logbuch" }
        return result
    }
}
