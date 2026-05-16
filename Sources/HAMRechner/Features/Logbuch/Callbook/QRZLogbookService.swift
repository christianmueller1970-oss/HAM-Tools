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
        req.httpBody = formEncode([
            "KEY":    key,
            "ACTION": "INSERT",
            "ADIF":   adifRecord
        ])

        let data: Data
        let http: HTTPURLResponse
        do {
            let (d, resp) = try await URLSession.shared.data(for: req)
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
