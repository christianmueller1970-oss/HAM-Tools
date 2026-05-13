import Foundation

// Beschreibt einen einzelnen Contest (Exchange-Format + Cabrillo-Defaults).
// Geladen aus Content/contests.json zur App-Startzeit; spätere Etappe 3
// öffnet einen User-Overlay-Folder (~/Library/Application Support/HAM-Tools/contests/).
struct ContestTemplate: Codable, Identifiable, Hashable {
    let id: String                      // "HELVETIA", "CQ-WW-CW" — auch CONTEST: Cabrillo-Header
    let name: String                    // "Helvetia (H26)"
    let sponsor: String?                // "USKA", "CQ Magazine"
    let modeHint: String?               // "CW", "SSB", "Mixed", "RTTY", "Digital", "VHF/UHF"
    let periodHint: String?             // "Last full weekend of April"
    let exchangeFields: [ExchangeFieldSpec]
    let defaultSerialScope: SerialScope
    /// Wenn `nil`, gilt `defaultSerialScope`. Mappt Cabrillo-`CATEGORY-OPERATOR`-String
    /// auf den abweichenden Serial-Scope (z.B. "MULTI-TWO" → `.band` bei CQ-WPX).
    let serialScopeByOperator: [String: SerialScope]?
    let defaultCategories: DefaultCategories?
    let infoURL: String?
    let notes: String?
}

struct ExchangeFieldSpec: Codable, Hashable {
    let key: String              // technischer Schlüssel — z.B. "rst_sent", "canton_sent", "serial_recv"
    let label: String            // UI-Label, z.B. "RST", "Kanton", "Serial"
    let kind: FieldKind
    let role: FieldRole
    let visibility: FieldVisibility?   // default .always
    let autoFill: AutoFillKind?
    let placeholder: String?
    let width: Int?              // UI-Hint in Punkten (default 80)
    let included: Bool?          // wenn false: Feld nur im Cabrillo-Output, nicht im UI rendern
}

/// Stellt einen aufgelösten Sent-/Recv-Wert pro Feld dar — kommt aus
/// `ContestEntryForm` und fließt in `QSO.contestExchangeSent / Recv` ein.
struct ContestExchangeValue: Hashable {
    let key: String
    let value: String
}
