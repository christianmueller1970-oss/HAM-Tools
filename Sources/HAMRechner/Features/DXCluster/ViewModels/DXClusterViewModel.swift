import Foundation
import SwiftUI

@MainActor
final class DXClusterViewModel: ObservableObject {
    // MARK: - Data
    @Published var spots:       [DXSpot] = []
    @Published var logMessages: [String] = []
    @Published var propagation  = PropagationData()
    @Published var clusterStatus: ClusterClient.Status = .disconnected

    // MARK: - API status (true = reached at least once)
    @Published var sotaActive = false
    @Published var potaActive = false
    @Published var wwffActive = false

    // MARK: - Filter state
    @Published var filterBand:       String = "Alle"
    @Published var filterMode:       String = "Alle"
    @Published var filterContinent:  String = "Alle"
    @Published var showDX    = true
    @Published var showSOTA  = true
    @Published var showPOTA  = true
    @Published var showWWFF  = true
    @Published var searchText = ""

    // MARK: - Settings (persisted)
    @AppStorage("callsign")    private var storedCallsign = "HB9HJI"
    @AppStorage("clusterHost") private var clusterHost   = "dxspider.funkwelt.net"
    @AppStorage("clusterPort") private var clusterPort   = 7300

    var myCallsign: String { storedCallsign }

    private var client:    ClusterClient?
    private var propTask:  Task<Void, Never>?
    private var sotaTask:  Task<Void, Never>?
    private var potaTask:  Task<Void, Never>?
    private var wwffTask:  Task<Void, Never>?

    private let sotaFetcher = SOTAFetcher()
    private let potaFetcher = POTAFetcher()
    private let wwffFetcher = WWFFFetcher()

    // MARK: - Computed

    var filteredSpots: [DXSpot] {
        spots.filter { spot in
            if filterBand != "Alle" && spot.band != filterBand { return false }
            if filterMode != "Alle" && spot.mode != filterMode { return false }
            if filterContinent != "Alle" && spot.continent != filterContinent { return false }
            switch spot.sourceType {
            case "SOTAwatch3": if !showSOTA { return false }
            case "POTA":       if !showPOTA { return false }
            case "WWFF":       if !showWWFF { return false }
            default:           if !showDX   { return false }
            }
            if !searchText.isEmpty {
                let q = searchText.uppercased()
                if !spot.dxCall.uppercased().contains(q) &&
                   !spot.comment.uppercased().contains(q) &&
                   !spot.spotter.uppercased().contains(q) { return false }
            }
            return true
        }
    }

    var spotCount: Int { filteredSpots.count }

    /// Band × Continent matrix for heatmap
    func bandMatrix(minutes: Int) -> [[Int]] {
        let cutoff = Date().addingTimeInterval(-Double(minutes) * 60)
        let recent = spots.filter { $0.timestamp >= cutoff }
        var matrix = Array(repeating: Array(repeating: 0, count: CONTINENTS.count),
                           count: HEATMAP_BANDS.count)
        for spot in recent {
            if let bi = HEATMAP_BANDS.firstIndex(of: spot.band),
               let ci = CONTINENTS.firstIndex(of: spot.continent) {
                matrix[bi][ci] += 1
            }
        }
        return matrix
    }

    // MARK: - Lifecycle

    func connect(host: String? = nil, port: Int? = nil) {
        let host = host ?? clusterHost
        let port = UInt16(port ?? clusterPort)
        let call = storedCallsign

        client = ClusterClient(host: host, port: port, callsign: call, name: host)
        client?.onSpot    = { [weak self] spot in self?.addSpot(spot) }
        client?.onStatus  = { [weak self] status in self?.clusterStatus = status }
        client?.onMessage = { [weak self] msg in self?.appendLog(msg) }
        client?.connect()

        propTask = Task {
            let fetcher = PropagationFetcher()
            while !Task.isCancelled {
                propagation = await fetcher.fetchOnce()
                try? await Task.sleep(for: .seconds(900))
            }
        }

        sotaTask = Task {
            while !Task.isCancelled {
                let newSpots = await sotaFetcher.fetchNew()
                if !newSpots.isEmpty { sotaActive = true }
                for spot in newSpots { addSpot(spot) }
                try? await Task.sleep(for: .seconds(SOTAFetcher.pollInterval))
            }
        }

        potaTask = Task {
            while !Task.isCancelled {
                let newSpots = await potaFetcher.fetchNew()
                if !newSpots.isEmpty { potaActive = true }
                for spot in newSpots { addSpot(spot) }
                try? await Task.sleep(for: .seconds(POTAFetcher.pollInterval))
            }
        }

        wwffTask = Task {
            while !Task.isCancelled {
                let newSpots = await wwffFetcher.fetchNew()
                if !newSpots.isEmpty { wwffActive = true }
                for spot in newSpots { addSpot(spot) }
                try? await Task.sleep(for: .seconds(WWFFFetcher.pollInterval))
            }
        }
    }

    func disconnect() {
        client?.disconnect()
        propTask?.cancel()
        sotaTask?.cancel()
        potaTask?.cancel()
        wwffTask?.cancel()
    }

    /// Switch to a different cluster node mid-session.
    func reconnect(to node: ClusterNode) {
        clusterHost = node.host
        clusterPort = node.port
        disconnect()
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            connect(host: node.host, port: node.port)
        }
    }

    func resetFilters() {
        filterBand = "Alle"; filterMode = "Alle"; filterContinent = "Alle"
        showDX = true; showSOTA = true; showPOTA = true; showWWFF = true
        searchText = ""
    }

    /// Send a DX spot to the connected cluster node.
    func sendSpot(freq: Double, call: String, comment: String) {
        let cmd = "DX \(String(format: "%.1f", freq)) \(call.uppercased()) \(comment)"
        client?.sendCommand(cmd)
    }

    // MARK: - Private

    private func addSpot(_ spot: DXSpot) {
        spots.insert(spot, at: 0)
        if spots.count > 500 { spots.removeLast() }
    }

    private func appendLog(_ msg: String) {
        logMessages.append(msg)
        if logMessages.count > 200 { logMessages.removeFirst(10) }
    }
}
