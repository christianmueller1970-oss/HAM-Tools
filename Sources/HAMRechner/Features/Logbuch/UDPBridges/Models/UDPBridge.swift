import Foundation

// Protokoll-Auswahl für einen UDP-Bridge-Listener.
//
// `wsjtxCompatible` deckt WSJT-X, JTDX, JS8Call und MSHV ab — alle vier
// reden das gleiche Binär-Protokoll (NetworkMessage), nur die Default-Ports
// und QSO-Logged-Ausprägungen unterscheiden sich minimal.
//
// `n1mmContestUDP` ist N1MM-Logger-Plus' XML-Broadcast: ContactInfo (QSOs)
// + SpotInfo (Spotter-Eingaben). Andere Pakete (RadioInfo, ScoreUpdate,
// LookupInfo, ContactReplace, ContactDelete) werden geparst aber stillschweigend
// verworfen, weil sie für den Standard-Loggermode keinen Mehrwert bieten.
enum UDPBridgeProtocol: String, Codable, CaseIterable, Identifiable {
    case wsjtxCompatible    = "wsjtx"
    case n1mmContestUDP     = "n1mm"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wsjtxCompatible: return "WSJT-X / JTDX / JS8Call / MSHV"
        case .n1mmContestUDP:  return "N1MM Logger+ (Contest)"
        }
    }

    var shortName: String {
        switch self {
        case .wsjtxCompatible: return "WSJT-X-Familie"
        case .n1mmContestUDP:  return "N1MM"
        }
    }

    /// Default-Port-Vorschlag beim Anlegen einer neuen Bridge mit diesem
    /// Protokoll. WSJT-X = 2237, N1MM = 12060.
    var defaultPort: UInt16 {
        switch self {
        case .wsjtxCompatible: return 2237
        case .n1mmContestUDP:  return 12060
        }
    }
}

/// Ein einzelner UDP-Listener-Eintrag mit Port + Protokoll-Adapter.
struct UDPBridge: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var port: UInt16
    var enabled: Bool
    var bridgeProtocol: UDPBridgeProtocol

    init(id: UUID = UUID(),
         name: String,
         port: UInt16,
         enabled: Bool = false,
         bridgeProtocol: UDPBridgeProtocol) {
        self.id = id
        self.name = name
        self.port = port
        self.enabled = enabled
        self.bridgeProtocol = bridgeProtocol
    }
}

/// Event, das ein Adapter aus einem Datagramm extrahiert. Der
/// UDPBridgesService routet das je nach Typ in den LogbookManager oder
/// in den DXClusterViewModel.
enum UDPBridgeEvent: Equatable {
    /// Vom Logger gemeldetes QSO. Konvertierung in `QSO` passiert im
    /// Service-Layer (braucht das aktive Log).
    case qsoLogged(UDPBridgeQSOPayload)

    /// Spotter-Eingabe (z.B. N1MM-Bandmap → Spot). Wird in den DX-Cluster-
    /// Stream gespeist mit Quelle als „N1MM" o.ä.
    case spot(UDPBridgeSpotPayload)

    /// Heartbeat / Verbindung lebt — Status-Display, kein Logger-Effekt.
    case heartbeat(version: String?)

    /// Logger meldet sich ab.
    case close
}

struct UDPBridgeQSOPayload: Equatable {
    var call: String
    var datetime: Date
    var band: String
    var mode: String
    var frequencyMHz: Double?
    var rstSent: String?
    var rstReceived: String?
    var grid: String?
    var name: String?
    var comment: String?
    var contestExchangeSent: String?
    var contestExchangeRecv: String?
    var operatorCall: String?
    var stationCall: String?
    var myGrid: String?
}

struct UDPBridgeSpotPayload: Equatable {
    var dxCall: String
    var spotterCall: String
    var freqKHz: Double
    var comment: String
    var sourceTag: String   // z.B. „N1MM"
    var time: Date
}
