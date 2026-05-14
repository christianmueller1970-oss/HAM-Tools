import Foundation
import SQLite3

// SQLite-Wrapper für die BOTA-Reference-Datenbank. Strukturparallel zu
// WWFFRefDatabase — Bulk-Replace beim Import, Lookup für Picker.
final class BOTARefDatabase {
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
            CREATE TABLE IF NOT EXISTS bota_refs (
                reference   TEXT PRIMARY KEY,
                name        TEXT NOT NULL,
                program     TEXT NOT NULL,
                country     TEXT,
                bunker_type TEXT,
                latitude    REAL,
                longitude   REAL,
                is_active   INTEGER NOT NULL
            );
        """) else {
            throw SQLiteError.openFailed(conn.lastErrorMessage)
        }
        _ = conn.exec("CREATE INDEX IF NOT EXISTS idx_bota_active  ON bota_refs(is_active);")
        _ = conn.exec("CREATE INDEX IF NOT EXISTS idx_bota_program ON bota_refs(program);")
        _ = conn.exec("""
            CREATE TABLE IF NOT EXISTS bota_refs_meta (
                key   TEXT PRIMARY KEY,
                value TEXT
            );
        """)
    }

    // MARK: - Bulk-Replace

    func replaceAll(_ refs: [BOTAReference]) throws {
        _ = conn.exec("BEGIN IMMEDIATE TRANSACTION;")
        defer { _ = conn.exec("ROLLBACK;") }

        _ = conn.exec("DELETE FROM bota_refs;")
        _ = conn.exec("DROP INDEX IF EXISTS idx_bota_active;")
        _ = conn.exec("DROP INDEX IF EXISTS idx_bota_program;")

        let stmt = try conn.prepare("""
            INSERT INTO bota_refs
              (reference, name, program, country, bunker_type,
               latitude, longitude, is_active)
              VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8);
        """)

        for r in refs {
            stmt.reset()
            stmt.bind(1, r.reference)
            stmt.bind(2, r.name)
            stmt.bind(3, r.program)
            stmt.bind(4, r.country)
            stmt.bind(5, r.bunkerType)
            stmt.bind(6, r.latitude)
            stmt.bind(7, r.longitude)
            stmt.bind(8, r.isActive ? 1 : 0)
            if stmt.step() != SQLITE_DONE {
                throw SQLiteError.stepFailed(conn.lastErrorMessage)
            }
        }

        _ = conn.exec("CREATE INDEX IF NOT EXISTS idx_bota_active  ON bota_refs(is_active);")
        _ = conn.exec("CREATE INDEX IF NOT EXISTS idx_bota_program ON bota_refs(program);")
        _ = conn.exec("COMMIT;")
    }

    // MARK: - Lookup

    func ref(reference: String) -> BOTAReference? {
        guard let stmt = try? conn.prepare("""
            SELECT reference, name, program, country, bunker_type,
                   latitude, longitude, is_active
              FROM bota_refs WHERE reference = ?1;
        """) else { return nil }
        stmt.bind(1, reference)
        guard stmt.step() == SQLITE_ROW else { return nil }
        return makeRef(from: stmt)
    }

    func search(prefix: String, limit: Int = 30) -> [BOTAReference] {
        let q = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let upperPattern = q.uppercased() + "%"
        let lowerPattern = "%" + q.lowercased() + "%"

        guard let stmt = try? conn.prepare("""
            SELECT reference, name, program, country, bunker_type,
                   latitude, longitude, is_active
              FROM bota_refs
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

        var rows: [BOTAReference] = []
        while stmt.step() == SQLITE_ROW {
            if let r = makeRef(from: stmt) { rows.append(r) }
        }
        return rows
    }

    func totalCount() -> Int {
        guard let stmt = try? conn.prepare("SELECT COUNT(*) FROM bota_refs;") else {
            return 0
        }
        guard stmt.step() == SQLITE_ROW else { return 0 }
        return stmt.columnInt(0) ?? 0
    }

    func activeCount() -> Int {
        guard let stmt = try? conn.prepare("SELECT COUNT(*) FROM bota_refs WHERE is_active = 1;") else {
            return 0
        }
        guard stmt.step() == SQLITE_ROW else { return 0 }
        return stmt.columnInt(0) ?? 0
    }

    // MARK: - Meta

    func setMeta(_ key: String, value: String) {
        guard let stmt = try? conn.prepare("""
            INSERT INTO bota_refs_meta(key, value) VALUES(?1, ?2)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
        """) else { return }
        stmt.bind(1, key)
        stmt.bind(2, value)
        _ = stmt.step()
    }

    func getMeta(_ key: String) -> String? {
        guard let stmt = try? conn.prepare("SELECT value FROM bota_refs_meta WHERE key = ?1;") else {
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

    private func makeRef(from stmt: SQLiteStatement) -> BOTAReference? {
        guard let ref = stmt.columnText(0),
              let name = stmt.columnText(1),
              let program = stmt.columnText(2) else { return nil }
        return BOTAReference(
            reference: ref,
            name: name,
            program: program,
            country: stmt.columnText(3),
            bunkerType: stmt.columnText(4),
            latitude: stmt.columnDouble(5),
            longitude: stmt.columnDouble(6),
            isActive: (stmt.columnInt(7) ?? 0) != 0
        )
    }
}
