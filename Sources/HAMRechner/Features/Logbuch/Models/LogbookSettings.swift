import Foundation
import Combine

// Globale Logbuch-Einstellungen — vor allem der Ordner in dem die
// .htlog-Dateien liegen. Persistiert in UserDefaults als Bookmark
// (sandboxing-tauglich, behält Zugriffsrechte auch über App-Neustarts).
final class LogbookSettings: ObservableObject {
    private let directoryKey = "logbook.directory.path"

    @Published var logbookDirectory: URL {
        didSet {
            UserDefaults.standard.set(logbookDirectory.path, forKey: directoryKey)
            ensureExists(logbookDirectory)
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: directoryKey)
        let url = stored.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? Self.defaultDirectory
        self.logbookDirectory = url
        ensureExists(url)
    }

    static var defaultDirectory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base
            .appendingPathComponent("HAMRechner", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
    }

    private func ensureExists(_ url: URL) {
        try? FileManager.default.createDirectory(at: url,
                                                 withIntermediateDirectories: true)
    }
}
