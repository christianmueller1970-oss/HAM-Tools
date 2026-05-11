import Foundation
import Combine

// Zentraler Datenordner für die ganze App. Default: ~/Documents/HAM-Tools/.
// Enthält Sub-Ordner für Logs, Cache, Exports, Backups, Audio.
// Pfad ist konfigurierbar (UserDefaults). Bei Pfad-Wechsel werden die
// Sub-Ordner im neuen Root automatisch angelegt; Daten werden nicht
// automatisch mitkopiert — der User muss entscheiden.
@MainActor
final class AppDataRoot: ObservableObject {
    private let rootKey = "app.dataRoot.path"

    @Published var rootURL: URL {
        didSet {
            UserDefaults.standard.set(rootURL.path, forKey: rootKey)
            ensureStructure()
        }
    }

    static var defaultRoot: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("HAM-Tools", isDirectory: true)
    }

    // Legacy-Pfad — relevant für die einmalige Auto-Migration.
    static var legacyAppSupportRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("HAMRechner", isDirectory: true)
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: rootKey)
        let url = stored.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? Self.defaultRoot
        self.rootURL = url
        ensureStructure()
        migrateFromLegacyIfNeeded()
    }

    // MARK: - Sub-Ordner

    var logsDir: URL    { rootURL.appendingPathComponent("Logs",    isDirectory: true) }
    var cacheDir: URL   { rootURL.appendingPathComponent("Cache",   isDirectory: true) }
    var exportsDir: URL { rootURL.appendingPathComponent("Exports", isDirectory: true) }
    var backupsDir: URL { rootURL.appendingPathComponent("Backups", isDirectory: true) }
    var audioDir: URL   { rootURL.appendingPathComponent("Audio",   isDirectory: true) }

    private func ensureStructure() {
        for url in [rootURL, logsDir, cacheDir, exportsDir, backupsDir, audioDir] {
            try? FileManager.default.createDirectory(
                at: url, withIntermediateDirectories: true)
        }
    }

    // MARK: - Migration

    /// Beim allerersten Start mit dem neuen System: prüft den alten
    /// Speicherort (~/Library/Application Support/HAMRechner) und
    /// verschiebt vorhandene Logbücher + Cache-Files ins neue Root.
    /// Macht nichts wenn der neue Root schon Daten hat oder kein altes
    /// Verzeichnis existiert.
    private func migrateFromLegacyIfNeeded() {
        let fm = FileManager.default
        let legacy = Self.legacyAppSupportRoot
        let legacyLogs = legacy.appendingPathComponent("Logs", isDirectory: true)
        let legacySpots = legacy.appendingPathComponent("spots.json")

        // Schon migriert? Marker im UserDefaults.
        let migratedKey = "app.dataRoot.migratedFromLegacy"
        if UserDefaults.standard.bool(forKey: migratedKey) { return }

        var migratedAny = false

        // Logs verschieben
        if fm.fileExists(atPath: legacyLogs.path),
           let items = try? fm.contentsOfDirectory(at: legacyLogs,
                                                   includingPropertiesForKeys: nil) {
            for item in items {
                let dst = logsDir.appendingPathComponent(item.lastPathComponent)
                if fm.fileExists(atPath: dst.path) { continue }
                do {
                    try fm.moveItem(at: item, to: dst)
                    migratedAny = true
                } catch {
                    print("Migration log file failed for \(item.lastPathComponent): \(error)")
                }
            }
            // Leeren Logs/-Ordner mitnehmen
            if let leftover = try? fm.contentsOfDirectory(at: legacyLogs,
                                                          includingPropertiesForKeys: nil),
               leftover.isEmpty {
                try? fm.removeItem(at: legacyLogs)
            }
        }

        // Cache (spots.json) ins Cache-Subdir verschieben
        if fm.fileExists(atPath: legacySpots.path) {
            let dst = cacheDir.appendingPathComponent("spots.json")
            if !fm.fileExists(atPath: dst.path) {
                try? fm.moveItem(at: legacySpots, to: dst)
                migratedAny = true
            }
        }

        // Auch in der knownPaths-Liste der LogbookSettings die alten Pfade
        // auf neue umbiegen — sonst zeigen sie auf nicht-existente Dateien.
        let knownPathsKey = "logbook.knownPaths"
        if let oldPaths = UserDefaults.standard.stringArray(forKey: knownPathsKey) {
            let newPaths = oldPaths.map { path -> String in
                let url = URL(fileURLWithPath: path)
                if url.deletingLastPathComponent().standardized == legacyLogs.standardized {
                    return logsDir.appendingPathComponent(url.lastPathComponent).path
                }
                return path
            }
            UserDefaults.standard.set(newPaths, forKey: knownPathsKey)
        }

        UserDefaults.standard.set(true, forKey: migratedKey)
        if migratedAny {
            print("HAM-Tools: Migration vom Legacy-Speicherort (~/Library/Application Support/HAMRechner) ins neue Root abgeschlossen.")
        }
    }
}
