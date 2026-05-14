import Foundation

// Rolle einer SOTA-Session. Festgelegt beim Anlegen, nicht änderbar.
enum SOTARole: String, Codable, CaseIterable, Identifiable {
    case activator = "Activator"
    case chaser    = "Chaser"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .activator: return "Activator (ich aktiviere)"
        case .chaser:    return "Chaser (ich jage)"
        }
    }
}
