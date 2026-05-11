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
    var potaParkRef: String?
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
         potaParkRef: String? = nil,
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
        self.potaParkRef = potaParkRef
        self.sotaSummitRef = sotaSummitRef
        self.role = role
        self.notes = notes
        self.createdAt = createdAt
    }
}
