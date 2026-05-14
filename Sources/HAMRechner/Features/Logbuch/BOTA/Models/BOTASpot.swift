import Foundation

// BOTA-Spot, abgeleitet aus DXSpot wenn der Comment eine BOTA-Reference
// enthält. Analoge Architektur zu WWFFSpot: kein eigenes API-Endpoint,
// stattdessen DX-Cluster-Filter mit Pattern-Erkennung + DB-Lookup.
struct BOTASpot: Identifiable, Hashable {
    let id: UUID
    let dxCall: String
    let reference: String
    let frequencyMHz: Double
    let band: String
    let mode: String
    let comments: String
    let spotter: String
    let timeStamp: Date

    var isAutomaticSpot: Bool {
        spotter.uppercased().hasSuffix("-#")
            || spotter.uppercased().contains("RBN")
            || spotter.uppercased().contains("SKIMMER")
    }

    init(from dx: DXSpot, reference: String) {
        self.id = dx.id
        self.dxCall = dx.dxCall
        self.reference = reference.uppercased()
        self.frequencyMHz = dx.frequency / 1000.0
        self.band = dx.band
        self.mode = dx.mode
        self.comments = dx.comment
        self.spotter = dx.spotter
        self.timeStamp = dx.timestamp
    }
}
