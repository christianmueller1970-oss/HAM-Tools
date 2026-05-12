import Foundation
import SQLite3

// SQLite-Wrapper für die POTA-Park-Datenbank. Eine Datei pro App-Instanz,
// liegt im AppDataRoot.cacheDir/parks.sqlite. Bulk-Replace beim Refresh,
// Lookup für Picker/Autocomplete.
final class PotaParkDatabase {
    private let conn: SQLiteConnection
    let fileURL: URL

    init(fileURL: URL) throws {
        // Verzeichnis sicherstellen.
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir,
                                                withIntermediateDirectories: true)
        self.fileURL = fileURL
        self.conn = try SQLiteConnection(path: fileURL.path)
        try createSchema()
    }

    private func createSchema() throws {
        guard conn.exec("""
            CREATE TABLE IF NOT EXISTS parks (
                reference     TEXT PRIMARY KEY,
                name          TEXT NOT NULL,
                active        INTEGER NOT NULL,
                entity_id     INTEGER,
                location_desc TEXT,
                latitude      REAL,
                longitude     REAL,
                grid          TEXT
            );
        """) else {
            throw SQLiteError.openFailed(conn.lastErrorMessage)
        }
        _ = conn.exec("CREATE INDEX IF NOT EXISTS idx_parks_active ON parks(active);")
        _ = conn.exec("""
            CREATE TABLE IF NOT EXISTS parks_meta (
                key   TEXT PRIMARY KEY,
                value TEXT
            );
        """)
    }

    // MARK: - Bulk-Replace

    /// Ersetzt den kompletten Park-Bestand atomar. Bei großem Bestand (~90k
    /// Rows) ist eine Transaktion + Index-Drop-and-Recreate signifikant
    /// schneller als Einzel-INSERTs.
    func replaceAll(_ parks: [Park]) throws {
        _ = conn.exec("BEGIN IMMEDIATE TRANSACTION;")
        defer {
            // Falls vorher schon committed: ROLLBACK ist ein no-op.
            _ = conn.exec("ROLLBACK;")
        }

        _ = conn.exec("DELETE FROM parks;")
        _ = conn.exec("DROP INDEX IF EXISTS idx_parks_active;")

        let stmt = try conn.prepare("""
            INSERT INTO parks
              (reference, name, active, entity_id, location_desc, latitude, longitude, grid)
              VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8);
        """)

        for p in parks {
            stmt.reset()
            stmt.bind(1, p.reference)
            stmt.bind(2, p.name)
            stmt.bind(3, p.active ? 1 : 0)
            stmt.bind(4, p.entityId)
            stmt.bind(5, p.locationDesc)
            stmt.bind(6, p.latitude)
            stmt.bind(7, p.longitude)
            stmt.bind(8, p.grid)
            if stmt.step() != SQLITE_DONE {
                throw SQLiteError.stepFailed(conn.lastErrorMessage)
            }
        }

        _ = conn.exec("CREATE INDEX IF NOT EXISTS idx_parks_active ON parks(active);")
        _ = conn.exec("COMMIT;")
    }

    // MARK: - Lookup

    func park(reference: String) -> Park? {
        guard let stmt = try? conn.prepare("""
            SELECT reference, name, active, entity_id, location_desc,
                   latitude, longitude, grid
              FROM parks WHERE reference = ?1;
        """) else { return nil }
        stmt.bind(1, reference)
        guard stmt.step() == SQLITE_ROW else { return nil }
        return makePark(from: stmt)
    }

    /// Prefix-Suche für Autocomplete. Sucht in `reference` UND `name`.
    func search(prefix: String, limit: Int = 30) -> [Park] {
        let q = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let upperPattern = q.uppercased() + "%"
        let lowerPattern = "%" + q.lowercased() + "%"

        guard let stmt = try? conn.prepare("""
            SELECT reference, name, active, entity_id, location_desc,
                   latitude, longitude, grid
              FROM parks
             WHERE (UPPER(reference) LIKE ?1 OR LOWER(name) LIKE ?2)
               AND active = 1
             ORDER BY
                CASE WHEN UPPER(reference) LIKE ?1 THEN 0 ELSE 1 END,
                reference
             LIMIT ?3;
        """) else { return [] }
        stmt.bind(1, upperPattern)
        stmt.bind(2, lowerPattern)
        stmt.bind(3, limit)

        var rows: [Park] = []
        while stmt.step() == SQLITE_ROW {
            if let p = makePark(from: stmt) { rows.append(p) }
        }
        return rows
    }

    func totalCount() -> Int {
        guard let stmt = try? conn.prepare("SELECT COUNT(*) FROM parks;") else {
            return 0
        }
        guard stmt.step() == SQLITE_ROW else { return 0 }
        return stmt.columnInt(0) ?? 0
    }

    // MARK: - Meta

    func setMeta(_ key: String, value: String) {
        guard let stmt = try? conn.prepare("""
            INSERT INTO parks_meta(key, value) VALUES(?1, ?2)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
        """) else { return }
        stmt.bind(1, key)
        stmt.bind(2, value)
        _ = stmt.step()
    }

    func getMeta(_ key: String) -> String? {
        guard let stmt = try? conn.prepare("SELECT value FROM parks_meta WHERE key = ?1;") else {
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

    private func makePark(from stmt: SQLiteStatement) -> Park? {
        guard let ref = stmt.columnText(0),
              let name = stmt.columnText(1) else { return nil }
        return Park(
            reference: ref,
            name: name,
            active: (stmt.columnInt(2) ?? 0) != 0,
            entityId: stmt.columnInt(3),
            locationDesc: stmt.columnText(4),
            latitude: stmt.columnDouble(5),
            longitude: stmt.columnDouble(6),
            grid: stmt.columnText(7)
        )
    }
}
