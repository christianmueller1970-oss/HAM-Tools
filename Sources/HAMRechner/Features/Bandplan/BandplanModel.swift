import Foundation
import SwiftUI

// MARK: - Bandplan-Datenmodell (geteilt mit Web via JSON)

struct BandplanData: Decodable {
    let bands:      [Band]
    let categories: [String: BandCategory]
}

struct BandCategory: Decodable {
    let label: String
    let color: String
    var swiftColor: Color { Color(hex: color) }
}

struct Band: Decodable, Identifiable {
    let id:          String
    let name:        String
    let freq:        String
    let fMin:        Double      // MHz
    let fMax:        Double      // MHz
    let type:        String      // lf | mf | hf | vhf | uhf | shf
    let leistung:    String
    let zuweisung:   String
    let contest:     Bool
    let digi:        Bool
    let modes:       [String]
    let typUse:      String
    let info:        String
    let iaru:        String
    let segments:    [BandSegmentBar]
    let subsegments: [BandSubsegment]
}

struct BandSegmentBar: Decodable, Hashable {
    let label: String
    let pct:   Double
    let color: String
    var swiftColor: Color { Color(hex: color) }
}

struct BandSubsegment: Decodable, Hashable, Identifiable {
    let von:  Double      // kHz
    let bis:  Double      // kHz
    let bw:   Int         // Hz
    let mode: String
    let cat:  String      // category-id (cw, ssb, digi, …)
    let info: String

    var id: String { "\(von)-\(bis)" }
    var bandwidthDisplay: String {
        if bw == 0 { return "—" }
        if bw < 1000 { return "\(bw) Hz" }
        let kHz = Double(bw) / 1000.0
        return kHz.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f kHz", kHz)
            : String(format: "%.1f kHz", kHz)
    }
}

// MARK: - Loader

enum BandplanLoader {
    static func load() -> BandplanData {
        guard let url = AppResource.url(forResource: "bandplan", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(BandplanData.self, from: data)
        else {
            return BandplanData(bands: [], categories: [:])
        }
        return decoded
    }

    /// Lookup: Frequenz in kHz → passendes Band + Subsegment
    static func lookup(frequencyKHz: Double, in data: BandplanData) -> (band: Band, sub: BandSubsegment)? {
        for band in data.bands {
            // Band-Bereich in kHz
            let bandMinKHz = band.fMin * 1000
            let bandMaxKHz = band.fMax * 1000
            guard frequencyKHz >= bandMinKHz && frequencyKHz <= bandMaxKHz else { continue }
            for sub in band.subsegments {
                if frequencyKHz >= sub.von && frequencyKHz <= sub.bis {
                    return (band, sub)
                }
            }
            if let first = band.subsegments.first { return (band, first) }
        }
        return nil
    }
}
