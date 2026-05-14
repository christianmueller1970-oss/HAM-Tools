import Foundation

// WWFF-Spot. Im Gegensatz zu POTA/SOTA gibt es kein dediziertes offenes
// API — wir derivieren WWFF-Spots aus dem regulären DX-Cluster-Stream,
// indem wir Spot-Kommentare nach WWFF-Refs durchsuchen (Pattern siehe
// LogEntryBridge.wwffPattern).
//
// Das Modell ist leichter als SOTASpot/POTASpot — keine API-Decoder,
// keine Custom-Serialization. WWFFSpotsView baut Instances zur Rendezeit
// aus DXSpot + extrahierter Ref.
struct WWFFSpot: Identifiable, Hashable {
    let id: UUID          // entspricht DXSpot.id für stabile Selection
    let dxCall: String    // Activator-Call aus DXSpot.dxCall
    let reference: String // Extrahierte WWFF-Ref aus dem Spot-Kommentar
    let frequencyMHz: Double
    let band: String
    let mode: String
    let comments: String
    let spotter: String   // Wer den Spot eingetragen hat
    let timeStamp: Date

    // Automatische Cluster-Bot-Spots (Skimmer / RBN) sind unter WWFF
    // selten relevant — wird optional zur Filter-Markierung genutzt.
    var isAutomaticSpot: Bool {
        spotter.uppercased().hasSuffix("-#")
            || spotter.uppercased().contains("RBN")
            || spotter.uppercased().contains("SKIMMER")
    }

    // Bequeme Init aus einem DXSpot + bereits extrahierter Ref.
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
