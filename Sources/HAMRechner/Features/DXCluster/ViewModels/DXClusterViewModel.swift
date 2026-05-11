import Foundation
import SwiftUI

@MainActor
final class DXClusterViewModel: ObservableObject {
    // MARK: - Data
    @Published var spots:         [DXSpot] = []
    @Published var logMessages:   [String] = []
    @Published var propagation    = PropagationData()
    @Published var clusterStatus: ClusterClient.Status = .disconnected

    // MARK: - API status (true = reached at least once)
    @Published var sotaActive = false
    @Published var potaActive = false
    @Published var wwffActive = false

    // MARK: - Filter state (persistiert in UserDefaults)
    // Defaults: nur DXSpider an, SOTA/POTA/WWFF aus — User-Wunsch.
    @Published var filterBand:      String = UserDefaults.standard.string(forKey: "cluster.filterBand") ?? "Alle" {
        didSet { UserDefaults.standard.set(filterBand, forKey: "cluster.filterBand") }
    }
    @Published var filterMode:      String = UserDefaults.standard.string(forKey: "cluster.filterMode") ?? "Alle" {
        didSet { UserDefaults.standard.set(filterMode, forKey: "cluster.filterMode") }
    }
    @Published var filterContinent: String = UserDefaults.standard.string(forKey: "cluster.filterContinent") ?? "Alle" {
        didSet { UserDefaults.standard.set(filterContinent, forKey: "cluster.filterContinent") }
    }
    @Published var showDX:   Bool = UserDefaults.standard.object(forKey: "cluster.showDX")   as? Bool ?? true  {
        didSet { UserDefaults.standard.set(showDX,   forKey: "cluster.showDX") }
    }
    @Published var showSOTA: Bool = UserDefaults.standard.object(forKey: "cluster.showSOTA") as? Bool ?? false {
        didSet { UserDefaults.standard.set(showSOTA, forKey: "cluster.showSOTA") }
    }
    @Published var showPOTA: Bool = UserDefaults.standard.object(forKey: "cluster.showPOTA") as? Bool ?? false {
        didSet { UserDefaults.standard.set(showPOTA, forKey: "cluster.showPOTA") }
    }
    @Published var showWWFF: Bool = UserDefaults.standard.object(forKey: "cluster.showWWFF") as? Bool ?? false {
        didSet { UserDefaults.standard.set(showWWFF, forKey: "cluster.showWWFF") }
    }
    @Published var searchText: String = UserDefaults.standard.string(forKey: "cluster.searchText") ?? "" {
        didSet { UserDefaults.standard.set(searchText, forKey: "cluster.searchText") }
    }
    @Published var spotterRadiusKm: Int = UserDefaults.standard.integer(forKey: "cluster.spotterRadiusKm") {
        didSet { UserDefaults.standard.set(spotterRadiusKm, forKey: "cluster.spotterRadiusKm") }
    }

    // MARK: - Settings (persisted)
    @AppStorage("callsign")    private var storedCallsign = "HB9HJI"
    @AppStorage("qthLocator")  private var qthLocator     = "JN47PN"
    @AppStorage("clusterHost") private var clusterHost    = "dxspider.funkwelt.net"
    @AppStorage("clusterPort") private var clusterPort    = 7300
    @AppStorage("alertCooldownMin") private var alertCooldownMin = 15

    var myCallsign: String { storedCallsign }

    // MARK: - Watch list
    var watchStore: WatchListStore?
    @Published var alertCount = 0
    private var lastNotifiedAt: [String: Date] = [:]

    // MARK: - Persistence
    private var didSetup     = false
    private var unsavedCount = 0

    // MARK: - Network
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
        let myPos: (lat: Double, lon: Double)? = spotterRadiusKm > 0
            ? locatorToLatLon(qthLocator)
            : nil

        return spots.filter { spot in
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
            if let pos = myPos, spot.spotterLat != 0 || spot.spotterLon != 0 {
                let dist = haversineKm(lat1: pos.lat, lon1: pos.lon,
                                       lat2: spot.spotterLat, lon2: spot.spotterLon)
                if dist > Double(spotterRadiusKm) { return false }
            }
            return true
        }
    }

    var spotCount: Int { filteredSpots.count }

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

    // MARK: - Persistence setup (einmalig aus DXClusterView.onAppear)

    func setup(watchStore: WatchListStore? = nil) {
        if let ws = watchStore { self.watchStore = ws }
        guard !didSetup else { return }
        didSetup = true
        let loaded = SpotPersistence.load()
        spots = loaded
        if !loaded.isEmpty {
            appendLog("[DB] \(loaded.count) gespeicherte Spots geladen")
        }
    }

    // MARK: - Lifecycle

    func connect(host: String? = nil, port: Int? = nil, name: String? = nil) {
        let h    = host ?? clusterHost
        let p    = UInt16(port ?? clusterPort)
        let call = storedCallsign
        let n    = name ?? h

        client = ClusterClient(host: h, port: p, callsign: call, name: n)
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
        savePending()
        client?.disconnect()
        propTask?.cancel()
        sotaTask?.cancel()
        potaTask?.cancel()
        wwffTask?.cancel()
    }

    func reconnect(to node: ClusterNode) {
        clusterHost = node.host
        clusterPort = node.port
        disconnect()
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            connect(host: node.host, port: node.port, name: node.name)
        }
    }

    func resetFilters() {
        filterBand = "Alle"; filterMode = "Alle"; filterContinent = "Alle"
        showDX = true; showSOTA = true; showPOTA = true; showWWFF = true
        searchText = ""; spotterRadiusKm = 0
    }

    func clearSpots() {
        spots = []
        unsavedCount = 0
        SpotPersistence.save([])
        lastNotifiedAt.removeAll()
        alertCount = 0
        appendLog("[INFO] Spot-Liste geleert")
    }

    func sendSpot(freq: Double, call: String, comment: String) {
        let cmd = "DX \(String(format: "%.1f", freq)) \(call.uppercased()) \(comment)"
        client?.sendCommand(cmd)
    }

    // MARK: - Private

    private func addSpot(_ spot: DXSpot) {
        spots.insert(spot, at: 0)
        if spots.count > SpotPersistence.maxSpots { spots.removeLast() }
        unsavedCount += 1
        if unsavedCount >= 25 { savePending() }

        guard let ws = watchStore, let reason = ws.matches(spot: spot) else { return }
        alertCount += 1

        // Cooldown-Key: Call+Reason (Call-Watch und DXCC-Watch separat zählen)
        let key: String
        switch reason {
        case .call:           key = "call:\(spot.dxCall.uppercased())"
        case .dxcc(let c):    key = "dxcc:\(c)|\(spot.dxCall.uppercased())"
        }
        let cooldown = Double(max(1, alertCooldownMin)) * 60
        if let last = lastNotifiedAt[key], Date().timeIntervalSince(last) < cooldown {
            return  // noch im Cooldown — kein erneutes Notification
        }
        lastNotifiedAt[key] = Date()
        ws.sendNotification(for: spot, reason: reason)
    }

    private func appendLog(_ msg: String) {
        logMessages.append(msg)
        if logMessages.count > 200 { logMessages.removeFirst(10) }
    }

    private func savePending() {
        guard unsavedCount > 0 else { return }
        SpotPersistence.save(spots)
        unsavedCount = 0
    }
}
