import Foundation

// Adapter für die WSJT-X-Familie (WSJT-X, JTDX, JS8Call, MSHV). Nutzt den
// bestehenden `WsjtxProtocolDecoder` aus dem WSJTX-Modul und mappt die
// Messages auf das protokoll-agnostische `UDPBridgeEvent`-Modell.
enum WsjtxAdapter {

    static func decode(_ data: Data) -> UDPBridgeEvent? {
        guard let msg = try? WsjtxProtocolDecoder.decode(data) else {
            return nil
        }
        switch msg {
        case .heartbeat(let h):
            return .heartbeat(version: h.version.isEmpty ? nil : h.version)
        case .qsoLogged(let q):
            return .qsoLogged(payload(from: q))
        case .close:
            return .close
        case .status, .unhandled:
            // Status / Reply / Clear / Decode / Replay / Halt / FreeText /
            // WSPRDecode / Location / LoggedADIF — ignorieren, aber das
            // Heartbeat-Update läuft über den Datagramm-Counter im Listener.
            return .heartbeat(version: nil)
        }
    }

    private static func payload(from q: WsjtxQSOLogged) -> UDPBridgeQSOPayload {
        UDPBridgeQSOPayload(
            call: q.dxCall,
            datetime: q.dateTimeOff,
            band: HamBand.from(frequencyMHz: q.txFrequencyMHz)?.rawValue ?? "",
            mode: q.mode.uppercased(),
            frequencyMHz: q.txFrequencyMHz,
            rstSent: q.reportSent.isEmpty ? nil : q.reportSent,
            rstReceived: q.reportReceived.isEmpty ? nil : q.reportReceived,
            grid: q.dxGrid.isEmpty ? nil : q.dxGrid,
            name: q.name.isEmpty ? nil : q.name,
            comment: q.comments.isEmpty ? nil : q.comments,
            contestExchangeSent: q.exchangeSent.isEmpty ? nil : q.exchangeSent,
            contestExchangeRecv: q.exchangeReceived.isEmpty ? nil : q.exchangeReceived,
            operatorCall: q.operatorCall.isEmpty ? nil : q.operatorCall,
            stationCall: q.myCall.isEmpty ? nil : q.myCall,
            myGrid: q.myGrid.isEmpty ? nil : q.myGrid
        )
    }
}
