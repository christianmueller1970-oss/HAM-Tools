import Foundation

// Punkte-Berechnung nach den SOTA-Regeln. Stand 2026, mit saisonalem
// Winterbonus:
//   - Nordhalbkugel (Lat ≥ 0): 1. Dezember – 15. März
//   - Südhalbkugel (Lat < 0):   1. Juni     – 15. September
// Der Bonus-Wert pro Summit kommt aus der CSV-Spalte BonusPoints (typisch 0
// oder +3); er wird nur addiert, wenn der QSO/Aktivierung im Winter-Fenster
// liegt UND der Summit überhaupt einen Bonus hat.
struct SOTAPointsCalculator {

    /// Activator-Punkte für eine Aktivierung am gegebenen Summit + Datum.
    /// Liefert Base + Bonus separat zurück, damit das UI sie unterschiedlich
    /// färben kann.
    static func activatorPoints(for summit: Summit, on date: Date = Date())
        -> (base: Int, bonus: Int)
    {
        let bonus = (summit.bonusPoints > 0
                     && isInWinterBonusWindow(date: date,
                                              latitude: summit.latitude))
            ? summit.bonusPoints
            : 0
        return (summit.points, bonus)
    }

    /// Chaser-Punkte pro QSO mit einem aktivierten Summit. Chaser bekommt
    /// die Base-Punkte des Summits, keinen Winterbonus.
    static func chaserPoints(for summit: Summit) -> Int { summit.points }

    /// Winterbonus-Fenster auf Basis der UTC-Datums-Komponenten + Halbkugel.
    /// Latitude == nil → angenommen Nordhalbkugel (sicherer Default für EU).
    static func isInWinterBonusWindow(date: Date, latitude: Double?) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.month, .day], from: date)
        guard let m = comps.month, let d = comps.day else { return false }

        let southern = (latitude ?? 0) < 0
        if southern {
            // 1. Juni – 15. September
            if m == 6 || m == 7 || m == 8 { return true }
            if m == 9 && d <= 15 { return true }
            return false
        }
        // 1. Dezember – 15. März
        if m == 12 { return true }
        if m == 1 || m == 2 { return true }
        if m == 3 && d <= 15 { return true }
        return false
    }
}
