import Foundation

// SOTA-Summit-Eintrag aus sotadata.org.uk/summitslist.csv. Wird in
// summits.sqlite gehalten. ~181k Summits weltweit.
struct Summit: Identifiable, Codable, Hashable {
    var id: String { reference }
    let reference: String          // "HB/BE-001", "G/LD-001"
    let association: String        // "Switzerland"
    let region: String             // "Berner Alpen"
    let name: String               // "Finsteraarhorn"
    let altitudeM: Int?
    let altitudeFt: Int?
    let latitude: Double?
    let longitude: Double?
    let points: Int                // 1..10 (Activator-Punkte)
    let bonusPoints: Int           // 0 oder 3 (Winterbonus, falls anwendbar)
    let validFrom: Date?
    let validTo: Date?
    let isActive: Bool             // valid_to >= today
    let activationCount: Int?
    let lastActivation: Date?

    var displayLabel: String {
        var parts: [String] = ["\(reference) — \(name)"]
        if let alt = altitudeM { parts.append("\(alt) m") }
        parts.append("\(points) p")
        if bonusPoints > 0 { parts.append("+\(bonusPoints) Bonus") }
        return parts.joined(separator: " · ")
    }

    // "HB" aus "HB/BE-001", für Filter-Picker
    var associationPrefix: String {
        if let slash = reference.firstIndex(of: "/") {
            return String(reference[..<slash])
        }
        return reference
    }
}
