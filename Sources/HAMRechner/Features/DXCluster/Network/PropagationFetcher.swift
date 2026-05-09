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
    private static let sfiFURL = URL(string: "https://services.swpc.noaa.gov/json/f107_cm_flux.json")!
    private static let kpURL   = URL(string: "https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json")!

    func fetchOnce() async -> PropagationData {
        var result = PropagationData()

        // SFI
        if let (data, _) = try? await URLSession.shared.data(from: Self.sfiFURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[Any]] {
            for row in json.reversed() {
                if let v = (row.last as? Double) ?? (row.last.flatMap { Double("\($0)") }) {
                    result.sfi = Int(v); break
                }
            }
            // Try dict format
            if result.sfi == nil,
               let dicts = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for row in dicts.reversed() {
                    if let v = row["flux"] as? Double ?? row["observed_flux"] as? Double {
                        result.sfi = Int(v); break
                    }
                }
            }
        }

        // Kp
        if let (data, _) = try? await URLSession.shared.data(from: Self.kpURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[Any]] {
            for row in json.reversed() {
                if let kpStr = row.dropFirst().first.map({ "\($0)" }),
                   let kp = Double(kpStr.trimmingCharacters(in: .letters)) {
                    result.kp = round(kp * 10) / 10; break
                }
            }
        }

        return result
    }
}
