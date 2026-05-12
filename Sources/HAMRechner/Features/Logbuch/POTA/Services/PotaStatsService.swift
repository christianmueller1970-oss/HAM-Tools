import Foundation
import Combine

// Holt das öffentliche pota.app-User-Profil und cached es lokal als
// JSON. Eine Aktualisierung wird nach 24 h automatisch angeboten,
// kann aber jederzeit manuell ausgelöst werden.
//
// Wir bevorzugen pota.app als Source-of-Truth gegenüber dem lokalen
// LogbookManager — pota.app sieht alle Aktivitäten geräteübergreifend,
// das lokale Log ist nur eine Teilmenge.
//
// Kein Auth: das öffentliche /profile/{CALLSIGN}-Endpoint ist zugänglich.
@MainActor
final class PotaStatsService: ObservableObject {

    enum Status: Equatable {
        case unknown
        case loading
        case ready(date: Date)
        case errored(String)
    }

    @Published private(set) var profile: PotaProfile?
    @Published private(set) var status: Status = .unknown

    private let dataRoot: AppDataRoot
    private let refreshAfter: TimeInterval = 60 * 60 * 24   // 24 h

    init(dataRoot: AppDataRoot) {
        self.dataRoot = dataRoot
        loadCache()
    }

    // MARK: - Public API

    /// Lädt das Profil für den gegebenen Call. Trim + uppercase wird hier
    /// gemacht; pota.app ist Case-Insensitive aber wir wollen Cache-Keys stabil.
    func refresh(callsign: String) async {
        let cs = callsign.trimmingCharacters(in: .whitespaces).uppercased()
        guard !cs.isEmpty else {
            status = .errored("Kein Callsign gesetzt — Einstellungen → Station.")
            return
        }
        guard let url = URL(string: "https://api.pota.app/profile/\(cs)") else {
            status = .errored("Ungültige URL für \(cs)")
            return
        }

        status = .loading
        do {
            var req = URLRequest(url: url)
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                throw NSError(domain: "POTA-Profile", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey:
                                "HTTP \(http.statusCode) von pota.app — Call \(cs) unbekannt?"])
            }
            let decoder = JSONDecoder()
            var p = try decoder.decode(PotaProfile.self, from: data)
            p.fetchedAt = Date()
            self.profile = p
            self.status = .ready(date: p.fetchedAt ?? Date())
            saveCache(data: data, fetchedAt: p.fetchedAt ?? Date())
        } catch let DecodingError.dataCorrupted(ctx) {
            status = .errored("pota.app-Schema unverständlich (\(ctx.debugDescription))")
        } catch {
            status = .errored(error.localizedDescription)
        }
    }

    /// True, wenn die letzte Aktualisierung > 24 h her ist (oder nie war).
    var shouldOfferRefresh: Bool {
        guard let last = profile?.fetchedAt else { return true }
        return Date().timeIntervalSince(last) > refreshAfter
    }

    // MARK: - Persistenz

    private var cacheURL: URL {
        dataRoot.cacheDir.appendingPathComponent("pota-profile.json")
    }
    private var metaURL: URL {
        dataRoot.cacheDir.appendingPathComponent("pota-profile.meta.json")
    }

    private struct CacheMeta: Codable {
        let fetchedAt: Date
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              var p = try? JSONDecoder().decode(PotaProfile.self, from: data)
        else { return }
        if let metaData = try? Data(contentsOf: metaURL),
           let meta = try? JSONDecoder().decode(CacheMeta.self, from: metaData) {
            p.fetchedAt = meta.fetchedAt
        }
        self.profile = p
        if let f = p.fetchedAt { self.status = .ready(date: f) }
    }

    private func saveCache(data: Data, fetchedAt: Date) {
        try? data.write(to: cacheURL, options: .atomic)
        if let meta = try? JSONEncoder().encode(CacheMeta(fetchedAt: fetchedAt)) {
            try? meta.write(to: metaURL, options: .atomic)
        }
    }
}
