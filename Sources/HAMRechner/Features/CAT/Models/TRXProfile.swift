import Foundation

// Hamlib-spezifische Werkseinstellungen pro Radio-Modell.
// Werte werden beim Auswählen eines Modells in die aktive Konfiguration
// gefüllt, sind aber editierbar.
struct TRXProfile: Codable, Identifiable, Hashable {
    let id: String              // "icom-ic7300"
    let brand: String           // "Icom"
    let model: String           // "IC-7300"
    let hamlibRigNumber: Int    // 3073 / 3081 / ...
    let defaultBaud: Int
    let defaultDataBits: Int    // 7 oder 8
    let defaultStopBits: Int    // 1 oder 2
    let defaultParity: SerialParity
    let defaultHandshake: SerialHandshake
    let needsSerialPort: Bool
    let supportsFreq: Bool
    let supportsMode: Bool
    let supportsPTT: Bool

    var displayName: String { "\(brand) \(model)" }
}

enum SerialParity: String, Codable, CaseIterable, Hashable, Identifiable {
    case none = "None"
    case odd  = "Odd"
    case even = "Even"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none: return "Keine"
        case .odd:  return "Ungerade (Odd)"
        case .even: return "Gerade (Even)"
        }
    }
}

enum SerialHandshake: String, Codable, CaseIterable, Hashable, Identifiable {
    case none     = "None"
    case hardware = "Hardware"
    case xonxoff  = "XONXOFF"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none:     return "Keine"
        case .hardware: return "Hardware (RTS/CTS)"
        case .xonxoff:  return "Software (XON/XOFF)"
        }
    }
}

@MainActor
final class TRXProfileLoader {
    static let shared = TRXProfileLoader()

    let profiles: [TRXProfile]

    private init() {
        guard let url = Bundle.module.url(forResource: "trx-profiles",
                                          withExtension: "json") else {
            self.profiles = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            self.profiles = try JSONDecoder().decode([TRXProfile].self, from: data)
        } catch {
            self.profiles = []
        }
    }

    func profile(forID id: String) -> TRXProfile? {
        profiles.first { $0.id == id }
    }

    // Alle einzigartigen Hersteller, in Reihenfolge des ersten Auftretens.
    var brands: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for p in profiles {
            if seen.insert(p.brand).inserted {
                ordered.append(p.brand)
            }
        }
        return ordered
    }

    func profiles(forBrand brand: String) -> [TRXProfile] {
        profiles.filter { $0.brand == brand }
    }
}
