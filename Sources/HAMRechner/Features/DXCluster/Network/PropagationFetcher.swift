import Foundation

struct PropagationData {
    var sfi:    Int?    = nil
    var kp:     Double? = nil
    var aIndex: Int?    = nil

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

        // --- hamqsl.com fallback (covers both SFI and Kp/A) ---
        if result.sfi == nil || result.kp == nil {
            if let (data, _) = try? await URLSession.shared.data(from: Self.hamqslURL),
               let xml = String(data: data, encoding: .utf8) {
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
            }
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
