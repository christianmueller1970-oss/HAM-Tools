import Foundation

// WWFF-Reference-Eintrag aus dem wwff-cc.org-Directory (oder einer
// manuell importierten CSV). Wird in wwff_refs.sqlite gehalten.
//
// Refs folgen dem Muster `XXFF-NNNN` mit Land-Präfix:
//   - DLFF-0001 (Deutschland)
//   - HBFF-0019 (Schweiz)
//   - KFF-1234  (USA)
//   - VKFF-0001 (Australien)
struct WWFFReference: Identifiable, Codable, Hashable {
    var id: String { reference }
    let reference: String          // "DLFF-0001"
    let name: String               // "Berchtesgaden National Park"
    let program: String            // "DLFF" — Land-Programm aus Ref-Prefix
    let country: String?           // "Germany"
    let iucCategory: String?       // "National Park", "Natura 2000", …
    let latitude: Double?
    let longitude: Double?
    let isActive: Bool
    let potaLink: String?          // optional: bekannte POTA-Ref bei Doppel-Park

    var displayLabel: String {
        var parts: [String] = ["\(reference) — \(name)"]
        if let c = country, !c.isEmpty { parts.append(c) }
        return parts.joined(separator: " · ")
    }

    // Aus "DLFF-0001" wird "DLFF" extrahiert (alles vor dem ersten Dash).
    static func programFromRef(_ ref: String) -> String {
        if let dash = ref.firstIndex(of: "-") {
            return String(ref[..<dash])
        }
        return ref
    }
}
