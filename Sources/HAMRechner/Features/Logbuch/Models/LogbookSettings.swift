import Foundation
import Combine

// Globale Logbuch-Einstellungen — vor allem der Ordner in dem die
// .htlog-Dateien liegen. Persistiert in UserDefaults als Bookmark
// (sandboxing-tauglich, behält Zugriffsrechte auch über App-Neustarts).
final class LogbookSettings: ObservableObject {
    private let directoryKey = "logbook.directory.path"
    private let knownPathsKey = "logbook.knownPaths"

    // Standard-Ordner für neue Logbücher (wird in der "Neues Log"-Maske
    // als Default vorgeschlagen, kann pro Log überschrieben werden).
    @Published var logbookDirectory: URL {
        didSet {
            UserDefaults.standard.set(logbookDirectory.path, forKey: directoryKey)
            ensureExists(logbookDirectory)
        }
    }

    // Liste aller Logbuch-Dateien die der Manager kennt — egal wo sie liegen.
    // So funktioniert auch ein Logbuch in iCloud Drive, auf einer externen
    // Platte, oder in den Documents.
    @Published var knownLogPaths: [URL] {
        didSet {
            let strings = knownLogPaths.map(\.path)
            UserDefaults.standard.set(strings, forKey: knownPathsKey)
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: directoryKey)
        let url = stored.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? Self.defaultDirectory
        self.logbookDirectory = url

        let storedPaths = (UserDefaults.standard.stringArray(forKey: knownPathsKey) ?? [])
            .map { URL(fileURLWithPath: $0) }
        self.knownLogPaths = storedPaths

        ensureExists(url)
    }

    static var defaultDirectory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base
            .appendingPathComponent("HAMRechner", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
    }

    // MARK: - Known paths API

    func addKnownLog(_ url: URL) {
        guard !knownLogPaths.contains(url) else { return }
        knownLogPaths.append(url)
    }

    func removeKnownLog(_ url: URL) {
        knownLogPaths.removeAll { $0 == url }
    }

    private func ensureExists(_ url: URL) {
        try? FileManager.default.createDirectory(at: url,
                                                 withIntermediateDirectories: true)
    }
}
