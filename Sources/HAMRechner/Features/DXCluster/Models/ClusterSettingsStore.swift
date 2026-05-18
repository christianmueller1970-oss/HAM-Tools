import Foundation

final class ClusterSettingsStore: ObservableObject {
    /// Obergrenze für gleichzeitig aktive Cluster-Verbindungen (Multi-Cluster-
    /// Pool). Drei reichen für realistische Coverage (eigener + zwei Fallback);
    /// mehr machen die Spot-Liste eher unruhig als nützlicher.
    static let maxActiveNodes = 3

    @Published var nodes: [ClusterNode] = [] {
        didSet { save() }
    }
    @Published var activeNodeID: UUID? {
        didSet {
            UserDefaults.standard.set(activeNodeID?.uuidString, forKey: "activeClusterID")
        }
    }

    /// Alle für den Multi-Cluster-Pool ausgewählten Nodes, in Reihenfolge der
    /// `nodes`-Liste. `first` gilt als „primary" — dahin laufen sendCommand-
    /// und sendSpot-Aufrufe, sobald das Backend-Refactor steht.
    var activeNodes: [ClusterNode] {
        nodes.filter { $0.isActive }
    }

    /// Anzahl der aktuell aktiven Nodes — für UI-Anzeige „N/3 aktiv".
    var activeCount: Int { activeNodes.count }

    /// Single-Cluster-Compat: liefert den aktuell beworbenen Node oder
    /// fällt auf den ersten aktiven / ersten überhaupt zurück. Wird bis
    /// zum Multi-Client-Refactor noch vom DXClusterViewModel genutzt.
    var activeNode: ClusterNode? {
        if let id = activeNodeID, let n = nodes.first(where: { $0.id == id }) {
            return n
        }
        return activeNodes.first ?? nodes.first
    }

    init() {
        load()
        if let str = UserDefaults.standard.string(forKey: "activeClusterID"),
           let id  = UUID(uuidString: str),
           nodes.contains(where: { $0.id == id }) {
            activeNodeID = id
        } else {
            activeNodeID = activeNodes.first?.id ?? nodes.first?.id
        }
    }

    // MARK: - Multi-Cluster-Pool

    /// Toggle für die Aktiv-Checkbox in der Settings-Liste. Wird das
    /// `maxActiveNodes`-Limit gerissen, bleibt der State unverändert und
    /// die Methode liefert `false` zurück — die UI kann dann z.B. einen
    /// Hinweis anzeigen.
    @discardableResult
    func setActive(nodeID: UUID, active: Bool) -> Bool {
        guard let idx = nodes.firstIndex(where: { $0.id == nodeID }) else { return false }
        if active, !nodes[idx].isActive, activeCount >= Self.maxActiveNodes {
            return false
        }
        nodes[idx].isActive = active
        // Wenn der primary deaktiviert wurde, ersten aktiven nachziehen.
        if !active, activeNodeID == nodeID {
            activeNodeID = activeNodes.first?.id
        }
        return true
    }

    /// True wenn ein weiterer Node noch aktiviert werden könnte.
    var canActivateMore: Bool { activeCount < Self.maxActiveNodes }

    // MARK: - CRUD

    func add(_ node: ClusterNode) {
        nodes.append(node)
    }

    func remove(at offsets: IndexSet) {
        let removedIDs = offsets.map { nodes[$0].id }
        nodes.remove(atOffsets: offsets)
        if let active = activeNodeID, removedIDs.contains(active) {
            activeNodeID = nodes.first?.id
        }
    }

    func update(_ node: ClusterNode) {
        if let i = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[i] = node
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(nodes) {
            UserDefaults.standard.set(data, forKey: "clusterNodes")
        }
    }

    private func load() {
        if let data    = UserDefaults.standard.data(forKey: "clusterNodes"),
           let decoded = try? JSONDecoder().decode([ClusterNode].self, from: data),
           !decoded.isEmpty {
            nodes = decoded
            return
        }
        // Ship with a useful default list
        nodes = [
            ClusterNode(name: "DXSpider Funkwelt", host: "dxspider.funkwelt.net", port: 7300, isActive: true),
            ClusterNode(name: "HB9W DX-Cluster",   host: "cluster.hb9w.ch",       port: 7300),
            ClusterNode(name: "DB0ERF Erlangen",   host: "db0erf.db0erft.de",     port: 7300),
            ClusterNode(name: "DX.OE5TXF",         host: "dx.oe5txf.at",          port: 7300),
            ClusterNode(name: "ON0ANT Antwerpen",  host: "on0ant.on4hs.net",      port: 7300),
            ClusterNode(name: "VE7CC Vancouver",   host: "dxc.ve7cc.net",         port: 23),
        ]
    }
}
