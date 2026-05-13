import Foundation

// Server-Manifest, das HAM-Tools beim Update-Check abruft.
//
// URL: https://toolbox.funkwelt.net/app/updates.json
//
// Schema auf dem Server (JSON-Envelope mit zwei Base64URL-Feldern):
//
//     {
//       "manifest":  "<base64URL(UpdateManifestPayload JSON)>",
//       "signature": "<base64URL(Ed25519-Signatur)>"
//     }
//
// Die Signatur wird über die UTF-8-Bytes des `manifest`-Strings gebildet,
// genau analog zum Lizenz-Verfahren (LicenseCrypto). Der Public Key ist
// derselbe — d.h. nur Christian kann gültige Manifeste erzeugen.

struct UpdateManifestEnvelope: Codable {
    let manifest: String   // base64URL(payload JSON)
    let signature: String  // base64URL(signature bytes)
}

struct UpdateManifestPayload: Codable, Hashable, Identifiable {
    /// Version dient als stabile ID für `.sheet(item:)` und Skip-Logik.
    var id: String { version }

    /// Schema-Version (1).
    var v: Int = 1
    /// Anzeigeversion z.B. "1.7.0" — nur informativ.
    var version: String
    /// Build-Datum der neuesten App-Version (ISO yyyy-MM-dd).
    /// Wird gegen die User-Lizenz `updatesUntil` geprüft, damit der Alert
    /// im richtigen Modus angezeigt wird.
    var buildDate: String
    /// macOS-Mindestversion (z.B. "14.0"). nil = keine Anforderung.
    var minMacOSVersion: String?
    /// Download-URL für das DMG.
    var dmgURL: String
    /// Release-Notes (Markdown-light, einfache Zeilenumbrüche).
    var releaseNotes: String
    /// Wenn true: User darf das Update nicht skippen (z.B. Sicherheits-Fix).
    var critical: Bool
}

// Vergleich: ist `latest` neuer als `current`? Wir vergleichen das
// Build-Datum (yyyy-MM-dd lässt sich String-Vergleich nutzen, lexikographisch
// === chronologisch).
func isNewerBuild(latest: String, than current: String) -> Bool {
    latest > current
}
