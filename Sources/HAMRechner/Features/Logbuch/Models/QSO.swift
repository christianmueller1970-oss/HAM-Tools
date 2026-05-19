import Foundation

struct QSO: Identifiable, Codable, Hashable {
    let id: UUID
    var logID: UUID                 // Foreign Key

    // Pflicht-Felder
    var call: String
    var datetime: Date
    var frequencyMHz: Double
    var band: String                // HamBand.rawValue
    var mode: String
    var rstSent: String
    var rstReceived: String

    // Standard-Optionalfelder
    var name: String?
    var qth: String?
    var locator: String?
    var country: String?
    var continent: String?
    var cqZone: Int?
    var ituZone: Int?
    var comment: String?
    var operatorCall: String?
    var stationCall: String?
    var powerW: Double?
    var antenna: String?

    // Contest (Phase 4)
    var contest: String?                // Template-ID (z.B. "HELVETIA", "CQ-WW-CW")
    var contestSerial: Int?             // eigener Serial (nil wenn Template keinen verlangt)
    var contestExchangeSent: String?    // voll formatierter sent-Exchange (z.B. "599 BE" oder "599 001")
    var contestExchangeRecv: String?    // voll formatierter recv-Exchange
    var contestExchange: String?        // Legacy: vor Etappe 1 das einzige Feld; bleibt zur Migration
    var contestIsRun: Bool?             // Etappe 2: Run vs S&P

    // POTA/SOTA (Phase 4c/4d)
    var myPotaRef: String?
    var myPotaRefs: String?
    var theirPotaRef: String?
    var mySotaRef: String?
    var mySotaRefs: String?
    var theirSotaRef: String?
    var theirSotaPoints: Int?
    var myWwffRef: String?
    var myWwffRefs: String?
    var theirWwffRef: String?
    var myBotaRef: String?
    var myBotaRefs: String?
    var theirBotaRef: String?

    // QSL (Phase 6)
    var qslSentDate: Date?
    var qslSentVia: String?
    var qslReceivedDate: Date?
    var qslReceivedVia: String?
    var lotwSent: Bool = false
    var lotwConfirmed: Bool = false
    var eqslSent: Bool = false
    var eqslConfirmed: Bool = false
    var clublogSent: Bool = false

    // QRZ Logbook Upload-Status (Phase 6, Schema v10):
    //   0 = nicht versucht
    //   1 = OK (akzeptiert)
    //   2 = duplicate (war bereits in QRZ — User-seitig wie 1 zu behandeln)
    //   3 = fail (auth, network, sonstige Fehler — Retry möglich)
    var qrzLogbookStatus: Int = 0

    // eQSL.cc Upload-Status (Phase 6 Schritt 2, Schema v11):
    //   0 = nicht versucht
    //   1 = OK (eQSL hat „Result: Confirming Submission" zurückgegeben)
    //   2 = duplicate (eQSL kennt das QSO bereits — wie 1 zu werten)
    //   3 = fail (Auth, Netzwerk, andere Rejects — Retry möglich)
    var eqslStatus: Int = 0

    // Solar (Phase 7)
    var sfi: Int?
    var kIndex: Double?
    var aIndex: Double?

    // Geo (Phase 3)
    var distanceKm: Double?
    var bearingDeg: Double?

    // Meta
    let createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(),
         logID: UUID,
         call: String,
         datetime: Date = Date(),
         frequencyMHz: Double,
         band: String,
         mode: String,
         rstSent: String,
         rstReceived: String,
         name: String? = nil,
         qth: String? = nil,
         locator: String? = nil,
         comment: String? = nil,
         operatorCall: String? = nil,
         stationCall: String? = nil,
         powerW: Double? = nil,
         antenna: String? = nil,
         createdAt: Date = Date(),
         modifiedAt: Date = Date()) {
        self.id = id
        self.logID = logID
        self.call = call.uppercased()
        self.datetime = datetime
        self.frequencyMHz = frequencyMHz
        self.band = band
        self.mode = mode
        self.rstSent = rstSent
        self.rstReceived = rstReceived
        self.name = name
        self.qth = qth
        self.locator = locator
        self.comment = comment
        self.operatorCall = operatorCall
        self.stationCall = stationCall
        self.powerW = powerW
        self.antenna = antenna
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
