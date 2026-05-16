import Foundation

// Distance- und Bearing-Berechnung aus zwei Maidenhead-Locatoren.
// Die zugrundeliegende `locatorToLatLon` und `haversineKm` sitzen
// schon in DXCluster/Models/BandData.swift als globale Helpers; hier
// kommt nur das Bearing dazu (in QTHLocatorView gibt's eine zweite
// Variante als statische Method, aber lokal versteckt — wir halten
// die QSO-Berechnung damit aus dem QTHLocator-Modul raus).
//
// Initial-Bearing entlang Großkreis vom Sender zum Empfänger, 0–360°,
// 0=Nord, im Uhrzeigersinn. Standard-Formel, identisch zu der in
// QTHLocatorView, hier nur frei aufrufbar.
func bearingDegrees(fromLat lat1: Double, fromLon lon1: Double,
                    toLat   lat2: Double, toLon   lon2: Double) -> Double {
    let φ1 = lat1 * .pi / 180
    let φ2 = lat2 * .pi / 180
    let Δλ = (lon2 - lon1) * .pi / 180
    let y = sin(Δλ) * cos(φ2)
    let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
    let θ = atan2(y, x)
    return (θ * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
}

extension QSO {
    /// Berechnet Distanz (km) und Bearing (°) zwischen zwei Maidenhead-
    /// Locatoren. nil wenn einer der Locatoren ungültig oder zu kurz ist
    /// (locatorToLatLon braucht mindestens 4 Stellen).
    static func computeGeometry(from ownLocator: String,
                                to   otherLocator: String) -> (distance: Double, bearing: Double)? {
        guard let own   = locatorToLatLon(ownLocator),
              let other = locatorToLatLon(otherLocator) else { return nil }
        let dist = haversineKm(lat1: own.lat,   lon1: own.lon,
                               lat2: other.lat, lon2: other.lon)
        let brg  = bearingDegrees(fromLat: own.lat,   fromLon: own.lon,
                                  toLat:   other.lat, toLon:   other.lon)
        return (dist, brg)
    }
}
