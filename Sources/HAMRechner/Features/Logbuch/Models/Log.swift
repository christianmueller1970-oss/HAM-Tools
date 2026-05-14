import Foundation

// Container für QSOs. Jeder Log hat einen Typ (Standard / Contest / POTA / SOTA).
// Phase 1 (MVP): nur Standard aktiv. Andere Typen sind im Schema schon angelegt.
struct Log: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var type: LogType
    var startDate: Date
    var endDate: Date?

    // Typ-spezifische Felder — in MVP ungenutzt, in späteren Phasen aktiviert.
    var contestID: String?
    var contestCategory: String?
    var contestSerialScope: String?    // "log" | "band" — Override des Template-Defaults aus Multi-Op-Kategorie
    var contestModeCategory: String?   // "CW" | "PH" | "RY" | "DG" | "FM" | "MIXED" — vom Wizard gewählt
    var potaParkRef: String?       // primärer Park (auch der einzige bei Non-Hopping)
    var potaParkRefs: String?      // Komma-Liste aller Parks (Multi-Park-Hopping), inkl. primärer; nil bei Single-Park
    var sotaSummitRef: String?     // primärer Summit (auch der einzige bei Non-Hopping)
    var sotaSummitRefs: String?    // Komma-Liste aller Summits (Multi-Summit-Hopping); nil bei Single-Summit
    var wwffRef: String?           // primäre WWFF-Ref
    var wwffRefs: String?          // Komma-Liste bei Multi-Ref-Aktivierung
    var botaRef: String?           // primäre BOTA-Ref
    var botaRefs: String?          // Komma-Liste bei Multi-Bunker-Aktivierung
    var role: String?

    // Pro-Log-Callsign (1.8.2): überschreibt den globalen Settings-Default,
    // damit Portabel- (HB9HJI/P), Ausland- (DL/HB9HJI) oder Club-Calls pro
    // Log möglich sind, ohne die Settings dauerhaft umzustellen. nil → Fallback
    // auf `@AppStorage("callsign")`. Validierung gegen die Lizenz erfolgt
    // beim Wizard via CallValidator (Substring-Match an "/").
    var usedCallsign: String?

    // OP-Liste pro Contest-Log (Multi-Op-Workflow, 1.8.2). Komma-getrennter
    // String, beim Anlegen definiert. Befüllt das OP-Switcher-Dropdown im
    // ContestEntryForm und damit qso.operatorCall. Diese Calls brauchen
    // KEINE eigene Lizenz — sind reine Strings für Cabrillo/Statistik.
    var contestOperators: String?

    var notes: String?
    let createdAt: Date

    init(id: UUID = UUID(),
         name: String,
         type: LogType = .standard,
         startDate: Date = Date(),
         endDate: Date? = nil,
         contestID: String? = nil,
         contestCategory: String? = nil,
         contestSerialScope: String? = nil,
         contestModeCategory: String? = nil,
         potaParkRef: String? = nil,
         potaParkRefs: String? = nil,
         sotaSummitRef: String? = nil,
         sotaSummitRefs: String? = nil,
         wwffRef: String? = nil,
         wwffRefs: String? = nil,
         botaRef: String? = nil,
         botaRefs: String? = nil,
         role: String? = nil,
         usedCallsign: String? = nil,
         contestOperators: String? = nil,
         notes: String? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.contestID = contestID
        self.contestCategory = contestCategory
        self.contestSerialScope = contestSerialScope
        self.contestModeCategory = contestModeCategory
        self.potaParkRef = potaParkRef
        self.potaParkRefs = potaParkRefs
        self.sotaSummitRef = sotaSummitRef
        self.sotaSummitRefs = sotaSummitRefs
        self.wwffRef = wwffRef
        self.wwffRefs = wwffRefs
        self.botaRef = botaRef
        self.botaRefs = botaRefs
        self.role = role
        self.usedCallsign = usedCallsign
        self.contestOperators = contestOperators
        self.notes = notes
        self.createdAt = createdAt
    }
}
