import Foundation

/// Liest und schreibt DXSpots als JSON-Datei in ~/Library/Application Support/HAMRechner/spots.json.
/// Spots älter als 60 Minuten werden beim Laden automatisch verworfen — beim Start sind so
/// nur "frische" Cluster-Daten sichtbar, alte Sessions werden nicht reanimiert.
enum SpotPersistence {
    private static let fileName:  String         = "spots.json"
    private static let retention: TimeInterval   = 60 * 60   // 60 Minuten
    static  let maxSpots:         Int            = 500

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
        guard let base = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let dir = base.appendingPathComponent("HAMRechner", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }
}
