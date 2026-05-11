import Foundation

// HamQTH.com XML-API (https://www.hamqth.com/developers.php).
// Kostenlos, Login mit User+Passwort, dann Session-ID für Queries.
// Endpoint: https://www.hamqth.com/xml.php
final class HamQTHService: CallbookService {
    let name = "HamQTH"
    private let baseURL = URL(string: "https://www.hamqth.com/xml.php")!
    private let appName = "HAM-Tools"

    private let settings: CallbookSettings
    private var sessionID: String?
    private let session: URLSession

    init(settings: CallbookSettings) {
        self.settings = settings
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    nonisolated var isConfigured: Bool {
        let user = UserDefaults.standard.string(forKey: "callbook.hamqth.username") ?? ""
        let pass = UserDefaults.standard.string(forKey: "callbook.hamqth.password") ?? ""
        return !user.trimmingCharacters(in: .whitespaces).isEmpty
            && !pass.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Lookup

    func lookup(call: String) async -> CallbookResult? {
        let trimmed = call.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmed.isEmpty else { return nil }

        if sessionID == nil {
            sessionID = await login()
        }
        guard let id = sessionID else { return nil }

        var result = await query(call: trimmed, id: id)
        if result == nil {
            // Session evtl. abgelaufen — einmal neu loggen
            sessionID = await login()
            if let newID = sessionID {
                result = await query(call: trimmed, id: newID)
            }
        }
        return result
    }

    // MARK: - Login

    private func login() async -> String? {
        let user = settings.hamqthUsername.trimmingCharacters(in: .whitespaces)
        let pass = settings.hamqthPassword.trimmingCharacters(in: .whitespaces)
        guard !user.isEmpty, !pass.isEmpty else { return nil }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "u", value: user),
            URLQueryItem(name: "p", value: pass)
        ]
        guard let url = components.url else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            guard let xml = String(data: data, encoding: .utf8) else { return nil }
            if let err = extract(tag: "error", from: xml) {
                print("HamQTH login failed: \(err)")
                return nil
            }
            return extract(tag: "id", from: xml)
        } catch {
            print("HamQTH login network error: \(error.localizedDescription)")
            return nil
        }
    }

    private func query(call: String, id: String) async -> CallbookResult? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "id",       value: id),
            URLQueryItem(name: "callsign", value: call),
            URLQueryItem(name: "prg",      value: appName)
        ]
        guard let url = components.url else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            guard let xml = String(data: data, encoding: .utf8) else { return nil }
            if let err = extract(tag: "error", from: xml) {
                // »Callsign not found« oder Session-Timeout
                if err.localizedCaseInsensitiveContains("session") { sessionID = nil }
                return nil
            }
            return parseCallsign(from: xml)
        } catch {
            print("HamQTH query network error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - XML-Parsing

    private func parseCallsign(from xml: String) -> CallbookResult? {
        guard xml.contains("<search>") else { return nil }
        var r = CallbookResult()

        // Name: nick (Funkername) bevorzugt; sonst adr_name splitten
        if let nick = extract(tag: "nick", from: xml), !nick.isEmpty {
            r.firstName = nick
        }
        if let full = extract(tag: "adr_name", from: xml), !full.isEmpty {
            let parts = full.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if r.firstName == nil, let first = parts.first {
                r.firstName = String(first)
            }
            if parts.count > 1 {
                r.lastName = String(parts.last!)
            }
        }
        // adr_city bevorzugt vor qth
        r.qth     = extract(tag: "adr_city", from: xml) ?? extract(tag: "qth", from: xml)
        r.street  = extract(tag: "adr_street1", from: xml)
        // adr_country bevorzugt vor country (USA vs »United States« etc.)
        r.country = extract(tag: "adr_country", from: xml) ?? extract(tag: "country", from: xml)
        r.continent = extract(tag: "continent", from: xml)
        r.locator = extract(tag: "grid", from: xml)
        r.cqZone  = extract(tag: "cq",  from: xml).flatMap(Int.init)
        r.ituZone = extract(tag: "itu", from: xml).flatMap(Int.init)
        r.dxccCode = extract(tag: "adif", from: xml).flatMap(Int.init)
        r.email   = extract(tag: "email", from: xml)
        r.lat     = extract(tag: "latitude",  from: xml).flatMap(Double.init)
        r.lon     = extract(tag: "longitude", from: xml).flatMap(Double.init)
        r.imageURL = extract(tag: "picture", from: xml)
        r.qrzURL   = extract(tag: "web", from: xml)

        return r.isEmpty ? nil : r
    }

    private func extract(tag: String, from xml: String) -> String? {
        let pattern = "<\(tag)>([^<]*)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: xml)
        else { return nil }
        let value = String(xml[r])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
        return value.isEmpty ? nil : value
    }
}
