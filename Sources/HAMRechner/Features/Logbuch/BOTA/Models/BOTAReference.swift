import Foundation

// BOTA-Reference-Eintrag aus einer CSV (kein zentrales öffentliches API
// gefunden — File-Import-Pfad ist primär). Refs folgen einem flexiblen
// Pattern XX-NNNN (z.B. DE-1234 für deutsches BOTA, BU-099 für Russian
// Bunker Award, BPL-001 für polnisches BPL).
struct BOTAReference: Identifiable, Codable, Hashable {
    var id: String { reference }
    let reference: String          // "DE-1234"
    let name: String               // "Bunker Münster"
    let program: String            // "DE", "BU" — Land/Programm-Präfix
    let country: String?
    let bunkerType: String?        // "WWII", "Kalter Krieg", "ATM", …
    let latitude: Double?
    let longitude: Double?
    let isActive: Bool

    var displayLabel: String {
        var parts: [String] = ["\(reference) — \(name)"]
        if let c = country, !c.isEmpty { parts.append(c) }
        if let t = bunkerType, !t.isEmpty { parts.append(t) }
        return parts.joined(separator: " · ")
    }

    /// Aus "DE-1234" wird "DE" — Programm-Präfix vor dem ersten Dash.
    static func programFromRef(_ ref: String) -> String {
        if let dash = ref.firstIndex(of: "-") {
            return String(ref[..<dash])
        }
        return ref
    }
}
