import Foundation

// Adapter für N1MM-Logger-Plus-UDP-Broadcasts. Parst zwei Paket-Typen:
//   • <contactinfo>  → UDPBridgeEvent.qsoLogged
//   • <spot>         → UDPBridgeEvent.spot (Action="add")
//
// Andere Pakete (RadioInfo, ScoreUpdate, LookupInfo, ContactReplace,
// ContactDelete) werden defensiv ignoriert — sie haben keinen klaren Use-
// Case in einem Standalone-Logger-Modus.
//
// Format-Doku: n1mmwp.hamdocs.com/appendices/external-udp-broadcasts/
//
// Bemerkenswerte Eigenheiten:
//   • `rxfreq` / `txfreq` in 10-Hz-Einheiten (Hertz / 10), nicht kHz!
//     352519 → 3525.19 kHz → 3.52519 MHz.
//   • `<frequency>` im Spot dagegen ist in **kHz** als String (z.B. "7061.2").
//   • `<timestamp>` UTC, Format "yyyy-MM-dd HH:mm:ss".
//   • Doku-Tippfehler: `<exchangel>` mit kleinem L (statt "exchange1") —
//     N1MM sendet das tatsächlich so. Wir parsen beide Schreibweisen.
enum N1MMAdapter {

    static func decode(_ data: Data) -> UDPBridgeEvent? {
        // Wir lesen das Datagramm als UTF-8-String + scannen nach dem Root-
        // Element. Foundation-`XMLParser` arbeitet stream-basiert; für
        // erste Disambiguation reicht ein simpler Substring-Check.
        guard let s = String(data: data, encoding: .utf8) else { return nil }

        if s.contains("<contactinfo>") || s.contains("<contactinfo ") {
            if let payload = parseContactInfo(data: data) {
                return .qsoLogged(payload)
            }
        }
        if s.contains("<spot>") || s.contains("<spot ") {
            if let payload = parseSpot(data: data) {
                return .spot(payload)
            }
        }
        // Andere bekannte Pakete sind no-ops für uns; wir signalisieren
        // dem Listener trotzdem Aktivität (Heartbeat-Effekt) damit die
        // UI-Pille »lauscht/aktiv« sauber umschaltet.
        if s.contains("<RadioInfo>") || s.contains("<ScoreUpdate>")
            || s.contains("<AppInfo>") || s.contains("<ContactReplace>")
            || s.contains("<ContactDelete>") || s.contains("<LookupInfo>") {
            return .heartbeat(version: nil)
        }
        return nil
    }

    // MARK: - ContactInfo

    private static func parseContactInfo(data: Data) -> UDPBridgeQSOPayload? {
        let fields = parseLeafFields(data: data)

        guard let call = fields["call"]?.uppercased(), !call.isEmpty else { return nil }

        let mode = (fields["mode"] ?? "").uppercased()
        let bandStr = fields["band"] ?? ""
        // Frequenz aus rxfreq oder txfreq (10-Hz-Einheiten).
        let txFreq = parseInt(fields["txfreq"])
        let rxFreq = parseInt(fields["rxfreq"])
        let freqMHz: Double? = {
            if let f = txFreq, f > 0 { return Double(f) / 100_000.0 }
            if let f = rxFreq, f > 0 { return Double(f) / 100_000.0 }
            if let b = Double(bandStr), b > 0 { return b }
            return nil
        }()

        // Band: falls vom Frequenz-Wert ableitbar — bevorzugen wir das,
        // weil N1MM bei `band` nur die nominale MHz schreibt (z.B. "3.5",
        // nicht "80m").
        let band: String = {
            if let f = freqMHz, let derived = HamBand.from(frequencyMHz: f)?.rawValue {
                return derived
            }
            return bandStr
        }()

        let ts = parseN1MMTimestamp(fields["timestamp"]) ?? Date()

        // Exchange-Felder: SentExchange / "exchangel" (Tippfehler in Doku
        // bleibt im echten Strom). Für Recv-Exchange nimmt N1MM den
        // rcvnr-Wert als Serial — wir bauen einen kombinierten String.
        let sentExchange = fields["sentexchange"] ?? fields["exchangel"] ?? fields["exchange1"]
        let recvParts: [String] = [fields["rcvnr"], fields["section"], fields["name"], fields["qth"]]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let recvExchange = recvParts.isEmpty ? nil : recvParts.joined(separator: " ")

        return UDPBridgeQSOPayload(
            call: call,
            datetime: ts,
            band: band,
            mode: mode,
            frequencyMHz: freqMHz,
            rstSent: fields["snt"]?.nilIfEmpty,
            rstReceived: fields["rcv"]?.nilIfEmpty,
            grid: fields["gridsquare"]?.nilIfEmpty,
            name: fields["name"]?.nilIfEmpty,
            comment: fields["comment"]?.nilIfEmpty,
            contestExchangeSent: sentExchange?.nilIfEmpty,
            contestExchangeRecv: recvExchange,
            operatorCall: fields["operator"]?.nilIfEmpty?.uppercased(),
            stationCall: fields["mycall"]?.nilIfEmpty?.uppercased(),
            myGrid: nil
        )
    }

    // MARK: - Spot

    private static func parseSpot(data: Data) -> UDPBridgeSpotPayload? {
        let fields = parseLeafFields(data: data)
        // Nur add-Actions weiterleiten — delete würde lokale Spots löschen
        // wollen, dafür haben wir keine ID-Brücke zum lokalen Cluster-Stream.
        let action = (fields["action"] ?? "add").lowercased()
        guard action == "add" else { return nil }

        guard let dxCall = fields["dxcall"]?.uppercased(), !dxCall.isEmpty,
              let freqStr = fields["frequency"],
              let freqKHz = Double(freqStr.replacingOccurrences(of: ",", with: ".")),
              freqKHz > 0 else { return nil }

        let spotter = fields["spottercall"]?.uppercased() ?? "N1MM"
        let comment = fields["comment"]?.trimmingCharacters(in: .whitespaces) ?? ""
        let ts = parseN1MMTimestamp(fields["timestamp"]) ?? Date()
        return UDPBridgeSpotPayload(
            dxCall: dxCall,
            spotterCall: spotter,
            freqKHz: freqKHz,
            comment: comment,
            sourceTag: "N1MM",
            time: ts
        )
    }

    // MARK: - XML-Helpers

    /// Liest alle Leaf-Element-Texte (eine Ebene unter dem Root) in ein
    /// case-insensitive Dictionary. Foundation `XMLParser` ist stream-basiert
    /// — wir sammeln Element-Inhalte via Delegate-Klasse.
    private static func parseLeafFields(data: Data) -> [String: String] {
        let parser = XMLParser(data: data)
        let delegate = LeafCollector()
        parser.delegate = delegate
        parser.parse()
        return delegate.fields
    }

    private final class LeafCollector: NSObject, XMLParserDelegate {
        var fields: [String: String] = [:]
        private var currentElement: String?
        private var currentText: String = ""
        private var rootSeen: Bool = false

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String : String] = [:]) {
            if !rootSeen { rootSeen = true; return }
            currentElement = elementName.lowercased()
            currentText = ""
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentText += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            guard let key = currentElement,
                  key == elementName.lowercased() else {
                currentElement = nil
                return
            }
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                fields[key] = trimmed
            }
            currentElement = nil
            currentText = ""
        }
    }

    private static func parseN1MMTimestamp(_ s: String?) -> Date? {
        guard let s = s?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        let fmt = DateFormatter()
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fmt.date(from: s)
    }

    private static func parseInt(_ s: String?) -> Int? {
        guard let s = s?.trimmingCharacters(in: .whitespaces) else { return nil }
        return Int(s)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let s = trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? nil : s
    }
}
