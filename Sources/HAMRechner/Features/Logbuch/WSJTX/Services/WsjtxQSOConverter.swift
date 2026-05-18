import Foundation

// Wandelt eine WSJT-X QSOLogged-Message in unser QSO-Modell um. Übernimmt
// Frequenz-/Band-Mapping und schreibt typ-spezifische Felder aus dem aktiven
// Log mit (POTA → myPotaRef/myPotaRefs, Contest → contestID + Exchange-Felder).
enum WsjtxQSOConverter {

    static func qso(from msg: WsjtxQSOLogged, into log: Log) -> QSO {
        let freqMHz = msg.txFrequencyMHz
        let band = HamBand.from(frequencyMHz: freqMHz)?.rawValue ?? ""

        // Mode normalisieren: WSJT-X sendet z.B. "FT8" / "FT4" / "JT65".
        // Manche Sub-Modes kommen über das Mode-Feld direkt; wir nehmen es 1:1.
        let mode = msg.mode.uppercased()

        // RST-Reports: WSJT-X-Reports sind Signal-Reports im SNR-Format
        // (z.B. "-12"). Das ist ADIF-konform für RST_SENT/RST_RCVD bei FT8.
        let rstSent = msg.reportSent.isEmpty ? defaultRST(for: mode) : msg.reportSent
        let rstRecv = msg.reportReceived.isEmpty ? defaultRST(for: mode) : msg.reportReceived

        // Power: WSJT-X sendet als String ("5", "100"). Wenn parsebar als
        // Double, übernehmen — sonst leer lassen.
        let power: Double? = Double(msg.txPower.trimmingCharacters(in: .whitespaces))

        // Bei Outdoor-Aktivierungen ist Log.usedCallsign der authoritative
        // Activator-Call. WSJT-X kann mid-session umkonfiguriert werden
        // (Home-Call vs. /P) und schickt dann gemischte my_call-Werte, was
        // pota.app & Co. als "Only a single STATION_CALLSIGN" ablehnen.
        // Outdoor-Logs sehen den Log-Override darum vor — Standard/Contest
        // benutzen weiter den WSJT-X-Originalwert.
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
            ?? msg.operatorCall.nilIfEmpty ?? msg.myCall.nilIfEmpty
        let resolvedStation = activatorOverride ?? msg.myCall.nilIfEmpty

        var qso = QSO(
            logID: log.id,
            call: msg.dxCall,
            datetime: msg.dateTimeOff,
            frequencyMHz: freqMHz,
            band: band,
            mode: mode,
            rstSent: rstSent,
            rstReceived: rstRecv,
            name: msg.name.nilIfEmpty,
            locator: msg.dxGrid.nilIfEmpty,
            comment: msg.comments.nilIfEmpty,
            operatorCall: resolvedOperator,
            stationCall: resolvedStation,
            powerW: power
        )

        // Typ-spezifische Erweiterungen aus dem aktiven Log. SOTA und WWFF
        // füllen ihre My-Refs analog POTA — bei FT8/FT4 vom Berg/Park aus
        // ist das genau der typische Use-Case.
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
            qso.contestExchangeSent = msg.exchangeSent.nilIfEmpty
            qso.contestExchangeRecv = msg.exchangeReceived.nilIfEmpty

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
