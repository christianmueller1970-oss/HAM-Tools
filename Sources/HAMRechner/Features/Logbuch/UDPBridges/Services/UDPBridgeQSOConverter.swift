import Foundation

// Konvertiert ein protokoll-agnostisches `UDPBridgeQSOPayload` zusammen mit
// dem aktiven Log in ein `QSO`-Modell. Übernimmt typ-spezifische Log-Felder
// (POTA → myPotaRef, SOTA → mySotaRef, …) — analog zum existierenden
// WsjtxQSOConverter, aber input-agnostisch zwischen WSJT-X-Familie und
// N1MM.
enum UDPBridgeQSOConverter {

    static func qso(from payload: UDPBridgeQSOPayload, into log: Log) -> QSO {
        let freqMHz: Double = payload.frequencyMHz ?? 0
        let mode = payload.mode.uppercased()
        let rstSent = payload.rstSent?.nilIfEmpty ?? defaultRST(for: mode)
        let rstRecv = payload.rstReceived?.nilIfEmpty ?? defaultRST(for: mode)

        // Bei Outdoor-Aktivierungen ist Log.usedCallsign der authoritative
        // Activator-Call. Logger können mid-session umkonfiguriert werden
        // (Home-Call vs. /P) und schicken dann gemischte my_call-Werte —
        // Outdoor-Logs sehen den Log-Override darum vor.
        let activatorOverride: String? = {
            switch log.type {
            case .pota, .sota, .wwff, .bota:
                if let c = log.usedCallsign?.trimmingCharacters(in: .whitespaces),
                   !c.isEmpty {
                    return c.uppercased()
                }
                return nil
            case .standard, .contest:
                return nil
            }
        }()
        let resolvedOperator = activatorOverride
            ?? payload.operatorCall ?? payload.stationCall
        let resolvedStation = activatorOverride ?? payload.stationCall

        var qso = QSO(
            logID: log.id,
            call: payload.call.uppercased(),
            datetime: payload.datetime,
            frequencyMHz: freqMHz,
            band: payload.band,
            mode: mode,
            rstSent: rstSent,
            rstReceived: rstRecv,
            name: payload.name?.nilIfEmpty,
            locator: payload.grid?.nilIfEmpty,
            comment: payload.comment?.nilIfEmpty,
            operatorCall: resolvedOperator,
            stationCall: resolvedStation
        )

        switch log.type {
        case .pota:
            qso.myPotaRef  = log.potaParkRef
            qso.myPotaRefs = log.potaParkRefs
        case .sota:
            qso.mySotaRef  = log.sotaSummitRef
            qso.mySotaRefs = log.sotaSummitRefs
        case .wwff:
            qso.myWwffRef  = log.wwffRef
            qso.myWwffRefs = log.wwffRefs
        case .bota:
            qso.myBotaRef  = log.botaRef
            qso.myBotaRefs = log.botaRefs
        case .contest:
            qso.contest = log.contestID
            qso.contestExchangeSent = payload.contestExchangeSent?.nilIfEmpty
            qso.contestExchangeRecv = payload.contestExchangeRecv?.nilIfEmpty
        case .standard:
            break
        }
        return qso
    }

    private static func defaultRST(for mode: String) -> String {
        switch mode.uppercased() {
        case "CW", "RTTY", "PSK", "PSK31", "PSK63", "OLIVIA", "MFSK":
            return "599"
        case "FT8", "FT4", "JT65", "JT9", "JT4", "MSK144", "Q65":
            return "-15"
        default:
            return "59"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let s = trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? nil : s
    }
}
