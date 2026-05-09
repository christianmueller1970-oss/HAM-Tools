import Foundation

// MARK: - Base API Fetcher

private let userAgent = "HAMTools/2.0 HB9HJI"

private func fetchJSON(from url: URL) async throws -> Any {
    var req = URLRequest(url: url, timeoutInterval: 15)
    req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    let (data, _) = try await URLSession.shared.data(for: req)
    return try JSONSerialization.jsonObject(with: data)
}

private func makeSpot(freqKHz: Double, dxCall: String, spotter: String,
                      comment: String, spotTime: String, source: String) -> DXSpot? {
    guard freqKHz > 0, dxCall.count >= 3 else { return nil }
    let dx = lookupPrefix(dxCall)
    let sp = lookupPrefix(spotter)
    var spot = DXSpot(spotter: spotter.isEmpty ? source : spotter,
                      frequency: freqKHz, dxCall: dxCall,
                      comment: String(comment.prefix(80)),
                      spotTime: spotTime, source: source)
    spot.band        = freqToBand(freqKHz)
    spot.mode        = freqToMode(freqKHz, comment: comment)
    spot.country     = dx.country
    spot.continent   = dx.continent
    spot.lat         = dx.lat
    spot.lon         = dx.lon
    spot.spotterLat  = sp.lat
    spot.spotterLon  = sp.lon
    spot.timestamp   = Date()
    return spot.isValid ? spot : nil
}

private func isoToTime(_ ts: String) -> String {
    guard !ts.isEmpty,
          let dt = ISO8601DateFormatter().date(from: ts.replacingOccurrences(of: "Z", with: "+00:00"))
    else { return "" }
    let f = DateFormatter(); f.dateFormat = "HHmm"; f.timeZone = TimeZone(identifier: "UTC")
    return f.string(from: dt) + "Z"
}

// MARK: - SOTA Fetcher

actor SOTAFetcher {
    static let url = URL(string: "https://api2.sota.org.uk/api/spots/50/all")!
    static let pollInterval: TimeInterval = 60
    private var seenIDs = Set<String>()

    func fetchNew() async -> [DXSpot] {
        guard let raw = try? await fetchJSON(from: Self.url),
              let list = raw as? [[String: Any]] else { return [] }
        var results: [DXSpot] = []
        for entry in list {
            let uid = String(entry["id"] as? Int ?? 0)
            guard !seenIDs.contains(uid) else { continue }
            seenIDs.insert(uid)
            if seenIDs.count > 5000 { seenIDs.removeAll() }
            let freqMHz = (entry["frequency"] as? Double) ?? Double(entry["frequency"] as? String ?? "") ?? 0
            let dxCall  = (entry["activatorCallsign"] as? String ?? "").uppercased()
            let spotter = (entry["callsign"] as? String ?? "").uppercased()
            let summit  = entry["summitCode"] as? String ?? ""
            let notes   = entry["comments"] as? String ?? ""
            let comment = "SOTA \(summit) \(notes)".trimmingCharacters(in: .whitespaces)
            let ts      = entry["timeStamp"] as? String ?? entry["timestamp"] as? String ?? ""
            if let spot = makeSpot(freqKHz: freqMHz * 1000, dxCall: dxCall, spotter: spotter,
                                   comment: comment, spotTime: isoToTime(ts), source: "SOTAwatch3") {
                results.append(spot)
            }
        }
        return results
    }
}

// MARK: - POTA Fetcher

actor POTAFetcher {
    static let url = URL(string: "https://api.pota.app/spot/activator")!
    static let pollInterval: TimeInterval = 60
    private var seenIDs = Set<String>()

    func fetchNew() async -> [DXSpot] {
        guard let raw = try? await fetchJSON(from: Self.url),
              let list = raw as? [[String: Any]] else { return [] }
        var results: [DXSpot] = []
        for entry in list {
            let uid = String(entry["spotId"] as? Int ?? 0)
                + (entry["activator"] as? String ?? "")
            guard !seenIDs.contains(uid) else { continue }
            seenIDs.insert(uid)
            if seenIDs.count > 5000 { seenIDs.removeAll() }
            let freqKHz = Double(entry["frequency"] as? String ?? "") ?? entry["frequency"] as? Double ?? 0
            let dxCall  = (entry["activator"] as? String ?? "").uppercased()
            let spotter = (entry["spotter"] as? String ?? "").uppercased()
            let ref     = entry["reference"] as? String ?? ""
            let name    = entry["name"] as? String ?? ""
            let comment = "POTA \(ref) \(name)".trimmingCharacters(in: .whitespaces)
            let ts      = entry["spotTime"] as? String ?? ""
            var spot    = makeSpot(freqKHz: freqKHz, dxCall: dxCall, spotter: spotter,
                                   comment: comment, spotTime: isoToTime(ts), source: "POTA")
            // POTA sometimes provides direct coordinates
            if let lat = entry["latitude"] as? Double, let lon = entry["longitude"] as? Double,
               lat != 0 || lon != 0 {
                spot?.lat = lat; spot?.lon = lon
            }
            if let s = spot { results.append(s) }
        }
        return results
    }
}

// MARK: - WWFF Fetcher

actor WWFFFetcher {
    static let candidates = [
        URL(string: "https://wwff.co/api/spots/json/"),
        URL(string: "https://www.cqgma.org/spots/wwff.php"),
    ].compactMap { $0 }
    static let pollInterval: TimeInterval = 120
    private var seenIDs = Set<String>()
    private var workingURL: URL? = nil

    func fetchNew() async -> [DXSpot] {
        let urls = workingURL.map { [$0] + Self.candidates } ?? Self.candidates
        for url in urls {
            if let spots = try? await fetch(from: url), !spots.isEmpty {
                workingURL = url
                return spots
            }
        }
        return []
    }

    private func fetch(from url: URL) async throws -> [DXSpot] {
        let raw  = try await fetchJSON(from: url)
        let list: [[String: Any]]
        if let arr = raw as? [[String: Any]] {
            list = arr
        } else if let dict = raw as? [String: Any] {
            list = (dict["spots"] ?? dict["data"] ?? dict["result"]) as? [[String: Any]] ?? []
        } else { return [] }

        var results: [DXSpot] = []
        for entry in list {
            let freqKHz = entry["freq"] as? Double ?? entry["frequency"] as? Double ?? 0
            let dxCall  = ((entry["dxCall"] ?? entry["activator"] ?? entry["callsign"]) as? String ?? "").uppercased()
            guard freqKHz > 0, dxCall.count >= 3 else { continue }
            let uid = String(entry["id"] as? Int ?? 0) + dxCall
            guard !seenIDs.contains(uid) else { continue }
            seenIDs.insert(uid)
            if seenIDs.count > 5000 { seenIDs.removeAll() }
            let ref     = (entry["wwffRef"] ?? entry["reference"] ?? entry["park"]) as? String ?? ""
            let comment = "WWFF \(ref)".trimmingCharacters(in: .whitespaces)
            let spotter = (entry["spotter"] as? String ?? "").uppercased()
            let ts      = entry["time"] as? String ?? entry["spotTime"] as? String ?? ""
            if let spot = makeSpot(freqKHz: freqKHz, dxCall: dxCall, spotter: spotter,
                                   comment: comment, spotTime: isoToTime(ts), source: "WWFF") {
                results.append(spot)
            }
        }
        return results
    }
}
