import Foundation
import Combine

// Persistiert Logs und QSOs als JSON-Datei in
// ~/Library/Application Support/HAMRechner/logbuch.json.
// (SwiftData ist nicht nutzbar weil das Command-Line-Toolchain die
// SwiftDataMacros nicht ausliefert — JSON-Datei ist ohnehin transparent,
// gut zu backuppen und bei <100k QSOs schnell genug.)
final class LogbuchStore: ObservableObject {
    @Published private(set) var logs: [Log] = []
    @Published private(set) var qsos: [QSO] = []

    private let fileName = "logbuch.json"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private struct Payload: Codable {
        var version: Int
        var logs: [Log]
        var qsos: [QSO]
    }
    private static let currentVersion = 1

    init() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        load()
        ensureLebensLog()
    }

    // MARK: - Logs

    func addLog(_ log: Log) {
        logs.insert(log, at: 0)
        persist()
    }

    func deleteLog(_ log: Log) {
        logs.removeAll { $0.id == log.id }
        qsos.removeAll { $0.logID == log.id }
        persist()
    }

    func updateLog(_ log: Log) {
        guard let idx = logs.firstIndex(where: { $0.id == log.id }) else { return }
        logs[idx] = log
        persist()
    }

    // MARK: - QSOs

    func qsos(for log: Log) -> [QSO] {
        qsos.filter { $0.logID == log.id }
    }

    func qsoCount(for log: Log) -> Int {
        qsos.reduce(0) { $1.logID == log.id ? $0 + 1 : $0 }
    }

    func lastQsoDate(for log: Log) -> Date? {
        qsos.filter { $0.logID == log.id }.map(\.datetime).max()
    }

    func addQSO(_ qso: QSO) {
        qsos.append(qso)
        persist()
    }

    func updateQSO(_ qso: QSO) {
        guard let idx = qsos.firstIndex(where: { $0.id == qso.id }) else { return }
        var updated = qso
        updated.modifiedAt = Date()
        qsos[idx] = updated
        persist()
    }

    func deleteQSO(_ qso: QSO) {
        qsos.removeAll { $0.id == qso.id }
        persist()
    }

    // MARK: - Persistence

    private func ensureLebensLog() {
        guard logs.isEmpty else { return }
        let lebensLog = Log(
            name: "Lebens-Log",
            type: .standard,
            notes: "Allgemeines Log — wird automatisch beim ersten Start angelegt."
        )
        logs.append(lebensLog)
        persist()
    }

    private func load() {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let payload = try? decoder.decode(Payload.self, from: data) else { return }
        self.logs = payload.logs
        self.qsos = payload.qsos
    }

    private func persist() {
        guard let url = fileURL else { return }
        let payload = Payload(version: Self.currentVersion, logs: logs, qsos: qsos)
        if let data = try? encoder.encode(payload) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private var fileURL: URL? {
        guard let base = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let dir = base.appendingPathComponent("HAMRechner", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }
}
