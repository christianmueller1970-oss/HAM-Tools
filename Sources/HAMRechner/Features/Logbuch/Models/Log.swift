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
    var sotaSummitRef: String?
    var role: String?

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
         role: String? = nil,
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
        self.role = role
        self.notes = notes
        self.createdAt = createdAt
    }
}
