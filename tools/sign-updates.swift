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

let RELEASE_VERSION   = "1.8.8"
let RELEASE_BUILDDATE = "2026-05-17"          // ISO 8601, YYYY-MM-DD
let RELEASE_MIN_MACOS = "14.0"                 // oder nil
let RELEASE_DMG_URL   = "https://toolbox.funkwelt.net/app/dmg/HAM-Tools-1.8.8.dmg"
let RELEASE_CRITICAL  = false                  // true zwingt User zur Installation (kein Skip)
let RELEASE_NOTES = """
Outdoor-Programme: Upload jetzt plattform-konform, POTA-Self-Spot, \
WWBOTA-Live-Anbindung, viele Polishs.

ADIF-Export jetzt direkt hochladbar:
- POTA-ADIF entspricht 1:1 der pota.app-Vorgabe (MY_SIG=POTA, kein \
nicht-dokumentiertes MY_POTA_REF mehr).
- WWBOTA-ADIF mit MY_SIG=WWBOTA und Komma-Liste in MY_SIG_INFO für \
Multi-Bunker — laut offiziellem WWBOTA-ADIF-Guide.
- Multi-Park-Hopping (POTA): pro Park ein eigenes File mit \
{CALL}@{PARK} YYYYMMDD.adi — pota.app erlaubt keine Komma-Listen.

POTA Self-Spot:
- Im Activator-Modus mit gesetztem Park + Frequenz erscheint in der \
Status-Bar ein "Spot senden"-Button. Sheet mit Vorschau + Comment, \
Senden direkt an pota.app — sofort für alle Hunter sichtbar.

SOTA-CSV für sotadata.org.uk:
- Neuer Toolbar-Button "Für sotadata.org.uk exportieren (CSV)" \
schreibt das offizielle V2-CSV-Format inkl. Summit-Gruppierung, \
S2S-Spalte und Band-Mapping.

WWBOTA-Anbindung:
- Bunker-Datenbank lädt jetzt von api.wwbota.org (~26.7k Bunker \
weltweit). Snapshot kommt direkt aus der App, jederzeit aktualisierbar.
- Refs durchgängig im offiziellen B/XX-NNNN-Format.

Logbuch-Polish:
- QRZ-Auto-Fill in Outdoor-Logs übernimmt jetzt auch QTH, Locator, \
Country, Continent, CQ-/ITU-Zone (nicht mehr nur den Namen).
- Hopping-Felder beim Log-Anlegen zeigen pro Eintrag den \
vollständigen Park-/Summit-/Bunker-Namen + Details.
- Bandplan jetzt eigenes Fenster (Fenster → Bandplan-Fenster, ⌘⇧P).
- Multi-File-Export zeigt alle Dateinamen + "Im Finder zeigen"-Button.
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
