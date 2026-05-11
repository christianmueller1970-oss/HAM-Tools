import Foundation

/// Liest und schreibt DXSpots als JSON-Datei. Pfad kommt zur Laufzeit
/// vom AppDataRoot (Default: ~/Documents/HAM-Tools/Cache/spots.json).
/// Spots älter als 60 Minuten werden beim Laden automatisch verworfen.
enum SpotPersistence {
    private static let fileName:  String         = "spots.json"
    private static let retention: TimeInterval   = 60 * 60   // 60 Minuten
    static  let maxSpots:         Int            = 500

    // Wird vom App-Setup gesetzt (HAMRechnerApp injiziert AppDataRoot).
    // Bis dahin Fallback auf den Legacy-Pfad damit nichts crasht.
    nonisolated(unsafe) static var cacheDirectory: URL?

    // MARK: - Public API

    static func load() -> [DXSpot] {
        guard let url  = fileURL,
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([DXSpot].self, from: data)
        else { return [] }
        let cutoff = Date().addingTimeInterval(-retention)
        return Array(list.filter { $0.timestamp >= cutoff }.prefix(maxSpots))
    }

    static func save(_ spots: [DXSpot]) {
        guard let url = fileURL else { return }
        let slice = Array(spots.prefix(maxSpots))
        if let data = try? JSONEncoder().encode(slice) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Private

    private static var fileURL: URL? {
        let dir: URL
        if let configured = cacheDirectory {
            dir = configured
        } else {
            // Fallback während sehr früher App-Init-Phase: alte Location
            guard let base = FileManager.default
                    .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            else { return nil }
            dir = base.appendingPathComponent("HAMRechner", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }
}
