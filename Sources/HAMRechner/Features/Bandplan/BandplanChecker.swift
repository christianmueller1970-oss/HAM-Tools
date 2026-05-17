import Foundation

// Live-Validierung Frequenz + Mode gegen den IARU-R1-Bandplan
// (Sources/HAMRechner/Content/bandplan.json). Liefert eine Pille-
// freundliche Status-Information, die das QSO-Form direkt rendern kann.
//
// Drei mögliche Resultate:
// - `.ok`           — Frequenz liegt in einem Band UND der Mode passt zur
//                     Subsegment-Kategorie.
// - `.wrongCategory`— Frequenz ist im Band, aber im falschen Sub-Segment
//                     (z.B. SSB im CW-Subband 7.000–7.040 MHz).
// - `.outOfBand`    — Frequenz ist überhaupt nicht im Amateurfunkband.
//
// Der Check ist bewusst tolerant — bandplan.json hat viele »alle
// Sendearten«-Sub-Segmente, die wir nicht künstlich einschränken.
enum BandplanChecker {

    enum Result: Equatable {
        case ok(band: String, subsegment: String)
        case wrongCategory(band: String, expectedCategory: String, subsegment: String)
        case outOfBand
    }

    /// Lazy-loaded Bandplan-Daten; einmal pro App-Lebenszyklus geladen.
    private static let data: BandplanData = BandplanLoader.load()

    /// Hauptcheck.
    /// - parameter frequencyMHz: QSO-Frequenz in MHz (≤ 0 → unbekannt, wir
    ///   liefern .outOfBand zurück, das blendet die Pille aus).
    /// - parameter mode: ADIF-Mode-String wie "SSB", "CW", "FT8", "FM".
    static func check(frequencyMHz: Double, mode: String) -> Result {
        guard frequencyMHz > 0 else { return .outOfBand }
        let freqKHz = frequencyMHz * 1000.0
        guard let hit = BandplanLoader.lookup(frequencyKHz: freqKHz, in: data) else {
            return .outOfBand
        }
        let bandLabel = hit.band.name
        let subLabel  = "\(formatKHz(hit.sub.von))–\(formatKHz(hit.sub.bis)) kHz · \(hit.sub.mode)"
        if isModeCompatible(mode: mode, withCategory: hit.sub.cat, modeText: hit.sub.mode) {
            return .ok(band: bandLabel, subsegment: subLabel)
        }
        return .wrongCategory(band: bandLabel,
                              expectedCategory: prettyCategory(hit.sub.cat),
                              subsegment: subLabel)
    }

    // MARK: - Mode-Compatibility-Tabelle

    /// Welche User-Modes passen zu welcher bandplan.json-Kategorie? Bewusst
    /// tolerant gehalten — bandplan.json hat reichlich »alle Sendearten«-
    /// Sub-Segmente, die wir nicht künstlich einschränken.
    private static func isModeCompatible(mode: String,
                                         withCategory cat: String,
                                         modeText: String) -> Bool {
        let m = mode.uppercased().trimmingCharacters(in: .whitespaces)
        let c = cat.lowercased()
        guard !m.isEmpty else { return true }      // kein Mode gesetzt → keine Warnung

        // Tolerante Kategorien: alles erlaubt.
        if c == "mixed" || c == "dx" || c == "emcom" || c == "sat" { return true }

        // Wenn der modeText "alle Sendearten" enthält, sind wir tolerant
        // egal welche cat — bandplan.json macht das z.B. im 40m-SSB-Bereich.
        let lower = modeText.lowercased()
        if lower.contains("alle sendearten") || lower.contains("alle modes") {
            return true
        }

        switch c {
        case "cw":     return m == "CW"
        case "ssb":    return Self.phoneModes.contains(m)
        case "digi":   return Self.digiModes.contains(m) || (lower.contains("cw") && m == "CW")
        case "fm":     return m == "FM" || m == "FM-NARROW" || m == "FM-WIDE"
        case "am":     return m == "AM" || Self.phoneModes.contains(m)
        case "beacon": return false                 // Baken-Sub-Segmente: nur Beacons selbst
        default:       return true                  // unbekannte cat → tolerant
        }
    }

    /// Phone-Modes: alles was als Sprach-Mode geloggt wird.
    private static let phoneModes: Set<String> = [
        "SSB", "USB", "LSB", "AM", "FM", "DV", "C4FM", "DSTAR", "DMR"
    ]

    /// Digital-Modes: ADIF + WSJT-X-übliche Bezeichnungen.
    private static let digiModes: Set<String> = [
        "FT8", "FT4", "PSK", "PSK31", "PSK63", "RTTY", "JT65", "JT9",
        "MFSK", "OLIVIA", "JS8", "DATA", "MSK144", "Q65", "FSK441",
        "JT4", "JT6M", "ROS", "VARA", "PACTOR", "PACKET", "FLDIGI"
    ]

    // MARK: - Format-Helper

    private static func formatKHz(_ kHz: Double) -> String {
        // Ganze kHz ohne Nachkomma anzeigen, sonst eine Stelle.
        if kHz.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", kHz)
        }
        return String(format: "%.1f", kHz)
    }

    private static func prettyCategory(_ cat: String) -> String {
        switch cat.lowercased() {
        case "cw":     return "CW"
        case "ssb":    return "SSB/Phone"
        case "digi":   return "Schmalband-Digital"
        case "fm":     return "FM"
        case "am":     return "AM"
        case "beacon": return "Baken"
        case "sat":    return "Satellit"
        case "mixed":  return "Mixed"
        case "dx":     return "DX-Fenster"
        case "emcom":  return "Emergency Comm"
        default:       return cat.uppercased()
        }
    }
}
