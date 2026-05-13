import Foundation
import CryptoKit

// Signiert ein Update-Manifest mit demselben Ed25519-Schlüssel wie die
// Lizenzen. Output ist ein JSON-Envelope, der 1:1 auf den Webserver
// hochgeladen werden kann (toolbox.funkwelt.net/app/updates.json).
//
// Spiegelbild zum App-seitigen UpdateChecker. Schema muss synchron bleiben.

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

enum ManifestSigner {

    /// Generiert den fertig signierten JSON-Envelope-String, der als
    /// `updates.json` auf dem Webserver liegt.
    static func sign(payload: UpdateManifestPayloadOut,
                     with key: Curve25519.Signing.PrivateKey) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payloadData = try encoder.encode(payload)
        let payloadB64 = payloadData.base64URLEncodedString()
        guard let msg = payloadB64.data(using: .utf8) else {
            throw NSError(domain: "ManifestSigner", code: 1)
        }
        let sig = try key.signature(for: msg)
        let envelope = UpdateManifestEnvelopeOut(
            manifest: payloadB64,
            signature: sig.base64URLEncodedString()
        )
        let envOut = try encoder.encode(envelope)
        return String(data: envOut, encoding: .utf8) ?? ""
    }
}
