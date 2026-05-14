import Foundation
import SwiftUI

// Bridge zwischen DX-Cluster (oder anderen Modulen) und dem QSO-Eingabe-
// Panel im Logbuch. Funktioniert analog zur AntennaSimBridge: setzt einen
// Draft + triggert via navigationRequest den Wechsel zum Logbuch-Tab.
//
// Verwendung:
//   LogEntryBridge.shared.openInLog(from: spot)
//   → ContentView lauscht und schaltet auf .logbuch
//   → QSOEntryPanel zieht den Draft im onAppear / onChange
final class LogEntryBridge: ObservableObject {
    @Published var pendingDraft: QSODraft? = nil
    @Published var navigationRequest: UUID? = nil

    // POTA-spezifisch: eigener Slot, weil das POTA-Form anders aufgebaut
    // ist (eigene @State-Felder) als das DX-Form.
    @Published var pendingPotaSpot: POTASpot? = nil

    // SOTA-spezifisch: analog POTA-Slot. Das SOTA-Form hat Their-Summit-
    // Autocomplete + Punkte-Lookup, das hier auslöst.
    @Published var pendingSotaSpot: SOTASpot? = nil


    static let shared = LogEntryBridge()
    private init() {}

    func openInLog(from memory: Memory) {
        var draft = QSODraft(call: memory.call)
        draft.frequencyMHz = memory.frequencyMHz
        draft.band = memory.band
        draft.mode = memory.mode
        draft.spotComment = memory.notes
        pendingDraft = draft
        navigationRequest = UUID()
    }

    func openInLog(from spot: DXSpot) {
        var draft = QSODraft(call: spot.dxCall)
        // DXSpot.frequency ist in kHz.
        draft.frequencyMHz = spot.frequency / 1000.0
        draft.band = spot.band
        draft.mode = spot.mode
        draft.country = spot.country
        draft.spotterCall = spot.spotter

        // POTA/SOTA/WWFF-Ref aus dem Spot-Kommentar extrahieren.
        let (sota, pota, wwff) = Self.extractRefs(from: spot.comment,
                                                  sourceType: spot.sourceType)
        draft.mySotaRef = sota   // NB: aus Sicht des Spots ist es dessen Activator-Ref —
        draft.myPotaRef = pota   // beim Hunten landet das tatsächlich im "their"-Feld
        draft.myWwffRef = wwff   // (siehe applyTo()). Hier nur als Bestpath-Pre-Fill.

        draft.spotComment = spot.comment

        pendingDraft = draft
        navigationRequest = UUID()
    }

    func consume() -> QSODraft? {
        let d = pendingDraft
        pendingDraft = nil
        return d
    }

    // MARK: - Reference-Extraction

    // Regex-Defs einmal, wiederverwendet
    private static let sotaPattern = try! NSRegularExpression(
        pattern: #"\b([A-Z0-9]{1,4})/([A-Z0-9]{1,4})-(\d{1,4})\b"#)
    private static let potaPattern = try! NSRegularExpression(
        pattern: #"\b([A-Z0-9]{1,3})-(\d{2,5})\b"#)
    private static let wwffPattern = try! NSRegularExpression(
        pattern: #"\b([A-Z0-9]{1,3}FF)-(\d{2,5})\b"#)

    static func extractRefs(from comment: String, sourceType: String)
        -> (sota: String?, pota: String?, wwff: String?) {
        let range = NSRange(comment.startIndex..., in: comment)

        // WWFF zuerst suchen — Pattern ist spezifischer als POTA
        var wwff: String?
        if let m = wwffPattern.firstMatch(in: comment, range: range),
           let r = Range(m.range, in: comment) {
            wwff = String(comment[r])
        }

        var sota: String?
        if let m = sotaPattern.firstMatch(in: comment, range: range),
           let r = Range(m.range, in: comment) {
            sota = String(comment[r])
        }

        // POTA Pattern matched fast alles — nur nehmen wenn es kein WWFF/SOTA-Match war
        var pota: String?
        if sourceType == "POTA" || comment.uppercased().contains("POTA") {
            if let m = potaPattern.firstMatch(in: comment, range: range),
               let r = Range(m.range, in: comment) {
                let candidate = String(comment[r])
                if candidate != wwff && !candidate.contains("/") {
                    pota = candidate
                }
            }
        }

        return (sota, pota, wwff)
    }
}

// MARK: - QSODraft

// Träger für Pre-Fill-Daten von Spot → Eingabeformular.
// Optional weil nicht jeder Aufruf alle Felder kennt.
struct QSODraft {
    var call: String
    var frequencyMHz: Double? = nil
    var band: String? = nil
    var mode: String? = nil
    var country: String? = nil
    var spotterCall: String? = nil
    var spotComment: String? = nil
    var mySotaRef: String? = nil
    var myPotaRef: String? = nil
    var myWwffRef: String? = nil
}
