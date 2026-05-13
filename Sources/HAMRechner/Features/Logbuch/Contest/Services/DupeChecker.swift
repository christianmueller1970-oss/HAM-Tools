import Foundation

// Contest-Dupe-Check.
// Prüft beim Tippen des Callsigns, ob das Call im aktuellen Log auf demselben
// Band + Mode schon einmal gearbeitet wurde — die übliche "Dupe"-Regel in
// CQ-WW / WPX / ARRL-DX und den meisten anderen Major-Contests.
//
// Sonderfall HB-Helvetia: dort gilt traditionell Dupe pro Band + Mode +
// Verbindungspartner-Kategorie (HB-zu-HB ist getrennt von HB-zu-DX); für
// Etappe 2 reicht uns die generische Band+Mode-Regel, das fängt 95% der
// versehentlichen Doppel-Logs ab.
enum DupeChecker {

    /// Liefert das erste passende vorhandene QSO als Beweis, oder nil wenn
    /// kein Dupe vorliegt. Eingabe ist die noch nicht persistierte Eingabe;
    /// Vergleich case-insensitive auf Call.
    static func findDupe(call: String,
                         band: String,
                         mode: String,
                         in qsos: [QSO]) -> QSO? {
        let needle = call.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !needle.isEmpty, !band.isEmpty else { return nil }
        let bandKey = band.uppercased()
        let modeKey = mode.uppercased()
        return qsos.first { q in
            q.call.uppercased() == needle
                && q.band.uppercased() == bandKey
                && q.mode.uppercased() == modeKey
        }
    }
}
