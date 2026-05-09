import SwiftUI

// MARK: - Band definitions

struct BandRange {
    let name: String
    let low: Double   // kHz
    let high: Double  // kHz
}

let BANDS: [BandRange] = [
    BandRange(name: "160m", low: 1800,   high: 2000),
    BandRange(name: "80m",  low: 3500,   high: 4000),
    BandRange(name: "60m",  low: 5250,   high: 5450),
    BandRange(name: "40m",  low: 7000,   high: 7300),
    BandRange(name: "30m",  low: 10100,  high: 10150),
    BandRange(name: "20m",  low: 14000,  high: 14350),
    BandRange(name: "17m",  low: 18068,  high: 18168),
    BandRange(name: "15m",  low: 21000,  high: 21450),
    BandRange(name: "12m",  low: 24890,  high: 24990),
    BandRange(name: "10m",  low: 28000,  high: 29700),
    BandRange(name: "6m",   low: 50000,  high: 54000),
    BandRange(name: "4m",   low: 70000,  high: 70500),
    BandRange(name: "2m",   low: 144000, high: 148000),
    BandRange(name: "70cm", low: 430000, high: 440000),
]

let HEATMAP_BANDS = ["6m","10m","12m","15m","17m","20m","30m","40m","80m","160m"]
let CONTINENTS    = ["EU","NA","SA","AS","AF","OC"]

// MARK: - Band colors (same palette as Python app)

let BAND_COLORS: [String: Color] = [
    "160m": Color(hex: "#8B0000"),
    "80m":  Color(hex: "#FF4500"),
    "60m":  Color(hex: "#FF8C00"),
    "40m":  Color(hex: "#FFD700"),
    "30m":  Color(hex: "#9ACD32"),
    "20m":  Color(hex: "#00CED1"),
    "17m":  Color(hex: "#1E90FF"),
    "15m":  Color(hex: "#8A2BE2"),
    "12m":  Color(hex: "#FF69B4"),
    "10m":  Color(hex: "#DC143C"),
    "6m":   Color(hex: "#00FA9A"),
    "4m":   Color(hex: "#40E0D0"),
    "2m":   Color(hex: "#87CEEB"),
    "70cm": Color(hex: "#DDA0DD"),
    "OOB":  Color(hex: "#888888"),
]

func bandColor(for band: String) -> Color {
    BAND_COLORS[band] ?? Color(hex: "#888888")
}

// MARK: - Frequency lookups

private let FT8_FREQS: Set<Double> = [
    1840, 3573, 5357, 7074, 10136, 14074, 18100, 21074,
    24915, 28074, 50313, 50323, 144174, 432174
]
private let FT4_FREQS: Set<Double> = [
    3575, 7047.5, 10140, 14080, 18104, 21140, 24919, 28180, 50318
]

func freqToBand(_ khz: Double) -> String {
    for b in BANDS {
        if khz >= b.low && khz <= b.high { return b.name }
    }
    return "OOB"
}

func freqToMode(_ khz: Double, comment: String) -> String {
    let up = comment.uppercased()
    for mode in ["FT8","FT4","CW","SSB","AM","FM","RTTY","PSK31","PSK63",
                 "JS8","WSPR","SSTV","OLIVIA","MFSK","DIGITALVOICE","DMR","C4FM"] {
        if up.contains(mode) { return mode }
    }
    if up.contains("DIGITAL") { return "Digital" }
    if FT8_FREQS.contains(khz) { return "FT8" }
    if FT4_FREQS.contains(khz) { return "FT4" }
    // CW sub-bands
    if (1800...1840).contains(khz) || (3500...3580).contains(khz) ||
       (7000...7040).contains(khz) || (14000...14070).contains(khz) ||
       (21000...21080).contains(khz) || (28000...28070).contains(khz) {
        return "CW"
    }
    return "SSB"
}

func allBandNames() -> [String] {
    BANDS.map(\.name) + ["OOB"]
}

// MARK: - Geo utilities

/// Maidenhead-Locator → (lat, lon) in Grad. Unterstützt 4- und 6-stellige Locatoren.
func locatorToLatLon(_ loc: String) -> (lat: Double, lon: Double)? {
    let s = loc.uppercased()
    guard s.count >= 4 else { return nil }
    let c = Array(s)
    guard let f0 = c[0].asciiValue, let f1 = c[1].asciiValue,
          let d0 = c[2].asciiValue, let d1 = c[3].asciiValue,
          c[0].isLetter, c[1].isLetter,
          c[2].isNumber, c[3].isNumber else { return nil }

    let lonBase = Double(f0 - 65) * 20.0 - 180.0 + Double(d0 - 48) * 2.0
    let latBase = Double(f1 - 65) * 10.0 - 90.0  + Double(d1 - 48) * 1.0

    if s.count >= 6,
       let s0 = c[4].asciiValue, let s1 = c[5].asciiValue,
       c[4].isLetter, c[5].isLetter {
        let lon = lonBase + Double(s0 - 65) * (2.0 / 24.0) + (1.0 / 24.0)
        let lat = latBase + Double(s1 - 65) * (1.0 / 24.0) + (0.5 / 24.0)
        return (lat, lon)
    }
    return (latBase + 0.5, lonBase + 1.0)
}

/// Haversine-Distanz zwischen zwei Punkten in Kilometern.
func haversineKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let R = 6371.0
    let dLat = (lat2 - lat1) * .pi / 180
    let dLon = (lon2 - lon1) * .pi / 180
    let a = sin(dLat / 2) * sin(dLat / 2)
           + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180)
           * sin(dLon / 2) * sin(dLon / 2)
    return R * 2 * atan2(sqrt(a), sqrt(1 - a))
}
