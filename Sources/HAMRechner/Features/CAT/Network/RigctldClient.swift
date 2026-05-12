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

    // MARK: - High-Level

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
