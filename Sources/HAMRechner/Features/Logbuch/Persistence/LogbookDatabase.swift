import Foundation
import SQLite3

// Repräsentiert genau EIN Logbuch (eine .htlog-Datei). Hält die SQLite-
// Verbindung, kennt das Schema, und bietet CRUD für Log-Metadaten + QSOs.
//
// Schema-Version 1:
//   log_meta (single-row, id=1)  — alle Log-Felder
//   qsos                          — alle QSO-Felder
//   schema_info                   — Format-Version, App-Version
final class LogbookDatabase {
    let fileURL: URL
    private let conn: SQLiteConnection

    static let schemaVersion = 6
    static let fileExtension = "htlog"          // intern SQLite

    private(set) var log: Log
    private(set) var qsos: [QSO] = []

    // MARK: - Init

    /// Öffnet ein bestehendes Logbuch.
    init(opening fileURL: URL) throws {
        self.fileURL = fileURL
        self.conn = try SQLiteConnection(path: fileURL.path)
        try LogbookDatabase.migrateIfNeeded(conn: conn)
        guard let loaded = try LogbookDatabase.readLogMeta(conn: conn) else {
            throw LogbookError.corruptFile(fileURL.lastPathComponent)
        }
        self.log = loaded
        try reloadQSOs()
    }

    /// Legt ein neues, leeres Logbuch an.
    init(creating fileURL: URL, log: Log) throws {
        self.fileURL = fileURL
        self.conn = try SQLiteConnection(path: fileURL.path)
        try LogbookDatabase.createSchema(conn: conn)
        self.log = log
        try writeLogMeta(log)
    }

    // MARK: - Log meta

    func updateLog(_ newLog: Log) throws {
        try writeLogMeta(newLog)
        self.log = newLog
    }

    // MARK: - QSOs (in-memory cache)

    func reloadQSOs() throws {
        self.qsos = try fetchQSOs()
    }

    func addQSO(_ qso: QSO) throws {
        try writeQSO(qso, isNew: true)
        qsos.append(qso)
    }

    func updateQSO(_ qso: QSO) throws {
        var updated = qso
        updated.modifiedAt = Date()
        try writeQSO(updated, isNew: false)
        if let idx = qsos.firstIndex(where: { $0.id == qso.id }) {
            qsos[idx] = updated
        }
    }

    func deleteQSO(_ qso: QSO) throws {
        let stmt = try conn.prepare("DELETE FROM qsos WHERE id = ?1;")
        stmt.bind(1, qso.id.uuidString)
        guard stmt.step() == SQLITE_DONE else {
            throw LogbookError.writeFailed(conn.lastErrorMessage)
        }
        qsos.removeAll { $0.id == qso.id }
    }

    /// Schnelle Suche aller QSOs zu einem Call (Case-Insensitive,
    /// exakter Call-Match). Nutzt den idx_qso_call-Index.
    func findQSOs(matching call: String) -> [QSO] {
        let upper = call.uppercased().trimmingCharacters(in: .whitespaces)
        guard !upper.isEmpty else { return [] }
        // Suche bereits geladene QSOs (in-memory) — schneller als
        // erneute SQLite-Query für das offene Log.
        return qsos
            .filter { $0.call.uppercased() == upper }
            .sorted { $0.datetime > $1.datetime }
    }

    var qsoCount: Int { qsos.count }
    var lastQsoDate: Date? { qsos.map(\.datetime).max() }

    // MARK: - Schema setup

    private static func createSchema(conn: SQLiteConnection) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS schema_info (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        INSERT INTO schema_info(key, value) VALUES('schemaVersion', '\(schemaVersion)');
        INSERT INTO schema_info(key, value) VALUES('format', 'HAM-Tools-Log');

        CREATE TABLE IF NOT EXISTS log_meta (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            startDate REAL NOT NULL,
            endDate REAL,
            contestID TEXT,
            contestCategory TEXT,
            contestSerialScope TEXT,
            contestModeCategory TEXT,
            potaParkRef TEXT,
            potaParkRefs TEXT,
            sotaSummitRef TEXT,
            sotaSummitRefs TEXT,
            wwffRef TEXT,
            wwffRefs TEXT,
            role TEXT,
            notes TEXT,
            createdAt REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS qsos (
            id TEXT PRIMARY KEY,
            call TEXT NOT NULL,
            datetime REAL NOT NULL,
            frequencyMHz REAL NOT NULL,
            band TEXT NOT NULL,
            mode TEXT NOT NULL,
            rstSent TEXT NOT NULL,
            rstReceived TEXT NOT NULL,
            name TEXT,
            qth TEXT,
            locator TEXT,
            country TEXT,
            continent TEXT,
            cqZone INTEGER,
            ituZone INTEGER,
            comment TEXT,
            operatorCall TEXT,
            stationCall TEXT,
            powerW REAL,
            antenna TEXT,
            contest TEXT,
            contestExchange TEXT,
            contestSerial INTEGER,
            contestExchangeSent TEXT,
            contestExchangeRecv TEXT,
            contestIsRun INTEGER,
            myPotaRef TEXT,
            myPotaRefs TEXT,
            theirPotaRef TEXT,
            mySotaRef TEXT,
            mySotaRefs TEXT,
            theirSotaRef TEXT,
            theirSotaPoints INTEGER,
            myWwffRef TEXT,
            myWwffRefs TEXT,
            theirWwffRef TEXT,
            qslSentDate REAL,
            qslSentVia TEXT,
            qslReceivedDate REAL,
            qslReceivedVia TEXT,
            lotwSent INTEGER NOT NULL DEFAULT 0,
            lotwConfirmed INTEGER NOT NULL DEFAULT 0,
            eqslSent INTEGER NOT NULL DEFAULT 0,
            eqslConfirmed INTEGER NOT NULL DEFAULT 0,
            clublogSent INTEGER NOT NULL DEFAULT 0,
            sfi INTEGER,
            kIndex REAL,
            aIndex REAL,
            distanceKm REAL,
            bearingDeg REAL,
            createdAt REAL NOT NULL,
            modifiedAt REAL NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_qso_datetime ON qsos(datetime);
        CREATE INDEX IF NOT EXISTS idx_qso_call ON qsos(call);
        CREATE INDEX IF NOT EXISTS idx_qso_band ON qsos(band);
        """
        if !conn.exec(sql) {
            throw LogbookError.schemaCreateFailed(conn.lastErrorMessage)
        }
    }

    // MARK: - Migration
    //
    // Wendet inkrementelle Schema-Migrationen auf bestehende .htlog-Dateien an.
    // SQLite hat kein "ALTER TABLE ADD COLUMN IF NOT EXISTS", deshalb prüfen wir
    // via PRAGMA table_info, ob die Spalte schon existiert. Die schema_info-
    // Tabelle wird am Ende aktualisiert, damit wiederholte Aufrufe idempotent
    // bleiben.
    private static func migrateIfNeeded(conn: SQLiteConnection) throws {
        let current = readSchemaVersion(conn: conn)
        guard current < schemaVersion else { return }

        // v1 → v2: Spalte log_meta.potaParkRefs für Multi-Park-Hopping
        if current < 2 {
            if !columnExists(conn: conn, table: "log_meta", column: "potaParkRefs") {
                if !conn.exec("ALTER TABLE log_meta ADD COLUMN potaParkRefs TEXT;") {
                    throw LogbookError.writeFailed(conn.lastErrorMessage)
                }
            }
        }

        // v3 → v4: Contest-Mode-Kategorie auf Log-Ebene (Wizard-Wahl persistieren).
        if current < 4 {
            if !columnExists(conn: conn, table: "log_meta", column: "contestModeCategory") {
                if !conn.exec("ALTER TABLE log_meta ADD COLUMN contestModeCategory TEXT;") {
                    throw LogbookError.writeFailed(conn.lastErrorMessage)
                }
            }
        }

        // v4 → v5: SOTA-Multi-Summit-Hopping (log_meta.sotaSummitRefs) + QSO-
        // Multi-Summit-Liste (qsos.mySotaRefs). Symmetrisch zu potaParkRefs /
        // myPotaRefs aus v2.
        if current < 5 {
            let migrations: [(table: String, column: String, type: String)] = [
                ("log_meta", "sotaSummitRefs", "TEXT"),
                ("qsos",     "mySotaRefs",     "TEXT")
            ]
            for m in migrations where !columnExists(conn: conn, table: m.table, column: m.column) {
                let sql = "ALTER TABLE \(m.table) ADD COLUMN \(m.column) \(m.type);"
                if !conn.exec(sql) {
                    throw LogbookError.writeFailed(conn.lastErrorMessage)
                }
            }
        }

        // v5 → v6: WWFF-Felder. log_meta bekommt wwffRef + wwffRefs für
        // Session-Anlage, qsos bekommt myWwffRef + myWwffRefs (Hopping) +
        // theirWwffRef (R2R-Erkennung).
        if current < 6 {
            let migrations: [(table: String, column: String, type: String)] = [
                ("log_meta", "wwffRef",      "TEXT"),
                ("log_meta", "wwffRefs",     "TEXT"),
                ("qsos",     "myWwffRef",    "TEXT"),
                ("qsos",     "myWwffRefs",   "TEXT"),
                ("qsos",     "theirWwffRef", "TEXT")
            ]
            for m in migrations where !columnExists(conn: conn, table: m.table, column: m.column) {
                let sql = "ALTER TABLE \(m.table) ADD COLUMN \(m.column) \(m.type);"
                if !conn.exec(sql) {
                    throw LogbookError.writeFailed(conn.lastErrorMessage)
                }
            }
        }

        // v2 → v3: Contest-Etappe-1-Felder (Serial, Sent/Recv-Exchange, Run/S&P).
        if current < 3 {
            let migrations: [(table: String, column: String, type: String)] = [
                ("log_meta", "contestSerialScope",  "TEXT"),
                ("qsos",     "contestSerial",       "INTEGER"),
                ("qsos",     "contestExchangeSent", "TEXT"),
                ("qsos",     "contestExchangeRecv", "TEXT"),
                ("qsos",     "contestIsRun",        "INTEGER")
            ]
            for m in migrations where !columnExists(conn: conn, table: m.table, column: m.column) {
                let sql = "ALTER TABLE \(m.table) ADD COLUMN \(m.column) \(m.type);"
                if !conn.exec(sql) {
                    throw LogbookError.writeFailed(conn.lastErrorMessage)
                }
            }
            // Legacy-Migration: alter contestExchange → contestExchangeRecv kopieren,
            // falls noch nicht gesetzt. So bleibt der Wert nach v3-Upgrade lesbar.
            _ = conn.exec("""
                UPDATE qsos
                SET contestExchangeRecv = contestExchange
                WHERE contestExchangeRecv IS NULL AND contestExchange IS NOT NULL;
            """)
        }

        // schema_info finale Version setzen (UPSERT)
        let stmt = try conn.prepare("""
            INSERT INTO schema_info(key, value) VALUES('schemaVersion', ?1)
            ON CONFLICT(key) DO UPDATE SET value=excluded.value;
        """)
        stmt.bind(1, String(schemaVersion))
        guard stmt.step() == SQLITE_DONE else {
            throw LogbookError.writeFailed(conn.lastErrorMessage)
        }
    }

    private static func readSchemaVersion(conn: SQLiteConnection) -> Int {
        guard let stmt = try? conn.prepare(
            "SELECT value FROM schema_info WHERE key='schemaVersion';")
        else { return 1 }
        if stmt.step() == SQLITE_ROW,
           let v = stmt.columnText(0),
           let n = Int(v) { return n }
        return 1
    }

    private static func columnExists(conn: SQLiteConnection,
                                     table: String,
                                     column: String) -> Bool {
        // PRAGMA table_info(...) lässt sich nicht parametrisieren, daher
        // Tabellennamen quoten. Wird nur intern aufgerufen, kein User-Input.
        let quoted = table.replacingOccurrences(of: "\"", with: "\"\"")
        guard let stmt = try? conn.prepare("PRAGMA table_info(\"\(quoted)\");")
        else { return false }
        while stmt.step() == SQLITE_ROW {
            if stmt.columnText(1) == column { return true }
        }
        return false
    }

    // MARK: - Log meta I/O

    private static func readLogMeta(conn: SQLiteConnection) throws -> Log? {
        let stmt = try conn.prepare("""
            SELECT id, name, type, startDate, endDate, contestID, contestCategory,
                   contestSerialScope, contestModeCategory,
                   potaParkRef, potaParkRefs, sotaSummitRef, role, notes, createdAt,
                   sotaSummitRefs,
                   wwffRef, wwffRefs
            FROM log_meta LIMIT 1;
        """)
        guard stmt.step() == SQLITE_ROW,
              let idStr = stmt.columnText(0),
              let id = UUID(uuidString: idStr),
              let name = stmt.columnText(1),
              let typeRaw = stmt.columnText(2),
              let startTS = stmt.columnDouble(3),
              let createdTS = stmt.columnDouble(14) else {
            return nil
        }
        return Log(
            id: id,
            name: name,
            type: LogType(rawValue: typeRaw) ?? .standard,
            startDate: Date(timeIntervalSince1970: startTS),
            endDate: stmt.columnDate(4),
            contestID: stmt.columnText(5),
            contestCategory: stmt.columnText(6),
            contestSerialScope: stmt.columnText(7),
            contestModeCategory: stmt.columnText(8),
            potaParkRef: stmt.columnText(9),
            potaParkRefs: stmt.columnText(10),
            sotaSummitRef: stmt.columnText(11),
            sotaSummitRefs: stmt.columnText(15),
            wwffRef: stmt.columnText(16),
            wwffRefs: stmt.columnText(17),
            role: stmt.columnText(12),
            notes: stmt.columnText(13),
            createdAt: Date(timeIntervalSince1970: createdTS)
        )
    }

    private func writeLogMeta(_ log: Log) throws {
        let stmt = try conn.prepare("""
            INSERT INTO log_meta(id, name, type, startDate, endDate, contestID,
                contestCategory, contestSerialScope, contestModeCategory,
                potaParkRef, potaParkRefs, sotaSummitRef, role, notes, createdAt,
                sotaSummitRefs,
                wwffRef, wwffRefs)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18)
            ON CONFLICT(id) DO UPDATE SET
                name=excluded.name,
                type=excluded.type,
                startDate=excluded.startDate,
                endDate=excluded.endDate,
                contestID=excluded.contestID,
                contestCategory=excluded.contestCategory,
                contestSerialScope=excluded.contestSerialScope,
                contestModeCategory=excluded.contestModeCategory,
                potaParkRef=excluded.potaParkRef,
                potaParkRefs=excluded.potaParkRefs,
                sotaSummitRef=excluded.sotaSummitRef,
                sotaSummitRefs=excluded.sotaSummitRefs,
                wwffRef=excluded.wwffRef,
                wwffRefs=excluded.wwffRefs,
                role=excluded.role,
                notes=excluded.notes;
        """)
        stmt.bind(1,  log.id.uuidString)
        stmt.bind(2,  log.name)
        stmt.bind(3,  log.type.rawValue)
        stmt.bind(4,  date: log.startDate)
        stmt.bind(5,  date: log.endDate)
        stmt.bind(6,  log.contestID)
        stmt.bind(7,  log.contestCategory)
        stmt.bind(8,  log.contestSerialScope)
        stmt.bind(9,  log.contestModeCategory)
        stmt.bind(10, log.potaParkRef)
        stmt.bind(11, log.potaParkRefs)
        stmt.bind(12, log.sotaSummitRef)
        stmt.bind(13, log.role)
        stmt.bind(14, log.notes)
        stmt.bind(15, date: log.createdAt)
        stmt.bind(16, log.sotaSummitRefs)
        stmt.bind(17, log.wwffRef)
        stmt.bind(18, log.wwffRefs)
        guard stmt.step() == SQLITE_DONE else {
            throw LogbookError.writeFailed(conn.lastErrorMessage)
        }
    }

    // MARK: - QSO I/O

    private func fetchQSOs() throws -> [QSO] {
        let stmt = try conn.prepare("""
            SELECT id, call, datetime, frequencyMHz, band, mode, rstSent, rstReceived,
                   name, qth, locator, country, continent, cqZone, ituZone, comment,
                   operatorCall, stationCall, powerW, antenna,
                   contest, contestExchange,
                   myPotaRef, myPotaRefs, theirPotaRef,
                   mySotaRef, theirSotaRef, theirSotaPoints,
                   qslSentDate, qslSentVia, qslReceivedDate, qslReceivedVia,
                   lotwSent, lotwConfirmed, eqslSent, eqslConfirmed, clublogSent,
                   sfi, kIndex, aIndex,
                   distanceKm, bearingDeg,
                   contestSerial, contestExchangeSent, contestExchangeRecv, contestIsRun,
                   createdAt, modifiedAt,
                   mySotaRefs,
                   myWwffRef, myWwffRefs, theirWwffRef
            FROM qsos ORDER BY datetime DESC;
        """)
        var out: [QSO] = []
        while stmt.step() == SQLITE_ROW {
            guard let idStr = stmt.columnText(0),
                  let id = UUID(uuidString: idStr),
                  let call = stmt.columnText(1),
                  let dt = stmt.columnDouble(2),
                  let f = stmt.columnDouble(3),
                  let band = stmt.columnText(4),
                  let mode = stmt.columnText(5),
                  let rstS = stmt.columnText(6),
                  let rstR = stmt.columnText(7),
                  let created = stmt.columnDouble(46),
                  let modified = stmt.columnDouble(47)
            else { continue }

            var qso = QSO(
                id: id,
                logID: log.id,
                call: call,
                datetime: Date(timeIntervalSince1970: dt),
                frequencyMHz: f,
                band: band,
                mode: mode,
                rstSent: rstS,
                rstReceived: rstR,
                createdAt: Date(timeIntervalSince1970: created),
                modifiedAt: Date(timeIntervalSince1970: modified)
            )
            qso.name             = stmt.columnText(8)
            qso.qth              = stmt.columnText(9)
            qso.locator          = stmt.columnText(10)
            qso.country          = stmt.columnText(11)
            qso.continent        = stmt.columnText(12)
            qso.cqZone           = stmt.columnInt(13)
            qso.ituZone          = stmt.columnInt(14)
            qso.comment          = stmt.columnText(15)
            qso.operatorCall     = stmt.columnText(16)
            qso.stationCall      = stmt.columnText(17)
            qso.powerW           = stmt.columnDouble(18)
            qso.antenna          = stmt.columnText(19)
            qso.contest          = stmt.columnText(20)
            qso.contestExchange  = stmt.columnText(21)
            qso.myPotaRef        = stmt.columnText(22)
            qso.myPotaRefs       = stmt.columnText(23)
            qso.theirPotaRef     = stmt.columnText(24)
            qso.mySotaRef        = stmt.columnText(25)
            qso.theirSotaRef     = stmt.columnText(26)
            qso.theirSotaPoints  = stmt.columnInt(27)
            qso.qslSentDate      = stmt.columnDate(28)
            qso.qslSentVia       = stmt.columnText(29)
            qso.qslReceivedDate  = stmt.columnDate(30)
            qso.qslReceivedVia   = stmt.columnText(31)
            qso.lotwSent         = stmt.columnBool(32)
            qso.lotwConfirmed    = stmt.columnBool(33)
            qso.eqslSent         = stmt.columnBool(34)
            qso.eqslConfirmed    = stmt.columnBool(35)
            qso.clublogSent      = stmt.columnBool(36)
            qso.sfi              = stmt.columnInt(37)
            qso.kIndex           = stmt.columnDouble(38)
            qso.aIndex           = stmt.columnDouble(39)
            qso.distanceKm         = stmt.columnDouble(40)
            qso.bearingDeg         = stmt.columnDouble(41)
            qso.contestSerial      = stmt.columnInt(42)
            qso.contestExchangeSent = stmt.columnText(43)
            qso.contestExchangeRecv = stmt.columnText(44)
            qso.contestIsRun       = stmt.columnInt(45).map { $0 != 0 }
            qso.mySotaRefs         = stmt.columnText(48)
            qso.myWwffRef          = stmt.columnText(49)
            qso.myWwffRefs         = stmt.columnText(50)
            qso.theirWwffRef       = stmt.columnText(51)
            out.append(qso)
        }
        return out
    }

    private func writeQSO(_ qso: QSO, isNew: Bool) throws {
        let sql: String
        if isNew {
            sql = """
            INSERT INTO qsos(id, call, datetime, frequencyMHz, band, mode, rstSent, rstReceived,
                name, qth, locator, country, continent, cqZone, ituZone, comment,
                operatorCall, stationCall, powerW, antenna,
                contest, contestExchange,
                myPotaRef, myPotaRefs, theirPotaRef,
                mySotaRef, theirSotaRef, theirSotaPoints,
                qslSentDate, qslSentVia, qslReceivedDate, qslReceivedVia,
                lotwSent, lotwConfirmed, eqslSent, eqslConfirmed, clublogSent,
                sfi, kIndex, aIndex,
                distanceKm, bearingDeg,
                contestSerial, contestExchangeSent, contestExchangeRecv, contestIsRun,
                createdAt, modifiedAt,
                mySotaRefs,
                myWwffRef, myWwffRefs, theirWwffRef)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16,
                    ?17, ?18, ?19, ?20, ?21, ?22, ?23, ?24, ?25, ?26, ?27, ?28,
                    ?29, ?30, ?31, ?32, ?33, ?34, ?35, ?36, ?37, ?38, ?39, ?40,
                    ?41, ?42, ?43, ?44, ?45, ?46, ?47, ?48, ?49, ?50, ?51, ?52);
            """
        } else {
            sql = """
            UPDATE qsos SET
                call=?2, datetime=?3, frequencyMHz=?4, band=?5, mode=?6,
                rstSent=?7, rstReceived=?8,
                name=?9, qth=?10, locator=?11, country=?12, continent=?13,
                cqZone=?14, ituZone=?15, comment=?16,
                operatorCall=?17, stationCall=?18, powerW=?19, antenna=?20,
                contest=?21, contestExchange=?22,
                myPotaRef=?23, myPotaRefs=?24, theirPotaRef=?25,
                mySotaRef=?26, theirSotaRef=?27, theirSotaPoints=?28,
                qslSentDate=?29, qslSentVia=?30, qslReceivedDate=?31, qslReceivedVia=?32,
                lotwSent=?33, lotwConfirmed=?34, eqslSent=?35, eqslConfirmed=?36, clublogSent=?37,
                sfi=?38, kIndex=?39, aIndex=?40,
                distanceKm=?41, bearingDeg=?42,
                contestSerial=?43, contestExchangeSent=?44, contestExchangeRecv=?45, contestIsRun=?46,
                createdAt=?47, modifiedAt=?48,
                mySotaRefs=?49,
                myWwffRef=?50, myWwffRefs=?51, theirWwffRef=?52
            WHERE id=?1;
            """
        }
        let stmt = try conn.prepare(sql)
        stmt.bind(1, qso.id.uuidString)
        stmt.bind(2, qso.call)
        stmt.bind(3, date: qso.datetime)
        stmt.bind(4, qso.frequencyMHz)
        stmt.bind(5, qso.band)
        stmt.bind(6, qso.mode)
        stmt.bind(7, qso.rstSent)
        stmt.bind(8, qso.rstReceived)
        stmt.bind(9, qso.name)
        stmt.bind(10, qso.qth)
        stmt.bind(11, qso.locator)
        stmt.bind(12, qso.country)
        stmt.bind(13, qso.continent)
        stmt.bind(14, qso.cqZone)
        stmt.bind(15, qso.ituZone)
        stmt.bind(16, qso.comment)
        stmt.bind(17, qso.operatorCall)
        stmt.bind(18, qso.stationCall)
        stmt.bind(19, qso.powerW)
        stmt.bind(20, qso.antenna)
        stmt.bind(21, qso.contest)
        stmt.bind(22, qso.contestExchange)
        stmt.bind(23, qso.myPotaRef)
        stmt.bind(24, qso.myPotaRefs)
        stmt.bind(25, qso.theirPotaRef)
        stmt.bind(26, qso.mySotaRef)
        stmt.bind(27, qso.theirSotaRef)
        stmt.bind(28, qso.theirSotaPoints)
        stmt.bind(29, date: qso.qslSentDate)
        stmt.bind(30, qso.qslSentVia)
        stmt.bind(31, date: qso.qslReceivedDate)
        stmt.bind(32, qso.qslReceivedVia)
        stmt.bind(33, qso.lotwSent)
        stmt.bind(34, qso.lotwConfirmed)
        stmt.bind(35, qso.eqslSent)
        stmt.bind(36, qso.eqslConfirmed)
        stmt.bind(37, qso.clublogSent)
        stmt.bind(38, qso.sfi)
        stmt.bind(39, qso.kIndex)
        stmt.bind(40, qso.aIndex)
        stmt.bind(41, qso.distanceKm)
        stmt.bind(42, qso.bearingDeg)
        stmt.bind(43, qso.contestSerial)
        stmt.bind(44, qso.contestExchangeSent)
        stmt.bind(45, qso.contestExchangeRecv)
        stmt.bind(46, qso.contestIsRun.map { $0 ? 1 : 0 })
        stmt.bind(47, date: qso.createdAt)
        stmt.bind(48, date: qso.modifiedAt)
        stmt.bind(49, qso.mySotaRefs)
        stmt.bind(50, qso.myWwffRef)
        stmt.bind(51, qso.myWwffRefs)
        stmt.bind(52, qso.theirWwffRef)

        guard stmt.step() == SQLITE_DONE else {
            throw LogbookError.writeFailed(conn.lastErrorMessage)
        }
    }
}

enum LogbookError: Error, LocalizedError {
    case schemaCreateFailed(String)
    case writeFailed(String)
    case corruptFile(String)
    case fileExists(String)

    var errorDescription: String? {
        switch self {
        case .schemaCreateFailed(let m): return "Schema-Anlage fehlgeschlagen: \(m)"
        case .writeFailed(let m):        return "Schreibfehler: \(m)"
        case .corruptFile(let f):        return "Datei beschädigt oder kein gültiges Logbuch: \(f)"
        case .fileExists(let f):         return "Datei existiert bereits: \(f)"
        }
    }
}
