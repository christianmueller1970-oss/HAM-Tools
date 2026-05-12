import SwiftUI
import MapKit

// Globale Map-Style-Auswahl (Stufe 1: Apple-MapKit-Stile).
// In Einstellungen → Darstellung wählbar, persistiert via @AppStorage.
// Stufe 2 (OSM/OpenTopoMap via MKTileOverlay) ist eine separate Etappe.
enum MapStyleChoice: String, CaseIterable, Identifiable {
    case standard
    case hybrid
    case imagery

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .hybrid:   return "Hybrid"
        case .imagery:  return "Satellit"
        }
    }

    var subtitle: String {
        switch self {
        case .standard: return "Strassenkarte (Apple Maps)"
        case .hybrid:   return "Satellitenbild mit Beschriftung + Strassen"
        case .imagery:  return "Reines Satellitenbild ohne Overlay"
        }
    }
}

extension View {
    // Wendet den globalen Map-Style auf eine SwiftUI-`Map` an. Wird in allen
    // Logbuch-/Cluster-Karten verwendet, damit ein einziger Picker in den
    // Einstellungen alle Views umstellt.
    @ViewBuilder
    func appMapStyle(_ choice: MapStyleChoice) -> some View {
        switch choice {
        case .standard: self.mapStyle(.standard(elevation: .flat))
        case .hybrid:   self.mapStyle(.hybrid(elevation: .flat))
        case .imagery:  self.mapStyle(.imagery(elevation: .flat))
        }
    }
}
