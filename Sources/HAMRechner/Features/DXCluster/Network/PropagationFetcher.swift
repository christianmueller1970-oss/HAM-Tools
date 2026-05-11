import Foundation

struct PropagationData {
    var sfi:        Int?    = nil
    var kp:         Double? = nil
    var aIndex:     Int?    = nil
    var ssn:        Int?    = nil       // Sunspot Number
    var xray:       String? = nil       // X-Ray Class (z.B. "B2.5", "C1.4")
    var solarWind:  Int?    = nil       // Solar Wind Speed in km/s
    var helium:     Double? = nil       // He I 304 Å (Solar EUV)
    var auroraLat:  Int?    = nil       // Aurora-Grenze in °N
    var geomagField:String? = nil       // QUIET / UNSETTLED / ACTIVE / STORM
    var updated:    String? = nil       // Aktualisierungs-Zeit (UTC-String)

    var sfiBand: String {
        guard let v = sfi else { return "?" }
        if v >= 150 { return "Ausgezeichnet" }
        if v >= 100 { return "Gut" }
        if v >= 70  { return "Normal" }
        return "Niedrig"
    }
    var kpBand: String {
        guard let v = kp else { return "?" }
        if v <= 2 { return "Ruhig" }
        if v <= 4 { return "Unsicher" }
        return "Gestört"
    }
}

actor PropagationFetcher {
    // NOAA endpoints
    private static let sfiURL  = URL(string: "https://services.swpc.noaa.gov/json/f107_cm_flux.json")!
    private static let kpURL   = URL(string: "https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json")!
    // hamqsl.com fallback (XML, ham-specific, very reliable)
    private static let hamqslURL = URL(string: "https://www.hamqsl.com/solarxml.php")!

    func fetchOnce() async -> PropagationData {
        var result = PropagationData()

        // --- SFI from NOAA f107_cm_flux.json ---
        // Format: [[time_tag, f107_index, f107_81day_avg], ...]  (first row may be header)
        if let (data, _) = try? await URLSession.shared.data(from: Self.sfiURL) {
            result.sfi = parseSFI(data)
        }

        // --- Kp from NOAA noaa-planetary-k-index.json ---
        // Format: [["time_tag","Kp","Kp_flag"], ["2026-01-01 00:00:00","2.00","0"], ...]
        if let (data, _) = try? await URLSession.shared.data(from: Self.kpURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[Any]] {
            for row in json.reversed() {
                guard row.count >= 2 else { continue }
                let kpRaw = row[1]
                var kp: Double? = nil
                if let v = kpRaw as? Double        { kp = v }
                else if let s = kpRaw as? String   { kp = Double(s.trimmingCharacters(in: .whitespaces)) }
                if let kp, kp >= 0 {
                    result.kp = round(kp * 10) / 10; break
                }
            }
        }

        // --- hamqsl.com (immer aufrufen für SSN/X-Ray/SolarWind/Aurora,
        //                und als Fallback für SFI/Kp/A wenn NOAA scheitert)
        if let (data, _) = try? await URLSession.shared.data(from: Self.hamqslURL),
           let xml = String(data: data, encoding: .utf8) {
            // Fallback für Werte die NOAA nicht geliefert hat
            if result.sfi == nil,
               let v = xmlValue(xml, tag: "solarflux").flatMap(Int.init) {
                result.sfi = v
            }
            if result.kp == nil,
               let v = xmlValue(xml, tag: "kindex").flatMap(Double.init) {
                result.kp = v
            }
            if result.aIndex == nil,
               let v = xmlValue(xml, tag: "aindex").flatMap(Int.init) {
                result.aIndex = v
            }
            // Zusätzliche Solar-Daten
            result.ssn         = xmlValue(xml, tag: "sunspots").flatMap(Int.init)
            result.xray        = xmlValue(xml, tag: "xray")
            result.solarWind   = xmlValue(xml, tag: "solarwind").flatMap { Int(Double($0) ?? 0) }
            result.helium      = xmlValue(xml, tag: "heliumline").flatMap(Double.init)
            result.auroraLat   = xmlValue(xml, tag: "latdegree").flatMap { Int(Double($0) ?? 0) }
            result.geomagField = xmlValue(xml, tag: "geomagfield")
            result.updated     = xmlValue(xml, tag: "updated")
        }

        return result
    }

    // MARK: - Helpers

    private func parseSFI(_ data: Data) -> Int? {
        // Try array-of-arrays format: [[time_tag, f107_index, f107_81day_avg], ...]
        if let json = try? JSONSerialization.jsonObject(with: data) as? [[Any]] {
            for row in json.reversed() {
                guard row.count >= 2 else { continue }
                // Skip header rows (first element is a string starting with "time")
                if let s = row[0] as? String, s.lowercased().hasPrefix("time") { continue }
                let val = row[1]   // f107_index (daily SFI)
                if let v = val as? Double, v > 50 { return Int(v) }
                if let s = val as? String, let v = Double(s.trimmingCharacters(in: .whitespaces)), v > 50 { return Int(v) }
            }
        }
        // Try array-of-dicts format
        if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for row in json.reversed() {
                for key in ["f107_index", "flux", "observed_flux", "sfi"] {
                    if let v = row[key] as? Double, v > 50 { return Int(v) }
                    if let s = row[key] as? String, let v = Double(s), v > 50 { return Int(v) }
                }
            }
        }
        return nil
    }

    private func xmlValue(_ xml: String, tag: String) -> String? {
        let open = "<\(tag)>"; let close = "</\(tag)>"
        guard let r1 = xml.range(of: open),
              let r2 = xml.range(of: close),
              r1.upperBound < r2.lowerBound else { return nil }
        return String(xml[r1.upperBound..<r2.lowerBound]).trimmingCharacters(in: .whitespaces)
    }
}
