import Foundation

// QRZ.com XML-API Anbindung (https://xmldata.qrz.com/xml/current/).
// Login liefert eine Session-Key, der bei nachfolgenden Queries
// mitgegeben wird. Session bleibt ~24h gültig — wir cachen sie und
// requesten on demand neu.
final class QRZService: CallbookService {
    let name = "QRZ.com"
    private let baseURL = URL(string: "https://xmldata.qrz.com/xml/current/")!
    private let agent = "HAM-Tools/1.5"

    private let settings: CallbookSettings
    private var sessionKey: String?
    private let session: URLSession

    init(settings: CallbookSettings) {
        self.settings = settings
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    nonisolated var isConfigured: Bool {
        let user = UserDefaults.standard.string(forKey: "callbook.qrz.username") ?? ""
        let pass = UserDefaults.standard.string(forKey: "callbook.qrz.password") ?? ""
        return !user.trimmingCharacters(in: .whitespaces).isEmpty
            && !pass.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Lookup

    func lookup(call: String) async -> CallbookResult? {
        let trimmed = call.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmed.isEmpty else { return nil }

        // Session holen falls noch keine
        if sessionKey == nil {
            sessionKey = await login()
        }
        guard let key = sessionKey else { return nil }

        // Query
        var result = await query(call: trimmed, key: key)
        // Wenn die Session abgelaufen ist, einmal neu einloggen und retry
        if result == nil {
            sessionKey = await login()
            if let newKey = sessionKey {
                result = await query(call: trimmed, key: newKey)
            }
        }
        return result
    }

    // MARK: - Login

    private func login() async -> String? {
        let user = settings.qrzUsername.trimmingCharacters(in: .whitespaces)
        let pass = settings.qrzPassword.trimmingCharacters(in: .whitespaces)
        guard !user.isEmpty, !pass.isEmpty else { return nil }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "username", value: user),
            URLQueryItem(name: "password", value: pass),
            URLQueryItem(name: "agent",    value: agent)
        ]
        guard let url = components.url else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            guard let xml = String(data: data, encoding: .utf8) else { return nil }
            if let err = extract(tag: "Error", from: xml) {
                print("QRZ login failed: \(err)")
                return nil
            }
            return extract(tag: "Key", from: xml)
        } catch {
            print("QRZ login network error: \(error.localizedDescription)")
            return nil
        }
    }

    private func query(call: String, key: String) async -> CallbookResult? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "s",         value: key),
            URLQueryItem(name: "callsign",  value: call)
        ]
        guard let url = components.url else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            guard let xml = String(data: data, encoding: .utf8) else { return nil }
            // »Not found« oder »Session Timeout« → nil zurück damit der
            // Caller bei Bedarf neu loggt.
            if let _ = extract(tag: "Error", from: xml) { return nil }
            return parseCallsign(from: xml)
        } catch {
            print("QRZ query network error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - XML-Parsing (flach, regex-basiert — die QRZ-Response hat
    // keine geschachtelten Felder die uns interessieren)

    private func parseCallsign(from xml: String) -> CallbookResult? {
        // Wenn kein <Callsign>-Block, dann nichts brauchbares
        guard xml.contains("<Callsign>") else { return nil }
        var r = CallbookResult()
        r.firstName = extract(tag: "fname",   from: xml)
        r.lastName  = extract(tag: "name",    from: xml)
        r.qth       = extract(tag: "addr2",   from: xml)  // City
        r.street    = extract(tag: "addr1",   from: xml)
        r.state     = extract(tag: "state",   from: xml)
        r.country   = extract(tag: "country", from: xml)
        r.locator   = extract(tag: "grid",    from: xml)
        r.cqZone    = extract(tag: "cqzone",  from: xml).flatMap(Int.init)
        r.ituZone   = extract(tag: "ituzone", from: xml).flatMap(Int.init)
        r.email     = extract(tag: "email",   from: xml)
        r.lat       = extract(tag: "lat",     from: xml).flatMap(Double.init)
        r.lon       = extract(tag: "lon",     from: xml).flatMap(Double.init)
        // Kontinent aus Country herleiten via lokaler DXCC-Daten,
        // falls QRZ ihn nicht direkt liefert.
        if r.continent == nil, let country = r.country {
            r.continent = continentForCountry(country)
        }
        return r.isEmpty ? nil : r
    }

    private func extract(tag: String, from xml: String) -> String? {
        // Einfacher non-nested-Extractor: <tag>value</tag>
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

    private func continentForCountry(_ country: String) -> String? {
        // Sehr grobe Heuristik; im Zweifel nutzt die App das was QRZ
        // schickt. Bewusst klein gehalten — eine richtige Country→Continent-
        // Tabelle gibt's in CTY.DAT, das wäre Phase 4-Vorgriff.
        let c = country.lowercased()
        if c.contains("germany") || c.contains("switzerland") || c.contains("austria")
            || c.contains("italy") || c.contains("france") || c.contains("spain")
            || c.contains("netherlands") || c.contains("belgium") || c.contains("portugal")
            || c.contains("poland") || c.contains("czech") || c.contains("slovakia")
            || c.contains("hungary") || c.contains("sweden") || c.contains("norway")
            || c.contains("denmark") || c.contains("finland") || c.contains("greece")
            || c.contains("ireland") || c.contains("united kingdom") || c.contains("england") {
            return "EU"
        }
        if c.contains("united states") || c.contains("canada") || c.contains("mexico") {
            return "NA"
        }
        if c.contains("brazil") || c.contains("argentina") || c.contains("chile")
            || c.contains("peru") || c.contains("colombia") || c.contains("venezuela") {
            return "SA"
        }
        if c.contains("china") || c.contains("japan") || c.contains("korea")
            || c.contains("russia") || c.contains("india") {
            return "AS"
        }
        if c.contains("australia") || c.contains("new zealand") {
            return "OC"
        }
        if c.contains("egypt") || c.contains("south africa") || c.contains("morocco") {
            return "AF"
        }
        return nil
    }
}
