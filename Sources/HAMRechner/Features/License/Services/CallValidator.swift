import Foundation

// Substring-/Segment-Validierung für Portabel- und Ausland-Calls.
//
// Eingaben wie `DL/HB9HJI/P` oder `F/HB9HJI/MM` werden an `/` gesplittet;
// gültig ist der Call, sobald ein Segment exakt einem lizenzierten Base-Call
// entspricht. Damit erlauben wir Country-Prefixe und Suffixe ohne die
// Lizenz-Pflicht aufzuweichen.
//
// Diese Logik wird sowohl von der globalen Lizenz-Validierung (LicenseService)
// als auch vom Log-Wizard für `Log.usedCallsign` (1.8.2 Phase C) genutzt.
enum CallValidator {

    /// Liefert true, wenn `call` durch die Lizenz-Liste gedeckt ist.
    /// Vergleich Case-insensitive, Whitespace wird getrimmt.
    static func isLicensed(call: String, licensedCalls: [String]) -> Bool {
        let normalized = normalize(call)
        guard !normalized.isEmpty else { return false }

        let licensed = licensedCalls
            .map { normalize($0) }
            .filter { !$0.isEmpty }
        guard !licensed.isEmpty else { return false }

        for segment in normalized.split(separator: "/").map(String.init) {
            let seg = segment.trimmingCharacters(in: .whitespaces)
            if licensed.contains(seg) {
                return true
            }
        }
        return false
    }

    private static func normalize(_ s: String) -> String {
        s.uppercased().trimmingCharacters(in: .whitespaces)
    }
}
