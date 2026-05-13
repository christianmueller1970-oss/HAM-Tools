import Foundation
import CryptoKit

// Lokale Ablage des Private-Key-Pairs.
//
// Pfad: ~/Library/Application Support/HAM-Tools License Generator/keypair.json
// Inhalt: { "privateKey": "<base64>", "publicKey": "<base64>" }
//
// **Wichtig**: Diese Datei NIE in das HAM-Tools-Repo committen oder weitergeben.
// Wenn der Private Key bekannt wird, könnte jemand selbst Lizenzen signieren.
enum KeyStore {

    struct Pair: Codable {
        var privateKey: String   // Base64(32 bytes)
        var publicKey:  String   // Base64(32 bytes)
    }

    static var fileURL: URL {
        let fm = FileManager.default
        let support = try? fm.url(for: .applicationSupportDirectory,
                                  in: .userDomainMask,
                                  appropriateFor: nil, create: true)
        let dir = (support ?? fm.temporaryDirectory)
            .appendingPathComponent("HAM-Tools License Generator", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("keypair.json")
    }

    /// Liest das vorhandene Schlüsselpaar — `nil` wenn noch keins generiert wurde.
    static func load() -> Pair? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Pair.self, from: data)
    }

    /// Erzeugt + speichert ein neues Ed25519-Pair. Überschreibt ein vorhandenes.
    @discardableResult
    static func generateNew() throws -> Pair {
        let priv = Curve25519.Signing.PrivateKey()
        let pub  = priv.publicKey
        let pair = Pair(
            privateKey: priv.rawRepresentation.base64EncodedString(),
            publicKey:  pub.rawRepresentation.base64EncodedString()
        )
        let data = try JSONEncoder().encode(pair)
        try data.write(to: fileURL, options: .atomic)
        // POSIX 0600 — nur User-readable
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: fileURL.path
        )
        return pair
    }

    /// Wandelt das gespeicherte Pair in eine CryptoKit-Private-Key-Instanz.
    static func signingKey(from pair: Pair) throws -> Curve25519.Signing.PrivateKey {
        guard let raw = Data(base64Encoded: pair.privateKey) else {
            throw NSError(domain: "KeyStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Privater Key ist kein gültiges Base64"])
        }
        return try Curve25519.Signing.PrivateKey(rawRepresentation: raw)
    }
}
