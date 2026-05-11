import Foundation

// MARK: - Ringkern-Datenbank

struct Ringkern: Identifiable {
    let id: String
    let gruppe: String
    let name: String
    let beschreibung: String
    let al: Double      // nH/N²
    let od: Double      // Außendurchmesser mm
    let idMM: Double    // Innendurchmesser mm
    let hoehe: Double   // Höhe mm
}

let alleKerne: [Ringkern] = [
    // Amidon Ferrit Mix 43
    .init(id: "ft50_43",  gruppe: "Amidon Ferrit Mix 43",   name: "FT-50-43",  beschreibung: "Kleiner Ferritkern, 80–10m Balun/Choke",              al: 523,  od: 12.7,  idMM: 7.15,  hoehe: 4.85),
    .init(id: "ft82_43",  gruppe: "Amidon Ferrit Mix 43",   name: "FT-82-43",  beschreibung: "Mittlerer Kern, gut für 1:1 Strombalun",               al: 557,  od: 21.0,  idMM: 13.1,  hoehe: 6.35),
    .init(id: "ft114_43", gruppe: "Amidon Ferrit Mix 43",   name: "FT-114-43", beschreibung: "Großer Kern, höhere Leistung",                         al: 603,  od: 29.0,  idMM: 19.0,  hoehe: 7.55),
    .init(id: "ft140_43", gruppe: "Amidon Ferrit Mix 43",   name: "FT-140-43", beschreibung: "Beliebt für 100W Stationsbalun",                       al: 885,  od: 35.55, idMM: 23.0,  hoehe: 12.7),
    .init(id: "ft240_43", gruppe: "Amidon Ferrit Mix 43",   name: "FT-240-43", beschreibung: "Großer Kern, 100–200W, empfohlen für 1:1 Strombalun",  al: 1075, od: 61.0,  idMM: 35.55, hoehe: 12.7),
    // Amidon Ferrit Mix 61
    .init(id: "ft114_61", gruppe: "Amidon Ferrit Mix 61",   name: "FT-114-61", beschreibung: "Mix 61, gut für 6–40m, niedriger Verlust",             al: 173,  od: 29.0,  idMM: 19.0,  hoehe: 7.55),
    .init(id: "ft240_61", gruppe: "Amidon Ferrit Mix 61",   name: "FT-240-61", beschreibung: "Mix 61, breitbandig 1–30 MHz, guter Wirkungsgrad",     al: 173,  od: 61.0,  idMM: 35.55, hoehe: 12.7),
    // Amidon Ferrit Mix 31 (sehr beliebt für EFHW & Mantelwellensperren <10 MHz)
    .init(id: "ft114_31", gruppe: "Amidon Ferrit Mix 31",   name: "FT-114-31", beschreibung: "Mix 31, sehr gut für 1–10 MHz, hohe Permeabilität",    al: 1180, od: 29.0,  idMM: 19.0,  hoehe: 7.55),
    .init(id: "ft140_31", gruppe: "Amidon Ferrit Mix 31",   name: "FT-140-31", beschreibung: "Mix 31, ideal für EFHW 80–10m, 100W",                  al: 1400, od: 35.55, idMM: 23.0,  hoehe: 12.7),
    .init(id: "ft240_31", gruppe: "Amidon Ferrit Mix 31",   name: "FT-240-31", beschreibung: "Mix 31, hervorragend als Mantelwellensperre KW",       al: 1400, od: 61.0,  idMM: 35.55, hoehe: 12.7),
    // Amidon Ferrit Mix 77 (NF, sehr breitbandig <2 MHz)
    .init(id: "ft240_77", gruppe: "Amidon Ferrit Mix 77",   name: "FT-240-77", beschreibung: "Mix 77, sehr hohe Permeabilität, MF/LW <2 MHz",        al: 3700, od: 61.0,  idMM: 35.55, hoehe: 12.7),
    // Amidon Eisenpulver Mix 2
    .init(id: "t50_2",    gruppe: "Amidon Eisenpulver Mix 2", name: "T-50-2",  beschreibung: "Klein, QRP-Tuner, schmalbandige LC-Kreise",            al: 49,   od: 12.7,  idMM: 7.7,   hoehe: 4.83),
    .init(id: "t68_2",    gruppe: "Amidon Eisenpulver Mix 2", name: "T-68-2",  beschreibung: "Klein-mittel, QRP-Filter, Vorkreise",                  al: 57,   od: 17.5,  idMM: 9.4,   hoehe: 4.83),
    .init(id: "t94_2",    gruppe: "Amidon Eisenpulver Mix 2", name: "T-94-2",  beschreibung: "Mittel, Tiefpass-Filter, 25–50W",                      al: 84,   od: 23.9,  idMM: 14.0,  hoehe: 7.92),
    .init(id: "t106_2",   gruppe: "Amidon Eisenpulver Mix 2", name: "T-106-2", beschreibung: "Mittelgroß, PA-Ausgangsfilter, Anpassnetzwerke",        al: 135,  od: 26.9,  idMM: 14.35, hoehe: 11.1),
    .init(id: "t130_2",   gruppe: "Amidon Eisenpulver Mix 2", name: "T-130-2", beschreibung: "Eisenpulver, HF/KW LC-Kreise, Koppelspulen",           al: 110,  od: 33.0,  idMM: 19.5,  hoehe: 11.1),
    .init(id: "t200_2",   gruppe: "Amidon Eisenpulver Mix 2", name: "T-200-2", beschreibung: "Großer Eisenpulverkern, Antennentuner, LPF",            al: 120,  od: 50.8,  idMM: 31.75, hoehe: 14.3),
    .init(id: "t300_2",   gruppe: "Amidon Eisenpulver Mix 2", name: "T-300-2", beschreibung: "Sehr groß, PA-Ausgangsfilter >500W, robuste LPF",      al: 228,  od: 76.2,  idMM: 49.0,  hoehe: 12.7),
    // Amidon Eisenpulver Mix 6
    .init(id: "t130_6",   gruppe: "Amidon Eisenpulver Mix 6", name: "T-130-6", beschreibung: "Mix 6, gut für 10–160m, hohe Güte",                    al: 96,   od: 33.0,  idMM: 19.5,  hoehe: 11.1),
    .init(id: "t200_6",   gruppe: "Amidon Eisenpulver Mix 6", name: "T-200-6", beschreibung: "Großer Mix-6 Kern, hohe Leistung möglich",              al: 105,  od: 50.8,  idMM: 31.75, hoehe: 14.3),
    // Fair-Rite
    .init(id: "fr_2643",  gruppe: "Fair-Rite Mix 43",       name: "2643625002",beschreibung: "Fair-Rite Äquivalent zum FT-240-43, Mix 43",           al: 1075, od: 61.0,  idMM: 35.55, hoehe: 12.7),
    .init(id: "fr_5943",  gruppe: "Fair-Rite Mix 31",       name: "5943003801",beschreibung: "Fair-Rite Mix 31, sehr gut für 1–10 MHz, MF/LW",       al: 4900, od: 23.0,  idMM: 13.0,  hoehe: 7.5),
    .init(id: "fr_5961",  gruppe: "Fair-Rite Mix 61",       name: "5961003801",beschreibung: "Fair-Rite Mix 61, 10–200 MHz, niedriger Verlust",       al: 68,   od: 23.0,  idMM: 13.0,  hoehe: 7.5),
]

let kernGruppen: [String] = {
    var seen = Set<String>()
    return alleKerne.compactMap { k in seen.insert(k.gruppe).inserted ? k.gruppe : nil }
}()

// MARK: - Balun-Typen

struct BalunTyp: Identifiable {
    let id: String
    let label: String
    let zielL_uH: Double
    let hinweis: String
    let wicklung: Wicklungsart
}

enum Wicklungsart {
    case monofilar      // 1:1, Mantelwellensperre, frei
    case bifilarZweiKerne  // 4:1 Guanella
    case trifilar       // 9:1
    case efhw49         // 49:1
    case langdraht64    // 64:1
}

let alleBalunTypen: [BalunTyp] = [
    .init(id: "1_1",  label: "1:1 Balun (Strombalun / Mantelwellensperre)", zielL_uH: 25.0,  hinweis: "Ziel ca. 25–30 µH für 80–10m. Monofilar mit Koaxkabel oder bifilar.",           wicklung: .monofilar),
    .init(id: "4_1",  label: "4:1 Balun (200 Ω zu 50 Ω)",                   zielL_uH: 12.5,  hinweis: "Ziel ca. 10–15 µH. Bifilar auf 2 Kernen (Guanella-Bauweise).",                   wicklung: .bifilarZweiKerne),
    .init(id: "9_1",  label: "9:1 Unun (450 Ω zu 50 Ω)",                    zielL_uH: 8.0,   hinweis: "Ziel ca. 7–10 µH. Trifilar gewickelt (3 Drähte gleichzeitig). Für Langdraht.",   wicklung: .trifilar),
    .init(id: "49_1", label: "49:1 Unun (EFHW, 2450 Ω zu 50 Ω)",            zielL_uH: 55.0,  hinweis: "Für EFHW-Antenne. 2 Primär- + 14 Sekundär-Windungen. FT-140-43 empfohlen.",       wicklung: .efhw49),
    .init(id: "64_1", label: "64:1 Unun (Langdraht, 3200 Ω zu 50 Ω)",       zielL_uH: 65.0,  hinweis: "Für Random-Wire. 1+7 Windungen (8:1 Verhältnis). FT-240-43 empfohlen.",           wicklung: .langdraht64),
    .init(id: "man",  label: "Mantelwellensperre (1:1 Choke)",               zielL_uH: 30.0,  hinweis: "Ziel > 25 µH für effektive Sperrwirkung auf 80–10m.",                             wicklung: .monofilar),
    .init(id: "free", label: "Freie L-Eingabe",                              zielL_uH: 10.0,  hinweis: "Eigene Induktivität eingeben. Windungen werden berechnet.",                        wicklung: .monofilar),
]

// MARK: - Berechnungsmodell

struct BalunErgebnis {
    let kern: Ringkern
    let typ: BalunTyp
    let windungen: Int
    let windungenRoh: Double
    let lTatsaechlich_uH: Double
    let drahtlaenge_m: Double
    let maxWindungen: Int
    let auslastungProzent: Double
    let innenumfang_mm: Double

    var bewertung: Bewertung {
        if auslastungProzent > 100 { return .zuKlein }
        if auslastungProzent > 80  { return .eng }
        return .ok
    }

    enum Bewertung { case ok, eng, zuKlein }
}

func berechneBalun(kern: Ringkern, typ: BalunTyp, lUH: Double, drahtDmm: Double) -> BalunErgebnis? {
    guard lUH > 0, drahtDmm > 0 else { return nil }

    let L_nH    = lUH * 1000.0
    let nRoh    = sqrt(L_nH / kern.al)
    let n       = Int(ceil(nRoh))

    let lTats   = Double(n * n) * kern.al / 1000.0

    let innenUmfang  = .pi * kern.idMM
    let mittlererD   = (kern.od + kern.idMM) / 2.0
    let mittlCirc    = .pi * mittlererD
    let drahtLen_mm  = Double(n) * mittlCirc + 100.0
    let drahtLen_m   = drahtLen_mm / 1000.0

    let maxN    = Int(innenUmfang / drahtDmm)
    let fill    = (Double(n) * drahtDmm) / innenUmfang * 100.0

    return BalunErgebnis(
        kern: kern, typ: typ,
        windungen: n, windungenRoh: nRoh,
        lTatsaechlich_uH: lTats,
        drahtlaenge_m: drahtLen_m,
        maxWindungen: maxN,
        auslastungProzent: fill,
        innenumfang_mm: innenUmfang
    )
}
