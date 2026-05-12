import Foundation

// Eine benannte CAT-Konfiguration. Mehrere können gespeichert werden
// (z.B. "Home-IC7300", "Portable-IC705", "Test-Dummy"). Beim Wechsel
// flippt die aktive Konfiguration und CAT verbindet (wenn enabled).
struct CATConfig: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var profileID: String       // matched gegen TRXProfile.id, "" = nichts gewählt
    var serialPort: String?
    var baudRate: Int
    var dataBits: Int           // 7 / 8
    var stopBits: Int           // 1 / 2
    var parity: SerialParity
    var handshake: SerialHandshake
    var pollIntervalMillis: Int

    init(id: UUID = UUID(),
         name: String,
         profileID: String = "",
         serialPort: String? = nil,
         baudRate: Int = 9600,
         dataBits: Int = 8,
         stopBits: Int = 1,
         parity: SerialParity = .none,
         handshake: SerialHandshake = .none,
         pollIntervalMillis: Int = 500) {
        self.id = id
        self.name = name
        self.profileID = profileID
        self.serialPort = serialPort
        self.baudRate = baudRate
        self.dataBits = dataBits
        self.stopBits = stopBits
        self.parity = parity
        self.handshake = handshake
        self.pollIntervalMillis = pollIntervalMillis
    }

    // Erstellt eine Konfig mit den Werkseinstellungen eines Profils.
    static func from(profile: TRXProfile, name: String? = nil) -> CATConfig {
        CATConfig(
            name: name ?? profile.displayName,
            profileID: profile.id,
            serialPort: nil,
            baudRate: profile.defaultBaud,
            dataBits: profile.defaultDataBits,
            stopBits: profile.defaultStopBits,
            parity: profile.defaultParity,
            handshake: profile.defaultHandshake,
            pollIntervalMillis: 500
        )
    }
}
