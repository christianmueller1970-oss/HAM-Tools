import Foundation

struct ClusterNode: Identifiable, Codable, Equatable {
    var id   = UUID()
    var name: String
    var host: String
    var port: Int

    /// Markiert den Node als aktiv im Multi-Cluster-Pool. Sobald das
    /// Backend-Refactor durch ist, verbindet die App parallel zu allen
    /// `isActive`-Nodes (max 3, via `ClusterSettingsStore.maxActiveNodes`).
    var isActive: Bool

    init(name: String, host: String, port: Int = 7300, isActive: Bool = false) {
        self.name     = name
        self.host     = host
        self.port     = port
        self.isActive = isActive
    }

    // Codable-Migration: bis 1.8.10 hieß das Flag `autoConnect`. Beim
    // Decoden alter UserDefaults-Daten lesen wir den alten Key mit; der
    // nächste Save schreibt den neuen.
    enum CodingKeys: String, CodingKey {
        case id, name, host, port, isActive
        case autoConnectLegacy = "autoConnect"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id   = try c.decodeIfPresent(UUID.self,   forKey: .id)   ?? UUID()
        self.name = try c.decode(String.self, forKey: .name)
        self.host = try c.decode(String.self, forKey: .host)
        self.port = try c.decodeIfPresent(Int.self,    forKey: .port) ?? 7300
        if let v = try c.decodeIfPresent(Bool.self, forKey: .isActive) {
            self.isActive = v
        } else {
            self.isActive = (try? c.decode(Bool.self, forKey: .autoConnectLegacy)) ?? false
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,       forKey: .id)
        try c.encode(name,     forKey: .name)
        try c.encode(host,     forKey: .host)
        try c.encode(port,     forKey: .port)
        try c.encode(isActive, forKey: .isActive)
    }
}
