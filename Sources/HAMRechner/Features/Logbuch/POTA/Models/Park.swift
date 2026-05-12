import Foundation

// POTA-Park-Eintrag aus all_parks_ext.csv. Wird in parks.sqlite gehalten.
struct Park: Identifiable, Codable, Hashable {
    var id: String { reference }
    let reference: String          // "K-1234", "DA-0042", "HB-0001"
    let name: String
    let active: Bool
    let entityId: Int?
    let locationDesc: String?      // z.B. "Geneva, Switzerland"
    let latitude: Double?
    let longitude: Double?
    let grid: String?              // Maidenhead-Locator

    var displayLabel: String {
        if let loc = locationDesc, !loc.isEmpty {
            return "\(reference) — \(name) (\(loc))"
        }
        return "\(reference) — \(name)"
    }
}
