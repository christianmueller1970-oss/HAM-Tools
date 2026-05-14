import Foundation
import Combine

// Live-Spots von api2.sota.org.uk/api/spots/50/all. Polls alle 60 Sek,
// hält die aktuelle Spot-Liste als @Published. Read-only — Self-Spotting
// kommt in einer späteren Phase.
//
// Lifecycle: start() vom SOTA-Spots-Tab beim Erscheinen, stop() beim
// Verschwinden, damit kein Hintergrund-Polling läuft.
@MainActor
final class SotaSpotsService: ObservableObject {

    @Published private(set) var spots: [SOTASpot] = []
    @Published private(set) var lastFetch: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading: Bool = false

    private var pollTask: Task<Void, Never>?
    private let pollInterval: UInt64 = 60_000_000_000   // 60 s
    private let url = URL(string: "https://api2.sota.org.uk/api/spots/50/all")!

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
        req.setValue("HAMTools/1.7", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                lastError = "HTTP \(http.statusCode) von sotadata.org.uk"
                return
            }
            let decoded = try JSONDecoder().decode([SOTASpot].self, from: data)
            // Spots ohne callsign oder ohne summitCode rausfiltern — kommt
            // in der API gelegentlich vor (Test-Einträge, abgebrochene Spots).
            spots = decoded.filter {
                !$0.callsign.isEmpty && !$0.summitCode.isEmpty
            }
            lastFetch = Date()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
