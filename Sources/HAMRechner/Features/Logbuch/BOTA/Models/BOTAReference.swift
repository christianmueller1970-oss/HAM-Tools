import Foundation

// BOTA-Reference-Eintrag, primär aus dem WWBOTA-CSV-Feed (api.wwbota.org).
// Refs folgen dem WWBOTA-Format `B/XX-NNNN`, wobei `B/` der globale Bunker-
// Präfix ist und `XX` der DXCC/Programm-Code (z.B. 9A Kroatien, DE Deutsch-
// land, BU Russland). Cluster-Spots senden Refs ebenfalls in dieser Form.
struct BOTAReference: Identifiable, Codable, Hashable {
    var id: String { reference }
    let reference: String          // "B/9A-0001"
    let name: String               // "Krči"
    let program: String            // "9A", "DE" — DXCC-/Programm-Code
    let country: String?
    let bunkerType: String?        // WWBOTA-"Type"-Spalte
    let latitude: Double?
    let longitude: Double?
    let isActive: Bool

    var displayLabel: String {
        var parts: [String] = ["\(reference) — \(name)"]
        if let c = country, !c.isEmpty { parts.append(c) }
        if let t = bunkerType, !t.isEmpty { parts.append(t) }
        return parts.joined(separator: " · ")
    }

    /// Aus "B/9A-0001" wird "9A" — globalen `B/`-Präfix abstreifen, dann
    /// alles vor dem ersten Dash als Programm-Code nehmen. Funktioniert
    /// auch für Refs ohne Präfix ("DE-1234" → "DE") für Backwards-Compat
    /// mit alten manuellen CSV-Imports.
    static func programFromRef(_ ref: String) -> String {
        let stripped = ref.hasPrefix("B/") ? String(ref.dropFirst(2)) : ref
        if let dash = stripped.firstIndex(of: "-") {
            return String(stripped[..<dash])
        }
        return stripped
    }
}
