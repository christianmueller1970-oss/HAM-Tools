import Foundation

// Phase 6 Schritt 3 — Club Log Upload. Deutlich einfacher als QRZ:
// Form-POST mit Email + Application-Password + Callsign + ADIF.
//
// API-Doku:
//   https://clublog.freshdesk.com/support/solutions/articles/54906 (single)
//   https://clublog.freshdesk.com/support/solutions/articles/54905 (batch)
//
// Endpoints:
//   • realtime.php — EIN QSO als ADIF-Record-String (form-urlencoded).
//     Für Auto-Upload jedes geloggten QSOs. NICHT für Backfills.
//   • putlogs.php  — komplette ADIF-Datei (multipart/form-data).
//     Für Bulk-Backfill oder Initial-Import.
//
// **Sehr wichtig:** bei wiederholten 4xx-Fehlern firewallt Club Log die
// Client-IP. Wir MÜSSEN Fehler dem User klar zeigen und den Versuch
// stoppen — kein silent retry.
final class ClubLogService: Sendable {

    static let realtimeURL = URL(string: "https://clublog.org/realtime.php")!
    static let putlogsURL  = URL(string: "https://clublog.org/putlogs.php")!

    enum UploadOutcome: Equatable {
        case accepted
        case authFailed(String)     // 403 mit "wrong credentials" o.ä.
        case rejected(String)       // andere Fehler-Antworten
        case network(String)

        var statusOK: Bool { self == .accepted }
        var failureReason: String? {
            switch self {
            case .accepted:                return nil
            case .authFailed(let m):       return "Auth: \(m)"
            case .rejected(let m):         return m
            case .network(let m):          return "Netzwerk: \(m)"
            }
        }
    }

    /// Single-QSO Live-Upload (realtime.php). Für Auto-Upload nach addQSO.
    /// Returns Outcome — wirft nicht, damit der Aufrufer den State im
    /// QSO persistieren und ggf. weiteres Senden unterbinden kann.
    ///
    /// **Wichtig:** seit dem API-Update (2026) muss der `api`-Parameter
    /// gesetzt sein — sonst blockt die nginx-WAF mit blankem 403. Der
    /// API-Key gehört zur Anwendung HAM-Tools und ist obfuskiert in
    /// `BuildInfo.clubLogApiKey` hinterlegt; ist er leer (z.B. noch nicht
    /// vom Helpdesk geliefert), wird der Request gar nicht erst gefeuert.
    func uploadSingle(qso: QSO,
                      email: String,
                      password: String,
                      callsign: String) async -> UploadOutcome {
        let trimmedEmail    = email.trimmingCharacters(in: .whitespaces)
        let trimmedPassword = password.trimmingCharacters(in: .whitespaces)
        let trimmedApiKey   = BuildInfo.clubLogApiKey
            .trimmingCharacters(in: .whitespaces)
        let trimmedCall     = callsign.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty, !trimmedCall.isEmpty
        else { return .authFailed("Email / Password / Callsign fehlen in Settings") }
        guard !trimmedApiKey.isEmpty
        else { return .authFailed("App-API-Key noch nicht hinterlegt — wird mit dem nächsten Update ausgeliefert.") }

        // Ein einzelner ADIF-Record, abgeschlossen mit <EOR>. ADIFCodec
        // schreibt den <EOR> ans Ende mit dazu.
        let adifRecord = ADIFCodec.encodeRecord(qso)

        var req = URLRequest(url: Self.realtimeURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded",
                     forHTTPHeaderField: "Content-Type")
        req.setValue("HAM-Tools (macOS)",
                     forHTTPHeaderField: "User-Agent")
        req.httpBody = formEncode([
            "email":    trimmedEmail,
            "password": trimmedPassword,
            "callsign": trimmedCall,
            "adif":     adifRecord,
            "api":      trimmedApiKey
        ])
        req.timeoutInterval = 30

        return await performRequest(req)
    }

    /// Bulk-Upload (putlogs.php) — eine zusammengefasste ADIF-Datei mit
    /// allen QSOs in einem Request. Für vom User getriggerte Backfills.
    /// Verlangt seit dem 2026-API-Update zusätzlich `api`-Parameter
    /// (statt password — putlogs.php ist API-Key-only). Der App-API-Key
    /// kommt aus BuildInfo.clubLogApiKey.
    func uploadBatch(qsos: [QSO],
                     logName: String,
                     email: String,
                     callsign: String) async -> UploadOutcome {
        let trimmedEmail    = email.trimmingCharacters(in: .whitespaces)
        let trimmedApiKey   = BuildInfo.clubLogApiKey
            .trimmingCharacters(in: .whitespaces)
        let trimmedCall     = callsign.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, !trimmedCall.isEmpty
        else { return .authFailed("Email / Callsign fehlen in Settings") }
        guard !trimmedApiKey.isEmpty
        else { return .authFailed("App-API-Key noch nicht hinterlegt — wird mit dem nächsten Update ausgeliefert.") }
        guard !qsos.isEmpty else { return .rejected("Keine QSOs zum Hochladen") }

        let adifText = ADIFCodec.encode(qsos: qsos, logName: logName)
        let boundary = "----HAMToolsClubLogBoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"

        var body = Data()
        appendFormField(&body, boundary: boundary, name: "email",    value: trimmedEmail)
        appendFormField(&body, boundary: boundary, name: "api",      value: trimmedApiKey)
        appendFormField(&body, boundary: boundary, name: "callsign", value: trimmedCall)
        appendFileField(&body, boundary: boundary, name: "file",
                        filename: "\(logName).adi",
                        contentType: "text/plain",
                        data: Data(adifText.utf8))
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: Self.putlogsURL)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)",
                     forHTTPHeaderField: "Content-Type")
        req.setValue("HAM-Tools (macOS)",
                     forHTTPHeaderField: "User-Agent")
        req.httpBody = body
        req.timeoutInterval = 60

        return await performRequest(req)
    }

    // MARK: - Shared HTTP

    private func performRequest(_ req: URLRequest) async -> UploadOutcome {
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

        let bodyPreview = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let snippet = String(bodyPreview.prefix(200))

        switch http.statusCode {
        case 200:
            return .accepted
        case 401, 403:
            return .authFailed(snippet.isEmpty ? "HTTP \(http.statusCode)" : snippet)
        default:
            return .rejected("HTTP \(http.statusCode): \(snippet)")
        }
    }

    // MARK: - Form-Encoding Helpers

    private func formEncode(_ params: [String: String]) -> Data {
        let allowed = CharacterSet.urlQueryAllowed
        let encoded = params.map { key, value -> String in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
        return Data(encoded.utf8)
    }

    private func appendFormField(_ body: inout Data, boundary: String,
                                 name: String, value: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append(value.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
    }

    private func appendFileField(_ body: inout Data, boundary: String,
                                 name: String, filename: String,
                                 contentType: String, data: Data) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
    }
}
