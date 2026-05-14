import Foundation
import Network
import Combine

// UDP-Listener für die WSJT-X-Brücke. Empfängt Heartbeats / Status / QSOLogged
// und macht sie als @Published verfügbar. QSO-Eingänge gehen über `onQSOLogged`
// raus — verdrahtet wird das im App-Root mit LogbookManager.addQSO(...).
@MainActor
final class WsjtxBridgeService: ObservableObject {

    enum ConnectionState: Equatable {
        case stopped
        case listening
        case linked         // Heartbeat in den letzten 30 Sek
        case failed(String)
    }

    @Published private(set) var connectionState: ConnectionState = .stopped
    @Published private(set) var port: UInt16 = 2237
    @Published private(set) var lastHeartbeat: Date?
    @Published private(set) var lastStatus: WsjtxStatus?
    @Published private(set) var wsjtxVersion: String?
    @Published private(set) var qsosLoggedCount: Int = 0
    @Published private(set) var lastQSO: WsjtxQSOLogged?
    @Published private(set) var lastError: String?

    /// Wird bei jedem geloggten QSO aufgerufen — App-Root verdrahtet das mit
    /// dem LogbookManager.
    var onQSOLogged: ((WsjtxQSOLogged) -> Void)?

    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var heartbeatTimer: Timer?

    // MARK: - Lifecycle

    func start(port: UInt16 = 2237) {
        stop()
        self.port = port
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            connectionState = .failed("Ungültiger Port \(port)")
            return
        }
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        do {
            let listener = try NWListener(using: params, on: nwPort)
            listener.newConnectionHandler = { [weak self] conn in
                Task { @MainActor in self?.accept(connection: conn) }
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in self?.handle(listenerState: state) }
            }
            listener.start(queue: .global(qos: .utility))
            self.listener = listener
            self.connectionState = .listening
            self.lastError = nil
            startHeartbeatTimer()
        } catch {
            connectionState = .failed("Listener-Start fehlgeschlagen: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    func stop() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        listener?.cancel()
        listener = nil
        for c in connections.values { c.cancel() }
        connections.removeAll()
        connectionState = .stopped
        lastHeartbeat = nil
        lastStatus = nil
        wsjtxVersion = nil
    }

    // Wird vom Settings-UI gerufen, wenn der User den Port ändert.
    func restart(port: UInt16) {
        let wasRunning = listener != nil
        stop()
        if wasRunning { start(port: port) }
    }

    // MARK: - Listener-State

    private func handle(listenerState: NWListener.State) {
        switch listenerState {
        case .ready:
            connectionState = .listening
        case .failed(let err):
            connectionState = .failed(err.localizedDescription)
            lastError = err.localizedDescription
        case .cancelled:
            connectionState = .stopped
        default:
            break
        }
    }

    // MARK: - Connections

    private func accept(connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        connections[key] = connection
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .cancelled, .failed:
                    self?.connections.removeValue(forKey: key)
                default: break
                }
            }
        }
        connection.start(queue: .global(qos: .utility))
        receive(on: connection)
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let data, !data.isEmpty {
                Task { @MainActor in self?.handle(datagram: data) }
            }
            if error == nil {
                Task { @MainActor in self?.receive(on: connection) }
            }
        }
    }

    // MARK: - Decode + Dispatch

    private func handle(datagram: Data) {
        let msg: WsjtxMessage
        do {
            msg = try WsjtxProtocolDecoder.decode(datagram)
        } catch {
            // Fremd-Datagramme können auf dem Port landen — still verwerfen.
            return
        }

        switch msg {
        case .heartbeat(let h):
            lastHeartbeat = Date()
            wsjtxVersion = h.version.isEmpty ? nil : h.version
            connectionState = .linked

        case .status(let s):
            lastStatus = s
            lastHeartbeat = Date()
            connectionState = .linked

        case .qsoLogged(let q):
            qsosLoggedCount += 1
            lastQSO = q
            lastHeartbeat = Date()
            connectionState = .linked
            onQSOLogged?(q)

        case .close:
            wsjtxVersion = nil
            lastStatus = nil
            connectionState = .listening

        case .unhandled:
            // Reply / Clear / Decode / Replay / Halt / FreeText / WSPRDecode
            // / Location / LoggedADIF — derzeit nicht ausgewertet.
            break
        }
    }

    // MARK: - Heartbeat-Watchdog

    // Nach 30 Sek ohne Heartbeat fallen wir auf .listening zurück, damit das
    // UI nicht "verbunden" zeigt, obwohl WSJT-X gar nicht mehr sendet.
    private func startHeartbeatTimer() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5,
                                              repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkHeartbeat() }
        }
    }

    private func checkHeartbeat() {
        guard connectionState == .linked,
              let hb = lastHeartbeat,
              Date().timeIntervalSince(hb) > 30 else { return }
        connectionState = .listening
        wsjtxVersion = nil
    }
}
