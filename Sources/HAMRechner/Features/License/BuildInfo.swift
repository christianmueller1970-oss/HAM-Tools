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
    static let appBuildDate: String = "2026-05-16"

    /// Support-/Lizenz-Anfragen
    static let licenseRequestEmail = "hb9hji@funkwelt.net"

    /// Bug-Reports vom In-App-Button "Bug melden…"
    static let bugReportEmail = "bugs@funkwelt.net"

    /// Update-Manifest auf Christians Webserver. Server-Setup s. tools/README-server.md.
    static let updateManifestURL = "https://toolbox.funkwelt.net/app/updates.json"

    /// User-sichtbare App-Version. Wird im Update-Dialog als „Aktuell"-
    /// Anzeige verwendet. Pflicht nachzuziehen bei jedem Release zusammen
    /// mit `appBuildDate`, CHANGELOG.md und der build-dmg.sh-VERSION —
    /// sonst zeigt der Update-Dialog beim Beta-Tester eine veraltete
    /// „Aktuell"-Version (Bug bis einschließlich 1.8.5).
    static let appVersion = "1.8.6"
}
