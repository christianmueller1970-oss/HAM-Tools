import Foundation

// Verarbeitet den eigentlichen ADIF-Upload an POTAs asynchrones Job-System:
//
//   POST https://api.pota.app/adif
//   authorization: <Cognito ID-Token>
//   content-type: multipart/form-data; boundary=...
//
//   ------boundary
//   Content-Disposition: form-data; name="file"; filename="POTA@<REF>.adi"
//   Content-Type: text/plain
//
//   <ADIF-Inhalt>
//   ------boundary--
//
// Server-Response (200) ist sehr klein (~18 Bytes) — vermutlich
// `{"jobId": 1234567}`. Der Upload-Effekt ist async: POTA legt den Job
// in seiner Queue ab und verarbeitet ihn im Backend. Den Job-Status holen
// wir später über [[PotaJobsService]].
//
// Body-Format aus HAR-Analyse 2026-05-16 plus dem `userComment`-Feld
// in der GET /user/jobs Liste abgeleitet — Chrome hat den Body selbst
// nicht in die HAR exportiert (bekanntes multipart-Manko). Field-Name
// `file` ist die übliche AWS-API-Gateway-Konvention für proxied
// File-Uploads; sollte es `adif` oder `log` sein, kommt vom Server ein
// klarer 400. Trial-Bestätigung beim ersten echten Upload.
@MainActor
final class PotaUploadService {

    enum UploadError: LocalizedError {
        case noQSOs
        case authMissing
        case http(status: Int, body: String)
        case invalidResponse
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .noQSOs:                 return "Keine QSOs zum Hochladen"
            case .authMissing:            return "Username/Passwort fehlen in den Einstellungen"
            case .http(let status, let b): return "POTA-Server: HTTP \(status) — \(b)"
            case .invalidResponse:        return "Unerwartete POTA-Antwort (kein jobId)"
            case .networkError(let m):    return m
            }
        }
    }

    struct UploadResult {
        let jobId:    Int
        let adifSize: Int    // Byte-Anzahl der gesendeten ADIF (nur Info/Log)
    }

    private let auth: CognitoAuthService

    init(auth: CognitoAuthService) { self.auth = auth }

    /// Lädt die übergebenen QSOs als ADIF an POTA hoch. ADIF wird in-memory
    /// generiert via `ADIFCodec.encode`. `filename` landet in POTAs Job-
    /// Eintrag als `userComment`-Feld — bewährt ist `POTA@<REF>.adi`.
    func upload(qsos: [QSO],
                logName: String,
                filename: String,
                username: String,
                password: String) async throws -> UploadResult {
        guard !qsos.isEmpty else { throw UploadError.noQSOs }
        guard !username.isEmpty, !password.isEmpty else { throw UploadError.authMissing }

        let idToken: String
        do {
            idToken = try await auth.validIdToken(username: username,
                                                   password: password)
        } catch let e as CognitoAuthService.AuthError {
            throw UploadError.networkError(e.errorDescription ?? "Login-Fehler")
        }

        let adifString = ADIFCodec.encode(qsos: qsos, logName: logName)
        let adifBytes  = Data(adifString.utf8)
        let boundary   = "----HAMToolsFormBoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let body       = makeMultipartBody(boundary: boundary,
                                           fieldName: "file",
                                           filename: filename,
                                           contentType: "text/plain",
                                           fileBytes: adifBytes)

        var req = URLRequest(url: URL(string: "https://api.pota.app/adif")!)
        req.httpMethod = "POST"
        req.setValue(idToken, forHTTPHeaderField: "authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)",
                     forHTTPHeaderField: "content-type")
        req.setValue("application/json, text/plain, */*",
                     forHTTPHeaderField: "accept")
        req.setValue("https://pota.app", forHTTPHeaderField: "origin")
        req.httpBody = body

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw UploadError.networkError(error.localizedDescription)
        }
        guard let http = resp as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }
        if http.statusCode != 200 {
            let txt = String(data: data, encoding: .utf8) ?? "(no body)"
            throw UploadError.http(status: http.statusCode, body: txt)
        }

        // Response ist mini-JSON; das Schema haben wir nicht 100% sicher
        // ausgegraben (Chrome hat den Body in der HAR weggelassen). Wir
        // versuchen jobId als Int, dann als String, dann verschiedene Keys.
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw UploadError.invalidResponse }

        let jobId: Int
        if let v = json["jobId"] as? Int { jobId = v }
        else if let s = json["jobId"] as? String, let v = Int(s) { jobId = v }
        else if let v = json["id"] as? Int { jobId = v }
        else if let s = json["id"] as? String, let v = Int(s) { jobId = v }
        else {
            // Sollte sich rausstellen, dass das Schema anders ist (z. B.
            // `{"job_id": 123}`), greift das hier — der Body landet im
            // Error-Detail und wir können nachjustieren.
            throw UploadError.http(status: 200,
                                   body: String(data: data, encoding: .utf8) ?? "(unparseable)")
        }
        return UploadResult(jobId: jobId, adifSize: adifBytes.count)
    }

    // MARK: - Multipart-Helper

    private func makeMultipartBody(boundary: String,
                                   fieldName: String,
                                   filename: String,
                                   contentType: String,
                                   fileBytes: Data) -> Data {
        var body = Data()
        let nl = "\r\n"
        body.append("--\(boundary)\(nl)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\(nl)".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\(nl)\(nl)".data(using: .utf8)!)
        body.append(fileBytes)
        body.append("\(nl)--\(boundary)--\(nl)".data(using: .utf8)!)
        return body
    }
}
