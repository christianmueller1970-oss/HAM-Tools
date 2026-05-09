import Foundation

struct ClusterNode: Identifiable, Codable, Equatable {
    var id   = UUID()
    var name: String
    var host: String
    var port: Int
    var autoConnect: Bool

    init(name: String, host: String, port: Int = 7300, autoConnect: Bool = false) {
        self.name        = name
        self.host        = host
        self.port        = port
        self.autoConnect = autoConnect
    }
}
