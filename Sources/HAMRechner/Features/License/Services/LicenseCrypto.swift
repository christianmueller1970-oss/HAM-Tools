import Foundation
import CryptoKit

// Ed25519-Verifikation für HAM-Tools-Lizenzen.
//
// Schlüsselpaar wird im "HAMToolsLicenseGen"-Helper-Tool generiert. Der
// **Public Key** wird hier als Base64-String hartcodiert; der Private Key
// liegt ausschließlich auf Christians Mac (im Helper / in seiner Keychain).
//
// Wir signieren die UTF-8-Bytes des `base64URL(payload-JSON)`-Strings
// — also den exakten String, der im Lizenz-Envelope an Position 2 steht.
// So ist die Verifikation deterministisch und unabhängig davon, wie der
// JSON intern serialisiert wird.
enum LicenseCrypto {

    // MARK: - Hardcoded Public Key
    //
    // Beim allerersten Setup mit dem License-Generator-Helper wird ein
    // Schlüsselpaar generiert. Das Helper-Tool gibt den Public Key als
    // Base64-String aus — diesen hier einsetzen.
    //
    // Bis dahin: leer → alle Lizenzen schlagen mit `.missingOrInvalid` fehl,
    // App läuft im Demo-Modus. Das ist Absicht damit die App nicht versehentlich
    // ohne echte Verifikation gebaut wird.
    static let publicKeyBase64 = "HykmjG4I1+GJmT4TEmpezr77+virJVy8IIpdHDJQ6DM="

    enum CryptoError: Error {
        case malformedEnvelope
        case unknownVersionPrefix(String)
        case publicKeyNotConfigured
        case signatureInvalid
        case payloadDecodeFailed
    }

    /// Verifiziert + dekodiert einen Lizenz-Envelope-String.
    /// Wirft bei jedem Fehler einen sprechenden `CryptoError`.
    static func verifyAndDecode(_ envelope: String) throws -> LicensePayload {
        // Format: ham1.<payload-b64url>.<sig-b64url>
        let trimmed = envelope.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 else { throw CryptoError.malformedEnvelope }
        let (versionTag, payloadB64URL, signatureB64URL) = (parts[0], parts[1], parts[2])

        guard versionTag == "ham1" else {
            throw CryptoError.unknownVersionPrefix(versionTag)
        }
        guard !publicKeyBase64.isEmpty,
              let pubKeyRaw = Data(base64Encoded: publicKeyBase64),
              let pubKey = try? Curve25519.Signing.PublicKey(rawRepresentation: pubKeyRaw)
        else {
            throw CryptoError.publicKeyNotConfigured
        }
        guard let signature = Data(base64URLEncoded: signatureB64URL) else {
            throw CryptoError.malformedEnvelope
        }
        // Signatur prüft über die UTF-8-Bytes des Base64URL-Payload-Strings.
        guard let message = payloadB64URL.data(using: .utf8) else {
            throw CryptoError.malformedEnvelope
        }
        guard pubKey.isValidSignature(signature, for: message) else {
            throw CryptoError.signatureInvalid
        }
        // Signatur OK → Payload decodieren
        guard let payloadJSON = Data(base64URLEncoded: payloadB64URL) else {
            throw CryptoError.payloadDecodeFailed
        }
        do {
            return try JSONDecoder().decode(LicensePayload.self, from: payloadJSON)
        } catch {
            throw CryptoError.payloadDecodeFailed
        }
    }
}

// MARK: - Base64URL Helpers
//
// Ed25519-Signaturen sind 64 Bytes; Lizenz-JSON ist ~150–300 Bytes.
// Wir nutzen die URL-safe Base64-Variante (- und _ statt + und /, kein
// Padding) — damit lassen sich Lizenz-Strings einfacher per E-Mail
// kopieren ohne Escaping-Stolperfallen.
extension Data {
    init?(base64URLEncoded s: String) {
        var t = s.replacingOccurrences(of: "-", with: "+")
                 .replacingOccurrences(of: "_", with: "/")
        // Padding wieder hinzufügen
        let pad = (4 - t.count % 4) % 4
        t += String(repeating: "=", count: pad)
        self.init(base64Encoded: t)
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
