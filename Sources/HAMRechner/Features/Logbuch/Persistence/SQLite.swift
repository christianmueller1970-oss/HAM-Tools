import Foundation
import SQLite3

// Schlanker Wrapper um die SQLite-C-API. Nur das was wir hier brauchen:
// Verbindung öffnen/schließen, prepared statements, bind/step/finalize.

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteConnection {
    private var db: OpaquePointer?

    init(path: String) throws {
        if sqlite3_open_v2(path, &db,
                           SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
                           nil) != SQLITE_OK {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw SQLiteError.openFailed(msg)
        }
        // Performance + Integrität
        _ = exec("PRAGMA journal_mode=WAL;")
        _ = exec("PRAGMA foreign_keys=ON;")
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    @discardableResult
    func exec(_ sql: String) -> Bool {
        guard let db else { return false }
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            if let err { sqlite3_free(err) }
            return false
        }
        return true
    }

    func prepare(_ sql: String) throws -> SQLiteStatement {
        guard let db else { throw SQLiteError.notOpen }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.prepareFailed(msg, sql)
        }
        return SQLiteStatement(stmt: stmt!)
    }

    var lastErrorMessage: String {
        guard let db else { return "no connection" }
        return String(cString: sqlite3_errmsg(db))
    }
}

final class SQLiteStatement {
    fileprivate var stmt: OpaquePointer?

    init(stmt: OpaquePointer) {
        self.stmt = stmt
    }

    deinit {
        if let stmt { sqlite3_finalize(stmt) }
    }

    // MARK: Bind

    func bind(_ index: Int32, _ value: String?) {
        if let v = value {
            sqlite3_bind_text(stmt, index, v, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    func bind(_ index: Int32, _ value: Double?) {
        if let v = value {
            sqlite3_bind_double(stmt, index, v)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    func bind(_ index: Int32, _ value: Int?) {
        if let v = value {
            sqlite3_bind_int64(stmt, index, Int64(v))
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    func bind(_ index: Int32, _ value: Bool) {
        sqlite3_bind_int(stmt, index, value ? 1 : 0)
    }

    func bind(_ index: Int32, date: Date?) {
        if let d = date {
            sqlite3_bind_double(stmt, index, d.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    // MARK: Step / Read

    @discardableResult
    func step() -> Int32 {
        sqlite3_step(stmt)
    }

    func reset() {
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)
    }

    // MARK: Column readers

    func columnText(_ index: Int32) -> String? {
        guard let cstr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cstr)
    }

    func columnInt(_ index: Int32) -> Int? {
        if sqlite3_column_type(stmt, index) == SQLITE_NULL { return nil }
        return Int(sqlite3_column_int64(stmt, index))
    }

    func columnDouble(_ index: Int32) -> Double? {
        if sqlite3_column_type(stmt, index) == SQLITE_NULL { return nil }
        return sqlite3_column_double(stmt, index)
    }

    func columnBool(_ index: Int32) -> Bool {
        sqlite3_column_int(stmt, index) != 0
    }

    func columnDate(_ index: Int32) -> Date? {
        guard let d = columnDouble(index) else { return nil }
        return Date(timeIntervalSince1970: d)
    }
}

enum SQLiteError: Error, LocalizedError {
    case openFailed(String)
    case notOpen
    case prepareFailed(String, String)
    case stepFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let m):     return "SQLite open: \(m)"
        case .notOpen:               return "SQLite connection not open"
        case .prepareFailed(let m, let sql): return "SQLite prepare: \(m) — SQL: \(sql)"
        case .stepFailed(let m):     return "SQLite step: \(m)"
        }
    }
}
