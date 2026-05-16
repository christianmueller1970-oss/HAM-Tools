import Foundation

// Holt die Liste der Upload-Jobs von POTA — wird vom Upload-Sheet nach
// einem erfolgreichen POST gepollt, um aus der Job-ID Status + verarbeitete
// QSO-Counts zu lesen.
//
// Schema-Beispiel aus HAR-Analyse 2026-05-16:
//   {
//     "jobId": 1480159, "submitted": "2026-05-16T07:49:36",
//     "processed": null, "status": 7,              // 7 = queued · 2 = processed
//     "reference": "DE-1098", "parkName": "...",
//     "cw": 0, "data": 0, "phone": 0, "total": 0, "inserted": 0,
//     "userComment": "POTA@DE-1098.adi",
//     "md5sum": "...", "userId": 24788, ...
//   }
@MainActor
final class PotaJobsService {

    struct Job: Identifiable {
        let id: Int
        let submitted: Date?
        let processed: Date?
        let status: Int
        let reference: String?
        let parkName: String?
        let cw: Int
        let data: Int
        let phone: Int
        let total: Int
        let inserted: Int
        let userComment: String?

        var isProcessed: Bool { status == 2 }
        var isQueued:    Bool { status == 7 }

        // Anzahl QSOs, die POTA als "akzeptiert" geführt hat. Nur sinnvoll
        // nach `isProcessed`.
        var acceptedCount: Int { inserted }
    }

    enum JobsError: LocalizedError {
        case http(status: Int, body: String)
        case invalidResponse
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .http(let s, let b):   return "POTA-Server: HTTP \(s) — \(b)"
            case .invalidResponse:      return "Unerwartete POTA-Antwort (Job-Liste)"
            case .networkError(let m):  return m
            }
        }
    }

    private let auth: CognitoAuthService

    init(auth: CognitoAuthService) { self.auth = auth }

    /// Gesamte Job-Liste des eingeloggten Users. POTA gibt die in
    /// absteigender Reihenfolge (neuester zuerst) zurück.
    func fetchJobs(username: String, password: String) async throws -> [Job] {
        let idToken: String
        do {
            idToken = try await auth.validIdToken(username: username, password: password)
        } catch let e as CognitoAuthService.AuthError {
            throw JobsError.networkError(e.errorDescription ?? "Login-Fehler")
        }

        var req = URLRequest(url: URL(string: "https://api.pota.app/user/jobs")!)
        req.httpMethod = "GET"
        req.setValue(idToken, forHTTPHeaderField: "authorization")
        req.setValue("application/json, text/plain, */*",
                     forHTTPHeaderField: "accept")
        req.setValue("https://pota.app", forHTTPHeaderField: "origin")

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw JobsError.networkError(error.localizedDescription)
        }
        guard let http = resp as? HTTPURLResponse else {
            throw JobsError.invalidResponse
        }
        if http.statusCode != 200 {
            let txt = String(data: data, encoding: .utf8) ?? "(no body)"
            throw JobsError.http(status: http.statusCode, body: txt)
        }
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw JobsError.invalidResponse
        }
        return arr.map { Self.parse($0) }
    }

    /// Sucht eine konkrete Job-ID in der Liste. Wird vom Upload-Sheet
    /// nach dem POST gerufen, um den Status des eben angelegten Jobs zu
    /// finden.
    func findJob(id: Int, username: String, password: String) async throws -> Job? {
        let all = try await fetchJobs(username: username, password: password)
        return all.first(where: { $0.id == id })
    }

    // MARK: - Parser

    private static func parse(_ d: [String: Any]) -> Job {
        Job(
            id:           (d["jobId"] as? Int) ?? 0,
            submitted:    parseISO(d["submitted"] as? String),
            processed:    parseISO(d["processed"] as? String),
            status:       (d["status"] as? Int) ?? 0,
            reference:    d["reference"] as? String,
            parkName:     d["parkName"]  as? String,
            cw:           (d["cw"]       as? Int) ?? 0,
            data:         (d["data"]     as? Int) ?? 0,
            phone:        (d["phone"]    as? Int) ?? 0,
            total:        (d["total"]    as? Int) ?? 0,
            inserted:     (d["inserted"] as? Int) ?? 0,
            userComment:  d["userComment"] as? String
        )
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        // POTA-Format ohne Z am Ende: "2026-05-16T07:49:36"
        f.formatOptions = [.withInternetDateTime,
                           .withColonSeparatorInTime,
                           .withDashSeparatorInDate]
        return f
    }()

    private static func parseISO(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        // POTA sendet "YYYY-MM-DDTHH:mm:ss" ohne Timezone → wir behandeln als UTC
        if let d = iso.date(from: s + "Z") { return d }
        if let d = iso.date(from: s) { return d }
        return nil
    }
}
