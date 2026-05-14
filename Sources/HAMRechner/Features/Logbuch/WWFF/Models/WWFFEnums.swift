import Foundation

// Rolle einer WWFF-Session. Festgelegt beim Anlegen, nicht änderbar.
enum WWFFRole: String, Codable, CaseIterable, Identifiable {
    case activator = "Activator"
    case hunter    = "Hunter"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .activator: return "Activator (ich aktiviere)"
        case .hunter:    return "Hunter (ich jage)"
        }
    }
}
