import Foundation

struct Koaxkabel: Identifiable {
    let id: String
    let gruppe: String
    let name: String
    let beschreibung: String
    let impedanz: Double
    let dbPro100m: [Double]  // bei: 10, 30, 100, 145, 300, 435, 1000, 1296 MHz

    static let messpunkte: [Double] = [10, 30, 100, 145, 300, 435, 1000, 1296]

    func daempfungPro100m(frequenzMHz f: Double) -> Double {
        let pts = Koaxkabel.messpunkte
        let db = dbPro100m
        if f <= pts.first! {
            return db[0] * sqrt(f / pts[0])
        }
        if f >= pts.last! {
            let last = pts.count - 1
            return db[last] * sqrt(f / pts[last])
        }
        for i in 0..<(pts.count - 1) {
            if f >= pts[i] && f <= pts[i + 1] {
                let ratio = (f - pts[i]) / (pts[i + 1] - pts[i])
                return db[i] + (db[i + 1] - db[i]) * ratio
            }
        }
        return db[0]
    }
}

struct KabeldaempfungErgebnis {
    let gesamtDaempfungDB: Double
    let ausgangsleistungW: Double
    let verlustleistungW: Double
    let effizienzProzent: Double

    var bewertung: Bewertung {
        if effizienzProzent >= 80 { return .gut }
        if effizienzProzent >= 50 { return .mittel }
        return .schlecht
    }

    enum Bewertung { case gut, mittel, schlecht }
}

func berechneKabeldaempfung(kabel: Koaxkabel, frequenzMHz: Double, laengeM: Double, eingangsleistungW: Double) -> KabeldaempfungErgebnis {
    let att100 = kabel.daempfungPro100m(frequenzMHz: frequenzMHz)
    let gesamtDB = (att100 / 100.0) * laengeM
    let ausgang = eingangsleistungW * pow(10, -gesamtDB / 10.0)
    let verlust = eingangsleistungW - ausgang
    let eff = (ausgang / eingangsleistungW) * 100.0
    return KabeldaempfungErgebnis(
        gesamtDaempfungDB: gesamtDB,
        ausgangsleistungW: ausgang,
        verlustleistungW: verlust,
        effizienzProzent: eff
    )
}

// MARK: - Kabeldaten (Quellen: Herstellerdatenblätter)

let allKabel: [Koaxkabel] = [
    // RG-Typen
    .init(id: "rg174",      gruppe: "RG-Typen",       name: "RG-174",         beschreibung: "Dünn, flexibel, für kurze Verbindungen",           impedanz: 50, dbPro100m: [8.0, 14.0, 26.0, 32.0, 48.0, 59.0, 100.0, 120.0]),
    .init(id: "rg316",      gruppe: "RG-Typen",       name: "RG-316",         beschreibung: "Dünn, PTFE-Dielektrikum, hitzebeständig",          impedanz: 50, dbPro100m: [6.5, 11.5, 22.0, 27.0, 41.0, 50.0, 85.0, 102.0]),
    .init(id: "rg58",       gruppe: "RG-Typen",       name: "RG-58",          beschreibung: "Klassisch, günstig, mittlere Dämpfung",            impedanz: 50, dbPro100m: [4.5, 7.5, 14.0, 19.0, 28.0, 35.0, 59.0, 70.0]),
    .init(id: "rg8x",       gruppe: "RG-Typen",       name: "RG-8X (Mini-8)", beschreibung: "Kompromiss zwischen RG-58 und RG-213",             impedanz: 50, dbPro100m: [3.0, 5.2, 9.8, 12.5, 18.5, 22.5, 37.0, 44.0]),
    .init(id: "rg8",        gruppe: "RG-Typen",       name: "RG-8 / RG-8A",   beschreibung: "Klassisch gross, ähnlich RG-213",                 impedanz: 50, dbPro100m: [2.1, 3.7, 6.9, 8.8, 13.0, 15.8, 26.5, 31.5]),
    .init(id: "rg213",      gruppe: "RG-Typen",       name: "RG-213",         beschreibung: "Standard Stationsverkabelung, 10 mm",              impedanz: 50, dbPro100m: [2.0, 3.5, 6.5, 8.5, 12.5, 15.5, 26.0, 30.0]),
    .init(id: "rg214",      gruppe: "RG-Typen",       name: "RG-214",         beschreibung: "Mil-Spec, doppelt versilbert, bessere Schirmung",  impedanz: 50, dbPro100m: [1.9, 3.3, 6.2, 7.8, 11.8, 14.8, 24.5, 28.5]),
    .init(id: "rg393",      gruppe: "RG-Typen",       name: "RG-393",         beschreibung: "Mil-Spec, PTFE, sehr robust",                      impedanz: 50, dbPro100m: [1.6, 2.8, 5.2, 6.6, 9.8, 11.9, 19.8, 23.5]),
    // Ecoflex
    .init(id: "ecoflex6",   gruppe: "Ecoflex",        name: "Ecoflex 6",      beschreibung: "Kompakt, flexibel, guter Low-Loss Einstieg",       impedanz: 50, dbPro100m: [2.3, 3.9, 7.2, 9.1, 13.4, 16.2, 27.0, 32.0]),
    .init(id: "ecoflex10",  gruppe: "Ecoflex",        name: "Ecoflex 10",     beschreibung: "Beliebt für UKW/UHF Stationsanlagen",              impedanz: 50, dbPro100m: [1.2, 2.1, 3.9, 4.9, 7.2, 8.7, 14.5, 17.2]),
    .init(id: "ecoflex15",  gruppe: "Ecoflex",        name: "Ecoflex 15",     beschreibung: "Sehr geringe Dämpfung, 15 mm Durchmesser",         impedanz: 50, dbPro100m: [0.8, 1.4, 2.6, 3.3, 4.8, 5.8, 9.7, 11.5]),
    .init(id: "ecoflex15p", gruppe: "Ecoflex",        name: "Ecoflex 15 Plus",beschreibung: "Verbesserte Version, noch geringere Dämpfung",     impedanz: 50, dbPro100m: [0.75, 1.3, 2.4, 3.0, 4.4, 5.3, 8.9, 10.5]),
    // Aircell
    .init(id: "aircell5",   gruppe: "Aircell",        name: "Aircell 5",      beschreibung: "Flexibel, 5 mm, für kurze Zuleitungen",            impedanz: 50, dbPro100m: [2.6, 4.5, 8.3, 10.5, 15.5, 18.8, 31.0, 37.0]),
    .init(id: "aircell7",   gruppe: "Aircell",        name: "Aircell 7",      beschreibung: "Sehr flexibel, geringer Verlust, 7 mm",            impedanz: 50, dbPro100m: [2.2, 3.8, 7.0, 8.9, 13.1, 15.8, 26.2, 31.0]),
    // LMR
    .init(id: "lmr200",     gruppe: "LMR",            name: "LMR-200",        beschreibung: "Flexibel, halbsteif, 5 mm",                        impedanz: 50, dbPro100m: [3.1, 5.3, 9.9, 12.6, 18.6, 22.5, 37.5, 44.5]),
    .init(id: "lmr400",     gruppe: "LMR",            name: "LMR-400",        beschreibung: "Beliebtes Low-Loss Kabel, 10 mm",                  impedanz: 50, dbPro100m: [1.3, 2.3, 4.3, 5.4, 8.0, 9.7, 16.2, 19.2]),
    .init(id: "lmr600",     gruppe: "LMR",            name: "LMR-600",        beschreibung: "Sehr geringe Dämpfung, halbsteif, 15 mm",          impedanz: 50, dbPro100m: [0.85, 1.5, 2.8, 3.5, 5.2, 6.3, 10.5, 12.4]),
    .init(id: "lmr900",     gruppe: "LMR",            name: "LMR-900",        beschreibung: "Profi-Backbone, sehr steif, 23 mm",                impedanz: 50, dbPro100m: [0.55, 0.97, 1.8, 2.3, 3.4, 4.1, 6.9, 8.2]),
    // Huber+Suhner
    .init(id: "sucofl104",  gruppe: "Huber+Suhner",   name: "Sucoflex 104",   beschreibung: "Flexibles PTFE-Kabel, sehr breitbandig",           impedanz: 50, dbPro100m: [2.8, 4.8, 9.0, 11.4, 16.8, 20.3, 33.8, 40.0]),
    .init(id: "sucofeed12", gruppe: "Huber+Suhner",   name: "Sucofeed 1/2\"", beschreibung: "Halbsteifes Feeder-Kabel, Stationsanlage",         impedanz: 50, dbPro100m: [0.7, 1.2, 2.2, 2.8, 4.1, 5.0, 8.3, 9.8]),
    .init(id: "suhnersc12", gruppe: "Huber+Suhner",   name: "S_FLEX-C 1/2\"", beschreibung: "Flexibler 1/2\" Feeder für Antennenmasten",        impedanz: 50, dbPro100m: [0.72, 1.25, 2.3, 2.9, 4.3, 5.2, 8.7, 10.3]),
    // H-Typen
    .init(id: "h100",       gruppe: "H-Typen",        name: "H-100",          beschreibung: "Preiswertes Allroundkabel, 6 mm",                  impedanz: 50, dbPro100m: [3.2, 5.5, 10.2, 13.0, 19.2, 23.2, 38.5, 45.5]),
    .init(id: "h155",       gruppe: "H-Typen",        name: "H-155",          beschreibung: "Flexibel, Low Loss, 5 mm, sehr verbreitet",        impedanz: 50, dbPro100m: [2.9, 4.9, 9.2, 11.6, 17.1, 20.7, 34.3, 40.6]),
    // Messi & Paoloni
    .init(id: "mp_hf5",     gruppe: "Messi & Paoloni", name: "Hyperflex 5",   beschreibung: "Sehr flexibel, 5 mm, gute Schirmung",              impedanz: 50, dbPro100m: [2.6, 4.4, 8.2, 10.4, 15.3, 18.5, 30.8, 36.5]),
    .init(id: "hypflex10",  gruppe: "Messi & Paoloni", name: "Hyperflex 10",  beschreibung: "Flexibel, 10 mm, beliebter Stationsfeeder",        impedanz: 50, dbPro100m: [1.5, 2.6, 4.8, 6.1, 9.0, 10.9, 18.1, 21.4]),
    .init(id: "mp_hf13",    gruppe: "Messi & Paoloni", name: "Hyperflex 13",  beschreibung: "Low-Loss, 13 mm, professioneller Feeder",          impedanz: 50, dbPro100m: [1.0, 1.7, 3.2, 4.1, 6.0, 7.2, 12.1, 14.3]),
    .init(id: "mp_uf7",     gruppe: "Messi & Paoloni", name: "Ultraflex 7",   beschreibung: "Ultraflexibel, 7 mm, kleine Biegeradien",          impedanz: 50, dbPro100m: [2.1, 3.7, 6.8, 8.6, 12.7, 15.4, 25.7, 30.4]),
    .init(id: "mp_uf10",    gruppe: "Messi & Paoloni", name: "Ultraflex 10",  beschreibung: "Ultraflexibel, 10 mm, Antennenmast-Verkabelung",   impedanz: 50, dbPro100m: [1.4, 2.5, 4.6, 5.8, 8.6, 10.4, 17.4, 20.6]),
    .init(id: "mp_uf13",    gruppe: "Messi & Paoloni", name: "Ultraflex 13",  beschreibung: "Ultraflexibel, 13 mm, Profi-Feeder, sehr Low-Loss",impedanz: 50, dbPro100m: [1.1, 1.9, 3.5, 4.4, 6.5, 7.9, 13.2, 15.6]),
    .init(id: "mp_ab5",     gruppe: "Messi & Paoloni", name: "Airborne 5",    beschreibung: "Ultraleicht, 5 mm, ideal für Portable/SOTA",       impedanz: 50, dbPro100m: [2.8, 4.8, 8.9, 11.3, 16.7, 20.2, 33.7, 39.9]),
    .init(id: "mp_ab10",    gruppe: "Messi & Paoloni", name: "Airborne 10",   beschreibung: "Leicht, 10 mm, transportabel mit guter Performance",impedanz: 50, dbPro100m: [1.6, 2.7, 5.0, 6.4, 9.4, 11.4, 19.0, 22.5]),
]

let kabelGruppen: [String] = {
    var seen = Set<String>()
    return allKabel.compactMap { k in
        seen.insert(k.gruppe).inserted ? k.gruppe : nil
    }
}()

// MARK: - Amateurfunkbänder

struct AFUBand: Identifiable {
    let id: String
    let name: String
    let frequenzMHz: Double
}

let afuBaender: [AFUBand] = [
    .init(id: "160m",  name: "160 m",  frequenzMHz: 1.85),
    .init(id: "80m",   name: "80 m",   frequenzMHz: 3.65),
    .init(id: "40m",   name: "40 m",   frequenzMHz: 7.1),
    .init(id: "30m",   name: "30 m",   frequenzMHz: 10.12),
    .init(id: "20m",   name: "20 m",   frequenzMHz: 14.2),
    .init(id: "17m",   name: "17 m",   frequenzMHz: 18.1),
    .init(id: "15m",   name: "15 m",   frequenzMHz: 21.2),
    .init(id: "12m",   name: "12 m",   frequenzMHz: 24.9),
    .init(id: "10m",   name: "10 m",   frequenzMHz: 28.5),
    .init(id: "6m",    name: "6 m",    frequenzMHz: 50.1),
    .init(id: "2m",    name: "2 m",    frequenzMHz: 144.3),
    .init(id: "70cm",  name: "70 cm",  frequenzMHz: 432.1),
    .init(id: "23cm",  name: "23 cm",  frequenzMHz: 1296.0),
]
