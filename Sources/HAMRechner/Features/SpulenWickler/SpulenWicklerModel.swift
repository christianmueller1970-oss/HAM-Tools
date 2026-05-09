import Foundation

struct SpulenErgebnis {
    // Eingaben
    let L_uH: Double      // Induktivität µH
    let D_mm: Double      // Körperdurchmesser mm
    let dw_mm: Double     // Drahtdurchmesser mm
    let s_mm: Double      // Windungsabstand mm
    let C_pF: Double      // Kapazität für LC-Resonanz pF

    // Berechnete Grössen
    let windungen: Double
    let pitch_mm: Double      // Wickelschritt mm
    let spulenlaenge_mm: Double
    let aussenD_mm: Double
    let drahtlaenge_m: Double
    let induktProWindung_uH: Double
    let schlankheit: Double   // Länge / Körperdurchmesser

    // Optionale Grössen
    let resonanzFreq_MHz: Double?
    let guete: Double?

    static func berechne(L: Double, D: Double, dw: Double, s: Double, C: Double) -> SpulenErgebnis? {
        guard L > 0, D > 0, dw > 0, s >= 0 else { return nil }

        let r_inch = (D / 2.0) / 25.4
        let n      = wheeler(L_uh: L, r_inch: r_inch, d_mm: dw, s_mm: s)
        guard n > 0 else { return nil }

        let pitch   = dw + s
        let laenge  = n * pitch
        let aussenD = D + 2 * dw
        // Drahtlänge = Helixlänge
        let wireLen = n * sqrt(pow(.pi * D, 2) + pow(pitch, 2)) / 1000.0

        // LC-Resonanz
        var freq: Double? = nil
        if C > 0 {
            let f_hz = 1.0 / (2 * .pi * sqrt(L * 1e-6 * C * 1e-12))
            freq = f_hz / 1e6
        }

        // Güte Q = (2π·f·L) / R_DC   (R_DC = ρ_Cu · l / A)
        var q: Double? = nil
        if let f = freq, f > 0 {
            let rho = 1.72e-8
            let A   = .pi * pow(dw * 0.5e-3, 2)
            let Rdc = rho * wireLen / A
            let qVal = (2 * .pi * f * 1e6 * L * 1e-6) / Rdc
            q = qVal >= 1 ? qVal : nil
        }

        return SpulenErgebnis(
            L_uH: L, D_mm: D, dw_mm: dw, s_mm: s, C_pF: C,
            windungen: n,
            pitch_mm: pitch,
            spulenlaenge_mm: laenge,
            aussenD_mm: aussenD,
            drahtlaenge_m: wireLen,
            induktProWindung_uH: L / n,
            schlankheit: laenge / D,
            resonanzFreq_MHz: freq,
            guete: q
        )
    }

    // Wheeler-Iteration für einlagige Luftspule
    private static func wheeler(L_uh: Double, r_inch: Double, d_mm: Double, s_mm: Double) -> Double {
        let pitch_inch = (d_mm + s_mm) / 25.4
        var n = 10.0, np = 0.0
        for _ in 0..<80 {
            let l_inch = n * pitch_inch
            n = sqrt(L_uh * (9 * r_inch + 10 * l_inch)) / r_inch
            if abs(n - np) < 0.0001 { break }
            np = n
        }
        return n
    }
}
