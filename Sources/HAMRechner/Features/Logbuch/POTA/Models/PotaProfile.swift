import Foundation

// Schlankes Modell für api.pota.app/profile/{CALLSIGN}.
// pota.app's Schema ist nicht offiziell dokumentiert; deshalb alle Felder
// optional + tolerante Decoder. Was nicht ankommt, wird im UI als "—" gezeigt.
struct PotaProfile: Codable, Equatable {
    var callsign: String?
    var name: String?
    var qth: String?
    var gravatar: String?

    var stats: PotaStats?

    // Persistenz-Metadaten — nicht aus API, von uns selbst gesetzt.
    var fetchedAt: Date?
}

struct PotaStats: Codable, Equatable {
    var activator: PotaActivatorStats?
    var hunter:    PotaHunterStats?
    var awards: Int?
    var endorsements: Int?

    // Manche pota.app-Antworten haben park_to_park separat,
    // manche stecken es in activator/hunter mit drin. Beides aufnehmen.
    var park_to_park: PotaP2PStats?
}

struct PotaActivatorStats: Codable, Equatable {
    var activations: Int?
    var parks: Int?
    var qsos: Int?
}

struct PotaHunterStats: Codable, Equatable {
    var parks: Int?
    var qsos: Int?
}

struct PotaP2PStats: Codable, Equatable {
    var parks: Int?
    var qsos: Int?
}
