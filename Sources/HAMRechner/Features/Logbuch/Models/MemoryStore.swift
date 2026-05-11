import Foundation
import Combine

// Verwaltet alle Memories (global, nicht pro Log). Persistiert als JSON
// in Root/Cache/memories.json.
@MainActor
final class MemoryStore: ObservableObject {
    @Published private(set) var memories: [Memory] = []

    private let dataRoot: AppDataRoot
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(dataRoot: AppDataRoot) {
        self.dataRoot = dataRoot
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = e
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
        load()
    }

    // MARK: - CRUD

    func add(_ m: Memory) {
        memories.append(m)
        sortInPlace()
        save()
    }

    func update(_ m: Memory) {
        guard let idx = memories.firstIndex(where: { $0.id == m.id }) else { return }
        memories[idx] = m
        sortInPlace()
        save()
    }

    func delete(_ m: Memory) {
        memories.removeAll { $0.id == m.id }
        save()
    }

    func togglePin(_ m: Memory) {
        guard let idx = memories.firstIndex(where: { $0.id == m.id }) else { return }
        memories[idx].pinned.toggle()
        sortInPlace()
        save()
    }

    func markUsed(_ m: Memory) {
        guard let idx = memories.firstIndex(where: { $0.id == m.id }) else { return }
        memories[idx].lastUsedAt = Date()
        save()
    }

    // MARK: - Sortier-Logik

    private func sortInPlace() {
        memories.sort { a, b in
            // Pinned zuerst
            if a.pinned != b.pinned { return a.pinned && !b.pinned }
            // Bevorstehende Skeds vor allem anderen
            let aActive = isUpcomingSked(a)
            let bActive = isUpcomingSked(b)
            if aActive != bActive { return aActive && !bActive }
            // Dann nach letzter Verwendung (frischere zuerst)
            let aLast = a.lastUsedAt ?? a.createdAt
            let bLast = b.lastUsedAt ?? b.createdAt
            return aLast > bLast
        }
    }

    private func isUpcomingSked(_ m: Memory) -> Bool {
        guard let d = m.skedDate else { return false }
        // 1 Stunde davor bis 1 Stunde danach
        let now = Date()
        return d.timeIntervalSince(now) > -3600 && d.timeIntervalSince(now) < 86400 * 7
    }

    // MARK: - Persistenz

    private var fileURL: URL { dataRoot.cacheDir.appendingPathComponent("memories.json") }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([Memory].self, from: data)
        else { return }
        memories = decoded
        sortInPlace()
    }

    private func save() {
        guard let data = try? encoder.encode(memories) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
