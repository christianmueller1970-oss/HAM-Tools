import Foundation
import Combine

// Persistierte Liste aller UDP-Bridges. Default-Setup beim ersten Start:
// - WSJT-X auf 2237 (an, falls aus dem alten WsjtxBridgeSettings migriert)
// - JS8Call auf 2242 (aus)
// - MSHV auf 2333 (aus — eigener Port, damit WSJT-X und MSHV parallel
//   laufen können; MSHV-User stellen das im MSHV-UDP-Tab um)
// - N1MM Logger+ auf 12060 (aus)
//
// Migration: existierende `wsjtx.bridge.enabled` + `wsjtx.bridge.port` aus
// dem alten WsjtxBridgeSettings werden beim ersten Start in den WSJT-X-
// Default-Eintrag übernommen und die Legacy-Keys gelöscht.
@MainActor
final class UDPBridgesSettings: ObservableObject {

    @Published var bridges: [UDPBridge] {
        didSet { persist() }
    }

    private static let storageKey = "udpBridges.list.v1"
    private static let legacyEnabledKey = "wsjtx.bridge.enabled"
    private static let legacyPortKey    = "wsjtx.bridge.port"

    init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.data(forKey: Self.storageKey),
           let list = try? JSONDecoder().decode([UDPBridge].self, from: raw),
           !list.isEmpty {
            self.bridges = list
        } else {
            // Default-Templates beim ersten Start.
            let legacyEnabled = defaults.bool(forKey: Self.legacyEnabledKey)
            let storedPort = defaults.integer(forKey: Self.legacyPortKey)
            let legacyPort: UInt16 = (storedPort >= 1024 && storedPort <= 65535)
                ? UInt16(storedPort) : 2237

            self.bridges = [
                UDPBridge(name: "WSJT-X",   port: legacyPort, enabled: legacyEnabled, bridgeProtocol: .wsjtxCompatible),
                UDPBridge(name: "JS8Call",  port: 2242,  enabled: false, bridgeProtocol: .wsjtxCompatible),
                UDPBridge(name: "MSHV",     port: 2333,  enabled: false, bridgeProtocol: .wsjtxCompatible),
                UDPBridge(name: "N1MM",     port: 12060, enabled: false, bridgeProtocol: .n1mmContestUDP),
            ]

            // Legacy-Keys aufräumen — der WSJT-X-Eintrag oben hat die alten
            // Werte bereits übernommen.
            defaults.removeObject(forKey: Self.legacyEnabledKey)
            defaults.removeObject(forKey: Self.legacyPortKey)
            persist()
        }
    }

    func add(_ bridge: UDPBridge) {
        bridges.append(bridge)
    }

    func remove(_ id: UUID) {
        bridges.removeAll { $0.id == id }
    }

    func update(_ updated: UDPBridge) {
        guard let idx = bridges.firstIndex(where: { $0.id == updated.id }) else { return }
        bridges[idx] = updated
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(bridges) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
