import Foundation
import Network

final class ClusterClient {
    enum Status: String {
        case disconnected = "Getrennt"
        case connecting   = "Verbinde…"
        case loggingIn    = "Login…"
        case connected    = "Verbunden"
        case error        = "Fehler"
    }

    let host:      String
    let port:      UInt16
    let callsign:  String
    let name:      String

    var onSpot:    ((DXSpot) -> Void)?
    var onStatus:  ((Status) -> Void)?
    var onMessage: ((String) -> Void)?

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "dx.cluster.tcp", qos: .background)
    private var buffer        = ""
    private var loggedIn      = false
    private var callsignSent  = false
    private var stopFlag      = false
    private var keepaliveWork: DispatchWorkItem?

    /// Letzter Daten-Empfang vom Cluster — für Inactivity-Watchdog.
    /// Wenn länger als `inactivityTimeout` keine Daten kommen, gilt die Verbindung
    /// als "still tot" (TCP offen, Server reagiert aber nicht mehr) → reconnect.
    private var lastDataAt: Date = Date()
    private let inactivityTimeout: TimeInterval = 5 * 60   // 5 Minuten

    init(host: String, port: UInt16, callsign: String, name: String = "") {
        self.host     = host
        self.port     = port
        self.callsign = callsign.uppercased()
        self.name     = name.isEmpty ? "\(host):\(port)" : name
    }

    // MARK: - Public

    func connect() {
        stopFlag = false
        queue.async { self._connect() }
    }

    func disconnect() {
        stopFlag = true
        keepaliveWork?.cancel()
        keepaliveWork = nil
        connection?.cancel()
        connection = nil
        appendLog("════════ Trennung von \(name) ════════")
        setStatus(.disconnected)
    }

    func sendCommand(_ cmd: String) {
        guard loggedIn else { return }
        connection?.send(content: "\(cmd)\r\n".data(using: .utf8),
                         completion: .idempotent)
        appendLog("[SENT] \(cmd)")
    }

    // MARK: - Private

    private func _connect() {
        buffer = ""; loggedIn = false; callsignSent = false
        keepaliveWork?.cancel(); keepaliveWork = nil
        appendLog("")
        appendLog("════════ \(name) (\(host):\(port)) ════════")
        setStatus(.connecting)

        let conn = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.setStatus(.loggingIn)
                self.appendLog("[\(ts())] TCP-Verbindung zu \(self.host):\(self.port) hergestellt")
                self.scheduleCallsignFallback()
                self.receiveLoop()
            case .failed(let err):
                self.appendLog("[\(ts())] Verbindungsfehler: \(err)")
                self.setStatus(.error)
                self.scheduleReconnect()
            case .cancelled:
                if !self.stopFlag { self.scheduleReconnect() }
            default: break
            }
        }
        conn.start(queue: queue)
    }

    private func receiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
            [weak self] data, _, isDone, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.lastDataAt = Date()
                // Normalize CR/CRLF → LF at byte level before string conversion.
                // Swift String replacingOccurrences is unreliable when mixed
                // with Latin-1 data; byte-level is guaranteed.
                var norm: [UInt8] = []
                norm.reserveCapacity(data.count)
                var prev: UInt8 = 0
                for b in data {
                    if b == 0x0D {          // CR → LF
                        norm.append(0x0A)
                    } else if b == 0x0A && prev == 0x0D {
                        // already emitted LF for the preceding CR — skip
                    } else {
                        norm.append(b)
                    }
                    prev = b
                }
                let text = String(bytes: norm, encoding: .utf8)
                       ?? String(bytes: norm, encoding: .isoLatin1)
                       ?? ""
                self.buffer += text
                self.processBuffer()
            }
            if error == nil && !isDone {
                self.receiveLoop()
            } else if let error {
                self.appendLog("[\(ts())] Empfangsfehler: \(error)")
                self.scheduleReconnect()
            }
        }
    }

    private func processBuffer() {
        // Check login prompt before first newline
        if !callsignSent {
            let low = buffer.lowercased()
            if low.contains("login") || low.contains("call:") {
                sendCallsign()
            }
        }

        while let nl = buffer.range(of: "\n") {
            let raw  = String(buffer[buffer.startIndex..<nl.lowerBound])
            buffer   = String(buffer[nl.upperBound...])
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            appendLog("  << \(line)")

            let lower = line.lowercased()
            if !callsignSent && (lower.contains("login") || lower.contains("call:")) {
                sendCallsign(); continue
            }
            if lower.contains("password") || lower.contains("passwd") {
                connection?.send(content: "\r\n".data(using: .utf8), completion: .idempotent)
                continue
            }
            if callsignSent && !loggedIn {
                let isSpot = lower.hasPrefix("dx de")
                if line.uppercased().contains(callsign) ||
                   lower.contains("connected") || lower.contains("hello") || isSpot {
                    loggedIn = true
                    setStatus(.connected)
                    appendLog("[\(ts())] >>> EINGELOGGT als \(callsign) <<<")
                    scheduleKeepalive()
                    if !isSpot {
                        connection?.send(content: "sh/dx 50\r\n".data(using: .utf8),
                                         completion: .idempotent)
                        continue
                    }
                    // DX-Spot erkannt → durchfallen zu Spot-Verarbeitung
                } else {
                    continue
                }
            }
            if loggedIn, let spot = SpotParser.parse(line, source: name) {
                DispatchQueue.main.async { self.onSpot?(spot) }
            }
        }
    }

    private func sendCallsign() {
        guard !callsignSent else { return }
        callsignSent = true
        connection?.send(content: "\(callsign)\r\n".data(using: .utf8),
                         completion: .idempotent)
        appendLog("[\(ts())] Sende Rufzeichen: \(callsign)")
        scheduleLoginFallback()
    }

    private func scheduleLoginFallback() {
        queue.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.callsignSent, !self.loggedIn, !self.stopFlag else { return }
            self.loggedIn = true
            self.setStatus(.connected)
            self.appendLog("[\(ts())] >>> EINGELOGGT (\(self.callsign)) — Timeout-Fallback <<<")
            self.scheduleKeepalive()
            self.connection?.send(content: "sh/dx 50\r\n".data(using: .utf8),
                                  completion: .idempotent)
        }
    }

    private func scheduleCallsignFallback() {
        queue.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, !self.callsignSent else { return }
            self.sendCallsign()
        }
    }

    private func scheduleKeepalive() {
        keepaliveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.loggedIn, !self.stopFlag else { return }

            // Inactivity-Watchdog: wenn lange keine Daten mehr kamen,
            // gilt die Verbindung als tot → Reconnect erzwingen.
            let idle = Date().timeIntervalSince(self.lastDataAt)
            if idle > self.inactivityTimeout {
                self.appendLog("[\(ts())] Keine Daten seit \(Int(idle))s — Verbindung als tot markiert")
                self.setStatus(.error)
                self.connection?.cancel()
                self.scheduleReconnect()
                return
            }

            self.connection?.send(content: "\r\n".data(using: .utf8), completion: .idempotent)
            self.scheduleKeepalive()
        }
        keepaliveWork = work
        queue.asyncAfter(deadline: .now() + 60, execute: work)   // Check alle 60s statt 120s
    }

    private func scheduleReconnect() {
        guard !stopFlag else { return }
        setStatus(.disconnected)
        appendLog("[\(ts())] Nächster Verbindungsversuch in 30s…")
        queue.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self, !self.stopFlag else { return }
            self._connect()
        }
    }

    private func setStatus(_ s: Status) {
        DispatchQueue.main.async { self.onStatus?(s) }
    }
    private func appendLog(_ msg: String) {
        let tagged = msg.isEmpty ? msg : "\(msg)  [\(shortTag)]"
        DispatchQueue.main.async { self.onMessage?(tagged) }
    }

    /// Kompakter Cluster-Tag fürs Log-Suffix: erstes Wort des Namens, max. 6 Zeichen.
    /// "DXSpider Funkwelt" → "DXSpid"  ·  "HB9W DX-Cluster" → "HB9W"  ·  "VE7CC Vancouver" → "VE7CC"
    private var shortTag: String {
        let first = name.split(whereSeparator: { $0 == " " }).first.map(String.init) ?? name
        return String(first.prefix(6))
    }

    private static func stripIAC(_ data: Data) -> [UInt8] {
        var out = [UInt8]()
        var i = 0
        let bytes = Array(data)
        while i < bytes.count {
            if bytes[i] == 0xFF {
                i += (i + 1 < bytes.count) ? (i + 2 < bytes.count ? 3 : 2) : 1
            } else {
                out.append(bytes[i]); i += 1
            }
        }
        return out
    }
}

private func ts() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f.string(from: Date())
}
