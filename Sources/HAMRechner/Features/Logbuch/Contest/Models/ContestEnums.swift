import Foundation

// Schema-Bausteine für Contest-Templates (contests.json).
// Bewusst stringbasiert dekodiert, damit unbekannte Werte aus zukünftig
// nachgeladenen Templates die App nicht in den Crash treiben (lieber als
// .free oder mit Default behandelt).

enum FieldKind: String, Codable, Hashable, CaseIterable {
    case rst            // Rapport (599 / 59 je nach Mode)
    case serial         // laufende Nummer
    case canton         // Schweizer Kanton (z.B. BE, ZH)
    case zone           // CQ- oder IARU-Zone (Integer)
    case grid           // 4- oder 6-stelliger Maidenhead-Locator
    case state          // US-State / Kanadische Provinz
    case district       // DARC-DOK, OK-District
    case freeText       // generisches Textfeld
}

enum FieldRole: String, Codable, Hashable {
    case sent
    case recv
}

enum FieldVisibility: String, Codable, Hashable {
    case always
    case onlyIfRecvIsHB     // nur sichtbar wenn die Gegenstation in HB ist
    case onlyIfRecvIsDX     // nur sichtbar wenn die Gegenstation NICHT in HB ist
}

enum AutoFillKind: String, Codable, Hashable {
    case rstFromMode        // 599 für CW/RTTY/DIGI, 59 für SSB/FM
    case serialNext         // nächste Serial aus ContestService (scope-abhängig)
    case myCanton           // eigener Kanton aus User-Profil
    case myGrid             // eigener Locator (4/6-stellig) aus User-Profil
    case myZone             // eigene CQ-Zone aus User-Profil
}

enum SerialScope: String, Codable, Hashable {
    case log                // Serial 001…N für den ganzen Log durchgehend
    case band               // Serial 001…N je Band — CQ-WPX Multi-2 / Multi-Unlimited
}

// Cabrillo-Header-Kategorien als Strings. Nicht als enum modelliert weil
// die Liste pro Contest leicht variiert und wir nichts kaputt machen wollen
// wenn ein Contest ein exotisches "CATEGORY-OVERLAY: TB-WIRES" hat.
struct DefaultCategories: Codable, Hashable {
    var op: String?          // "SINGLE-OP" | "MULTI-SINGLE" | "MULTI-TWO" | "MULTI-UNLIMITED" | "CHECKLOG"
    var power: String?       // "HIGH" | "LOW" | "QRP"
    var band: String?        // "ALL" | "160M" | "80M" | "40M" | "20M" | "15M" | "10M" | "6M" | "2M"
    var mode: String?        // "CW" | "PH" | "RY" | "DG" | "MIXED"
    var station: String?     // "FIXED" | "MOBILE" | "PORTABLE" | "ROVER" | "EXPEDITION" | "HQ"
    var assisted: String?    // "ASSISTED" | "NON-ASSISTED"
    var time: String?        // "24-HOURS" | "12-HOURS" | "8-HOURS" | "6-HOURS"
    var transmitter: String? // "ONE" | "TWO" | "LIMITED" | "UNLIMITED" | "SWL"
    var overlay: String?     // "CLASSIC" | "ROOKIE" | "TB-WIRES" | "NOVICE-TECH" | "OVER-50"
}

// Pickliste der 26 Schweizer Kantone — vorgegeben fürs Canton-Feld.
enum SwissCanton: String, CaseIterable, Identifiable {
    case AG, AI, AR, BE, BL, BS, FR, GE, GL, GR, JU, LU, NE, NW, OW
    case SG, SH, SO, SZ, TG, TI, UR, VD, VS, ZG, ZH

    var id: String { rawValue }

    /// Vollname zur Anzeige (DE)
    var fullName: String {
        switch self {
        case .AG: return "Aargau"
        case .AI: return "Appenzell Innerrhoden"
        case .AR: return "Appenzell Ausserrhoden"
        case .BE: return "Bern"
        case .BL: return "Basel-Landschaft"
        case .BS: return "Basel-Stadt"
        case .FR: return "Freiburg"
        case .GE: return "Genf"
        case .GL: return "Glarus"
        case .GR: return "Graubünden"
        case .JU: return "Jura"
        case .LU: return "Luzern"
        case .NE: return "Neuenburg"
        case .NW: return "Nidwalden"
        case .OW: return "Obwalden"
        case .SG: return "St. Gallen"
        case .SH: return "Schaffhausen"
        case .SO: return "Solothurn"
        case .SZ: return "Schwyz"
        case .TG: return "Thurgau"
        case .TI: return "Tessin"
        case .UR: return "Uri"
        case .VD: return "Waadt"
        case .VS: return "Wallis"
        case .ZG: return "Zug"
        case .ZH: return "Zürich"
        }
    }
}

// Heuristik: gehört das Call zu einem HB-(Schweizer) Rufzeichen?
// Bewusst tolerant: Präfixe HB9, HB0, HB3 + Sonderkennungen HE9 (USKA).
// Wird in Helvetia-Contest für die Recv-Field-Visibility benutzt.
func isHBCallsign(_ call: String) -> Bool {
    let upper = call.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    return upper.hasPrefix("HB") || upper.hasPrefix("HE")
}
