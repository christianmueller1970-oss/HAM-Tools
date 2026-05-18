import Foundation

// TCP-Client für das rigctld-Textprotokoll (Hamlib).
// Eine Instanz hält eine Verbindung. Aufrufer (CATController) serialisiert
// Commands; intern keine Parallelität.
//
// Protokoll-Kurzreferenz:
//   "f\n"       → "<hz>\n"
//   "F <hz>\n"  → "RPRT 0\n"          (Set Freq — Phase 5b)
//   "m\n"       → "<mode>\n<pass>\n"  (Mode + Passband)
//   "M <m> <p>\n" → "RPRT 0\n"        (Set Mode — Phase 5b)
final class RigctldClient: @unchecked Sendable {
    private let session = URLSession(configuration: .ephemeral)
    private var task: URLSessionStreamTask?
    private var buffer = Data()
    private let timeoutSeconds: TimeInterval = 2.0

    var isConnected: Bool { task != nil }

    func connect(host: String = "127.0.0.1", port: Int = 4532) {
        task = session.streamTask(withHostName: host, port: port)
        task?.resume()
        buffer = Data()
    }

    func disconnect() {
        task?.closeRead()
        task?.closeWrite()
        task = nil
        buffer = Data()
    }

    // MARK: - High-Level Read

    func getFrequencyHz() async throws -> Int64 {
        let lines = try await sendCommand("f", expectingLines: 1)
        guard let hz = Int64(lines[0]) else {
            throw CATError.protocolError(message: "Frequenz nicht parsebar: '\(lines[0])'")
        }
        return hz
    }

    func getMode() async throws -> (mode: String, passbandHz: Int) {
        let lines = try await sendCommand("m", expectingLines: 2)
        let mode = lines[0]
        let pb = Int(lines[1]) ?? 0
        return (mode, pb)
    }

    // Signal-Stärke in dB RELATIV zu S9. S9 = 0, S0 ≈ -54, S9+10 = +10, etc.
    // Hamlib-Doku: RIG_LEVEL_STRENGTH liefert integer in dB rel S9.
    // Einige rigctld-Versionen liefern Float — daher tolerant parsen.
    func getSignalStrengthRelDB() async throws -> Int {
        let lines = try await sendCommand("l STRENGTH", expectingLines: 1)
        let raw = lines[0].trimmingCharacters(in: .whitespaces)
        if let i = Int(raw) { return i }
        if let d = Double(raw) { return Int(d.rounded()) }
        throw CATError.protocolError(message: "Signal-Stärke nicht parsebar: '\(raw)'")
    }

    // RF-Output-Power als Hamlib-RFPOWER-Level: Float 0.0 – 1.0 als Anteil
    // der TRX-Maximalpower. Hamlib normalisiert das pro Modell selbst —
    // wir bekommen direkt den Prozentwert.
    //
    // Hinweis: Einige Hamlib-Backends antworten mit "RPRT -11" (Funktion
    // nicht unterstützt), wenn das Radio kein Power-Reading liefert. Der
    // Aufrufer behandelt das als »kein Wert« und blendet die Anzeige aus.
    func getRFPowerLevel() async throws -> Float {
        let lines = try await sendCommand("l RFPOWER", expectingLines: 1)
        let raw = lines[0].trimmingCharacters(in: .whitespaces)
        if let f = Float(raw) { return max(0, min(1, f)) }
        throw CATError.protocolError(message: "RFPOWER nicht parsebar: '\(raw)'")
    }

    // Aktiver VFO: "VFOA" / "VFOB" / "MEM" / ... — Hamlib-Konvention.
    func getVFO() async throws -> String {
        let lines = try await sendCommand("v", expectingLines: 1)
        return lines[0]
    }

    // Split-Status: 0 = aus, 1 = an. Liefert dazu den TX-VFO.
    func getSplit() async throws -> (on: Bool, txVfo: String) {
        let lines = try await sendCommand("s", expectingLines: 2)
        let on = (Int(lines[0]) ?? 0) != 0
        return (on, lines[1])
    }

    // MARK: - High-Level Write (Phase 5b)

    func setFrequencyHz(_ hz: Int64) async throws {
        let lines = try await sendCommand("F \(hz)", expectingLines: 1)
        try Self.checkRPRT(lines[0], context: "setFrequency")
    }

    // passbandHz=0 → Hamlib übernimmt Default für den Mode.
    func setMode(_ mode: String, passbandHz: Int = 0) async throws {
        let lines = try await sendCommand("M \(mode) \(passbandHz)", expectingLines: 1)
        try Self.checkRPRT(lines[0], context: "setMode")
    }

    func setVFO(_ vfo: String) async throws {
        let lines = try await sendCommand("V \(vfo)", expectingLines: 1)
        try Self.checkRPRT(lines[0], context: "setVFO")
    }

    func setSplit(on: Bool, txVfo: String) async throws {
        let lines = try await sendCommand("S \(on ? 1 : 0) \(txVfo)", expectingLines: 1)
        try Self.checkRPRT(lines[0], context: "setSplit")
    }

    private static func checkRPRT(_ line: String, context: String) throws {
        // Antwort-Format: "RPRT 0" (ok) oder "RPRT -<errcode>".
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed == "RPRT 0" { return }
        if trimmed.hasPrefix("RPRT") {
            throw CATError.protocolError(message: "\(context) abgelehnt: \(trimmed)")
        }
        // Manche rigctld-Versionen liefern bei Erfolg eine leere Zeile.
        if trimmed.isEmpty { return }
        throw CATError.protocolError(message: "\(context): unerwartete Antwort '\(trimmed)'")
    }

    // MARK: - Low-Level Send + Receive

    private func sendCommand(_ cmd: String, expectingLines: Int) async throws -> [String] {
        guard let task else { throw CATError.connectionClosed }

        guard let payload = (cmd + "\n").data(using: .utf8) else {
            throw CATError.protocolError(message: "Command nicht UTF-8: \(cmd)")
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            task.write(payload, timeout: timeoutSeconds) { err in
                if let err {
                    cont.resume(throwing: CATError.connectionFailed(underlying: err))
                } else {
                    cont.resume()
                }
            }
        }

        while countNewlines(buffer) < expectingLines {
            let chunk = try await receiveChunk()
            if chunk.isEmpty {
                throw CATError.connectionClosed
            }
            buffer.append(chunk)
        }

        var lines: [String] = []
        for _ in 0..<expectingLines {
            guard let nlRange = buffer.range(of: Data([0x0A])) else {
                throw CATError.protocolError(message: "Fehlende Newline in Response")
            }
            let lineData = buffer.subdata(in: 0..<nlRange.lowerBound)
            buffer.removeSubrange(0..<nlRange.upperBound)
            let line = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            lines.append(line)
        }
        return lines
    }

    private func receiveChunk() async throws -> Data {
        guard let task else { throw CATError.connectionClosed }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            task.readData(ofMinLength: 1, maxLength: 4096, timeout: timeoutSeconds) { data, _, err in
                if let err {
                    cont.resume(throwing: CATError.connectionFailed(underlying: err))
                    return
                }
                cont.resume(returning: data ?? Data())
            }
        }
    }

    private func countNewlines(_ d: Data) -> Int {
        d.reduce(0) { $0 + ($1 == 0x0A ? 1 : 0) }
    }
}
