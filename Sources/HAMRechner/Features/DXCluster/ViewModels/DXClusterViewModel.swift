import Foundation
import SwiftUI
import Combine

@MainActor
final class DXClusterViewModel: ObservableObject {
    // MARK: - Data
    @Published var spots:         [DXSpot] = []
    @Published var logMessages:   [String] = []
    @Published var propagation    = PropagationData()

    /// Status pro aktivem Cluster-Node (Multi-Connect-Pool, max 3).
    /// `clusterStatus` (Computed) aggregiert daraus den Gesamt-Status für
    /// alle Top-Bars und Status-Indikatoren — siehe unten.
    @Published private(set) var statusByNode: [UUID: ClusterClient.Status] = [:]

    /// Aggregierter Status für die UI. „Verbunden" sobald mind. 1 Pool-Member
    /// connected ist; „Fehler" nur wenn alle in .error sind.
    var clusterStatus: ClusterClient.Status {
        let states = Array(statusByNode.values)
        if states.contains(.connected)  { return .connected }
        if states.contains(.loggingIn)  { return .loggingIn }
        if states.contains(.connecting) { return .connecting }
        if !states.isEmpty, states.allSatisfy({ $0 == .error }) { return .error }
        return .disconnected
    }

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
    /// Multi-Connect-Pool: ein ClusterClient pro aktivem Node. Wird via
    /// `applyActiveNodes()` mit `ClusterSettingsStore.activeNodes` in Sync
    /// gehalten — Toggle in den Settings öffnet/schließt den jeweiligen
    /// Client live (über die Combine-Subscription auf `$nodes`).
    private var clients: [UUID: ClusterClient] = [:]
    private var clusterStore: ClusterSettingsStore?
    private var storeObserver: AnyCancellable?

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

    func setup(watchStore: WatchListStore? = nil,
               clusterStore: ClusterSettingsStore? = nil) {
        if let ws = watchStore { self.watchStore = ws }
        if let cs = clusterStore, self.clusterStore !== cs {
            self.clusterStore = cs
            // Live-Sync: jeder Settings-Toggle (Aktiv-Checkbox) führt sofort
            // zum Öffnen/Schließen der jeweiligen Cluster-Verbindung. Erste
            // Lieferung wird via dropFirst geschluckt — `connect()` macht
            // den initialen Pool-Aufbau.
            storeObserver = cs.$nodes
                .dropFirst()
                .sink { [weak self] _ in
                    Task { @MainActor in self?.applyActiveNodes() }
                }
        }
        guard !didSetup else { return }
        didSetup = true
        let loaded = SpotPersistence.load()
        spots = loaded
        if !loaded.isEmpty {
            appendLog("[DB] \(loaded.count) gespeicherte Spots geladen")
        }
    }

    // MARK: - Lifecycle

    /// Öffnet den Multi-Cluster-Pool (alle in den Settings aktivierten Nodes,
     /// max `ClusterSettingsStore.maxActiveNodes`) und startet die externen
    /// Spot-Fetcher (SOTA/POTA/WWFF + Propagation).
    ///
    /// Die Args `host/port/name` werden ignoriert — sie blieben für Aufrufer
    /// stehen, die den alten Single-Connect kannten. Maßgeblich ist seit dem
    /// Multi-Cluster-Refactor allein der `ClusterSettingsStore`.
    func connect(host: String? = nil, port: Int? = nil, name: String? = nil) {
        applyActiveNodes()

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
        for (_, c) in clients { c.disconnect() }
        clients.removeAll()
        statusByNode.removeAll()
        propTask?.cancel()
        sotaTask?.cancel()
        potaTask?.cancel()
        wwffTask?.cancel()
    }

    /// Bringt den Pool in Einklang mit `clusterStore.activeNodes` — schließt
    /// Clients, deren Node nicht mehr aktiv ist, öffnet Clients für neu
    /// hinzugekommene und startet Clients neu, deren Host/Port sich
    /// geändert hat. Idempotent.
    func applyActiveNodes() {
        guard let store = clusterStore else { return }
        let desired = Set(store.activeNodes.map { $0.id })

        // (1) Trenne, was nicht mehr aktiv ist
        for id in Set(clients.keys).subtracting(desired) {
            clients[id]?.disconnect()
            clients.removeValue(forKey: id)
            statusByNode.removeValue(forKey: id)
        }

        // (2) Field-Diff für bereits offene Clients: bei Host- oder Port-
        // Änderung den alten Client schließen, damit Step (3) ihn mit den
        // neuen Werten neu öffnet. Name-Only-Edits triggern keinen
        // Reconnect (sonst kickt der Cluster bei jeder Umbenennung).
        for node in store.activeNodes {
            guard let existing = clients[node.id] else { continue }
            if existing.host != node.host || existing.port != UInt16(node.port) {
                existing.disconnect()
                clients.removeValue(forKey: node.id)
                statusByNode.removeValue(forKey: node.id)
            }
        }

        // (3) Öffne, was neu oder gerade neu zu öffnen ist
        for node in store.activeNodes where !clients.keys.contains(node.id) {
            let id = node.id
            let client = ClusterClient(host: node.host,
                                       port: UInt16(node.port),
                                       callsign: storedCallsign,
                                       name: node.name)
            client.onSpot    = { [weak self] spot in self?.addSpot(spot) }
            client.onStatus  = { [weak self] s in
                Task { @MainActor in self?.statusByNode[id] = s }
            }
            client.onMessage = { [weak self] m in
                Task { @MainActor in self?.appendLog(m) }
            }
            clients[id] = client
            statusByNode[id] = .disconnected
            client.connect()
        }
    }

    /// Bleibt als Compat für das Cluster-Menü im Logbuch-Header — wir
    /// triggern einfach einen Pool-Resync, der Store ist die Wahrheit.
    func reconnect(to node: ClusterNode) {
        applyActiveNodes()
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
        primaryClient()?.sendCommand(cmd)
    }

    /// Generisches Senden eines beliebigen Cluster-Befehls. Wird vom
    /// Cluster-Terminal-Fenster genutzt. Antworten landen über onMessage
    /// im logMessages-Buffer; falls Spots zurückkommen (z.B. nach "sh/dx"),
    /// parst der ClusterClient sie wie Live-Feed-Spots und fügt sie der
    /// globalen Spot-Liste hinzu — automatisch.
    func sendCommand(_ cmd: String) {
        let trimmed = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        primaryClient()?.sendCommand(trimmed)
    }

    /// Primary-Client für Send-Commands (DX-Spot, sh/dx, …): der erste
    /// aktive Node aus der Settings-Reihenfolge. Verhindert, dass der
    /// gleiche Send-Befehl aus 3 Clusters parallel rausgeht.
    private func primaryClient() -> ClusterClient? {
        if let store = clusterStore {
            for node in store.activeNodes {
                if let c = clients[node.id] { return c }
            }
        }
        return clients.values.first
    }

    // MARK: - Private

    private func addSpot(_ spot: DXSpot) {
        // Multi-Cluster-Dedup: derselbe DX-Spot wird typischerweise von
        // mehreren Clusters innerhalb weniger Sekunden gepusht (RBN-Hub
        // ist global). Wir vergleichen Call + Frequenz (auf 0.1 kHz
        // gerundet) gegen die letzten 60 s. Bei Match → bestehenden Spot
        // mit der zusätzlichen Quelle anreichern (alsoSeenBy), nicht neu
        // einfügen. UI rendert daraus ein „+N"-Confidence-Badge.
        let call = spot.dxCall.uppercased()
        let freq = (spot.frequency * 10).rounded() / 10
        let cutoff = Date().addingTimeInterval(-60)
        if let i = spots.firstIndex(where: { existing in
            existing.timestamp >= cutoff
                && existing.dxCall.uppercased() == call
                && ((existing.frequency * 10).rounded() / 10) == freq
        }) {
            let primary = spots[i].source
            let newSource = spot.source
            if !newSource.isEmpty,
               newSource != primary,
               !spots[i].alsoSeenBy.contains(newSource) {
                spots[i].alsoSeenBy.append(newSource)
            }
            return
        }

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
        // 2000 Lines Ring-Buffer — reichlich für Cluster-Terminal-History.
        // Bei average 80 Bytes/Line ~160kB; kompletter Trim alle ~200 Adds.
        if logMessages.count > 2000 { logMessages.removeFirst(200) }
    }

    private func savePending() {
        guard unsavedCount > 0 else { return }
        SpotPersistence.save(spots)
        unsavedCount = 0
    }
}
