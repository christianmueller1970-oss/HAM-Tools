import Foundation

struct DXSpot: Identifiable, Equatable, Codable {
    let id = UUID()
    var spotter:     String
    var frequency:   Double
    var dxCall:      String
    var comment:     String
    var spotTime:    String
    var source:      String

    var band:        String = ""
    var mode:        String = ""
    var country:     String = ""
    var continent:   String = ""
    var lat:         Double = 0
    var lon:         Double = 0
    var spotterLat:  Double = 0
    var spotterLon:  Double = 0
    var timestamp:   Date   = Date()

    // Which logical source type (for filter checkboxes)
    var sourceType: String {
        if source.contains("SOTAwatch") || source == "SOTAwatch3" { return "SOTAwatch3" }
        if source == "POTA"  { return "POTA" }
        if source == "WWFF"  { return "WWFF" }
        return "DX"
    }

    var ageMinutes: Double {
        Date().timeIntervalSince(timestamp) / 60
    }

    var displayTime: String {
        spotTime.isEmpty ? timestamp.formatted(.dateTime.hour().minute().timeZone()) : spotTime
    }

    var displayFreq: String {
        String(format: "%.1f", frequency)
    }

    /// Mode wie er in der UI angezeigt werden soll. Wenn der Spotter
    /// generisch "SSB" gemeldet hat, leiten wir aus der Frequenz die
    /// Seitenband-Variante ab: < 10 MHz → LSB, ≥ 10 MHz → USB.
    /// (Konvention: 160/80/60/40m = LSB, 30m kein SSB, 20m+ = USB.)
    var displayMode: String {
        SSBResolver.displayMode(rawMode: mode, frequencyKHz: frequency)
    }

    var isValid: Bool {
        dxCall.count >= 3 && spotter.count >= 3 && frequency > 0
    }
}

// MARK: - SSB-Seitenband-Resolver (für alle Spot-Tabellen wiederverwendbar)

enum SSBResolver {
    /// Aus rohem Mode-String + Frequenz die UI-Anzeige ableiten.
    /// Macht nur etwas, wenn der rohe Mode "SSB" ist; andere Modes
    /// (CW, FT8, RTTY …) bleiben unverändert.
    static func displayMode(rawMode: String, frequencyKHz: Double) -> String {
        guard rawMode.uppercased() == "SSB" else { return rawMode }
        return frequencyKHz < 10_000 ? "LSB" : "USB"
    }

    static func displayMode(rawMode: String, frequencyMHz: Double) -> String {
        displayMode(rawMode: rawMode, frequencyKHz: frequencyMHz * 1000)
    }

    /// Mapping vom Spot-Mode-String (wie er aus Cluster/POTA/SOTA kommt) auf
    /// den Hamlib-Mode-String, den rigctld erwartet. Wird beim Spot-Klick
    /// genutzt, damit der TRX nicht nur QSYt, sondern auch in den richtigen
    /// Mode geht. Gibt `nil` zurück, wenn der Mode unbekannt ist — dann
    /// lässt der Aufrufer den TRX-Mode unverändert.
    static func hamlibMode(rawMode: String, frequencyKHz: Double) -> String? {
        switch rawMode.uppercased() {
        case "SSB":
            return frequencyKHz < 10_000 ? "LSB" : "USB"
        case "USB", "LSB", "CW", "CWR", "FM", "FMN", "AM", "RTTY", "RTTYR":
            return rawMode.uppercased()
        case "FT8", "FT4", "JS8", "PSK", "PSK31", "PSK63", "PSK125",
             "DIGI", "DATA", "MFSK", "OLIVIA", "VARA":
            // Digital-Modes laufen via Soundkarte über PKTUSB (>10 MHz) bzw.
            // PKTLSB (<10 MHz). Übliche WSJT-X/JS8Call-Konvention.
            return frequencyKHz < 10_000 ? "PKTLSB" : "PKTUSB"
        default:
            return nil
        }
    }

    static func hamlibMode(rawMode: String, frequencyMHz: Double) -> String? {
        hamlibMode(rawMode: rawMode, frequencyKHz: frequencyMHz * 1000)
    }
}
