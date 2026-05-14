import Foundation

// Domain-Modelle für das WSJT-X UDP-Protokoll. Nur die Message-Typen, die
// wir für HAM-Tools wirklich auswerten. Wire-Format-Decode → WsjtxProtocolDecoder.
//
// Quelle: WSJT-X Source `Network/NetworkMessage.hpp` (Schema 2/3).
// Magic 0xADBCCBDA, Big-Endian Qt-QDataStream.

enum WsjtxMessageType: UInt32 {
    case heartbeat   = 0
    case status      = 1
    case decode      = 2
    case clear       = 3
    case reply       = 4
    case qsoLogged   = 5
    case close       = 6
    case replay      = 7
    case haltTx      = 8
    case freeText    = 9
    case wsprDecode  = 10
    case location    = 11
    case loggedAdif  = 12
}

enum WsjtxMessage {
    case heartbeat(WsjtxHeartbeat)
    case status(WsjtxStatus)
    case qsoLogged(WsjtxQSOLogged)
    case close(id: String)
    case unhandled(type: UInt32, id: String)
}

struct WsjtxHeartbeat: Equatable {
    let id: String              // WSJT-X Instance-Id (üblich: "WSJT-X")
    let maxSchema: UInt32
    let version: String
    let revision: String
}

struct WsjtxStatus: Equatable {
    let id: String
    let dialFrequencyHz: UInt64
    let mode: String
    let dxCall: String
    let report: String
    let txMode: String
    let txEnabled: Bool
    let transmitting: Bool
    let decoding: Bool
    let rxDF: UInt32
    let txDF: UInt32
    let deCall: String
    let deGrid: String
    let dxGrid: String
    let txWatchdog: Bool
    let subMode: String
    let fastMode: Bool
    let specialOpMode: UInt8
}

struct WsjtxQSOLogged: Equatable {
    let id: String
    let dateTimeOff: Date
    let dxCall: String
    let dxGrid: String
    let txFrequencyHz: UInt64
    let mode: String
    let reportSent: String
    let reportReceived: String
    let txPower: String
    let comments: String
    let name: String
    let dateTimeOn: Date
    let operatorCall: String
    let myCall: String
    let myGrid: String
    let exchangeSent: String
    let exchangeReceived: String
    let propagationMode: String

    var txFrequencyMHz: Double { Double(txFrequencyHz) / 1_000_000 }
}
