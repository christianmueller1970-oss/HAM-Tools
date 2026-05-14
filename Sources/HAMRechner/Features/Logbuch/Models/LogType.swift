import Foundation
import SwiftUI

// Phase 1 (MVP): nur Standard-Log aktiv. Contest/POTA/SOTA sind im Enum
// bereits angelegt damit das Datenmodell stabil bleibt — UI-Aktivierung
// kommt in Phasen 4 / 4c / 4d.
enum LogType: String, Codable, CaseIterable, Identifiable {
    case standard
    case contest
    case pota
    case sota
    case wwff

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard-Log"
        case .contest:  return "Contest-Log"
        case .pota:     return "POTA-Session"
        case .sota:     return "SOTA-Session"
        case .wwff:     return "WWFF-Session"
        }
    }

    var shortDescription: String {
        switch self {
        case .standard: return "Allgemeines Log (Lebens-Log, Tages-Log, …)"
        case .contest:  return "Contest mit Exchange + Cabrillo-Export"
        case .pota:     return "Parks On The Air, Activator/Hunter"
        case .sota:     return "Summits On The Air, Activator/Chaser"
        case .wwff:     return "Worldwide Flora & Fauna, Activator/Hunter (44-QSO-Regel)"
        }
    }

    var systemImage: String {
        switch self {
        case .standard: return "book"
        case .contest:  return "stopwatch"
        case .pota:     return "tree"
        case .sota:     return "mountain.2"
        case .wwff:     return "leaf"
        }
    }

    // Standard + POTA + Contest + SOTA + WWFF sind umgesetzt.
    var isAvailable: Bool {
        self == .standard || self == .pota || self == .contest
            || self == .sota || self == .wwff
    }
}
