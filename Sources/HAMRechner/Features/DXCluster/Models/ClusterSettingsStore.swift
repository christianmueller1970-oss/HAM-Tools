import Foundation

final class ClusterSettingsStore: ObservableObject {
    @Published var nodes: [ClusterNode] = [] {
        didSet { save() }
    }
    @Published var activeNodeID: UUID? {
        didSet {
            UserDefaults.standard.set(activeNodeID?.uuidString, forKey: "activeClusterID")
        }
    }

    var activeNode: ClusterNode? {
        nodes.first { $0.id == activeNodeID } ?? nodes.first
    }

    init() {
        load()
        if let str = UserDefaults.standard.string(forKey: "activeClusterID"),
           let id  = UUID(uuidString: str),
           nodes.contains(where: { $0.id == id }) {
            activeNodeID = id
        } else {
            activeNodeID = nodes.first?.id
        }
    }

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
            ClusterNode(name: "DXSpider Funkwelt", host: "dxspider.funkwelt.net", port: 7300, autoConnect: true),
            ClusterNode(name: "HB9W DX-Cluster",   host: "cluster.hb9w.ch",       port: 7300),
            ClusterNode(name: "DB0ERF Erlangen",   host: "db0erf.db0erft.de",     port: 7300),
            ClusterNode(name: "DX.OE5TXF",         host: "dx.oe5txf.at",          port: 7300),
            ClusterNode(name: "ON0ANT Antwerpen",  host: "on0ant.on4hs.net",      port: 7300),
            ClusterNode(name: "VE7CC Vancouver",   host: "dxc.ve7cc.net",         port: 23),
        ]
    }
}
