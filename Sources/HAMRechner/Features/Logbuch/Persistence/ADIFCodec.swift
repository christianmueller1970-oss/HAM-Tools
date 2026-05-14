import Foundation

// ADIF 3.x Codec: Encoder (QSOs → ADIF-Text) + Parser (ADIF-Text → Felder-Dicts).
// Spec: https://adif.org/315/ADIF_315.htm
//
// Format-Grundlage:
//   <TAG:LEN>value <TAG:LEN:TYPE>value ... <EOR>
//   Header endet mit <EOH>, dann Records.
//   Längen sind UTF-8-Byte-Anzahl.
enum ADIFCodec {

    static let appVersion = "HAM-Tools 1.5"

    // MARK: - Export

    static func encode(qsos: [QSO], logName: String) -> String {
        // ADIF-Header: laut Spec ist alles vor dem ersten Tag bzw. <EOH>
        // Header-Text. Manche strikte Parser akzeptieren aber kein Free-Text
        // vor dem ersten Tag. Wir bleiben deshalb minimal und schreiben den
        // beschreibenden Kommentar als ADIF-konformen Kommentar-Header
        // (alles vor dem ersten "<" ist erlaubt, aber wir verzichten ganz
        // drauf für maximale Kompatibilität).
        var out = field("ADIF_VER", "3.1.5")
        out += field("PROGRAMID", "HAM-Tools")
        out += field("PROGRAMVERSION", appVersion)
        out += field("CREATED_TIMESTAMP", adifTimestamp(Date()))
        out += field("APP_HAMTOOLS_LOGNAME", logName)
        out += "<EOH>\n\n"

        for qso in qsos {
            out += encodeRecord(qso)
            out += "\n"
        }
        return out
    }

    private static func encodeRecord(_ q: QSO) -> String {
        var s = ""
        // Pflichtfelder
        s += field("CALL", q.call)
        s += field("QSO_DATE", dateField(q.datetime))
        s += field("TIME_ON", timeField(q.datetime))
        // pota.app + viele Logger erwarten DATE_OFF/TIME_OFF auch wenn das
        // QSO nur einen Zeitstempel hat — wir spiegeln TIME_ON in OFF.
        s += field("QSO_DATE_OFF", dateField(q.datetime))
        s += field("TIME_OFF", timeField(q.datetime))
        s += field("BAND", q.band)
        s += field("FREQ", String(format: "%.6f", q.frequencyMHz))
        s += field("MODE", q.mode)
        s += field("RST_SENT", q.rstSent)
        s += field("RST_RCVD", q.rstReceived)

        // Optional-Felder
        if let v = q.name        { s += field("NAME", v) }
        if let v = q.qth         { s += field("QTH", v) }
        if let v = q.locator     { s += field("GRIDSQUARE", v) }
        if let v = q.country     { s += field("COUNTRY", v) }
        if let v = q.continent   { s += field("CONT", v) }
        if let v = q.cqZone      { s += field("CQZ", String(v)) }
        if let v = q.ituZone     { s += field("ITUZ", String(v)) }
        if let v = q.comment     { s += field("COMMENT", v) }
        // OPERATOR + STATION_CALLSIGN: pota.app + LoTW erwarten beide.
        // Fallback auf App-Settings (Stations-Tab → callsign) falls das
        // QSO selber keinen Wert hat (z.B. vor dem Phase-4c-Fix gespeicherte
        // Records).
        let settingsCall = UserDefaults.standard.string(forKey: "callsign")?
            .trimmingCharacters(in: .whitespaces).uppercased()
        if let v = q.operatorCall, !v.isEmpty {
            s += field("OPERATOR", v)
        } else if let v = settingsCall, !v.isEmpty {
            s += field("OPERATOR", v)
        }
        if let v = q.stationCall, !v.isEmpty {
            s += field("STATION_CALLSIGN", v)
        } else if let v = settingsCall, !v.isEmpty {
            s += field("STATION_CALLSIGN", v)
        }
        if let v = q.powerW      { s += field("TX_PWR", String(format: "%g", v)) }
        if let v = q.antenna     { s += field("ANTENNA", v) }
        if let v = q.contest     { s += field("CONTEST_ID", v) }
        // Contest-Exchange (Etappe 1): eigener Serial → STX, voller Sent/Recv → STX_STRING/SRX_STRING.
        // Wenn die neuen Felder leer sind, fällt der Code auf den Legacy-`contestExchange` zurück,
        // damit Logs aus der Vor-Etappe-1-Zeit weiter exportierbar bleiben.
        if let v = q.contestSerial          { s += field("STX", String(v)) }
        if let v = q.contestExchangeSent    { s += field("STX_STRING", v) }
        let recvEx = q.contestExchangeRecv ?? q.contestExchange
        if let v = recvEx                   { s += field("SRX_STRING", v) }
        if let v = q.distanceKm  { s += field("DISTANCE", String(format: "%.0f", v)) }
        if let v = q.bearingDeg  { s += field("ANT_AZ", String(format: "%.0f", v)) }

        // POTA — sowohl spezifische als auch generische SIG-Felder schreiben
        // (verschiedene Logger lesen das unterschiedlich).
        // Multi-Park-Hopping: myPotaRefs (Komma-Liste) wird, wenn gesetzt,
        // bevorzugt — entspricht POTA-ADIF-Spec für MY_POTA_REF mit Komma.
        let myPota = (q.myPotaRefs?.isEmpty == false ? q.myPotaRefs : q.myPotaRef) ?? ""
        if !myPota.isEmpty {
            s += field("MY_SIG", "POTA")
            s += field("MY_SIG_INFO", myPota)
            s += field("MY_POTA_REF", myPota)
            // pota.app empfiehlt MY_GRIDSQUARE — übernimm Locator aus App-
            // Settings (Stations-Tab → qthLocator).
            if let myGrid = UserDefaults.standard.string(forKey: "qthLocator")?
                .trimmingCharacters(in: .whitespaces), !myGrid.isEmpty {
                s += field("MY_GRIDSQUARE", myGrid)
            }
        }
        if let v = q.theirPotaRef, !v.isEmpty {
            s += field("SIG", "POTA")
            s += field("SIG_INFO", v)
            s += field("POTA_REF", v)
        }
        // SOTA — analog POTA strukturiert, mit MY_SIG für maximale
        // Kompatibilität (manche Logger lesen nur SIG, nicht das spezifische
        // MY_SOTA_REF-Feld). MY_SIG-Konflikt mit POTA: wenn beides gesetzt
        // ist, gewinnt POTA (wir schreiben SOTA danach). Realistisch passiert
        // das praktisch nie — ein QSO ist entweder auf einem Park oder einem
        // Summit, selten auf beidem gleichzeitig.
        //
        // Multi-Summit-Hopping: SOTA-Regeln zählen Aktivierungen pro Summit
        // getrennt. Im ADIF schreiben wir den primären Summit (mySotaRef
        // bzw. erster Eintrag aus mySotaRefs). Pro-Summit-Aufteilung für
        // sotadata.org.uk-Upload macht der CSV-Export in Phase 6.
        let mySotaPrimary: String? = {
            if let raw = q.mySotaRef?.trimmingCharacters(in: .whitespaces),
               !raw.isEmpty { return raw }
            if let multi = q.mySotaRefs?.split(separator: ",").first {
                let s = String(multi).trimmingCharacters(in: .whitespaces)
                return s.isEmpty ? nil : s
            }
            return nil
        }()
        if let v = mySotaPrimary {
            s += field("MY_SIG", "SOTA")
            s += field("MY_SIG_INFO", v)
            s += field("MY_SOTA_REF", v)
            if let myGrid = UserDefaults.standard.string(forKey: "qthLocator")?
                .trimmingCharacters(in: .whitespaces), !myGrid.isEmpty {
                s += field("MY_GRIDSQUARE", myGrid)
            }
        }
        if let v = q.theirSotaRef, !v.isEmpty {
            s += field("SIG", "SOTA")
            s += field("SIG_INFO", v)
            s += field("SOTA_REF", v)
        }
        // Punkte des Gegen-Summits als proprietäres Feld speichern —
        // ADIF hat keinen Standard dafür, aber so überlebt der Wert
        // beim Re-Import in dieselbe App.
        if let v = q.theirSotaPoints {
            s += field("APP_HAMTOOLS_THEIR_SOTA_POINTS", String(v))
        }

        // QSL-Status — nur schreiben wenn tatsächlich gesendet/bestätigt.
        // "N" für jeden Eintrag pumpt das ADIF unnötig auf und manche
        // Aufnahmedienste (pota.app, eQSL) ignorieren oder warnen darüber.
        if q.lotwSent      { s += field("LOTW_QSL_SENT", "Y") }
        if q.lotwConfirmed { s += field("LOTW_QSL_RCVD", "Y") }
        if q.eqslSent      { s += field("EQSL_QSL_SENT", "Y") }
        if q.eqslConfirmed { s += field("EQSL_QSL_RCVD", "Y") }
        if let d = q.qslSentDate     { s += field("QSLSDATE", dateField(d)) }
        if let v = q.qslSentVia      { s += field("QSL_SENT_VIA", v) }
        if let d = q.qslReceivedDate { s += field("QSLRDATE", dateField(d)) }
        if let v = q.qslReceivedVia  { s += field("QSL_RCVD_VIA", v) }

        // Solar (proprietäre Felder als APP_*)
        if let v = q.sfi    { s += field("APP_HAMTOOLS_SFI",    String(v)) }
        if let v = q.kIndex { s += field("APP_HAMTOOLS_K",      String(format: "%.1f", v)) }
        if let v = q.aIndex { s += field("APP_HAMTOOLS_A",      String(format: "%.1f", v)) }

        s += "<EOR>\n"
        return s
    }

    private static func field(_ tag: String, _ value: String) -> String {
        let bytes = value.utf8.count
        return "<\(tag):\(bytes)>\(value) "
    }

    // MARK: - Import (Parser)

    /// Liest ADIF-Text und gibt eine Liste von Field-Dictionaries zurück
    /// (ein Dict pro QSO-Record). Tags sind immer uppercased.
    static func parse(_ text: String) -> [[String: String]] {
        var records: [[String: String]] = []
        var current: [String: String] = [:]
        var i = text.startIndex
        var inHeader = true

        while i < text.endIndex {
            // Suche nächste '<' — Anfang eines Tags
            guard let openIdx = text[i...].firstIndex(of: "<") else { break }
            // Tag-Ende ist '>'
            guard let closeIdx = text[openIdx...].firstIndex(of: ">") else { break }
            let tagBody = text[text.index(after: openIdx)..<closeIdx]
            let parts = tagBody.split(separator: ":", omittingEmptySubsequences: false)
            let tag = String(parts[0]).uppercased()

            if tag == "EOH" {
                inHeader = false
                i = text.index(after: closeIdx)
                continue
            }
            if tag == "EOR" {
                if !current.isEmpty { records.append(current) }
                current = [:]
                i = text.index(after: closeIdx)
                continue
            }
            // Mit Längen-Spezifizierer: <TAG:N> oder <TAG:N:TYPE>
            guard parts.count >= 2, let len = Int(parts[1]) else {
                i = text.index(after: closeIdx)
                continue
            }
            let valueStart = text.index(after: closeIdx)
            // Wert nach Bytes lesen — UTF-8
            let valueEnd = endIndex(after: valueStart, byteLength: len, in: text)
                          ?? text.endIndex
            let value = String(text[valueStart..<valueEnd])
            if !inHeader {
                current[tag] = value
            }
            i = valueEnd
        }
        // Letzter Record falls ohne abschließendes <EOR>
        if !current.isEmpty { records.append(current) }
        return records
    }

    /// Springt `byteLength` UTF-8-Bytes ab `start` vorwärts und gibt
    /// den entsprechenden String-Index zurück.
    private static func endIndex(after start: String.Index,
                                 byteLength: Int,
                                 in text: String) -> String.Index? {
        guard byteLength >= 0 else { return start }
        var idx = start
        var remaining = byteLength
        while remaining > 0, idx < text.endIndex {
            let c = text[idx]
            let cBytes = String(c).utf8.count
            remaining -= cBytes
            idx = text.index(after: idx)
        }
        return idx
    }

    // MARK: - QSO aus Feld-Dict

    static func qso(from fields: [String: String], logID: UUID) -> QSO? {
        guard let call = fields["CALL"], !call.isEmpty,
              let dateStr = fields["QSO_DATE"],
              let timeStr = fields["TIME_ON"],
              let dt = parseDate(date: dateStr, time: timeStr)
        else { return nil }

        let freqStr = fields["FREQ"] ?? "0"
        let f = Double(freqStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        var band = fields["BAND"] ?? ""
        if band.isEmpty, f > 0, let b = HamBand.from(frequencyMHz: f) {
            band = b.rawValue
        }
        let mode = fields["MODE"] ?? ""
        let rstSent = fields["RST_SENT"] ?? "59"
        let rstRcvd = fields["RST_RCVD"] ?? "59"

        var q = QSO(logID: logID,
                    call: call,
                    datetime: dt,
                    frequencyMHz: f,
                    band: band,
                    mode: mode,
                    rstSent: rstSent,
                    rstReceived: rstRcvd)
        q.name           = fields["NAME"]
        q.qth            = fields["QTH"]
        q.locator        = fields["GRIDSQUARE"]
        q.country        = fields["COUNTRY"]
        q.continent      = fields["CONT"]
        q.cqZone         = fields["CQZ"].flatMap(Int.init)
        q.ituZone        = fields["ITUZ"].flatMap(Int.init)
        q.comment        = fields["COMMENT"]
        q.operatorCall   = fields["OPERATOR"]
        q.stationCall    = fields["STATION_CALLSIGN"]
        q.powerW         = fields["TX_PWR"].flatMap(Double.init)
        q.antenna        = fields["ANTENNA"]
        q.contest             = fields["CONTEST_ID"]
        q.contestSerial       = fields["STX"].flatMap(Int.init)
        q.contestExchangeSent = fields["STX_STRING"]
        q.contestExchangeRecv = fields["SRX_STRING"] ?? fields["SRX"]
        // Legacy-Feld absichtlich nicht mehr setzen — neue Felder sind die Quelle der Wahrheit.
        q.distanceKm     = fields["DISTANCE"].flatMap(Double.init)
        q.bearingDeg     = fields["ANT_AZ"].flatMap(Double.init)

        // POTA/SOTA — Spezial-Felder bevorzugen, sonst aus SIG-Tag.
        // Bei Komma-Liste (Multi-Park-Hopping): myPotaRef = erster Park,
        // myPotaRefs = volle Liste. POTA-ADIF spec erlaubt Komma in MY_POTA_REF.
        let myPotaRaw = fields["MY_POTA_REF"]
                     ?? (fields["MY_SIG"] == "POTA" ? fields["MY_SIG_INFO"] : nil)
        if let raw = myPotaRaw, !raw.isEmpty {
            let refs = raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            q.myPotaRef  = refs.first
            q.myPotaRefs = refs.count > 1 ? refs.joined(separator: ",") : nil
        }
        q.theirPotaRef = fields["POTA_REF"]
                     ?? (fields["SIG"] == "POTA" ? fields["SIG_INFO"] : nil)
        // SOTA — symmetrisch zum POTA-Pfad oben. Multi-Summit-Hopping wird
        // beim Re-Import als Komma-Liste in mySotaRefs gespeichert; der
        // erste Eintrag landet zusätzlich in mySotaRef für Single-Summit-
        // Lesepfade.
        let mySotaRaw = fields["MY_SOTA_REF"]
                     ?? (fields["MY_SIG"] == "SOTA" ? fields["MY_SIG_INFO"] : nil)
        if let raw = mySotaRaw, !raw.isEmpty {
            let refs = raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            q.mySotaRef  = refs.first
            q.mySotaRefs = refs.count > 1 ? refs.joined(separator: ",") : nil
        }
        q.theirSotaRef = fields["SOTA_REF"]
                     ?? (fields["SIG"] == "SOTA" ? fields["SIG_INFO"] : nil)
        q.theirSotaPoints = fields["APP_HAMTOOLS_THEIR_SOTA_POINTS"]
            .flatMap(Int.init)

        q.lotwSent      = parseBool(fields["LOTW_QSL_SENT"])
        q.lotwConfirmed = parseBool(fields["LOTW_QSL_RCVD"])
        q.eqslSent      = parseBool(fields["EQSL_QSL_SENT"])
        q.eqslConfirmed = parseBool(fields["EQSL_QSL_RCVD"])
        q.qslSentDate     = fields["QSLSDATE"].flatMap { parseDate(date: $0, time: "0000") }
        q.qslSentVia      = fields["QSL_SENT_VIA"]
        q.qslReceivedDate = fields["QSLRDATE"].flatMap { parseDate(date: $0, time: "0000") }
        q.qslReceivedVia  = fields["QSL_RCVD_VIA"]
        return q
    }

    private static func parseBool(_ s: String?) -> Bool {
        guard let s else { return false }
        let u = s.uppercased()
        return u == "Y" || u == "YES" || u == "1" || u == "TRUE"
    }

    // MARK: - Date/Time

    private static func dateField(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd"
        return f.string(from: d)
    }
    private static func timeField(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "HHmmss"
        return f.string(from: d)
    }
    private static func parseDate(date: String, time: String) -> Date? {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        let normTime = time.padding(toLength: 6, withPad: "0", startingAt: 0)
        f.dateFormat = "yyyyMMddHHmmss"
        return f.date(from: date + normTime)
    }
    private static func adifTimestamp(_ d: Date) -> String {
        dateField(d) + " " + timeField(d)
    }
    private static func currentISOTimestamp() -> String {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }
}
