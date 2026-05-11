import Foundation
import Combine

// Logbuch-spezifische Settings. Das aktuelle Standard-Verzeichnis kommt
// jetzt aus AppDataRoot (Root/Logs/). Wir tracken zusätzlich
// `knownLogPaths` damit Logs die per Import von außerhalb des Roots
// hinzugefügt wurden, weiter geöffnet werden können.
@MainActor
final class LogbookSettings: ObservableObject {
    private let knownPathsKey = "logbook.knownPaths"

    // Source-of-truth für den Standard-Logs-Ordner.
    private let dataRoot: AppDataRoot
    private var dataRootObserver: AnyCancellable?

    @Published var knownLogPaths: [URL] {
        didSet {
            let strings = knownLogPaths.map(\.path)
            UserDefaults.standard.set(strings, forKey: knownPathsKey)
        }
    }

    init(dataRoot: AppDataRoot) {
        self.dataRoot = dataRoot
        let storedPaths = (UserDefaults.standard.stringArray(forKey: knownPathsKey) ?? [])
            .map { URL(fileURLWithPath: $0) }
        self.knownLogPaths = storedPaths

        // Wenn der Root sich ändert, eventuell aufräumen.
        dataRootObserver = dataRoot.$rootURL
            .dropFirst()
            .sink { [weak self] _ in
                // Bei Root-Wechsel: nichts automatisch verschieben (User entscheidet).
                // Aber die knownLogPaths-Liste bleibt — alte Pfade bleiben gültig
                // solange die Dateien existieren.
                self?.objectWillChange.send()
            }
    }

    // Aktueller Default-Logs-Ordner = AppDataRoot/Logs/
    var logbookDirectory: URL { dataRoot.logsDir }

    // MARK: - Known paths API

    func addKnownLog(_ url: URL) {
        guard !knownLogPaths.contains(url) else { return }
        knownLogPaths.append(url)
    }

    func removeKnownLog(_ url: URL) {
        knownLogPaths.removeAll { $0 == url }
    }
}
