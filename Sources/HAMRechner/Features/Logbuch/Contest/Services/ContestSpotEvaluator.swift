import Foundation

// Klassifiziert einen DX-Spot aus Sicht des aktiven Contest-Logs.
//   .dupe         → Call+Band+Mode bereits geloggt → rot
//   .multiplier   → liefert (vermutlich) einen neuen Multiplikator → grün
//   .normal       → weder Dupe noch Mult — Standard-Farbe
//
// Multiplier-Heuristik pro Template-ID — bewusst pragmatisch ohne CQ-Zone-
// Lookup (die haben wir im Spot nicht), nutzt stattdessen DXCC-Country und
// für WPX den WPX-Präfix. Reicht für die UX (grün = "vermutlich neu, lohnt
// sich"), der echte Mult-Count im Stats-Panel ist die Wahrheit.
enum ContestSpotStatus {
    case normal
    case dupe
    case multiplier
}

enum ContestSpotEvaluator {

    static func status(for spot: DXSpot,
                       in qsos: [QSO],
                       template: ContestTemplate?) -> ContestSpotStatus {
        let call = spot.dxCall.uppercased()
        let band = spot.band.uppercased()
        let mode = spot.mode.uppercased()

        // Dupe-Check: Call + Band + Mode bereits geloggt.
        if qsos.contains(where: { q in
            q.call.uppercased() == call
                && q.band.uppercased() == band
                && q.mode.uppercased() == mode
        }) {
            return .dupe
        }

        guard let tpl = template else { return .normal }

        switch tpl.id {
        case "CQ-WPX-CW", "CQ-WPX-SSB":
            // WPX-Multiplier: unique Präfixe gesamt — egal welches Band.
            guard let pfx = ContestScoringEngine.wpxPrefix(call) else { return .normal }
            let used = Set(qsos.compactMap { ContestScoringEngine.wpxPrefix($0.call) })
            return used.contains(pfx) ? .normal : .multiplier

        case "CQ-WW-CW", "CQ-WW-SSB":
            // CQ-WW-Multiplier: Country pro Band (Zone-Info haben wir im Spot nicht
            // zuverlässig — Country-Heuristik fängt einen großen Teil ab).
            return isNewCountryOnBand(spot: spot, band: band, qsos: qsos)

        case "HELVETIA":
            // HB-Operator: für HB-Spots ist der Kanton der Mult — den haben wir aus
            // dem Spot nicht. Für DX-Spots ist DXCC-Country pro Band der Indikator.
            return isNewCountryOnBand(spot: spot, band: band, qsos: qsos)

        default:
            // Fallback: DXCC-Country pro Band als Multiplier-Indikator.
            return isNewCountryOnBand(spot: spot, band: band, qsos: qsos)
        }
    }

    private static func isNewCountryOnBand(spot: DXSpot,
                                           band: String,
                                           qsos: [QSO]) -> ContestSpotStatus {
        guard !spot.country.isEmpty else { return .normal }
        let used = Set(qsos
            .filter { $0.band.uppercased() == band }
            .compactMap { $0.country })
        return used.contains(spot.country) ? .normal : .multiplier
    }
}
