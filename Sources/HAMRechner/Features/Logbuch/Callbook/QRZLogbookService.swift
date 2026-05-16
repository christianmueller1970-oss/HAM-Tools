import Foundation

// Phase 6 — erster funktionaler Upload-Service. QRZ.com Logbook ist
// gnadenlos simpler als POTAs Cognito-Stack: statischer 32-Hex-API-Key
// (vom User in seinen QRZ-Account-Settings generiert), Form-encoded
// POST, klare Response-Codes.
//
// API-Doku: https://logbook.qrz.com/api  (öffentlich, ohne Auth lesbar)
//
//   POST https://logbook.qrz.com/api
//   Content-Type: application/x-www-form-urlencoded
//   KEY=<32-hex>&ACTION=INSERT&ADIF=<one ADIF record>
//
//   → RESULT=OK&COUNT=1&LOGID=12345    (akzeptiert)
//   → RESULT=AUTH&REASON=invalid key   (API-Key falsch)
//   → RESULT=FAIL&REASON=duplicate     (war bereits in QRZ — wir
//                                       behandeln das als OK)
//   → RESULT=FAIL&REASON=...           (sonstige Ablehnung)
//
// Wir bauen hier ausschließlich INSERT — FETCH (Bestätigungen abrufen)
// kommt im nächsten Schritt.
// Nicht @MainActor: damit Bulk-Uploads parallel in einer TaskGroup
// laufen können, ohne den Main-Thread zu blockieren. Service-Method
// macht nichts UI-spezifisches, nur URLSession.
final class QRZLogbookService: Sendable {

    static let endpoint = URL(string: "https://logbook.qrz.com/api")!

    // Eigene URLSession, ephemeral & ohne State — URLSession.shared
    // hatte am 2026-05-16 nach den ersten FETCH-Versuchen einen Zustand
    // (vermutlich gecachte 0-Byte-Response oder ein Set-Cookie), bei dem
    // weitere identische Anfragen RESULT=OK&COUNT=0 zurückgaben, obwohl
    // die gleiche URL im Browser einwandfrei lief.
    nonisolated(unsafe) private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }()

    enum UploadOutcome: Equatable {
        case accepted(logId: Int?)
        case duplicate
        case authFailed(String)
        case rejected(String)
        case network(String)

        // Mapping auf QSO.qrzLogbookStatus (siehe QSO.swift):
        //   0 = nicht versucht (wird hier nie zurückgegeben)
        //   1 = OK (accepted)
        //   2 = duplicate (war bereits drin — gilt als „erfolgreich")
        //   3 = fail (auth / rejected / network)
        var statusCode: Int {
            switch self {
            case .accepted: return 1
            case .duplicate: return 2
            case .authFailed, .rejected, .network: return 3
            }
        }

        // Für UI-Anzeigen, wenn was schief lief.
        var failureReason: String? {
            switch self {
            case .accepted, .duplicate:   return nil
            case .authFailed(let m):       return "Auth: \(m)"
            case .rejected(let m):         return m
            case .network(let m):          return "Netzwerk: \(m)"
            }
        }
    }

    /// Schickt einen einzelnen QSO an QRZ. Wirft nicht — alle Fehler-Fälle
    /// landen im `UploadOutcome`, damit der Aufrufer den Status persistieren
    /// und entscheiden kann, ob er weitere QSOs schicken soll.
    func upload(qso: QSO, apiKey: String) async -> UploadOutcome {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return .authFailed("Kein API-Key in Settings") }

        // ADIF-Record ohne Header — QRZ akzeptiert sowohl
        // "<call:6>HB9HJI...<eor>" als auch ganze Files.
        let adifRecord = ADIFCodec.encodeRecord(qso)

        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded",
                     forHTTPHeaderField: "Content-Type")
        req.setValue("application/x-www-form-urlencoded, text/plain, */*",
                     forHTTPHeaderField: "Accept")
        // QRZ-Doku: alle API-Aufrufe brauchen einen identifizierbaren UA,
        // sonst gibt's Rate-Limiting/Filtering.
        req.setValue("HAM-Tools/1.8.5 (macOS)",
                     forHTTPHeaderField: "User-Agent")
        req.httpBody = formEncode([
            "KEY":    key,
            "ACTION": "INSERT",
            "ADIF":   adifRecord
        ])

        let data: Data
        let http: HTTPURLResponse
        do {
            let (d, resp) = try await Self.session.data(for: req)
            data = d
            guard let h = resp as? HTTPURLResponse else {
                return .network("Keine HTTP-Antwort")
            }
            http = h
        } catch {
            return .network(error.localizedDescription)
        }

        if http.statusCode != 200 {
            return .network("HTTP \(http.statusCode)")
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        let parsed = parseFormURLEncoded(body)
        let result = (parsed["RESULT"] ?? "").uppercased()
        let reason = parsed["REASON"] ?? ""

        switch result {
        case "OK":
            let logId = parsed["LOGID"].flatMap { Int($0) }
            return .accepted(logId: logId)
        case "AUTH":
            return .authFailed(reason.isEmpty ? "API-Key ungültig" : reason)
        case "FAIL":
            // QRZ formuliert "duplicate", "Duplicate", "ALREADY_HAVE_QSO" u.ä.
            let lower = reason.lowercased()
            if lower.contains("duplicate") || lower.contains("already") {
                return .duplicate
            }
            return .rejected(reason.isEmpty ? "Vom Server abgelehnt" : reason)
        default:
            return .rejected("Unbekannte Antwort: \(result.isEmpty ? "(leer)" : result)")
        }
    }

    // MARK: - FETCH (Confirmations abrufen)

    enum FetchError: LocalizedError {
        case noApiKey
        case authFailed(String)
        case rejected(String)
        case network(String)

        var errorDescription: String? {
            switch self {
            case .noApiKey:           return "Kein API-Key in Settings"
            case .authFailed(let m):  return "Auth: \(m)"
            case .rejected(let m):    return m
            case .network(let m):     return "Netzwerk: \(m)"
            }
        }
    }

    struct FetchResult {
        let count: Int      // QRZ-eigenes COUNT (Anzahl QSOs in der Antwort)
        let adif: String    // rohes ADIF, vom Aufrufer mit ADIFCodec.parse zerlegt
    }

    /// Holt eine Page der QSOs aus QRZs Logbook (MAX:250 ab dem
    /// gegebenen `afterLogId`). Aufrufer muss durch Pagination iterieren:
    /// nach jedem Batch die höchste `app_qrzlog_logid` aus dem ADIF lesen,
    /// +1, und als `afterLogId` in die nächste Anfrage geben.
    func fetchAll(apiKey: String, afterLogId: Int = 0) async -> Result<FetchResult, FetchError> {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return .failure(.noApiKey) }

        // QRZ-Doku sagt POST, in der Praxis funktioniert FETCH aber NUR
        // mit GET (siehe QRZ-Forum-Thread 798437 — andere haben dasselbe
        // Problem gehabt). Parameter müssen daher als Query-String an die
        // URL, nicht als Body.
        // OPTION-Konstruktion gemäß offizieller QRZ-API-Doku (gelesen
        // 2026-05-16):
        //   • Default Scope = ALL (alle Records). Aber: "When the option
        //     ALL is given, only the options TYPE and STATUS may also be
        //     specified." → MAX/AFTERLOGID **darf nicht** mit ALL kombiniert
        //     werden, sonst antwortet QRZ mit COUNT=0.
        //   • MAX:nnnn ohne ALL ist der empfohlene Paging-Modus.
        //   • MAX:250 + AFTERLOGID:N → Standard-Pagination-Schritt.
        let optionString = "TYPE:ADIF,MAX:250,AFTERLOGID:\(afterLogId)"
        var components = URLComponents(url: Self.endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "KEY",    value: key),
            URLQueryItem(name: "ACTION", value: "FETCH"),
            URLQueryItem(name: "OPTION", value: optionString)
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        // App-spezifischer User-Agent — QRZ-Doku verlangt Identifikation
        // (generische UAs wie Safari/node-fetch werden rate-limited oder
        // ignoriert). Format gem. Empfehlung: AppName/version.
        req.setValue("HAM-Tools/1.8.5 (macOS)",
                     forHTTPHeaderField: "User-Agent")
        req.setValue("application/x-www-form-urlencoded, text/plain, */*",
                     forHTTPHeaderField: "Accept")
        // Cache umgehen — eine 0-Byte-Antwort von einem fehlgeschlagenen
        // Versuch davor würde sonst gemerkt und immer wieder zurückgegeben.
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        req.timeoutInterval = 60

        let data: Data
        let http: HTTPURLResponse
        do {
            let (d, resp) = try await Self.session.data(for: req)
            data = d
            guard let h = resp as? HTTPURLResponse else {
                return .failure(.network("Keine HTTP-Antwort"))
            }
            http = h
        } catch {
            return .failure(.network(error.localizedDescription))
        }
        let body = String(data: data, encoding: .utf8) ?? ""

        // Diagnose-Dump bei Fetch-Aufrufen: Request-URL + Response-Header
        // + ersten 4 KB Body nach /tmp/hamtools-qrz-fetch.log, damit wir
        // den Unterschied Browser-vs-App debuggen können.
        #if DEBUG
        QRZLogbookService.logFetchDebug(url: components.url,
                                         http: http,
                                         body: body,
                                         requestHeaders: req.allHTTPHeaderFields ?? [:],
                                         apiKey: key)
        #endif

        // Vor allem zur Diagnose der "leer"-Antwort: HTTP-Status + Bytes
        // im Fehler-Snippet mitführen.
        if http.statusCode != 200 {
            let snip = String(body.prefix(150))
                .replacingOccurrences(of: "\n", with: "⏎")
            return .failure(.network("HTTP \(http.statusCode) · \(data.count) Bytes · \(snip)"))
        }

        if body.isEmpty {
            // URL für den User: Key vor dem Output rausfiltern, damit er nicht
            // im Alert sichtbar wird. URL-Encoding direkt von URLComponents.
            let urlString = components.url?.absoluteString ?? "?"
            let sanitized = urlString.replacingOccurrences(
                of: "KEY=\(key)", with: "KEY=<HIDDEN>")
            let ct = http.value(forHTTPHeaderField: "Content-Type") ?? "?"
            return .failure(.rejected(
                "HTTP 200, 0 Bytes Body (Content-Type: \(ct)).\n\nGesendete URL: \(sanitized)\n\nMögliche Ursache: API-Key hat keine FETCH-Berechtigung. Kopier die URL oben, ersetze <HIDDEN> mit deinem Key, und ruf sie im Browser auf — wenn der Browser auch nur weiß zeigt, ist's ein QRZ-Account-Issue."))
        }
        // QRZ FETCH liefert zwei Varianten je nach Größe / Pool-Konfiguration:
        //  (a) form-urlencoded Wrapper wie INSERT: RESULT=OK&COUNT=N&ADIF=...
        //  (b) **direkter ADIF-Stream** als Body — keine RESULT-Hülle.
        // Wir erkennen (b) am <EOH>/<EOR>-Tag (case-insensitive).
        let lower = body.lowercased()
        let looksLikeRawADIF = lower.contains("<eor>") || lower.contains("<eoh>")

        if looksLikeRawADIF {
            // Variante (b): Body IST das ADIF.
            // COUNT aus QRZ-Header-Tags ableiten (z.B. <APP_QRZLOG_COUNT>),
            // sonst aus der Anzahl <eor> abzählen.
            let count = countOccurrences(of: "<eor>", in: lower)
            return .success(FetchResult(count: count, adif: body))
        }

        // Variante (a): form-urlencoded Wrapper. **Quirk:** QRZ schickt
        // den ADIF-Wert MIT HTML-Entities (`&lt;` und `&gt;`) ohne das
        // führende `&` zu URL-encoden. Naives Splitten an `&` zerlegt also
        // den ADIF-Block in tausend Fragmente und das `ADIF`-Feld bleibt
        // leer. Wir ziehen `ADIF=` daher manuell als "alles bis zum
        // Ende" raus und parsen den Rest des Headers normal.
        let (head, extractedADIF) = splitFetchADIF(body)
        var parsed = parseFormURLEncoded(head)
        if let v = extractedADIF { parsed["ADIF"] = v }
        let result = (parsed["RESULT"] ?? "").uppercased()
        let reason = parsed["REASON"] ?? ""

        // Vollständige Server-Antwort als Diagnose-Snippet, falls QRZ einen
        // Hinweis in einem nicht-Standard-Feld unterbringt.
        let diagSnippet: String = {
            let snippet = String(body.prefix(200))
                .replacingOccurrences(of: "\n", with: "⏎")
            return snippet.isEmpty ? "(leer)" : snippet
        }()

        switch result {
        case "OK":
            let count = parsed["COUNT"].flatMap { Int($0) } ?? 0
            // QRZ-FETCH-ADIF-Quirks (beobachtet 2026-05-16):
            //   1) HTML-Entities (`&lt;`, `&gt;`, `&amp;`) statt rohe `<>&`.
            //   2) Keine ADIF-Header-Sektion — der Block geht direkt mit
            //      `<…>`-Feldern los, ohne `<ADIF_VER>...<EOH>`. Unser
            //      Parser startet aber mit inHeader=true; wir prepend
            //      darum ein synthetisches `<EOH>`, damit er sofort in
            //      den Record-Mode springt.
            let rawADIF = decodeHTMLEntities(parsed["ADIF"] ?? "")
            let adif = "<EOH>\n" + rawADIF
            return .success(FetchResult(count: count, adif: adif))
        case "AUTH":
            return .failure(.authFailed(reason.isEmpty ? "API-Key ungültig" : reason))
        case "FAIL":
            let msg = reason.isEmpty
                ? "Server-Antwort: \(diagSnippet)"
                : reason
            return .failure(.rejected(msg))
        default:
            return .failure(.rejected("Unerwartete Antwort: \(diagSnippet)"))
        }
    }

    #if DEBUG
    private static func logFetchDebug(url: URL?,
                                       http: HTTPURLResponse,
                                       body: String,
                                       requestHeaders: [String: String],
                                       apiKey: String) {
        let path = "/tmp/hamtools-qrz-fetch.log"
        var dump = "\n=== \(Date().description) ===\n"
        dump += "URL: \((url?.absoluteString ?? "?").replacingOccurrences(of: apiKey, with: "<KEY>"))\n"
        dump += "HTTP Status: \(http.statusCode)\n"
        dump += "Response Content-Type: \(http.value(forHTTPHeaderField: "Content-Type") ?? "?")\n"
        dump += "Response Content-Length header: \(http.value(forHTTPHeaderField: "Content-Length") ?? "?")\n"
        dump += "Response Set-Cookie: \(http.value(forHTTPHeaderField: "Set-Cookie") ?? "(none)")\n"
        dump += "Body bytes: \(body.utf8.count)\n"
        var clean: [String: String] = [:]
        for (k, v) in requestHeaders { clean[k] = (k == "KEY") ? "<KEY>" : v }
        dump += "Request Headers: \(clean.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " | "))\n"
        dump += "Body (first 4 KB):\n"
        dump += String(body.prefix(4096))
        dump += "\n"
        if let data = dump.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: path) {
                if let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                    _ = try? h.seekToEnd()
                    try? h.write(contentsOf: data)
                    try? h.close()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: path))
            }
        }
    }
    #endif

    /// Extrahiert den `ADIF=`-Block aus einem QRZ-FETCH-Body. Wegen der
    /// HTML-Entities (mit `&` darin) splittet ein normaler form-url-Parser
    /// den Block falsch — wir nehmen einfach alles ab `ADIF=` bis zum
    /// Ende des Body als ADIF-Wert.
    private func splitFetchADIF(_ body: String) -> (head: String, adif: String?) {
        if let r = body.range(of: "&ADIF=") {
            let head = String(body[..<r.lowerBound])
            let adif = String(body[r.upperBound...])
            return (head, adif.removingPercentEncoding ?? adif)
        }
        if body.hasPrefix("ADIF=") {
            let adif = String(body.dropFirst("ADIF=".count))
            return ("", adif.removingPercentEncoding ?? adif)
        }
        return (body, nil)
    }

    /// Decodet die fünf häufigsten HTML-Entities. QRZs FETCH-Response
    /// schickt das ADIF-Stream HTML-encoded mit at-least `&lt;`/`&gt;`,
    /// gelegentlich auch `&amp;` in QSO-Comment-Feldern. `&amp;` muss
    /// ZULETZT decodet werden — sonst würde "&amp;lt;" zu "&lt;" und
    /// dann zu "<" doppelt-decodieren.
    private func decodeHTMLEntities(_ s: String) -> String {
        var r = s
        r = r.replacingOccurrences(of: "&lt;",   with: "<")
        r = r.replacingOccurrences(of: "&gt;",   with: ">")
        r = r.replacingOccurrences(of: "&quot;", with: "\"")
        r = r.replacingOccurrences(of: "&#39;",  with: "'")
        r = r.replacingOccurrences(of: "&amp;",  with: "&")
        return r
    }

    private func countOccurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var range = haystack.startIndex..<haystack.endIndex
        while let r = haystack.range(of: needle, options: .literal, range: range) {
            count += 1
            range = r.upperBound..<haystack.endIndex
        }
        return count
    }

    // MARK: - Helpers

    private func formEncode(_ params: [String: String]) -> Data {
        let allowed = CharacterSet.urlQueryAllowed
        let encoded = params.map { key, value -> String in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
        return Data(encoded.utf8)
    }

    private func parseFormURLEncoded(_ s: String) -> [String: String] {
        var result: [String: String] = [:]
        // QRZ trennt mit "&" wie üblich; Mehrzeiler erlaubt (manche
        // FAIL-Antworten haben Newlines vor &).
        let cleaned = s.replacingOccurrences(of: "\n", with: "")
                       .replacingOccurrences(of: "\r", with: "")
        for pair in cleaned.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0]
            let val = parts[1].removingPercentEncoding ?? parts[1]
            result[key] = val
        }
        return result
    }
}
