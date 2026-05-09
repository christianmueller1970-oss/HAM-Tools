import Foundation

// MARK: - Models

struct SOTASummit: Identifiable {
    let id    = UUID()
    let code:    String
    let name:    String
    let altM:    Int
    let lat:     Double
    let lng:     Double
    let points:  Int
    let distKm:  Double
}

struct POTAPark: Identifiable {
    let id        = UUID()
    let reference: String
    let name:      String
    let lat:       Double
    let lng:       Double
    let distKm:    Double
}

struct ElevPoint: Identifiable {
    let id:     Int
    let distKm: Double
    let elevM:  Double
}

// MARK: - Service

actor QTHService {
    static let shared = QTHService()
    private init() {}

    private var cachedCSV: String?
    private var csvFetchedAt: Date?
    private let csvTTL: TimeInterval = 24 * 3600

    // MARK: Geo

    func haversineKm(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let d2r = Double.pi / 180, R = 6371.0
        let dLat = (lat2 - lat1) * d2r, dLng = (lng2 - lng1) * d2r
        let a = sin(dLat/2)*sin(dLat/2) + cos(lat1*d2r)*cos(lat2*d2r)*sin(dLng/2)*sin(dLng/2)
        return R * 2 * atan2(sqrt(a), sqrt(1-a))
    }

    // MARK: SOTA

    func nearbySOTA(lat: Double, lng: Double, radiusKm: Int) async throws -> [SOTASummit] {
        let csv = try await loadSOTACSV()
        return parseSOTA(csv, lat: lat, lng: lng, radius: Double(radiusKm))
    }

    private func loadSOTACSV() async throws -> String {
        if let c = cachedCSV, let d = csvFetchedAt, Date().timeIntervalSince(d) < csvTTL {
            return c
        }
        let url = URL(string: "https://www.sotadata.org.uk/summitslist.csv")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        cachedCSV = text; csvFetchedAt = Date()
        return text
    }

    private func parseSOTA(_ csv: String, lat: Double, lng: Double, radius: Double) -> [SOTASummit] {
        let d2r = Double.pi / 180, R = 6371.0
        let latDel = radius / R / d2r
        let lngDel = radius / (R * cos(lat * d2r)) / d2r
        var metaDone = false, hdrDone = false
        var cC = 0, cN = 3, cA = 4, cLg = 8, cLt = 9, cP = 10
        var out: [SOTASummit] = []

        for raw in csv.components(separatedBy: .newlines) {
            let ln = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ln.isEmpty else { continue }
            if !metaDone { metaDone = true; continue }
            if !hdrDone {
                for (i, h) in csvSplit(ln).enumerated() {
                    switch h.lowercased().trimmingCharacters(in: .whitespaces) {
                    case "summitcode": cC = i
                    case "summitname": cN = i
                    case "altm":       cA = i
                    case "longitude":  cLg = i
                    case "latitude":   cLt = i
                    case "points":     cP = i
                    default: break
                    }
                }
                hdrDone = true; continue
            }
            let f = csvSplit(ln)
            guard f.count > max(cLt, cLg, cC, cN),
                  let slat = Double(f[cLt]), let slng = Double(f[cLg]),
                  !(slat == 0 && slng == 0),
                  abs(slat - lat) <= latDel, abs(slng - lng) <= lngDel else { continue }
            let dist = haversineKm(lat1: lat, lng1: lng, lat2: slat, lng2: slng)
            guard dist <= radius else { continue }
            out.append(SOTASummit(code: f[cC], name: f[cN], altM: Int(f[cA]) ?? 0,
                                  lat: slat, lng: slng,
                                  points: cP < f.count ? Int(f[cP]) ?? 0 : 0,
                                  distKm: (dist * 10).rounded() / 10))
        }
        return out.sorted { $0.distKm < $1.distKm }
    }

    private func csvSplit(_ line: String) -> [String] {
        var out: [String] = [], cur = "", q = false
        for ch in line {
            if ch == "\"" { q.toggle() }
            else if ch == "," && !q { out.append(cur); cur = "" }
            else { cur.append(ch) }
        }
        out.append(cur)
        return out
    }

    // MARK: POTA

    func nearbyPOTA(lat: Double, lng: Double, radiusKm: Int) async throws -> [POTAPark] {
        let d2r = Double.pi / 180
        let dLt = Double(radiusKm) / 111.0 + 0.1
        let dLg = Double(radiusKm) / (111.0 * cos(lat * d2r)) + 0.1
        let urlStr = String(format: "https://api.pota.app/park/grids/%.4f/%.4f/%.4f/%.4f/0",
                            lat - dLt, lng - dLg, lat + dLt, lng + dLg)
        let (data, _) = try await URLSession.shared.data(from: URL(string: urlStr)!)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else { return [] }
        var out: [POTAPark] = []
        for f in features {
            guard let geom = f["geometry"] as? [String: Any],
                  let coords = geom["coordinates"] as? [Double], coords.count >= 2,
                  let props = f["properties"] as? [String: Any] else { continue }
            let plat = coords[1], plng = coords[0]
            let dist = haversineKm(lat1: lat, lng1: lng, lat2: plat, lng2: plng)
            guard dist <= Double(radiusKm) else { continue }
            out.append(POTAPark(
                reference: props["reference"] as? String ?? "",
                name:      props["name"]      as? String ?? "",
                lat: plat, lng: plng,
                distKm: (dist * 10).rounded() / 10
            ))
        }
        return out.sorted { $0.distKm < $1.distKm }
    }

    // MARK: Elevation Profile

    func elevationProfile(lat1: Double, lng1: Double, lat2: Double, lng2: Double,
                          nPts: Int = 80) async throws -> [ElevPoint] {
        let pts = greatCircle(lat1: lat1, lng1: lng1, lat2: lat2, lng2: lng2, n: nPts)
        let locs = pts.map { ["latitude": $0.lat, "longitude": $0.lng] }
        let body = try JSONSerialization.data(withJSONObject: ["locations": locs])
        var req = URLRequest(url: URL(string: "https://api.open-elevation.com/api/v1/lookup")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 45
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return [] }
        let totalKm = haversineKm(lat1: lat1, lng1: lng1, lat2: lat2, lng2: lng2)
        return results.enumerated().map { i, r in
            ElevPoint(id: i,
                      distKm: totalKm * Double(i) / Double(nPts),
                      elevM:  Double(r["elevation"] as? Int ?? 0))
        }
    }

    private func greatCircle(lat1: Double, lng1: Double, lat2: Double, lng2: Double,
                              n: Int) -> [(lat: Double, lng: Double)] {
        let d2r = Double.pi / 180
        let φ1 = lat1*d2r, λ1 = lng1*d2r, φ2 = lat2*d2r, λ2 = lng2*d2r
        let d = 2 * asin(sqrt(pow(sin((φ2-φ1)/2), 2) + cos(φ1)*cos(φ2)*pow(sin((λ2-λ1)/2), 2)))
        guard d > 1e-6 else { return Array(repeating: (lat1, lng1), count: n + 1) }
        return (0...n).map { i in
            let f = Double(i) / Double(n)
            let A = sin((1-f)*d)/sin(d), B = sin(f*d)/sin(d)
            let x = A*cos(φ1)*cos(λ1) + B*cos(φ2)*cos(λ2)
            let y = A*cos(φ1)*sin(λ1) + B*cos(φ2)*sin(λ2)
            let z = A*sin(φ1) + B*sin(φ2)
            return (atan2(z, sqrt(x*x+y*y)) / d2r, atan2(y, x) / d2r)
        }
    }
}
