import Foundation
import Combine

// Orchestriert die Callbook-Lookups. Aktuell nur QRZ.com, später lassen
// sich HamQTH/qrzcq/etc. anhängen indem man ein CallbookService-Impl
// dazustellt und priorisiert.
//
// Persistenter Cache: Root/Cache/callbook-cache.json.
@MainActor
final class CallbookManager: ObservableObject {
    let settings: CallbookSettings
    private let dataRoot: AppDataRoot
    private let qrz: QRZService

    @Published private(set) var inFlightCalls: Set<String> = []
    @Published private(set) var lastError: String?

    private var cache: [String: CachedEntry] = [:]
    private let cacheTTL: TimeInterval = 60 * 60 * 24 * 30   // 30 Tage

    private struct CachedEntry: Codable {
        let result: CallbookResult
        let timestamp: Date
    }

    init(settings: CallbookSettings, dataRoot: AppDataRoot) {
        self.settings = settings
        self.dataRoot = dataRoot
        self.qrz = QRZService(settings: settings)
        loadCache()
    }

    // MARK: - Public Lookup

    /// Liefert ein Resultat aus Cache oder Live-Lookup (async).
    /// Nicht-konfigurierter Service oder Fehler → nil.
    func lookup(call: String, forceRefresh: Bool = false) async -> CallbookResult? {
        let key = call.trimmingCharacters(in: .whitespaces).uppercased()
        guard !key.isEmpty else { return nil }

        if !forceRefresh,
           let cached = cache[key],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.result
        }

        guard settings.qrzIsConfigured else {
            lastError = "QRZ.com nicht konfiguriert — Einstellungen → Callbook"
            return nil
        }

        inFlightCalls.insert(key)
        defer { inFlightCalls.remove(key) }
        lastError = nil

        guard let result = await qrz.lookup(call: key) else {
            lastError = "Kein Treffer für \(key) oder QRZ-Fehler"
            return nil
        }
        cache[key] = CachedEntry(result: result, timestamp: Date())
        saveCache()
        return result
    }

    func isInFlight(_ call: String) -> Bool {
        inFlightCalls.contains(call.uppercased())
    }

    func clearCache() {
        cache.removeAll()
        saveCache()
    }

    var cacheCount: Int { cache.count }

    // MARK: - Persistenz

    private var cacheFileURL: URL {
        dataRoot.cacheDir.appendingPathComponent("callbook-cache.json")
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let decoded = try? JSONDecoder.iso.decode([String: CachedEntry].self, from: data)
        else { return }
        cache = decoded
    }

    private func saveCache() {
        guard let data = try? JSONEncoder.iso.encode(cache) else { return }
        try? data.write(to: cacheFileURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static let iso: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
private extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
