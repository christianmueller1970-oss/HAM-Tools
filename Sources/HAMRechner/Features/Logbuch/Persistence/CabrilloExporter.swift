import Foundation

// Cabrillo V3 Export — Format für Contest-Log-Einreichungen
// (ARRL, CQ, IARU, etc.). Spec: https://wwrof.org/cabrillo/
//
// Aufbau:
//   START-OF-LOG: 3.0
//   <Header-Tags>
//   QSO: freq mo date time my-call my-rst my-exch their-call their-rst their-exch
//   ...
//   END-OF-LOG:
struct CabrilloHeader {
    var contestID:      String         // z.B. »CQ-WW-CW«, »WPX-SSB«, »ARRL-DX-CW«
    var callsign:       String
    var operatorName:   String         // Voller Name
    var email:          String
    var gridLocator:    String
    var location:       String         // ARRL Section / Country / etc.
    var categoryOperator: String       // SINGLE-OP / MULTI-OP-SINGLE / etc.
    var categoryBand:    String        // ALL / 20M / 10M / etc.
    var categoryMode:    String        // CW / SSB / MIXED / DIGI
    var categoryPower:   String        // HIGH / LOW / QRP
    var categoryStation: String        // FIXED / PORTABLE / MOBILE / etc.
    var categoryTime:    String        // 24-HOURS / 12-HOURS / 6-HOURS
    var claimedScore:    Int?
    var club:            String
    var soapbox:         String
    var sentExchange:    String        // Standard-Sent-Exch (z.B. »14« für CQ-WW)
}

enum CabrilloExporter {

    static let createdBy = "HAM-Tools 1.5"

    /// Generiert Cabrillo-Text. QSOs werden chronologisch sortiert.
    static func encode(qsos: [QSO], header: CabrilloHeader) -> String {
        let sorted = qsos.sorted { $0.datetime < $1.datetime }
        var s = "START-OF-LOG: 3.0\n"
        s += headerLine("CONTEST",            header.contestID)
        s += headerLine("CALLSIGN",           header.callsign)
        s += headerLine("OPERATORS",          header.callsign)
        if !header.operatorName.isEmpty { s += headerLine("NAME", header.operatorName) }
        if !header.email.isEmpty        { s += headerLine("EMAIL", header.email) }
        if !header.gridLocator.isEmpty  { s += headerLine("GRID-LOCATOR", header.gridLocator) }
        if !header.location.isEmpty     { s += headerLine("LOCATION", header.location) }
        s += headerLine("CATEGORY-OPERATOR",  header.categoryOperator)
        s += headerLine("CATEGORY-BAND",      header.categoryBand)
        s += headerLine("CATEGORY-MODE",      header.categoryMode)
        s += headerLine("CATEGORY-POWER",     header.categoryPower)
        s += headerLine("CATEGORY-STATION",   header.categoryStation)
        s += headerLine("CATEGORY-TIME",      header.categoryTime)
        if let score = header.claimedScore   { s += headerLine("CLAIMED-SCORE", String(score)) }
        if !header.club.isEmpty              { s += headerLine("CLUB", header.club) }
        s += headerLine("CREATED-BY",         createdBy)
        for line in header.soapbox.split(separator: "\n") {
            s += headerLine("SOAPBOX", String(line))
        }

        for qso in sorted {
            s += qsoLine(qso, myCall: header.callsign, sentExch: header.sentExchange)
        }
        s += "END-OF-LOG:\n"
        return s
    }

    // MARK: - Format Helpers

    private static func headerLine(_ tag: String, _ value: String) -> String {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(tag): \(v)\n"
    }

    private static func qsoLine(_ q: QSO, myCall: String, sentExch: String) -> String {
        // Spec: freq (kHz) mo date(yyyy-MM-dd) time(HHMM)
        //       my-call my-rst my-exch their-call their-rst their-exch
        let freqKHz = Int((q.frequencyMHz * 1000).rounded())
        let mode = cabrilloMode(q.mode)
        let dateF = DateFormatter()
        dateF.timeZone = TimeZone(identifier: "UTC")
        dateF.dateFormat = "yyyy-MM-dd"
        let timeF = DateFormatter()
        timeF.timeZone = TimeZone(identifier: "UTC")
        timeF.dateFormat = "HHmm"

        let dateStr = dateF.string(from: q.datetime)
        let timeStr = timeF.string(from: q.datetime)

        // Per-QSO-Exchange (Etappe 1) hat Vorrang vor dem Default-Header-Wert.
        // Legacy: alter contestExchange auf der QSO landete vor der Etappe-1-Migration
        // im Recv-Feld, daher Fallback dorthin.
        let myExch    = q.contestExchangeSent?.trimmingCharacters(in: .whitespaces).nilIfEmpty
                     ?? (sentExch.isEmpty ? "—" : sentExch)
        let theirExch = q.contestExchangeRecv?.trimmingCharacters(in: .whitespaces).nilIfEmpty
                     ?? q.contestExchange?.trimmingCharacters(in: .whitespaces).nilIfEmpty
                     ?? (q.cqZone.map { String(format: "%02d", $0) } ?? "—")

        // Loose-format mit Single-Space, Spaltenausrichtung über padding
        return String(
            format: "QSO: %5d %@ %@ %@ %-13@ %-3@ %-6@ %-13@ %-3@ %-6@\n",
            freqKHz, mode, dateStr, timeStr,
            myCall.padded(13),
            q.rstSent.padded(3),
            myExch.padded(6),
            q.call.padded(13),
            q.rstReceived.padded(3),
            theirExch.padded(6)
        )
    }

    private static func cabrilloMode(_ qsoMode: String) -> String {
        switch qsoMode.uppercased() {
        case "CW": return "CW"
        case "SSB", "USB", "LSB", "AM", "FM": return "PH"
        case "RTTY":                          return "RY"
        default:                              return "DG"  // FT8, FT4, PSK, JS8, etc.
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespaces).isEmpty ? nil : self
    }
    func padded(_ len: Int) -> String {
        if count >= len { return String(prefix(len)) }
        return self + String(repeating: " ", count: len - count)
    }
}
