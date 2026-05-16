// Generiert die obfuskierten Byte-Arrays für BuildInfo.clubLogApiKey.
//
// Hintergrund: der Club-Log-API-Key gehört zur App, nicht zum User. Er darf
// aber nicht als reine 40-Hex-Konstante im Repo / DMG liegen — Club Log
// scannt nach genau diesem Muster und löscht erkannte Keys automatisch.
// Wir speichern den Key deshalb als XOR zweier Byte-Arrays (Salt + xored).
//
// === Verwendung ===
//   swift tools/obfuscate-clublog-key.swift <api-key>
//
// Beispiel:
//   swift tools/obfuscate-clublog-key.swift 0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33
//
// Output: zwei Swift-Array-Literale, die direkt in BuildInfo.swift in die
// Stellen `clubLogApiKeyXored` und `clubLogApiKeySalt` einkopiert werden.
// Der ursprüngliche Key landet NICHT auf der Festplatte oder im Repo —
// nur die obfuskierten Bytes.

import Foundation

guard CommandLine.arguments.count == 2 else {
    let exe = (CommandLine.arguments.first as NSString?)?.lastPathComponent ?? "obfuscate-clublog-key.swift"
    fputs("Usage: swift \(exe) <api-key>\n", stderr)
    fputs("       (api-key ist der String aus der Helpdesk-Mail, typisch 40 Hex-Zeichen)\n", stderr)
    exit(2)
}

let key = CommandLine.arguments[1].trimmingCharacters(in: .whitespacesAndNewlines)
guard !key.isEmpty else {
    fputs("API-Key ist leer.\n", stderr)
    exit(2)
}

let keyBytes = Array(key.utf8)
let salt: [UInt8] = (0..<keyBytes.count).map { _ in UInt8.random(in: 0...255) }
let xored: [UInt8] = zip(keyBytes, salt).map { $0 ^ $1 }

func formatArray(_ bytes: [UInt8]) -> String {
    let hex = bytes.map { String(format: "0x%02x", $0) }
    var lines: [String] = []
    let perLine = 8
    var i = 0
    while i < hex.count {
        let end = min(i + perLine, hex.count)
        lines.append("        " + hex[i..<end].joined(separator: ", ") + ",")
        i = end
    }
    return lines.joined(separator: "\n")
}

// Round-Trip-Selbsttest: wenn die Bytes nicht zurück zum Original
// dekodieren, ist beim Generieren irgendwas schiefgelaufen.
let roundTrip = zip(xored, salt).map { $0 ^ $1 }
guard String(decoding: roundTrip, as: UTF8.self) == key else {
    fputs("Self-test failed — Bytes nicht inverse. Nicht einbauen!\n", stderr)
    exit(1)
}

print("// Block für BuildInfo.swift — clubLogApiKeyXored:")
print(formatArray(xored))
print()
print("// Block für BuildInfo.swift — clubLogApiKeySalt:")
print(formatArray(salt))
print()

// Status auf stderr, damit stdout sauber für copy-paste bleibt.
fputs("// Self-test passed: round-trip ergibt den eingegebenen Key (\(key.count) Bytes).\n",
      stderr)
