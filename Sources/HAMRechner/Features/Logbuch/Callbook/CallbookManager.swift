import Foundation
import Combine

// Orchestriert die Callbook-Lookups. Primär+Fallback-Logik:
//   1. Try primary service (QRZ oder HamQTH, je nach settings.primaryService)
//   2. Wenn kein Resultat: try the other service
//   3. Sonst: nil
//
// Persistenter Cache: Root/Cache/callbook-cache.json (Service-agnostisch).
@MainActor
final class CallbookManager: ObservableObject {
    let settings: CallbookSettings
    private let dataRoot: AppDataRoot
    private let qrz:    QRZService
    private let hamqth: HamQTHService

    @Published private(set) var inFlightCalls: Set<String> = []
    @Published private(set) var lastError: String?

    private var cache: [String: CachedEntry] = [:]
    private let cacheTTL: TimeInterval = 60 * 60 * 24 * 30   // 30 Tage

    private struct CachedEntry: Codable {
        let result: CallbookResult
        let timestamp: Date
        var source: String? = nil   // welcher Service hat geantwortet
    }

    init(settings: CallbookSettings, dataRoot: AppDataRoot) {
        self.settings = settings
        self.dataRoot = dataRoot
        self.qrz    = QRZService(settings: settings)
        self.hamqth = HamQTHService(settings: settings)
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

        guard settings.anyConfigured else {
            lastError = "Kein Callbook konfiguriert — Einstellungen → Callbook"
            return nil
        }

        inFlightCalls.insert(key)
        defer { inFlightCalls.remove(key) }
        lastError = nil

        // Reihenfolge: primary zuerst, der andere als Fallback.
        // Nicht-konfigurierte Services werden übersprungen.
        let order: [(name: String, service: CallbookService, configured: Bool)] =
            settings.primaryService == .qrz
            ? [("QRZ",    qrz,    settings.qrzIsConfigured),
               ("HamQTH", hamqth, settings.hamqthIsConfigured)]
            : [("HamQTH", hamqth, settings.hamqthIsConfigured),
               ("QRZ",    qrz,    settings.qrzIsConfigured)]

        for entry in order where entry.configured {
            if let result = await entry.service.lookup(call: key) {
                cache[key] = CachedEntry(result: result,
                                         timestamp: Date(),
                                         source: entry.name)
                saveCache()
                return result
            }
        }
        lastError = "Kein Treffer für \(key)"
        return nil
    }

    func isInFlight(_ call: String) -> Bool {
        inFlightCalls.contains(call.uppercased())
    }

    /// Synchroner Read auf den In-Memory-Cache. Liefert das gecachte Resultat,
    /// auch wenn es älter als TTL ist — TTL betrifft nur das Re-Fetching.
    /// Nützlich für reine Display-Use-Cases (z.B. POTA-Map-Pins).
    func cachedResult(forCall call: String) -> CallbookResult? {
        cache[call.trimmingCharacters(in: .whitespaces).uppercased()]?.result
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
