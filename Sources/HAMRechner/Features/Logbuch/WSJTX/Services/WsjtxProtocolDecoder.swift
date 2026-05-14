import Foundation

// Wire-Format-Decoder für das WSJT-X UDP-Protokoll. Big-Endian Qt-Stream
// (QDataStream Version 12+). Strings sind UTF8 mit 4-Byte-Length-Prefix —
// 0xFFFFFFFF bedeutet "null/empty". QDateTime: qint64 Julian Day + quint32
// ms-since-midnight + quint8 timespec (1=UTC, hier immer 1).

enum WsjtxDecodeError: Error {
    case shortRead
    case badMagic(UInt32)
    case unsupportedSchema(UInt32)
    case unsupportedTimeSpec(UInt8)
}

struct WsjtxProtocolDecoder {

    static let magic: UInt32 = 0xADBCCBDA

    // Versucht ein Datagramm zu dekodieren. Unbekannte Typen werden als
    // `.unhandled` zurückgegeben statt zu werfen, damit ein unerwartetes
    // Message-Typ-Update von WSJT-X die Bridge nicht in den Fehler zwingt.
    static func decode(_ data: Data) throws -> WsjtxMessage {
        var r = Reader(data: data)
        let magic = try r.readUInt32()
        guard magic == Self.magic else { throw WsjtxDecodeError.badMagic(magic) }
        let schema = try r.readUInt32()
        guard schema == 2 || schema == 3 else {
            throw WsjtxDecodeError.unsupportedSchema(schema)
        }
        let typeRaw = try r.readUInt32()
        let id = try r.readUtf8()

        switch WsjtxMessageType(rawValue: typeRaw) {

        case .heartbeat:
            let maxSchema = try r.readUInt32()
            let version   = try r.readUtf8()
            let revision  = try r.readUtf8()
            return .heartbeat(WsjtxHeartbeat(
                id: id, maxSchema: maxSchema,
                version: version, revision: revision))

        case .status:
            let dial     = try r.readUInt64()
            let mode     = try r.readUtf8()
            let dxCall   = try r.readUtf8()
            let report   = try r.readUtf8()
            let txMode   = try r.readUtf8()
            let txEn     = try r.readBool()
            let tx       = try r.readBool()
            let dec      = try r.readBool()
            let rxDF     = try r.readUInt32()
            let txDF     = try r.readUInt32()
            let deCall   = try r.readUtf8()
            let deGrid   = try r.readUtf8()
            let dxGrid   = try r.readUtf8()
            let watchdog = try r.readBool()
            let subMode  = try r.readUtf8()
            let fast     = try r.readBool()
            let special  = try r.readUInt8()
            return .status(WsjtxStatus(
                id: id,
                dialFrequencyHz: dial, mode: mode, dxCall: dxCall,
                report: report, txMode: txMode,
                txEnabled: txEn, transmitting: tx, decoding: dec,
                rxDF: rxDF, txDF: txDF,
                deCall: deCall, deGrid: deGrid, dxGrid: dxGrid,
                txWatchdog: watchdog, subMode: subMode,
                fastMode: fast, specialOpMode: special))

        case .qsoLogged:
            let dtOff      = try r.readQDateTime()
            let dxCall     = try r.readUtf8()
            let dxGrid     = try r.readUtf8()
            let txFreq     = try r.readUInt64()
            let mode       = try r.readUtf8()
            let rstSent    = try r.readUtf8()
            let rstRecv    = try r.readUtf8()
            let txPower    = try r.readUtf8()
            let comments   = try r.readUtf8()
            let name       = try r.readUtf8()
            let dtOn       = try r.readQDateTime()
            let opCall     = try r.readUtf8()
            let myCall     = try r.readUtf8()
            let myGrid     = try r.readUtf8()
            let exSent     = try r.readUtf8()
            let exRecv     = try r.readUtf8()
            let propMode   = try r.readUtf8()
            return .qsoLogged(WsjtxQSOLogged(
                id: id, dateTimeOff: dtOff,
                dxCall: dxCall, dxGrid: dxGrid,
                txFrequencyHz: txFreq, mode: mode,
                reportSent: rstSent, reportReceived: rstRecv,
                txPower: txPower, comments: comments, name: name,
                dateTimeOn: dtOn,
                operatorCall: opCall, myCall: myCall, myGrid: myGrid,
                exchangeSent: exSent, exchangeReceived: exRecv,
                propagationMode: propMode))

        case .close:
            return .close(id: id)

        default:
            return .unhandled(type: typeRaw, id: id)
        }
    }

    // MARK: - Reader

    private struct Reader {
        let data: Data
        var offset: Int = 0

        mutating func require(_ n: Int) throws {
            guard offset + n <= data.count else {
                throw WsjtxDecodeError.shortRead
            }
        }

        mutating func readUInt8() throws -> UInt8 {
            try require(1)
            let v = data[data.startIndex + offset]
            offset += 1
            return v
        }

        mutating func readUInt32() throws -> UInt32 {
            try require(4)
            var v: UInt32 = 0
            for i in 0..<4 {
                v = (v << 8) | UInt32(data[data.startIndex + offset + i])
            }
            offset += 4
            return v
        }

        mutating func readUInt64() throws -> UInt64 {
            try require(8)
            var v: UInt64 = 0
            for i in 0..<8 {
                v = (v << 8) | UInt64(data[data.startIndex + offset + i])
            }
            offset += 8
            return v
        }

        mutating func readInt64() throws -> Int64 {
            try Int64(bitPattern: readUInt64())
        }

        mutating func readBool() throws -> Bool {
            try readUInt8() != 0
        }

        // UTF8-QString: 4-Byte BE Length, 0xFFFFFFFF = null/empty.
        mutating func readUtf8() throws -> String {
            let len = try readUInt32()
            if len == 0xFFFF_FFFF { return "" }
            if len == 0 { return "" }
            try require(Int(len))
            let start = data.startIndex + offset
            let bytes = data[start..<(start + Int(len))]
            offset += Int(len)
            return String(data: bytes, encoding: .utf8) ?? ""
        }

        // QDateTime: qint64 Julian-Day · quint32 ms-since-midnight · quint8 spec.
        // spec=0 local, 1 UTC, 2 offset (+ qint32 offsetSec), 3 tz (+ QByteArray).
        // WSJT-X verschickt durchgehend UTC (spec=1).
        mutating func readQDateTime() throws -> Date {
            let jd  = try readInt64()
            let ms  = try readUInt32()
            let spec = try readUInt8()
            let offsetSec: Int32
            switch spec {
            case 0, 1:           offsetSec = 0
            case 2:              offsetSec = Int32(bitPattern: try readUInt32())
            default:             throw WsjtxDecodeError.unsupportedTimeSpec(spec)
            }
            // Julian-Day 2440588 entspricht 1970-01-01 00:00 UTC (Unix-Epoch).
            // Sekunden seit Epoch = (jd - 2440588) * 86400 + ms/1000 − offsetSec.
            let secondsSinceEpoch =
                Double(jd - 2_440_588) * 86_400
                + Double(ms) / 1000
                - Double(offsetSec)
            return Date(timeIntervalSince1970: secondsSinceEpoch)
        }
    }
}
