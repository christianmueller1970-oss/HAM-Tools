import Foundation

// Build-Datum dieser App-Version. Wird vom License-Service gegen den
// `updatesUntil`-Wert in der Lizenz geprüft (Modell B: Lifetime mit
// 12 Monaten Update-Inkludierung).
//
// Konvention: bei jedem Release-Build vor dem build-dmg.sh manuell
// nachziehen. Format ISO yyyy-MM-dd, UTC-Datum.
//
// Wenn ein User mit einer Lizenz "updatesUntil: 2027-05-13" eine App
// startet, die nach diesem Datum gebaut wurde, fällt die App in den
// Demo-Modus. User kann zur älteren App-Version zurück (die mit der
// Lizenz weiterhin voll läuft) oder Update-Verlängerung anfragen.
enum BuildInfo {
    /// Datum dieses App-Builds. Bei jedem Release-Build manuell aktualisieren.
    static let appBuildDate: String = "2026-05-13"

    /// Support-/Lizenz-Anfragen
    static let licenseRequestEmail = "hb9hji@funkwelt.net"

    /// Update-Manifest auf Christians Webserver. Server-Setup s. tools/README-server.md.
    static let updateManifestURL = "https://toolbox.funkwelt.net/app/updates.json"

    /// User-sichtbare App-Version (für About-Box, Update-Vergleich-Anzeige).
    static let appVersion = "1.7.0"
}
