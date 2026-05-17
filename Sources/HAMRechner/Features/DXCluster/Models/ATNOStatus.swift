import SwiftUI

// Live-Markierung für einen DX-Spot relativ zur eigenen Worked-Historie.
// "ATNO" = "All Time New One" (Country noch nie geloggt). Die anderen
// Stufen helfen beim Filter "Was sollte ich JETZT arbeiten?".
//
// `LogbookManager.atnoStatus(country:band:mode:)` produziert den Status
// pro Spot, `SpotListView` rendert eine kleine farbige Pille.
enum ATNOStatus: Equatable {
    case atno              // Country noch nie gearbeitet — Maximum-Priorität
    case newBand           // Country gearbeitet, aber nicht auf diesem Band
    case newMode           // Country+Band gearbeitet, aber nicht in diesem Mode
    case worked            // Alles schon — kein Highlight

    /// Kurzer Marker-Text für die Pille.
    var label: String {
        switch self {
        case .atno:     return "ATNO"
        case .newBand:  return "NEW BAND"
        case .newMode:  return "NEW MODE"
        case .worked:   return ""
        }
    }

    /// Hintergrund-Farbe der Pille (Vordergrund = weiß für ATNO, sonst dunkel).
    var color: Color {
        switch self {
        case .atno:     return .red
        case .newBand:  return .orange
        case .newMode:  return .yellow
        case .worked:   return .clear
        }
    }

    /// Vordergrund-Farbe (passend zur Lesbarkeit auf dem Hintergrund).
    var textColor: Color {
        switch self {
        case .atno:    return .white
        case .newBand: return .white
        case .newMode: return .black
        case .worked:  return .clear
        }
    }

    /// Wenn `true`, soll die Pille gerendert werden. Worked-Spots
    /// (Standardfall) bekommen keinen Marker, sonst rauscht die Liste.
    var isHighlight: Bool {
        if case .worked = self { return false }
        return true
    }
}
