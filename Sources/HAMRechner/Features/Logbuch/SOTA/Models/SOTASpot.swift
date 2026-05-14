import Foundation

// Spot von api2.sota.org.uk/api/spots/{count}/all. Read-only Feed, kein
// eigener Upload (Self-Spotting kommt in einer späteren Phase).
//
// Schema-Unterschiede zu POTA:
//   - `frequency` ist MHz als String (POTA: kHz)
//   - `summitCode` ist OHNE Assoc-Prefix → volle Referenz = associationCode + "/" + summitCode
//   - `callsign` = Spotter, `activatorCallsign` = die Station auf dem Gipfel
struct SOTASpot: Identifiable, Hashable, Codable {
    let id: Int
    let userID: Int?
    let timeStamp: Date
    let callsign: String              // Wer den Spot eingetragen hat
    let activatorCallsign: String     // Wer aktiv auf dem Summit ist (z.B. "DG2GTG/P")
    let activatorName: String?
    let associationCode: String       // "HB", "DM", "G", …
    let summitCode: String            // "BE-001", "BW-015" (ohne Assoc-Prefix!)
    let summitDetails: String?        // "Hochfirst, 1190m, 10 points"
    let frequencyMHz: Double          // API liefert MHz direkt (manchmal als leerer String)
    let mode: String                  // "FM"/"CW"/"SSB"/… (manchmal leer)
    let comments: String?
    let highlightColor: String?       // "green"/"yellow"/null — SOTAwatch-Markierung

    // Volle SOTA-Referenz, wie die App sie sonst kennt (HB/BE-001).
    var fullReference: String { "\(associationCode)/\(summitCode)" }
    var band: String { HamBand.from(frequencyMHz: frequencyMHz)?.rawValue ?? "" }

    // Automatische RBN-Spots haben "RBNHOLE" als Spotter-Callsign — UI
    // kann sie visuell abheben.
    var isAutomaticSpot: Bool {
        callsign.uppercased() == "RBNHOLE"
    }
}

// Custom Decoder: sotadata schickt frequency + mode teilweise als leerer
// String, highlightColor als null, comments oft leer. Defensive dekodieren.
extension SOTASpot {
    private enum Keys: String, CodingKey {
        case id, userID, timeStamp, comments, callsign
        case associationCode, summitCode
        case activatorCallsign, activatorName
        case frequency, mode
        case summitDetails, highlightColor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        self.id      = try c.decode(Int.self, forKey: .id)
        self.userID  = try? c.decode(Int.self, forKey: .userID)

        // frequency kommt als String "145.5" (MHz) — kann leer sein.
        let freqStr = (try? c.decode(String.self, forKey: .frequency)) ?? ""
        self.frequencyMHz = Double(freqStr) ?? 0.0

        self.mode = (try? c.decode(String.self, forKey: .mode)) ?? ""
        self.callsign = (try? c.decode(String.self, forKey: .callsign)) ?? ""
        self.activatorCallsign = (try? c.decode(String.self, forKey: .activatorCallsign))
            ?? self.callsign
        self.activatorName  = try? c.decode(String.self, forKey: .activatorName)
        self.associationCode = (try? c.decode(String.self, forKey: .associationCode)) ?? ""
        self.summitCode = (try? c.decode(String.self, forKey: .summitCode)) ?? ""
        self.summitDetails = try? c.decode(String.self, forKey: .summitDetails)
        self.comments = try? c.decode(String.self, forKey: .comments)
        self.highlightColor = try? c.decode(String.self, forKey: .highlightColor)

        // "2026-05-14T10:48:38" — kein Trailing Z. Tolerant parsen wie bei POTA.
        let timeStr = (try? c.decode(String.self, forKey: .timeStamp)) ?? ""
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: timeStr) {
            self.timeStamp = d
        } else if let d = iso.date(from: timeStr + "Z") {
            self.timeStamp = d
        } else {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            df.timeZone = TimeZone(identifier: "UTC")
            df.locale = Locale(identifier: "en_US_POSIX")
            self.timeStamp = df.date(from: timeStr) ?? Date()
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(userID, forKey: .userID)
        try c.encode(callsign, forKey: .callsign)
        try c.encode(activatorCallsign, forKey: .activatorCallsign)
        try c.encodeIfPresent(activatorName, forKey: .activatorName)
        try c.encode(associationCode, forKey: .associationCode)
        try c.encode(summitCode, forKey: .summitCode)
        try c.encodeIfPresent(summitDetails, forKey: .summitDetails)
        try c.encode(String(format: "%g", frequencyMHz), forKey: .frequency)
        try c.encode(mode, forKey: .mode)
        try c.encodeIfPresent(comments, forKey: .comments)
        try c.encodeIfPresent(highlightColor, forKey: .highlightColor)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        df.timeZone = TimeZone(identifier: "UTC")
        df.locale = Locale(identifier: "en_US_POSIX")
        try c.encode(df.string(from: timeStamp), forKey: .timeStamp)
    }
}
