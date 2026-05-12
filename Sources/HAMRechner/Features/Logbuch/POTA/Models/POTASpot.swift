import Foundation

// Spot von api.pota.app/spot/activator. Read-only Feed, kein eigener Upload.
struct POTASpot: Identifiable, Hashable, Codable {
    let spotId: Int
    let activator: String
    let frequencyKhz: Double
    let mode: String
    let reference: String
    let parkName: String?      // pota nennt das im JSON "name", "parkName" ist meist null
    let spotter: String?
    let spotTime: Date
    let comments: String?
    let source: String?        // "RBN", "Ham2K Portable Logger", "Manual", …
    let invalid: Bool
    let locationDesc: String?  // "US-WI", "CH-AG"
    let grid: String?
    let latitude: Double?
    let longitude: Double?

    var id: Int { spotId }

    var frequencyMHz: Double { frequencyKhz / 1000.0 }
    var band: String { HamBand.from(frequencyMHz: frequencyMHz)?.rawValue ?? "" }

    // State aus locationDesc extrahieren ("US-WI" → "WI", "CH-AG" → "AG").
    var state: String? {
        guard let loc = locationDesc, !loc.isEmpty else { return nil }
        if let dash = loc.firstIndex(of: "-") {
            return String(loc[loc.index(after: dash)...])
        }
        return loc
    }
}

// Decoder: pota.app schickt einige Felder als Strings, manche null. Wir
// dekodieren defensiv (Frequenz aus String, Datum mit Custom-Format).
extension POTASpot {
    private enum Keys: String, CodingKey {
        case spotId, activator, frequency, mode, reference
        case parkName, name           // server nutzt "name", "parkName" ist meist null
        case spotter, spotTime, comments, source, invalid, locationDesc
        case grid4, grid6
        case latitude, longitude
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        self.spotId    = try c.decode(Int.self, forKey: .spotId)
        self.activator = try c.decode(String.self, forKey: .activator)

        // frequency kommt als String "18100.0" (kHz)
        let freqStr = try c.decode(String.self, forKey: .frequency)
        self.frequencyKhz = Double(freqStr) ?? 0.0

        self.mode      = try c.decode(String.self, forKey: .mode)
        self.reference = try c.decode(String.self, forKey: .reference)
        // "name" ist der primäre Park-Name, "parkName" oft null
        self.parkName  = (try? c.decode(String.self, forKey: .name))
                      ?? (try? c.decode(String.self, forKey: .parkName))
        self.spotter   = try? c.decode(String.self, forKey: .spotter)

        // "2026-05-12T19:07:55" — kein Trailing Z, deshalb mit DateFormatter
        let timeStr = try c.decode(String.self, forKey: .spotTime)
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: timeStr) {
            self.spotTime = d
        } else if let d = f.date(from: timeStr + "Z") {
            self.spotTime = d
        } else {
            // Fallback: einfaches Format
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            df.timeZone = TimeZone(identifier: "UTC")
            df.locale = Locale(identifier: "en_US_POSIX")
            self.spotTime = df.date(from: timeStr) ?? Date()
        }

        self.comments     = try? c.decode(String.self, forKey: .comments)
        self.source       = try? c.decode(String.self, forKey: .source)
        // invalid kann null oder bool sein
        self.invalid      = (try? c.decode(Bool.self, forKey: .invalid)) ?? false
        self.locationDesc = try? c.decode(String.self, forKey: .locationDesc)
        self.grid         = (try? c.decode(String.self, forKey: .grid6))
                         ?? (try? c.decode(String.self, forKey: .grid4))
        self.latitude     = try? c.decode(Double.self, forKey: .latitude)
        self.longitude    = try? c.decode(Double.self, forKey: .longitude)
    }

    // Encode für Hashable-Konformität — nicht für Net-Roundtrip gedacht.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(spotId, forKey: .spotId)
        try c.encode(activator, forKey: .activator)
        try c.encode(String(format: "%.1f", frequencyKhz), forKey: .frequency)
        try c.encode(mode, forKey: .mode)
        try c.encode(reference, forKey: .reference)
        try c.encodeIfPresent(parkName, forKey: .name)
        try c.encodeIfPresent(spotter, forKey: .spotter)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        df.timeZone = TimeZone(identifier: "UTC")
        df.locale = Locale(identifier: "en_US_POSIX")
        try c.encode(df.string(from: spotTime), forKey: .spotTime)
        try c.encodeIfPresent(comments, forKey: .comments)
        try c.encodeIfPresent(source, forKey: .source)
        try c.encode(invalid, forKey: .invalid)
        try c.encodeIfPresent(locationDesc, forKey: .locationDesc)
        try c.encodeIfPresent(grid, forKey: .grid6)
        try c.encodeIfPresent(latitude, forKey: .latitude)
        try c.encodeIfPresent(longitude, forKey: .longitude)
    }
}
