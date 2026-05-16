import Foundation

// Build-Metadaten dieser App-Version.
//
// `appVersion` wird zur Laufzeit aus dem Info.plist gelesen (CFBundle-
// ShortVersionString) — `build-dmg.sh` setzt diesen Wert bereits aus dem
// VERSION-Parameter, also kann er nie veraltet sein.
//
// `appBuildDate` wird vom `build-dmg.sh` automatisch per sed-Patch auf
// das aktuelle Build-Datum gesetzt, **bevor** swift build läuft. Manuelle
// Pflege entfällt damit — siehe Block "Pflege der Build-Metadaten" im
// build-dmg.sh. Vor 1.8.6 war beides hardcoded und wurde regelmäßig
// vergessen (Bug 1.7.1 → 1.8.5: Update-Dialog zeigte "Aktuell: 1.7.0"
// obwohl längst 1.8.x installiert war).
enum BuildInfo {
    /// Datum dieses App-Builds. Wird vom build-dmg.sh automatisch via
    /// sed gepatcht — manuelle Bearbeitung ist nicht nötig (und würde
    /// beim nächsten Release-Build wieder überschrieben).
    static let appBuildDate: String = "2026-05-16"

    /// Support-/Lizenz-Anfragen
    static let licenseRequestEmail = "hb9hji@funkwelt.net"

    /// Bug-Reports vom In-App-Button "Bug melden…"
    static let bugReportEmail = "bugs@funkwelt.net"

    /// Update-Manifest auf Christians Webserver. Server-Setup s. tools/README-server.md.
    static let updateManifestURL = "https://toolbox.funkwelt.net/app/updates.json"

    /// User-sichtbare App-Version — liest CFBundleShortVersionString aus
    /// dem App-Bundle. Damit ist appVersion automatisch synchron mit
    /// dem VERSION-Parameter von build-dmg.sh (der die Info.plist
    /// generiert). Im SwiftPM-Debug-Build ohne App-Bundle gibt es
    /// fallback auf "DEV".
    static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "DEV"
    }
}
