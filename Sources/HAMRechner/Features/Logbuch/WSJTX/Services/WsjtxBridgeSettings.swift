import Foundation
import Combine

// Persistierte Settings für die WSJT-X-Brücke. Wird im App-Root mit dem
// WsjtxBridgeService verdrahtet, sodass start/stop und Port-Wechsel direkt
// auf den Listener wirken.
@MainActor
final class WsjtxBridgeSettings: ObservableObject {

    private let enabledKey = "wsjtx.bridge.enabled"
    private let portKey    = "wsjtx.bridge.port"

    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: enabledKey) }
    }

    @Published var port: UInt16 {
        didSet { UserDefaults.standard.set(Int(port), forKey: portKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        self.enabled = defaults.bool(forKey: enabledKey)
        let storedPort = defaults.integer(forKey: portKey)
        // 1024 unprivileged ports — alles drüber ist legitim. Fallback 2237
        // ist WSJT-X-Default.
        self.port = (storedPort >= 1024 && storedPort <= 65535)
            ? UInt16(storedPort) : 2237
    }
}
