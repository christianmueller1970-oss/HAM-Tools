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

// Vergleich: ist `latestVersion`/`latestBuildDate` neuer als
// `currentVersion`/`currentBuildDate`? Primär nach Semver-Version (Punkt-
// getrennt, numerisch pro Segment), Build-Datum nur als Tiebreaker bei
// gleicher Version. Bis 1.8.12 wurde nur das Datum verglichen — Hotfix-
// Releases vom selben Tag (1.8.11 → 1.8.12) wurden dadurch nicht erkannt.
func isNewerBuild(latestVersion: String, latestBuildDate: String,
                  currentVersion: String, currentBuildDate: String) -> Bool {
    switch compareVersions(latestVersion, currentVersion) {
    case .orderedDescending: return true
    case .orderedAscending:  return false
    case .orderedSame:       return latestBuildDate > currentBuildDate
    }
}

/// Semver-konformer Punkt-Segment-Vergleich: 1.8.12 > 1.8.11, 1.10.0 > 1.9.9.
/// Nicht-numerische Segmente werden als 0 behandelt (defensiv, sollte in
/// der Praxis nie vorkommen).
func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
    let aParts = a.split(separator: ".").map { Int($0) ?? 0 }
    let bParts = b.split(separator: ".").map { Int($0) ?? 0 }
    let n = max(aParts.count, bParts.count)
    for i in 0..<n {
        let ai = i < aParts.count ? aParts[i] : 0
        let bi = i < bParts.count ? bParts[i] : 0
        if ai < bi { return .orderedAscending }
        if ai > bi { return .orderedDescending }
    }
    return .orderedSame
}
