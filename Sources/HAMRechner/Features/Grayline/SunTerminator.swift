import Foundation

// Sonnen-Position + Dämmerungs-Klassifikation pro Geo-Punkt.
//
// Formeln nach NOAA Solar Position Algorithm (vereinfacht):
//   • Julian Date aus Calendar
//   • Sonnen-Deklination + Greenwich-Stundenwinkel
//   • Subsolar-Punkt: (lat = Deklination, lon = -GHA)
//   • Höhenwinkel pro Geo-Punkt: sin(h) = sin(lat)*sin(decl) + cos(lat)*cos(decl)*cos(hourAngle)
//
// Genauigkeit ~ 0.1°, mehr als ausreichend für Grayline-Visualisierung.
enum SunTerminator {

    /// Wo steht die Sonne am gegebenen Zeitpunkt direkt im Zenit?
    /// Returnt (lat, lon) in Grad. lon ∈ [-180, 180].
    static func subSolarPoint(at date: Date) -> (lat: Double, lon: Double) {
        let jd = julianDate(from: date)
        let n  = jd - 2_451_545.0        // Tage seit J2000

        // Mittlere Anomalie der Sonne (rad)
        let g = (357.528 + 0.9856003 * n).deg2rad

        // Ekliptische Länge (rad)
        let L = (280.460 + 0.9856474 * n).deg2rad

        // Wahre ekliptische Länge (rad)
        let lambda = L + (1.915.deg2rad * sin(g)) + (0.020.deg2rad * sin(2*g))

        // Schiefe der Ekliptik (rad)
        let epsilon = (23.439 - 0.0000004 * n).deg2rad

        // Deklination
        let decl = asin(sin(epsilon) * sin(lambda))

        // Greenwich Mean Sidereal Time → ergibt die Längengrad-Position
        // der Sonne. Einfacher Weg: Equation of Time approximieren.
        let eqOfTime = -1.915 * sin(g) - 0.020 * sin(2*g)   // Grad
                     + 2.466 * sin(2*L) - 0.053 * sin(4*L)   // (vereinfacht)

        let utcHours = utcHoursFraction(of: date)
        let solarNoonLonDeg = (12.0 - utcHours) * 15.0 + eqOfTime
        // Sub-solar-Längengrad ist dort, wo Sonne am höchsten steht
        var lon = solarNoonLonDeg
        // Normalisieren auf [-180, 180]
        lon = ((lon + 540).truncatingRemainder(dividingBy: 360)) - 180

        return (lat: decl.rad2deg, lon: lon)
    }

    /// Sonnen-Höhenwinkel in Grad an einem Geo-Punkt zur gegebenen Zeit.
    /// Werte > 0 = Sonne über Horizont (Tag); 0 bis -6 = bürgerliche Dämmerung;
    /// -6 bis -12 = nautische Dämmerung; -12 bis -18 = astronomische
    /// Dämmerung; < -18 = Nacht.
    static func solarAltitude(latDeg: Double, lonDeg: Double, at date: Date) -> Double {
        let sub = subSolarPoint(at: date)
        let lat1 = latDeg.deg2rad
        let lat2 = sub.lat.deg2rad
        // Differenz der Längen (Winkelabstand zur Sub-solar-Linie)
        let dLon = (lonDeg - sub.lon).deg2rad
        let sinH = sin(lat1) * sin(lat2)
                 + cos(lat1) * cos(lat2) * cos(dLon)
        let h = asin(max(-1, min(1, sinH)))
        return h.rad2deg
    }

    /// Klassifiziert einen Höhenwinkel in die fünf Tag/Dämmerungs-Stufen.
    enum DaylightClass {
        case day            // Sonne über Horizont
        case civil          // -6° ... 0°  (bürgerliche Dämmerung — Greyline-Korridor)
        case nautical       // -12° ... -6°
        case astronomical   // -18° ... -12°
        case night          // < -18°
    }

    static func classify(altitudeDeg h: Double) -> DaylightClass {
        if h >    0   { return .day }
        if h >  -6.0  { return .civil }
        if h > -12.0  { return .nautical }
        if h > -18.0  { return .astronomical }
        return .night
    }

    /// Berechnet die Terminator-Linie (alle Punkte mit Sonnen-Altitude = 0°)
    /// als geschlossene Großkreis-Linie. Returnt 361 Punkte (alle 1° Lon),
    /// inklusive des Start-Punkts am Ende, damit Polylinien geschlossen sind.
    ///
    /// Math: am Terminator gilt 0 = sin(lat)·sin(δ) + cos(lat)·cos(δ)·cos(H)
    /// → tan(lat) = -cos(H) / tan(δ)
    /// mit H = lon - λs (Stundenwinkel).
    static func terminatorLine(at date: Date) -> [(lat: Double, lon: Double)] {
        let sub = subSolarPoint(at: date)
        let decl = sub.lat.deg2rad
        // Edge case: Sonnen-Deklination nahe 0° → tan(δ) → 0 → lat → ±90°.
        // Geben wir hier einen geraden Terminator entlang des Äquators
        // zurück (passiert nur exakt an den Äquinoktien).
        guard abs(decl) > 0.001 else {
            return stride(from: -180.0, through: 180.0, by: 1.0)
                .map { ($0 * 0, $0) }
        }
        var pts: [(lat: Double, lon: Double)] = []
        pts.reserveCapacity(361)
        for lonDeg in stride(from: -180.0, through: 180.0, by: 1.0) {
            let H = (lonDeg - sub.lon).deg2rad
            let lat = atan2(-cos(H), tan(decl)).rad2deg
            pts.append((lat: lat, lon: lonDeg))
        }
        return pts
    }

    // MARK: - Helpers

    private static func julianDate(from date: Date) -> Double {
        // Direkt aus Unix-Epoche: JD = unix/86400 + 2440587.5
        return date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    private static func utcHoursFraction(of date: Date) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.hour, .minute, .second], from: date)
        return Double(c.hour ?? 0)
             + Double(c.minute ?? 0) / 60.0
             + Double(c.second ?? 0) / 3600.0
    }
}

private extension Double {
    var deg2rad: Double { self * .pi / 180.0 }
    var rad2deg: Double { self * 180.0 / .pi }
}
