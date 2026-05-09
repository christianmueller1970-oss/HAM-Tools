import Foundation

struct PegelErgebnis {
    let watt: Double
    let milliwatt: Double
    let dBm: Double
    let dBW: Double
    let volt50Ohm: Double  // Effektivwert bei 50 Ω

    static func fromWatt(_ w: Double) -> PegelErgebnis? {
        guard w > 0 else { return nil }
        return PegelErgebnis(
            watt: w,
            milliwatt: w * 1000,
            dBm: 10 * log10(w * 1000),
            dBW: 10 * log10(w),
            volt50Ohm: sqrt(w * 50)
        )
    }

    static func fromMilliwatt(_ mw: Double) -> PegelErgebnis? {
        fromWatt(mw / 1000)
    }

    static func fromDBm(_ dbm: Double) -> PegelErgebnis? {
        let mw = pow(10, dbm / 10)
        return fromMilliwatt(mw)
    }

    static func fromDBW(_ dbw: Double) -> PegelErgebnis? {
        let w = pow(10, dbw / 10)
        return fromWatt(w)
    }

    static func fromVolt(_ v: Double, impedance: Double = 50) -> PegelErgebnis? {
        guard v > 0, impedance > 0 else { return nil }
        let w = (v * v) / impedance
        return fromWatt(w)
    }
}

enum PegelEingabe: String, CaseIterable, Identifiable {
    case watt = "Watt (W)"
    case milliwatt = "Milliwatt (mW)"
    case dBm = "dBm"
    case dBW = "dBW"
    case volt = "Volt (Veff)"

    var id: String { rawValue }
}
