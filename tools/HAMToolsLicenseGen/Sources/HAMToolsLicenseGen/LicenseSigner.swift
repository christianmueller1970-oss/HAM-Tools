import Foundation
import CryptoKit

// Erzeugt signierte Lizenz-Envelopes im Format "ham1.<payload>.<sig>".
// Spiegelbild zur Verifikation in HAMRechner/Features/License/Services/LicenseCrypto.swift —
// das Schema muss zwischen Helper und App **exakt** identisch bleiben.

struct LicensePayload: Codable {
    var v: Int = 1
    var calls: [String]
    var email: String
    var name: String
    var issued: String         // yyyy-MM-dd
    var updatesUntil: String   // yyyy-MM-dd
    var notes: String?
}

enum LicenseSigner {

    static func sign(payload: LicensePayload,
                     with key: Curve25519.Signing.PrivateKey) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = try encoder.encode(payload)
        let payloadB64 = json.base64URLEncodedString()
        guard let message = payloadB64.data(using: .utf8) else {
            throw NSError(domain: "LicenseSigner", code: 1)
        }
        let sig = try key.signature(for: message)
        let sigB64 = sig.base64URLEncodedString()
        return "ham1.\(payloadB64).\(sigB64)"
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
