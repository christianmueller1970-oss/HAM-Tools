import Foundation
import Combine

// User-Einstellungen für CAT, in UserDefaults persistiert.
// Pattern analog zu ClusterSettingsStore.
@MainActor
final class CATSettings: ObservableObject {
    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Keys.enabled) }
    }
    @Published var selectedProfileID: String? {
        didSet { UserDefaults.standard.set(selectedProfileID, forKey: Keys.profileID) }
    }
    @Published var serialPort: String? {
        didSet { UserDefaults.standard.set(serialPort, forKey: Keys.port) }
    }
    @Published var baudRate: Int {
        didSet { UserDefaults.standard.set(baudRate, forKey: Keys.baud) }
    }
    @Published var pollIntervalMillis: Int {
        didSet { UserDefaults.standard.set(pollIntervalMillis, forKey: Keys.pollMs) }
    }

    init() {
        let d = UserDefaults.standard
        self.enabled = d.bool(forKey: Keys.enabled)
        self.selectedProfileID = d.string(forKey: Keys.profileID)
        self.serialPort = d.string(forKey: Keys.port)
        let storedBaud = d.integer(forKey: Keys.baud)
        self.baudRate = storedBaud > 0 ? storedBaud : 19200
        let storedPoll = d.integer(forKey: Keys.pollMs)
        self.pollIntervalMillis = storedPoll > 0 ? storedPoll : 500
    }

    private enum Keys {
        static let enabled   = "cat.enabled"
        static let profileID = "cat.profileID"
        static let port      = "cat.serialPort"
        static let baud      = "cat.baud"
        static let pollMs    = "cat.pollIntervalMs"
    }
}

// Serial-Port-Discovery durch Scan von /dev/cu.*.
// Reine Utility, kein Store-State.
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
