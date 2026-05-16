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

    // MARK: - Club Log API-Key (obfuskiert)
    //
    // Der API-Key gehört zur App »HAM-Tools«, nicht zum einzelnen User
    // (siehe https://clublog.freshdesk.com/support/solutions/articles/54910).
    // Normale Tester sollen ihn deshalb nicht im Settings-Panel sehen oder
    // einzeln anfragen müssen — er ist hier hinterlegt.
    //
    // Speicher-Format: zwei gleich lange Byte-Arrays. Der echte Key ergibt
    // sich aus byte-wise XOR. Hintergrund:
    //   * Club Log scannt öffentliche Repos / Web-Caches nach typischen
    //     40-Hex-Key-Mustern (siehe Doku »automated scans detect if keys
    //     are published«). Eine reine Hex-Konstante würde von solchen
    //     Scannern erkannt und automatisch gelöscht.
    //   * Mit zwei zufällig wirkenden Byte-Arrays findet `grep` nichts.
    //     Reverse-Engineering aus dem Binary ist trotzdem möglich — bei
    //     einem Leak wird der Key getauscht und ein 1.8.x-Release schickt
    //     die neue Konstante via Auto-Update raus.
    //
    // Generiert mit `swift tools/obfuscate-clublog-key.swift <key>` —
    // siehe Header dieses Skripts für Workflow.
    //
    // Solange der Key nicht von Club Log gekommen ist, bleibt das Array
    // leer; `clubLogApiKey` liefert dann "" und der Service stoppt clean,
    // bevor irgendein Netzwerk-Request rausgeht.
    private static let clubLogApiKeyXored: [UInt8] = [
        // <FÜLLE NACH ERHALT DES API-KEYS>
    ]
    private static let clubLogApiKeySalt: [UInt8] = [
        // <FÜLLE NACH ERHALT DES API-KEYS>
    ]

    /// Echter API-Key für Club-Log-Uploads. "" wenn noch nicht hinterlegt
    /// (z.B. zwischen Build und Helpdesk-Antwort). ClubLogService prüft
    /// das vor jedem Request und failt clean (.authFailed) statt einen
    /// 403 zu produzieren, der die IP-Firewall triggern könnte.
    static var clubLogApiKey: String {
        guard !clubLogApiKeyXored.isEmpty,
              clubLogApiKeyXored.count == clubLogApiKeySalt.count
        else { return "" }
        let bytes = zip(clubLogApiKeyXored, clubLogApiKeySalt).map { $0 ^ $1 }
        return String(decoding: bytes, as: UTF8.self)
    }
}
