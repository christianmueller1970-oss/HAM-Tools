import Foundation

// Live-Score-Berechnung für Contest-Logs.
//
// Bewusst pragmatisch: pro Template-ID eine Scoring-Routine. Vollständig
// deklarative JSON-Rules wurden im Plan diskutiert, aber jeder Contest hat
// Quirks (Helvetia Kanton-Sonderbehandlung, WPX-Prefix-Regeln, WAE-QTCs),
// die in einem einzigen Schema entweder mit kompliziertem DSL oder mit
// Custom-Hooks pro Contest landen. Letzteres ist hier direkt im Code —
// gut wartbar, gut testbar, kein 12-Tage-Yak-Shave für ein DSL.
enum ContestScoringEngine {

    /// Punkt-/Multiplier-Aufstellung. Score = points × max(multipliers, 1).
    struct Score {
        let qsoCount: Int
        let points: Int
        let multipliers: Int
        let breakdown: [String: Int]   // Detail-Liste fürs Panel ("Kantone" → 7 etc.)
        var total: Int { points * max(multipliers, 1) }
    }

    static let zero = Score(qsoCount: 0, points: 0, multipliers: 0, breakdown: [:])

    static func score(qsos: [QSO], templateID: String?) -> Score {
        guard !qsos.isEmpty, let id = templateID else { return zero }
        switch id {
        case "HELVETIA":                       return helvetia(qsos)
        case "CQ-WW-CW", "CQ-WW-SSB":          return cqWW(qsos)
        case "CQ-WPX-CW", "CQ-WPX-SSB":        return cqWPX(qsos)
        case "USKA-FD-SSB", "USKA-FD-CW":      return flat1Pt(qsos, label: "QSOs")
        case "USKA-50MHZ":                     return uska50(qsos)
        default:                               return flat1Pt(qsos, label: "QSOs")
        }
    }

    // MARK: - Helvetia (USKA H26)

    /// HB-Stationen: 1 Pkt pro HB-QSO, 3 Pkt pro Non-HB-QSO.
    /// Multiplier: Anzahl unique Kantone aus Recv-Exchange (aus HB-Gegenstationen).
    private static func helvetia(_ qsos: [QSO]) -> Score {
        var points = 0
        var cantons: Set<String> = []
        for q in qsos {
            if isHBCallsign(q.call) {
                points += 1
                if let canton = cantonFromExchange(q.contestExchangeRecv) {
                    cantons.insert(canton.uppercased())
                }
            } else {
                points += 3
            }
        }
        return Score(qsoCount: qsos.count,
                     points: points,
                     multipliers: cantons.count,
                     breakdown: ["Kantone": cantons.count])
    }

    // MARK: - CQ-WW

    /// 1 Pkt own continent / 3 Pkt other continent / 0 Pkt own country.
    /// Multiplier: unique CQ-Zonen × unique DXCC-Countries — pro Band gezählt.
    private static func cqWW(_ qsos: [QSO]) -> Score {
        var points = 0
        var zonesPerBand: [String: Set<Int>] = [:]
        var countriesPerBand: [String: Set<String>] = [:]
        for q in qsos {
            let kind = continentKind(of: q)
            switch kind {
            case .ownCountry:    points += 0
            case .ownContinent:  points += 1
            case .other:         points += 3
            }
            if let zone = q.cqZone {
                zonesPerBand[q.band, default: []].insert(zone)
            }
            if let country = q.country, !country.isEmpty {
                countriesPerBand[q.band, default: []].insert(country)
            }
        }
        let zoneMult    = zonesPerBand.values.reduce(0) { $0 + $1.count }
        let countryMult = countriesPerBand.values.reduce(0) { $0 + $1.count }
        let mults = zoneMult + countryMult
        return Score(qsoCount: qsos.count,
                     points: points,
                     multipliers: mults,
                     breakdown: [
                        "Zonen (per Band)": zoneMult,
                        "Länder (per Band)": countryMult
                     ])
    }

    // MARK: - CQ-WPX

    /// 1/3/6 Pkt-Schema wie CQ-WW. Multiplier: unique Präfixe (Etappe-2-Heuristik).
    private static func cqWPX(_ qsos: [QSO]) -> Score {
        var points = 0
        var prefixes: Set<String> = []
        for q in qsos {
            switch continentKind(of: q) {
            case .ownCountry:    points += 1
            case .ownContinent:  points += 3
            case .other:         points += 6
            }
            if let pfx = wpxPrefix(q.call) {
                prefixes.insert(pfx)
            }
        }
        return Score(qsoCount: qsos.count,
                     points: points,
                     multipliers: prefixes.count,
                     breakdown: ["Präfixe": prefixes.count])
    }

    // MARK: - USKA 50 MHz

    /// 1 Pkt pro QSO. Multiplier: unique 4-stellige Grid-Squares aus Recv-Exchange.
    private static func uska50(_ qsos: [QSO]) -> Score {
        var grids: Set<String> = []
        for q in qsos {
            if let g = gridSquareFromExchange(q.contestExchangeRecv) {
                grids.insert(g)
            }
        }
        return Score(qsoCount: qsos.count,
                     points: qsos.count,
                     multipliers: grids.count,
                     breakdown: ["Grid-Squares (4)": grids.count])
    }

    // MARK: - Generic 1-Punkt Fallback

    private static func flat1Pt(_ qsos: [QSO], label: String) -> Score {
        Score(qsoCount: qsos.count,
              points: qsos.count,
              multipliers: 0,
              breakdown: [label: qsos.count])
    }

    // MARK: - Helpers

    private enum ContinentKind { case ownCountry, ownContinent, other }

    /// Heuristik für unseren HB-User (HB9HJI): own country = HB, own continent = EU.
    /// Wenn QSO-Continent leer ist und das Call kein HB ist, wird "other" angenommen
    /// — das ist konservativ (höhere geschätzte Punkte, aber kein false-low).
    private static func continentKind(of q: QSO) -> ContinentKind {
        if isHBCallsign(q.call) { return .ownCountry }
        let cont = (q.continent ?? "").uppercased()
        if cont == "EU" { return .ownContinent }
        return .other
    }

    /// "599 ZH" → "ZH". Nimmt das letzte Token mit 2 Buchstaben.
    private static func cantonFromExchange(_ exchange: String?) -> String? {
        guard let raw = exchange?.trimmingCharacters(in: .whitespaces), !raw.isEmpty
        else { return nil }
        let tokens = raw.split(separator: " ").map(String.init)
        return tokens.first { token in
            token.count == 2 && token.allSatisfy { $0.isLetter }
        }
    }

    /// "599 JN47PN 001" → "JN47" (erstes 4-stelliges Grid).
    private static func gridSquareFromExchange(_ exchange: String?) -> String? {
        guard let raw = exchange?.trimmingCharacters(in: .whitespaces), !raw.isEmpty
        else { return nil }
        let tokens = raw.split(separator: " ").map(String.init)
        return tokens.first { token in
            (token.count == 4 || token.count == 6)
                && isMaidenheadPrefix(token)
        }.map { String($0.prefix(4)).uppercased() }
    }

    /// 4er-Maidenhead: 2 Letters + 2 Digits.
    private static func isMaidenheadPrefix(_ s: String) -> Bool {
        let chars = Array(s.uppercased())
        guard chars.count >= 4 else { return false }
        return chars[0].isLetter && chars[1].isLetter
            && chars[2].isNumber && chars[3].isNumber
    }

    /// CQ-WPX-Präfix-Heuristik: nimmt das Call und schneidet beim letzten
    /// Buchstabenblock VOR der ersten Ziffer + die erste Zifferngruppe ab.
    /// Beispiele:
    ///   HB9HJI    → "HB9"
    ///   DL/HB9HJI → "DL0"   (portable im Ausland → /-prefix mit künstlicher 0)
    ///   K1AA      → "K1"
    ///   2E0XYZ    → "2E0"
    /// Für die genauen Regeln siehe CQ-WPX Rules; das hier ist die häufigste Form.
    static func wpxPrefix(_ call: String) -> String? {
        let upper = call.uppercased().trimmingCharacters(in: .whitespaces)
        guard !upper.isEmpty else { return nil }
        // Portable mit "/" — beide Seiten beachten. Wir nehmen den linken Teil,
        // wenn er "kürzer" wirkt (Indikator für Country-Prefix vorne).
        if upper.contains("/") {
            let parts = upper.split(separator: "/").map(String.init)
            if let first = parts.first, !first.isEmpty,
               first.count < (parts.dropFirst().first?.count ?? 99) {
                return first.contains(where: \.isNumber) ? first : first + "0"
            }
            // Default: Präfix aus dem Hauptcall (rechter Teil bei "DL/HB9HJI")
            return wpxPrefix(parts.dropFirst().first ?? "")
        }
        // Erste Ziffergruppe und alle Buchstaben davor übernehmen.
        var prefix = ""
        var sawDigit = false
        for ch in upper {
            if ch.isNumber {
                prefix.append(ch)
                sawDigit = true
            } else if ch.isLetter {
                if sawDigit { break }
                prefix.append(ch)
            }
        }
        return prefix.isEmpty ? nil : prefix
    }
}
