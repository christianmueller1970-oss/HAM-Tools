import Foundation

// Rolle einer BOTA-Session. Festgelegt beim Anlegen, nicht änderbar.
enum BOTARole: String, Codable, CaseIterable, Identifiable {
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
