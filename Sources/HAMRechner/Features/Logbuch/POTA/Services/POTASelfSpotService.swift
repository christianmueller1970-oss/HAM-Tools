import Foundation

// POTA-Self-Spotting via api.pota.app/spot/. Anonym (kein Auth-Token,
// kein Cognito-SRP — die Cognito-Hürde betraf den Logbook-Upload, nicht
// das Spot-Endpoint). Schema rekonstruiert aus cwhelchel/hunterlog.
//
// Erfolgreich gesendete Spots landen im POTA-eigenen Spot-Stream
// (sichtbar auf pota.app und im POTA-Spots-Tab unserer App). DX-Cluster
// sehen den Spot nur, wenn dort ein POTA-Bot konfiguriert ist.
enum POTASelfSpotError: Error, LocalizedError {
    case missingField(String)
    case http(status: Int, body: String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingField(let f):   return "Pflichtfeld fehlt: \(f)."
        case .http(let s, let body): return "HTTP \(s) vom POTA-Server.\n\(body.prefix(200))"
        case .network(let m):        return "Netzwerk-Fehler: \(m)"
        }
    }
}

enum POTASelfSpotService {
    static let endpoint = URL(string: "https://api.pota.app/spot/")!

    /// Sendet einen Self-Spot an api.pota.app. Wirft bei Validierungs-,
    /// HTTP- oder Netzwerk-Fehler. Frequenz wird als ganzzahliger kHz-
    /// String übertragen (z.B. 7180 für 40m SSB).
    static func sendSpot(activator: String,
                         spotter: String,
                         frequencyKHz: Int,
                         reference: String,
                         mode: String,
                         comments: String?) async throws {
        guard !activator.isEmpty   else { throw POTASelfSpotError.missingField("Activator-Call") }
        guard !reference.isEmpty   else { throw POTASelfSpotError.missingField("Park-Referenz") }
        guard frequencyKHz > 0     else { throw POTASelfSpotError.missingField("Frequenz") }
        guard !mode.isEmpty        else { throw POTASelfSpotError.missingField("Mode") }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        req.setValue("https://pota.app",  forHTTPHeaderField: "Origin")
        req.setValue("https://pota.app/", forHTTPHeaderField: "Referer")
        req.setValue("HAM-Tools",         forHTTPHeaderField: "User-Agent")

        let body: [String: String] = [
            "activator": activator.uppercased(),
            "spotter":   (spotter.isEmpty ? activator : spotter).uppercased(),
            "frequency": "\(frequencyKHz)",
            "reference": reference.uppercased(),
            "mode":      mode.uppercased(),
            "source":    "HAM-Tools",
            "comments":  comments ?? ""
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw POTASelfSpotError.network("Keine HTTP-Response")
            }
            if !(200...299).contains(http.statusCode) {
                let bodyStr = String(data: data, encoding: .utf8) ?? ""
                throw POTASelfSpotError.http(status: http.statusCode, body: bodyStr)
            }
        } catch let err as POTASelfSpotError {
            throw err
        } catch {
            throw POTASelfSpotError.network(error.localizedDescription)
        }
    }
}
