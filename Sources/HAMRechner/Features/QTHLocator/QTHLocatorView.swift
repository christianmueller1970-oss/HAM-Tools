import SwiftUI

// MARK: - Maidenhead-Algorithmen

private enum Maidenhead {
    static func toLatLon(_ loc: String) -> (lat: Double, lon: Double)? {
        let s = loc.uppercased().trimmingCharacters(in: .whitespaces)
        guard s.count >= 4 else { return nil }
        let chars = Array(s)
        guard let f0 = chars[0].asciiValue, let f1 = chars[1].asciiValue,
              let c2 = chars[2].wholeNumberValue, let c3 = chars[3].wholeNumberValue,
              f0 >= 65, f0 <= 82, f1 >= 65, f1 <= 82 else { return nil }
        var lon = Double(f0 - 65) * 20.0 - 180.0 + Double(c2) * 2.0
        var lat = Double(f1 - 65) * 10.0 - 90.0  + Double(c3) * 1.0
        if s.count >= 6 {
            let a = chars[4], b = chars[5]
            if let av = a.asciiValue, let bv = b.asciiValue, av >= 65, bv >= 65 {
                lon += Double(av - 65) * (2.0 / 24.0) + (1.0 / 24.0)
                lat += Double(bv - 65) * (1.0 / 24.0) + (0.5 / 24.0)
            }
        } else {
            lon += 1.0; lat += 0.5
        }
        return (lat, lon)
    }

    static func fromLatLon(lat: Double, lon: Double) -> String {
        var lo = lon + 180.0, la = lat + 90.0
        let f0 = Int(lo / 20); lo -= Double(f0) * 20.0
        let f1 = Int(la / 10); la -= Double(f1) * 10.0
        let c2 = Int(lo / 2); lo -= Double(c2) * 2.0
        let c3 = Int(la / 1); la -= Double(c3) * 1.0
        let s4 = Int(lo / (2.0 / 24.0)); lo -= Double(s4) * (2.0 / 24.0)
        let s5 = Int(la / (1.0 / 24.0))
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWX"
        let l = Array(letters)
        return "\(l[f0])\(l[f1])\(c2)\(c3)\(l[s4].lowercased())\(l[s5].lowercased())"
    }

    static func distance(from a: (lat: Double, lon: Double), to b: (lat: Double, lon: Double)) -> Double {
        let R = 6371.0
        let dLat = (b.lat - a.lat) * .pi / 180
        let dLon = (b.lon - a.lon) * .pi / 180
        let sinLat = sin(dLat / 2)
        let sinLon = sin(dLon / 2)
        let h = sinLat * sinLat + cos(a.lat * .pi / 180) * cos(b.lat * .pi / 180) * sinLon * sinLon
        return 2 * R * asin(min(1, sqrt(h)))
    }

    static func bearing(from a: (lat: Double, lon: Double), to b: (lat: Double, lon: Double)) -> Double {
        let dLon = (b.lon - a.lon) * .pi / 180
        let y = sin(dLon) * cos(b.lat * .pi / 180)
        let x = cos(a.lat * .pi / 180) * sin(b.lat * .pi / 180)
              - sin(a.lat * .pi / 180) * cos(b.lat * .pi / 180) * cos(dLon)
        let bear = atan2(y, x) * 180 / .pi
        return (bear + 360).truncatingRemainder(dividingBy: 360)
    }
}

// MARK: - View

struct QTHLocatorView: View {
    @State private var modus = 0  // 0 = Locator → Koordinaten, 1 = Koordinaten → Locator

    // Locator → Lat/Lon
    @State private var locText = "JN47"

    // Lat/Lon → Locator
    @State private var latText = "47.5"
    @State private var lonText = "8.5"

    // Distanz zwischen zwei Locatoren
    @State private var loc1Text = "JN47"
    @State private var loc2Text = "IO51"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                modusWahl
                if modus == 0 { locToCoordBereich } else { coordToLocBereich }
                distanzBereich
            }
            .padding(24)
        }
        .navigationTitle("QTH-Locator")
    }

    // MARK: Modus

    private var modusWahl: some View {
        SectionCard(title: "Konvertierung") {
            Picker("", selection: $modus) {
                Text("Locator → Koordinaten").tag(0)
                Text("Koordinaten → Locator").tag(1)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Locator → Lat/Lon

    private var locToCoordBereich: some View {
        let result = Maidenhead.toLatLon(locText)
        return SectionCard(title: "Locator → Koordinaten") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maidenhead-Locator").font(.caption).foregroundStyle(.secondary)
                    TextField("z.B. JN47QM", text: $locText)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3.monospaced())
                        .frame(maxWidth: 200)
                    Text("4 oder 6 Zeichen (z.B. JN47 oder JN47QM)").font(.caption2).foregroundStyle(.secondary)
                }
                Divider()
                if let r = result {
                    ResultRow(label: "Breitengrad (Lat)",  value: String(format: "%.4f°  %@", abs(r.lat), r.lat >= 0 ? "N" : "S"), highlight: true)
                    ResultRow(label: "Längengrad (Lon)",   value: String(format: "%.4f°  %@", abs(r.lon), r.lon >= 0 ? "E" : "W"), highlight: true)
                    ResultRow(label: "DMS (Lat)",          value: dms(r.lat, isLat: true))
                    ResultRow(label: "DMS (Lon)",          value: dms(r.lon, isLat: false))
                    ResultRow(label: "Vollständiger Locator (6-stlg.)",  value: Maidenhead.fromLatLon(lat: r.lat, lon: r.lon))
                } else if !locText.isEmpty {
                    Text("Ungültiger Locator").font(.callout).foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: Lat/Lon → Locator

    private var coordToLocBereich: some View {
        let lat = Double(latText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let lon = Double(lonText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let locator = Maidenhead.fromLatLon(lat: lat, lon: lon)
        return SectionCard(title: "Koordinaten → Locator") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Breitengrad (N positiv, S negativ)").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("47.5", text: $latText).textFieldStyle(.roundedBorder)
                            Text("°").foregroundStyle(.secondary).font(.caption)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Längengrad (E positiv, W negativ)").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("8.5", text: $lonText).textFieldStyle(.roundedBorder)
                            Text("°").foregroundStyle(.secondary).font(.caption)
                        }
                    }
                }
                Divider()
                ResultRow(label: "Maidenhead-Locator (6-stlg.)", value: locator, highlight: true)
                ResultRow(label: "Maidenhead-Locator (4-stlg.)", value: String(locator.prefix(4)))
            }
        }
    }

    // MARK: Distanz zwischen zwei Locatoren

    private var distanzBereich: some View {
        let a = Maidenhead.toLatLon(loc1Text)
        let b = Maidenhead.toLatLon(loc2Text)
        return SectionCard(title: "Distanz & Richtung zwischen zwei Locatoren") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Locator 1 (Mein QTH)").font(.caption).foregroundStyle(.secondary)
                        TextField("JN47", text: $loc1Text)
                            .textFieldStyle(.roundedBorder).font(.body.monospaced())
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Locator 2 (Ziel)").font(.caption).foregroundStyle(.secondary)
                        TextField("IO51", text: $loc2Text)
                            .textFieldStyle(.roundedBorder).font(.body.monospaced())
                    }
                }
                Divider()
                if let pa = a, let pb = b {
                    let dist = Maidenhead.distance(from: pa, to: pb)
                    let bear = Maidenhead.bearing(from: pa, to: pb)
                    ResultRow(label: "Distanz",           value: String(format: "%.1f km", dist), highlight: true)
                    ResultRow(label: "Richtung (Bearing)", value: String(format: "%.1f°  %@", bear, compassDir(bear)))
                    ResultRow(label: "Gegenrichtung",      value: String(format: "%.1f°  %@", (bear + 180).truncatingRemainder(dividingBy: 360), compassDir((bear + 180).truncatingRemainder(dividingBy: 360))))
                } else {
                    Text("Bitte beide Locatoren eingeben").font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Helpers

    private func dms(_ deg: Double, isLat: Bool) -> String {
        let d = Int(abs(deg))
        let m = Int((abs(deg) - Double(d)) * 60)
        let s = ((abs(deg) - Double(d)) * 60 - Double(m)) * 60
        let dir = isLat ? (deg >= 0 ? "N" : "S") : (deg >= 0 ? "E" : "W")
        return String(format: "%d° %d' %.1f\" %@", d, m, s, dir)
    }

    private func compassDir(_ deg: Double) -> String {
        let dirs = ["N","NNO","NO","ONO","O","OSO","SO","SSO","S","SSW","SW","WSW","W","WNW","NW","NNW"]
        return dirs[Int((deg + 11.25) / 22.5) % 16]
    }
}
