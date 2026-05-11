import Foundation

// Memory = Schnellzugriffs-Karte. Im Contest oder Sked-Workflow kann der
// User damit häufige Calls / Sked-Notizen anlegen und mit einem Klick
// das QSO-Form vorausfüllen.
struct Memory: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String            // Eigene Bezeichnung, z.B. »HB9XYZ Field Day«
    var call: String             // Pflicht
    var name: String?
    var frequencyMHz: Double?
    var band: String?
    var mode: String?
    var skedDate: Date?          // Falls ein Termin angesetzt ist
    var notes: String?
    var pinned: Bool
    let createdAt: Date
    var lastUsedAt: Date?

    init(id: UUID = UUID(),
         label: String,
         call: String,
         name: String? = nil,
         frequencyMHz: Double? = nil,
         band: String? = nil,
         mode: String? = nil,
         skedDate: Date? = nil,
         notes: String? = nil,
         pinned: Bool = false,
         createdAt: Date = Date(),
         lastUsedAt: Date? = nil) {
        self.id = id
        self.label = label
        self.call = call.uppercased()
        self.name = name
        self.frequencyMHz = frequencyMHz
        self.band = band
        self.mode = mode
        self.skedDate = skedDate
        self.notes = notes
        self.pinned = pinned
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}
