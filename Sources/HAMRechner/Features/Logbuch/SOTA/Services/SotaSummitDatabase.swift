import Foundation
import SQLite3

// SQLite-Wrapper für die SOTA-Summit-Datenbank. Eine Datei pro App-Instanz,
// liegt im AppDataRoot.cacheDir/summits.sqlite. Bulk-Replace beim Refresh,
// Lookup für Picker/Autocomplete. Datumsfelder werden als ISO-8601-TEXT
// gespeichert, weil sie häufig NULL sind und ISO-Strings einfacher zu
// debuggen sind als Floats.
final class SotaSummitDatabase {
    private let conn: SQLiteConnection
    let fileURL: URL

    init(fileURL: URL) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir,
                                                withIntermediateDirectories: true)
        self.fileURL = fileURL
        self.conn = try SQLiteConnection(path: fileURL.path)
        try createSchema()
    }

    private func createSchema() throws {
        guard conn.exec("""
            CREATE TABLE IF NOT EXISTS summits (
                reference        TEXT PRIMARY KEY,
                association      TEXT NOT NULL,
                region           TEXT NOT NULL,
                name             TEXT NOT NULL,
                altitude_m       INTEGER,
                altitude_ft      INTEGER,
                latitude         REAL,
                longitude        REAL,
                points           INTEGER NOT NULL,
                bonus_points     INTEGER NOT NULL,
                valid_from       TEXT,
                valid_to         TEXT,
                is_active        INTEGER NOT NULL,
                activation_count INTEGER,
                last_activation  TEXT
            );
        """) else {
            throw SQLiteError.openFailed(conn.lastErrorMessage)
        }
        _ = conn.exec("CREATE INDEX IF NOT EXISTS idx_summits_active ON summits(is_active);")
        _ = conn.exec("CREATE INDEX IF NOT EXISTS idx_summits_assoc  ON summits(association);")
        _ = conn.exec("""
            CREATE TABLE IF NOT EXISTS summits_meta (
                key   TEXT PRIMARY KEY,
                value TEXT
            );
        """)
    }

    // MARK: - Bulk-Replace

    /// Ersetzt den kompletten Summit-Bestand atomar. Bei ~181k Rows ist
    /// eine Transaktion + Index-Drop signifikant schneller als Einzel-INSERTs.
    func replaceAll(_ summits: [Summit]) throws {
        _ = conn.exec("BEGIN IMMEDIATE TRANSACTION;")
        defer {
            _ = conn.exec("ROLLBACK;")
        }

        _ = conn.exec("DELETE FROM summits;")
        _ = conn.exec("DROP INDEX IF EXISTS idx_summits_active;")
        _ = conn.exec("DROP INDEX IF EXISTS idx_summits_assoc;")

        let stmt = try conn.prepare("""
            INSERT INTO summits
              (reference, association, region, name, altitude_m, altitude_ft,
               latitude, longitude, points, bonus_points,
               valid_from, valid_to, is_active,
               activation_count, last_activation)
              VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15);
        """)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]

        for s in summits {
            stmt.reset()
            stmt.bind(1, s.reference)
            stmt.bind(2, s.association)
            stmt.bind(3, s.region)
            stmt.bind(4, s.name)
            stmt.bind(5, s.altitudeM)
            stmt.bind(6, s.altitudeFt)
            stmt.bind(7, s.latitude)
            stmt.bind(8, s.longitude)
            stmt.bind(9, s.points)
            stmt.bind(10, s.bonusPoints)
            stmt.bind(11, s.validFrom.map { iso.string(from: $0) })
            stmt.bind(12, s.validTo.map   { iso.string(from: $0) })
            stmt.bind(13, s.isActive ? 1 : 0)
            stmt.bind(14, s.activationCount)
            stmt.bind(15, s.lastActivation.map { iso.string(from: $0) })
            if stmt.step() != SQLITE_DONE {
                throw SQLiteError.stepFailed(conn.lastErrorMessage)
            }
        }

        _ = conn.exec("CREATE INDEX IF NOT EXISTS idx_summits_active ON summits(is_active);")
        _ = conn.exec("CREATE INDEX IF NOT EXISTS idx_summits_assoc  ON summits(association);")
        _ = conn.exec("COMMIT;")
    }

    // MARK: - Lookup

    func summit(reference: String) -> Summit? {
        guard let stmt = try? conn.prepare("""
            SELECT reference, association, region, name, altitude_m, altitude_ft,
                   latitude, longitude, points, bonus_points,
                   valid_from, valid_to, is_active,
                   activation_count, last_activation
              FROM summits WHERE reference = ?1;
        """) else { return nil }
        stmt.bind(1, reference)
        guard stmt.step() == SQLITE_ROW else { return nil }
        return makeSummit(from: stmt)
    }

    /// Prefix-Suche für Autocomplete. Sucht in `reference` (Prefix) UND
    /// `name` (Substring). Bevorzugt aktive Summits, sortiert sie nach oben.
    func search(prefix: String, limit: Int = 30) -> [Summit] {
        let q = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let upperPattern = q.uppercased() + "%"
        let lowerPattern = "%" + q.lowercased() + "%"

        guard let stmt = try? conn.prepare("""
            SELECT reference, association, region, name, altitude_m, altitude_ft,
                   latitude, longitude, points, bonus_points,
                   valid_from, valid_to, is_active,
                   activation_count, last_activation
              FROM summits
             WHERE (UPPER(reference) LIKE ?1 OR LOWER(name) LIKE ?2)
             ORDER BY
                is_active DESC,
                CASE WHEN UPPER(reference) LIKE ?1 THEN 0 ELSE 1 END,
                reference
             LIMIT ?3;
        """) else { return [] }
        stmt.bind(1, upperPattern)
        stmt.bind(2, lowerPattern)
        stmt.bind(3, limit)

        var rows: [Summit] = []
        while stmt.step() == SQLITE_ROW {
            if let s = makeSummit(from: stmt) { rows.append(s) }
        }
        return rows
    }

    func totalCount() -> Int {
        guard let stmt = try? conn.prepare("SELECT COUNT(*) FROM summits;") else {
            return 0
        }
        guard stmt.step() == SQLITE_ROW else { return 0 }
        return stmt.columnInt(0) ?? 0
    }

    func activeCount() -> Int {
        guard let stmt = try? conn.prepare("SELECT COUNT(*) FROM summits WHERE is_active = 1;") else {
            return 0
        }
        guard stmt.step() == SQLITE_ROW else { return 0 }
        return stmt.columnInt(0) ?? 0
    }

    // MARK: - Meta

    func setMeta(_ key: String, value: String) {
        guard let stmt = try? conn.prepare("""
            INSERT INTO summits_meta(key, value) VALUES(?1, ?2)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
        """) else { return }
        stmt.bind(1, key)
        stmt.bind(2, value)
        _ = stmt.step()
    }

    func getMeta(_ key: String) -> String? {
        guard let stmt = try? conn.prepare("SELECT value FROM summits_meta WHERE key = ?1;") else {
            return nil
        }
        stmt.bind(1, key)
        guard stmt.step() == SQLITE_ROW else { return nil }
        return stmt.columnText(0)
    }

    var lastUpdate: Date? {
        guard let iso = getMeta("last_update") else { return nil }
        return ISO8601DateFormatter().date(from: iso)
    }

    // MARK: - Helper

    private func makeSummit(from stmt: SQLiteStatement) -> Summit? {
        guard let ref = stmt.columnText(0),
              let assoc = stmt.columnText(1),
              let region = stmt.columnText(2),
              let name = stmt.columnText(3) else { return nil }

        let dateParser = ISO8601DateFormatter()
        dateParser.formatOptions = [.withFullDate]

        return Summit(
            reference: ref,
            association: assoc,
            region: region,
            name: name,
            altitudeM: stmt.columnInt(4),
            altitudeFt: stmt.columnInt(5),
            latitude: stmt.columnDouble(6),
            longitude: stmt.columnDouble(7),
            points: stmt.columnInt(8) ?? 0,
            bonusPoints: stmt.columnInt(9) ?? 0,
            validFrom: stmt.columnText(10).flatMap { dateParser.date(from: $0) },
            validTo:   stmt.columnText(11).flatMap { dateParser.date(from: $0) },
            isActive: (stmt.columnInt(12) ?? 0) != 0,
            activationCount: stmt.columnInt(13),
            lastActivation: stmt.columnText(14).flatMap { dateParser.date(from: $0) }
        )
    }
}
