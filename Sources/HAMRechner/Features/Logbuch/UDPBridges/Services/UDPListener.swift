import Foundation
import Network

// Generischer UDP-Listener für eine einzelne Bridge. Wickelt NWListener +
// NWConnection-Lifecycle ab und ruft pro empfangenem Datagramm einen
// Adapter-Callback auf. Stoppt sauber bei `stop()` oder Deinit.
//
// Pattern-Twin zum bestehenden WsjtxBridgeService, aber protokoll-agnostisch
// — die Decode-Logik liegt im Adapter-Layer.
@MainActor
final class UDPListener {

    enum State: Equatable {
        case stopped
        case listening
        case linked         // letzter Verkehr <30s her
        case failed(String)
    }

    let bridgeID: UUID
    let port: UInt16

    private(set) var state: State = .stopped
    private(set) var lastActivity: Date?
    private(set) var lastError: String?
    private(set) var datagramCount: Int = 0

    /// Wird auf MainActor pro empfangenem Datagramm aufgerufen.
    var onDatagram: ((Data) -> Void)?
    /// State-Änderungen für UI-Status-Pillen.
    var onStateChange: ((State) -> Void)?

    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]

    init(bridgeID: UUID, port: UInt16) {
        self.bridgeID = bridgeID
        self.port = port
    }

    func start() {
        stop()
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            setState(.failed("Ungültiger Port \(port)"))
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
            setState(.listening)
            lastError = nil
        } catch {
            setState(.failed("Listener-Start fehlgeschlagen: \(error.localizedDescription)"))
            lastError = error.localizedDescription
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for c in connections.values { c.cancel() }
        connections.removeAll()
        setState(.stopped)
    }

    private func handle(listenerState: NWListener.State) {
        switch listenerState {
        case .ready:    setState(.listening)
        case .failed(let err):
            setState(.failed(err.localizedDescription))
            lastError = err.localizedDescription
        case .cancelled: setState(.stopped)
        default: break
        }
    }

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

    private func handle(datagram: Data) {
        datagramCount += 1
        lastActivity = Date()
        if state == .listening { setState(.linked) }
        onDatagram?(datagram)
    }

    /// Vom Service alle 5–10s gerufen — bei Inaktivität >30s fällt der Status
    /// von .linked auf .listening zurück.
    func tickWatchdog(now: Date = Date()) {
        guard state == .linked, let last = lastActivity,
              now.timeIntervalSince(last) > 30 else { return }
        setState(.listening)
    }

    private func setState(_ new: State) {
        guard new != state else { return }
        state = new
        onStateChange?(new)
    }
}
