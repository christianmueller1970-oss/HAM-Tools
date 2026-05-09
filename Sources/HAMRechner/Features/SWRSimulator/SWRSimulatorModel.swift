import Foundation
import SwiftUI

struct SWRErgebnis {
    let swr: Double
    let eingangsleistungW: Double
    let z0: Double

    var gamma: Double        { (swr - 1) / (swr + 1) }
    var gamma2: Double       { gamma * gamma }
    var ruecklaufW: Double   { gamma2 * eingangsleistungW }
    var ausgangsleistungW: Double { eingangsleistungW - ruecklaufW }
    var verlustProzent: Double    { gamma2 * 100.0 }
    var rueckflussdaempfungDB: Double { gamma > 0 ? -20 * log10(gamma) : .infinity }
    var mismatchVerlustDB: Double { -10 * log10(1 - gamma2) }
    var zLast: Double        { z0 * swr }

    var bewertung: SWRBewertung {
        if swr <= 1.5 { return .gut }
        if swr <= 2.5 { return .mittel }
        if swr <= 4.0 { return .hoch }
        return .gefahr
    }

    var farbe: Color {
        switch bewertung {
        case .gut:    return .green
        case .mittel: return Color(red: 0.95, green: 0.75, blue: 0.0)
        case .hoch:   return .orange
        case .gefahr: return .red
        }
    }
}

enum SWRBewertung {
    case gut, mittel, hoch, gefahr

    var label: String {
        switch self {
        case .gut:    return "Sehr gut"
        case .mittel: return "Akzeptabel"
        case .hoch:   return "Tuner empfohlen"
        case .gefahr: return "Gefahr für Endstufe"
        }
    }

    var icon: String {
        switch self {
        case .gut:    return "checkmark.circle.fill"
        case .mittel: return "exclamationmark.circle.fill"
        case .hoch:   return "exclamationmark.triangle.fill"
        case .gefahr: return "xmark.octagon.fill"
        }
    }

    var hintergrund: Color {
        switch self {
        case .gut:    return Color.green.opacity(0.1)
        case .mittel: return Color.yellow.opacity(0.15)
        case .hoch:   return Color.orange.opacity(0.12)
        case .gefahr: return Color.red.opacity(0.12)
        }
    }
}
