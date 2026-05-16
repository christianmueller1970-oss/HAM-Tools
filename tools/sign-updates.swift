// Signiert ein Update-Manifest (updates.json) für die HAM-Tools-App.
//
// Repliziert die Logik aus tools/HAMToolsLicenseGen/Sources/.../ManifestSigner.swift,
// damit Release-Drops ohne GUI-Workflow möglich sind. Nutzt denselben Ed25519-
// Private-Key wie das Lizenzsystem (gespeichert in
// ~/Library/Application Support/HAM-Tools License Generator/keypair.json).
//
// === Verwendung ===
// 1) Konstanten im "RELEASE-DATEN"-Block unten anpassen
// 2) Skript ausführen, signiertes Manifest landet in updates.json:
//      cd /Pfad/zum/Repo
//      swift tools/sign-updates.swift > updates.json
// 3) Hochladen auf den Webserver:
//      scp updates.json root@toolbox.funkwelt.net:/var/www/toolbox/app/
//
// Die App fragt das Manifest 1×/24h beim Start oder manuell via Cmd+Opt+U ab
// (BuildInfo.updateManifestURL).

import Foundation
import CryptoKit

// MARK: - RELEASE-DATEN (für jeden Release anpassen)

let RELEASE_VERSION   = "1.8.6"
let RELEASE_BUILDDATE = "2026-05-16"          // ISO 8601, YYYY-MM-DD
let RELEASE_MIN_MACOS = "14.0"                 // oder nil
let RELEASE_DMG_URL   = "https://toolbox.funkwelt.net/app/dmg/HAM-Tools-1.8.6.dmg"
let RELEASE_CRITICAL  = false                  // true zwingt User zur Installation (kein Skip)
let RELEASE_NOTES = """
QRZ-Logbook-Anbindung, neue Tabs und viel Polish.

QRZ Logbook (Phase 6 Schritt 1+2):
- Live-Upload jedes QSO an QRZ.com — API-Key in Einstellungen → \
Lookup & Upload → QRZ.com → Logbook, Toggle für Auto-Upload bei \
DX-Logs (Outdoor-Programme bleiben außen vor).
- Bulk-Upload für historische QSOs via Rechtsklick im Log: \
"N QSOs an QRZ Logbook hochladen".
- Bestätigungen abrufen: neuer Button im QSL-Tab, holt paginiert \
das komplette QRZ-Logbook und ergänzt fehlende LoTW-/eQSL-/Direkt- \
Bestätigungen lokal — additiv, manuelle lokale Flags bleiben.

Neue Tabs:
- QSL-Tab (Briefumschlag): Übersicht offener und bestätigter QSOs, \
Filter pro Service, Doppelklick öffnet das Edit-Sheet.
- Stats-Dashboard (Balken): 4 Kennzahlen + Charts pro Jahr/Band/ \
Mode/Kontinent + Top-DXCC und Top-DX-Strecken.

Distance & Bearing pro QSO:
- Automatische Berechnung beim Loggen/Editieren aus dem eigenen \
QTH-Locator. Neue Spalten Distanz/Peilung (default ausgeblendet).
- Bulk-Backfill für ältere QSOs via Spalten-Menü → Wartung.

Workflow:
- Bulk-Vervollständigen via Rechtsklick — mehrere QSOs markieren \
und parallel aus QRZ/HamQTH ergänzen.
- QRZ-Profilbild-Cache (30 Tage) — Bilder erscheinen beim zweiten \
Öffnen sofort statt mit Lade-Spinner.
- ADIF-Import läuft async — große Dateien (z. B. 7 MB QRZ-Export) \
blockieren die UI nicht mehr.

Web/Download-Bereich:
- Verzeichnis-Listing aller DMG-Versionen funktioniert wieder.
- Top-Nav-Download zeigt auf eine versionslose latest.dmg.
"""

// MARK: - Implementation (sollte stabil bleiben)

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

struct UpdateManifestPayloadOut: Codable {
    var v: Int = 1
    var version: String
    var buildDate: String
    var minMacOSVersion: String?
    var dmgURL: String
    var releaseNotes: String
    var critical: Bool
}

struct UpdateManifestEnvelopeOut: Codable {
    let manifest: String
    let signature: String
}

struct KeyPair: Codable {
    var privateKey: String
    var publicKey:  String
}

// MARK: - Main

let keypairPath = NSString(string: "~/Library/Application Support/HAM-Tools License Generator/keypair.json")
    .expandingTildeInPath

guard FileManager.default.fileExists(atPath: keypairPath) else {
    fputs("Keypair nicht gefunden unter \(keypairPath)\n", stderr)
    fputs("Erst HAMToolsLicenseGen GUI starten und ein Pair generieren.\n", stderr)
    exit(2)
}

let keypairData = try Data(contentsOf: URL(fileURLWithPath: keypairPath))
let pair = try JSONDecoder().decode(KeyPair.self, from: keypairData)

guard let privRaw = Data(base64Encoded: pair.privateKey) else {
    fputs("Privater Key ist kein gültiges Base64\n", stderr)
    exit(1)
}
let privKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privRaw)

let payload = UpdateManifestPayloadOut(
    v: 1,
    version: RELEASE_VERSION,
    buildDate: RELEASE_BUILDDATE,
    minMacOSVersion: RELEASE_MIN_MACOS,
    dmgURL: RELEASE_DMG_URL,
    releaseNotes: RELEASE_NOTES,
    critical: RELEASE_CRITICAL
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let payloadData = try encoder.encode(payload)
let payloadB64 = payloadData.base64URLEncodedString()
guard let msg = payloadB64.data(using: .utf8) else {
    fputs("UTF-8-Encoding fehlgeschlagen\n", stderr); exit(1)
}
let sig = try privKey.signature(for: msg)

let envelope = UpdateManifestEnvelopeOut(
    manifest: payloadB64,
    signature: sig.base64URLEncodedString()
)
let envOut = try encoder.encode(envelope)
let outString = String(data: envOut, encoding: .utf8)!

// Sanity-Check auf stderr, fertiger Envelope auf stdout (zum > umleiten)
fputs("=== Payload (entschlüsselt) ===\n", stderr)
let pretty = JSONEncoder()
pretty.outputFormatting = [.prettyPrinted, .sortedKeys]
fputs(String(data: try pretty.encode(payload), encoding: .utf8)! + "\n", stderr)
fputs("=== Envelope-Größe: \(outString.count) Bytes ===\n", stderr)

print(outString)
