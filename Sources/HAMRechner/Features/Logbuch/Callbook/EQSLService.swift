import Foundation

// Phase 6 Schritt 2 — eQSL.cc Upload.
//
// API-Endpoint:
//   https://www.eqsl.cc/qslcard/ImportADIF.cfm
//
// Form-Encoded POST mit Feldern:
//   • EQSL_USER  — eQSL.cc-Benutzername (so verlangt der Endpoint, getestet
//                  am 2026-05-19; `EQSLUserName` lehnt mit „Missing eQSL_User" ab)
//   • EQSL_PSWD  — eQSL.cc-Passwort
//   • ADIFData   — ein oder mehrere ADIF-Records, terminiert mit <EOR>
//   • Confirm    — Optional, hier ignoriert (wir wollen direkt importieren)
//
// Für Multi-QTH-User: Nickname (auch „QTH Nickname" genannt) wird nicht als
// Form-Param sondern direkt im ADIF-Record als `APP_EQSL_QTH_NICKNAME` mit-
// geschickt — eQSL routet den Record dann auf das passende QTH-Profil.
//
// Response: HTML mit Schlüssel-Strings, die wir aus dem Body suchen:
//   • "Result: X out of Y records added"           → akzeptiert
//   • "Warning: ... duplicate ..." / "Already in"  → duplicate (wie OK werten)
//   • "Error: Bad callsign"                        → rejected
//   • "Username/Password Incorrect"                → authFailed
//
// **Defensiv:** eQSL liefert kein strukturiertes JSON, der HTML-Body muss
// per Substring-Match interpretiert werden. Bei unbekannten Mustern → rejected
// statt accepted, damit kein QSO fälschlich als "OK" markiert wird.
final class EQSLService: Sendable {

    static let importADIFURL = URL(string: "https://www.eqsl.cc/qslcard/ImportADIF.cfm")!

    enum UploadOutcome: Equatable {
        case accepted
        case duplicate
        case authFailed(String)
        case rejected(String)
        case network(String)

        var statusInt: Int {
            switch self {
            case .accepted:  return 1
            case .duplicate: return 2
            case .authFailed, .rejected, .network: return 3
            }
        }
        var failureReason: String? {
            switch self {
            case .accepted, .duplicate: return nil
            case .authFailed(let m):    return "Auth: \(m)"
            case .rejected(let m):      return m
            case .network(let m):       return "Netzwerk: \(m)"
            }
        }
    }

    /// Single-QSO Upload. `nickname` ist optional — wenn gesetzt, wird er als
    /// `APP_EQSL_QTH_NICKNAME` in den ADIF-Record geschrieben und routet auf
    /// das passende QTH-Profil im User-Account.
    func uploadSingle(qso: QSO,
                      username: String,
                      password: String,
                      nickname: String?) async -> UploadOutcome {
        let u = username.trimmingCharacters(in: .whitespaces)
        let p = password.trimmingCharacters(in: .whitespaces)
        guard !u.isEmpty, !p.isEmpty else {
            return .authFailed("Username / Password fehlen in Settings")
        }

        let record = adifRecordWithNickname(qso: qso, nickname: nickname)

        var req = URLRequest(url: Self.importADIFURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded",
                     forHTTPHeaderField: "Content-Type")
        req.setValue("HAM-Tools (macOS)",
                     forHTTPHeaderField: "User-Agent")
        req.httpBody = formEncode([
            "EQSL_USER": u,
            "EQSL_PSWD": p,
            "ADIFData":  record
        ])
        req.timeoutInterval = 30

        return await performRequest(req)
    }

    /// Bulk-Upload: mehrere QSOs in einem Request. Nicknames werden pro QSO
    /// im Record geschrieben (alle QSOs eines Bulk-Calls teilen aktuell
    /// denselben Nickname — der Aufrufer entscheidet welcher).
    func uploadBatch(qsos: [QSO],
                     username: String,
                     password: String,
                     nickname: String?) async -> UploadOutcome {
        guard !qsos.isEmpty else { return .rejected("Keine QSOs zum Hochladen") }
        let u = username.trimmingCharacters(in: .whitespaces)
        let p = password.trimmingCharacters(in: .whitespaces)
        guard !u.isEmpty, !p.isEmpty else {
            return .authFailed("Username / Password fehlen in Settings")
        }

        let records = qsos.map { adifRecordWithNickname(qso: $0, nickname: nickname) }
                          .joined()

        var req = URLRequest(url: Self.importADIFURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded",
                     forHTTPHeaderField: "Content-Type")
        req.setValue("HAM-Tools (macOS)",
                     forHTTPHeaderField: "User-Agent")
        req.httpBody = formEncode([
            "EQSL_USER": u,
            "EQSL_PSWD": p,
            "ADIFData":  records
        ])
        req.timeoutInterval = 60

        return await performRequest(req)
    }

    // MARK: - ADIF-Record

    private func adifRecordWithNickname(qso: QSO, nickname: String?) -> String {
        // ADIFCodec.encodeRecord schreibt den Record inkl. <EOR>. Wir patchen
        // das APP_EQSL_QTH_NICKNAME vor das <EOR>, weil das ADIF-Feld zum
        // Datensatz gehört und nicht in den Header.
        let base = ADIFCodec.encodeRecord(qso)
        guard let nick = nickname?
            .trimmingCharacters(in: .whitespaces), !nick.isEmpty
        else { return base }

        let nickField = "<APP_EQSL_QTH_NICKNAME:\(nick.utf8.count)>\(nick) "
        if let eorRange = base.range(of: "<EOR>", options: .caseInsensitive) {
            return base.replacingCharacters(in: eorRange, with: nickField + "<EOR>")
        }
        // Fallback: kein <EOR> gefunden (sollte nicht passieren) — anhängen.
        return base + nickField + "<EOR>"
    }

    // MARK: - HTTP + Response-Parsing

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

        let body = String(data: data, encoding: .utf8) ?? ""
        return Self.interpret(body: body, status: http.statusCode)
    }

    /// Body-Parsing. eQSL liefert immer HTTP 200 — die echte Information
    /// steht im HTML-Body. Wir suchen nach bekannten Schlüssel-Strings.
    /// Reihenfolge der Checks ist relevant: Auth-Fail zuerst, dann Duplikat,
    /// dann Erfolg, sonst Fehler. Case-insensitive, weil eQSL schreibt
    /// uneinheitlich.
    static func interpret(body: String, status: Int) -> UploadOutcome {
        // HTTP-Layer-Fehler (sollte selten vorkommen, eQSL antwortet meist
        // mit 200 auch bei Logik-Fehlern).
        guard status == 200 else {
            return .rejected("HTTP \(status)")
        }
        let lower = body.lowercased()

        if lower.contains("username/password")
            || lower.contains("bad username")
            || lower.contains("incorrect password")
            || lower.contains("invalid login") {
            return .authFailed(snippet(of: body))
        }
        if lower.contains("duplicate")
            || lower.contains("already in")
            || lower.contains("rejected: callsign already exists") {
            return .duplicate
        }
        if lower.contains("result: 1 out of 1")
            || lower.contains("records added")
            || lower.contains("records were added")
            || lower.contains("result: 1 records added") {
            return .accepted
        }
        if lower.contains("bad callsign")
            || lower.contains("error:")
            || lower.contains("rejected:") {
            return .rejected(snippet(of: body))
        }
        // Unbekanntes Muster — defensiv: kein Erfolg ohne klares Signal.
        return .rejected("Unverständliche eQSL-Antwort: \(snippet(of: body))")
    }

    private static func snippet(of body: String) -> String {
        let trimmed = body
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "<[^>]+>", with: "",
                                  options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return String(trimmed.prefix(200))
    }

    // MARK: - Form-Encoding

    /// RFC-3986-konformes x-www-form-urlencoded. Analog zu ClubLogService —
    /// CharacterSet.urlQueryAllowed ist zu lasch und lässt z.B. `=` durch.
    private static let formAllowed: CharacterSet = {
        CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    }()

    private func formEncode(_ params: [String: String]) -> Data {
        let encoded = params.map { key, value -> String in
            let k = key.addingPercentEncoding(withAllowedCharacters: Self.formAllowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: Self.formAllowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
        return Data(encoded.utf8)
    }
}
