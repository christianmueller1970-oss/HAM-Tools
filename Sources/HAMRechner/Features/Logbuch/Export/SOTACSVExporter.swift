import Foundation

// sotadata.org.uk-konformer Export im V2-CSV-Format. SOTA ist das einzige
// Outdoor-Programm in der App, das NICHT auf ADIF hochgeladen wird —
// die Datenbank frisst nur das eigene CSV-Schema.
//
// Spaltenreihenfolge laut sotadata.org.uk/en/upload/activator/csv/info:
//   1. "V2"
//   2. MyCallsign     — eigenes Rufzeichen (Log-Override oder Settings)
//   3. MySummit       — eigener Summit z.B. HB/JU-001
//   4. Date           — dd/mm/yyyy (UTC-Datum des QSO)
//   5. Time           — HHMM UTC
//   6. Band           — z.B. "7.0MHz" mit MHz-Suffix
//   7. Mode           — "CW", "SSB", "FM", ...
//   8. WorkedCallsign — Rufzeichen der Gegenstation
//   9. TheirSummit    — Gegen-Summit (nur S2S, sonst leer)
//   10. Notes         — optional, hier leer
//
// Multi-Summit-Hopping: SOTA zählt Aktivierungen pro Summit getrennt.
// Wir schreiben pro Summit jeweils alle QSOs des Logs in einem Block —
// die DB erkennt am Ref-Wechsel das Ende einer Aktivierung. Innerhalb
// eines Summit-Blocks ist nach Datum+Zeit sortiert (Pflicht, sonst
// lehnt sotadata die Datei ab).
struct SOTACSVExporter: ProgramExporter {
    let menuTitle = "Für sotadata.org.uk exportieren (CSV)"
    let iconName  = "mountain.2"

    static func applies(to logType: LogType) -> Bool {
        logType == .sota
    }

    func export(qsos: [QSO], log: Log, exportsDir: URL) throws -> [URL] {
        // Welche Summits aktiviert das Log? Reihenfolge: Wizard-Setup
        // zuerst, dann eventuelle QSO-spezifische Override-Refs.
        var summits: [String] = ProgramExportRefs.split(
            primary: log.sotaSummitRef, multi: log.sotaSummitRefs)
        var seen = Set(summits)
        for q in qsos {
            for ref in ProgramExportRefs.split(primary: q.mySotaRef, multi: q.mySotaRefs) {
                if seen.insert(ref).inserted { summits.append(ref) }
            }
        }
        guard !summits.isEmpty else { return [] }

        let call = ProgramExportCallsign.resolve(log: log, qsos: qsos)

        // Pro Summit: alle QSOs dieser Aktivierung, sortiert nach Zeit.
        // Ein QSO, das mehrere Summits aktiviert (myPotaRefs-Komma-Liste),
        // landet in mehreren Blöcken — jeder Summit zählt für SOTA separat.
        var lines: [String] = []
        for summit in summits {
            let summitQSOs: [QSO] = qsos.filter { q in
                let refs = ProgramExportRefs.split(primary: q.mySotaRef, multi: q.mySotaRefs)
                if refs.contains(summit) { return true }
                if refs.isEmpty && log.sotaSummitRef == summit { return true }
                return false
            }.sorted { $0.datetime < $1.datetime }

            for q in summitQSOs {
                lines.append(Self.csvLine(qso: q, myCall: call, mySummit: summit))
            }
        }
        guard !lines.isEmpty else { return [] }

        let primarySummit = summits[0]
        let fileName = Self.filename(call: call, summit: primarySummit, date: log.startDate)
        let url = exportsDir.appendingPathComponent(fileName)
        // sotadata.org.uk akzeptiert nackte LF, aber CRLF ist robuster für
        // den Roundtrip über Mail-Clients und Browser-Uploads.
        let text = lines.joined(separator: "\r\n") + "\r\n"
        try text.write(to: url, atomically: true, encoding: .utf8)
        return [url]
    }

    // MARK: - Helpers

    private static func csvLine(qso q: QSO, myCall: String, mySummit: String) -> String {
        let date = dateField(q.datetime)
        let time = timeField(q.datetime)
        let band = bandField(qsoBand: q.band, freqMHz: q.frequencyMHz)
        let mode = q.mode.uppercased()
        let their = q.call.uppercased()
        let theirSummit = q.theirSotaRef?
            .trimmingCharacters(in: .whitespaces) ?? ""
        // Notes/Comment-Spalte bleibt leer — Kommas im Comment würden den
        // CSV-Parser von sotadata verwirren (Doku: »no commas in any field«).
        let notes = ""
        return [
            "V2",
            sanitize(myCall),
            sanitize(mySummit),
            date,
            time,
            band,
            sanitize(mode),
            sanitize(their),
            sanitize(theirSummit),
            sanitize(notes)
        ].joined(separator: ",")
    }

    private static func dateField(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: d)
    }

    private static func timeField(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "HHmm"
        return f.string(from: d)
    }

    /// SOTA-Beispiele zeigen Band-zentrierte Werte wie "7.0MHz" / "144MHz"
    /// statt exakter QSO-Frequenzen. Wir bilden den Band-Namen auf die
    /// Band-Mitten-Frequenz ab; nur wenn das Band-Mapping nichts kennt,
    /// fällt der Code auf die QSO-Frequenz zurück.
    private static func bandField(qsoBand: String, freqMHz: Double) -> String {
        if let mapped = Self.bandFrequencyMHz[qsoBand.lowercased()] {
            return mapped
        }
        if freqMHz > 0 {
            return String(format: "%.4gMHz", freqMHz)
        }
        return qsoBand
    }

    /// Band-Name → SOTA-konformer Band-String. Werte aus offiziellen
    /// sotadata.org.uk-CSV-Beispielen / Reflector-Threads.
    private static let bandFrequencyMHz: [String: String] = [
        "160m": "1.8MHz",
        "80m":  "3.5MHz",
        "60m":  "5MHz",
        "40m":  "7.0MHz",
        "30m":  "10MHz",
        "20m":  "14MHz",
        "17m":  "18MHz",
        "15m":  "21MHz",
        "12m":  "24MHz",
        "10m":  "28MHz",
        "6m":   "50MHz",
        "4m":   "70MHz",
        "2m":   "144MHz",
        "70cm": "432MHz",
        "23cm": "1.2GHz",
        "13cm": "2.3GHz",
        "9cm":  "3.4GHz",
        "6cm":  "5.7GHz",
        "3cm":  "10GHz"
    ]

    /// CSV-Sanitizing: SOTA-Doku verbietet Kommas in Feldern (»no commas
    /// in any field without confusing the upload program«). Wir strippen
    /// sie ersatzlos statt zu quoten, weil sotadata.org.uk laut Reflektor
    /// kein RFC-4180-Quoting versteht.
    private static func sanitize(_ s: String) -> String {
        s.replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func filename(call: String, summit: String, date: Date) -> String {
        let safeCall   = call.replacingOccurrences(of: "/", with: "_")
        let safeSummit = summit.replacingOccurrences(of: "/", with: "_")
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return "\(safeCall)@\(safeSummit) \(f.string(from: date)).csv"
    }
}
