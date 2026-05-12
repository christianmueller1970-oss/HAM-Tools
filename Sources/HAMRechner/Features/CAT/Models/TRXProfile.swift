import Foundation

// TRX-Profil aus trx-profiles.json. Hamlib-Rig-Number + Default-Serial-Settings.
struct TRXProfile: Codable, Identifiable, Hashable {
    let id: String                // z.B. "icom-ic7300"
    let name: String              // z.B. "Icom IC-7300"
    let hamlibRigNumber: Int      // 3073 / 3081 / 3085 ...
    let defaultBaud: Int          // 19200 / 115200 / ...
    let supportsFreq: Bool
    let supportsMode: Bool
    let supportsPTT: Bool         // Phase 5d
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
}
