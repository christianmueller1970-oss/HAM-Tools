import Foundation
import Combine

// Multi-Config-Store für CAT. Hält Liste von CATConfig + aktive ID.
// Persistiert in UserDefaults als JSON (analog zu ClusterSettingsStore).
@MainActor
final class CATSettings: ObservableObject {
    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Keys.enabled) }
    }
    @Published var configs: [CATConfig] {
        didSet { saveConfigs() }
    }
    @Published var activeConfigID: UUID? {
        didSet {
            UserDefaults.standard.set(activeConfigID?.uuidString,
                                      forKey: Keys.activeID)
        }
    }

    // Convenience: aktive Konfiguration. Schreiben aktualisiert das Element
    // in der Liste, damit @Published feuert.
    var activeConfig: CATConfig? {
        get { configs.first { $0.id == activeConfigID } }
        set {
            guard let v = newValue,
                  let idx = configs.firstIndex(where: { $0.id == v.id }) else { return }
            configs[idx] = v
        }
    }

    init() {
        let d = UserDefaults.standard
        self.enabled = d.bool(forKey: Keys.enabled)

        if let data = d.data(forKey: Keys.configs),
           let list = try? JSONDecoder().decode([CATConfig].self, from: data),
           !list.isEmpty {
            self.configs = list
        } else {
            // Erste Inbetriebnahme: ein Default-Dummy-Eintrag, damit die UI
            // nicht leer aussieht und der User sofort testen kann.
            self.configs = [CATConfig(name: "Dummy",
                                      profileID: "hamlib-dummy",
                                      baudRate: 9600)]
        }

        if let stored = d.string(forKey: Keys.activeID),
           let uuid = UUID(uuidString: stored),
           self.configs.contains(where: { $0.id == uuid }) {
            self.activeConfigID = uuid
        } else {
            self.activeConfigID = self.configs.first?.id
        }
    }

    // MARK: - CRUD

    func addConfig(_ config: CATConfig) {
        configs.append(config)
        activeConfigID = config.id
    }

    func removeConfig(id: UUID) {
        let wasActive = activeConfigID == id
        configs.removeAll { $0.id == id }
        if wasActive {
            activeConfigID = configs.first?.id
        }
    }

    func duplicateActive(withName newName: String) {
        guard var copy = activeConfig else { return }
        copy.id = UUID()
        copy.name = newName
        addConfig(copy)
    }

    // MARK: - Update-Helper

    // Aktive Konfig mit Werkseinstellungen eines neuen Profils auffüllen,
    // Port/Name beibehalten (Port ist physisch, Name ist user-gegeben).
    func applyProfileDefaultsToActive(_ profile: TRXProfile) {
        guard var cfg = activeConfig else { return }
        cfg.profileID  = profile.id
        cfg.baudRate   = profile.defaultBaud
        cfg.dataBits   = profile.defaultDataBits
        cfg.stopBits   = profile.defaultStopBits
        cfg.parity     = profile.defaultParity
        cfg.handshake  = profile.defaultHandshake
        activeConfig = cfg
    }

    private func saveConfigs() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: Keys.configs)
        }
    }

    private enum Keys {
        static let enabled  = "cat.enabled"
        static let configs  = "cat.configs"
        static let activeID = "cat.activeConfigID"
    }
}

// Serial-Port-Discovery durch Scan von /dev/cu.*.
enum SerialPortDiscovery {
    static func availablePorts() -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: "/dev") else {
            return []
        }
        return entries
            .filter { $0.hasPrefix("cu.") }
            .map { "/dev/" + $0 }
            .sorted()
    }
}
