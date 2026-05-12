import Foundation
import Combine

// Live-Spots von api.pota.app/spot/activator. Polls alle 60 Sek, hält die
// aktuelle Spot-Liste als @Published. Read-only — kein Upload-Pfad.
//
// Lifecycle: start() vom POTA-Spots-Tab beim Erscheinen, stop() beim
// Verschwinden, um nicht im Hintergrund unnötig zu pollen.
@MainActor
final class PotaSpotsService: ObservableObject {

    @Published private(set) var spots: [POTASpot] = []
    @Published private(set) var lastFetch: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading: Bool = false

    private var pollTask: Task<Void, Never>?
    private let pollInterval: UInt64 = 60_000_000_000   // 60 s
    private let url = URL(string: "https://api.pota.app/spot/activator")!

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchOnce()
                try? await Task.sleep(nanoseconds: self?.pollInterval ?? 60_000_000_000)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func fetchOnce() async {
        isLoading = true
        defer { isLoading = false }

        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("HAMTools/1.6", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                lastError = "HTTP \(http.statusCode) von pota.app"
                return
            }
            let decoded = try JSONDecoder().decode([POTASpot].self, from: data)
            // Filter: ungültige Spots ausblenden (server-flag invalid=true)
            let valid = decoded.filter { !$0.invalid }
            spots = valid
            lastFetch = Date()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
