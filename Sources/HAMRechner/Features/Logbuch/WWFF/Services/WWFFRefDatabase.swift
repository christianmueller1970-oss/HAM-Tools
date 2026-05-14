import Foundation
import SQLite3

// SQLite-Wrapper für die WWFF-Reference-Datenbank. Eine Datei pro
// App-Instanz, liegt im AppDataRoot.cacheDir/wwff_refs.sqlite. Bulk-
// Replace beim Refresh, Lookup für Picker/Autocomplete.
final class WWFFRefDatabase {
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
            CREATE TABLE IF NOT EXISTS wwff_refs (
                reference     TEXT PRIMARY KEY,
                name          TEXT NOT NULL,
                program       TEXT NOT NULL,
                country       TEXT,
                iuc_category  TEXT,
                latitude      REAL,
                longitude     REAL,
                is_active     INTEGER NOT NULL,
                pota_link     TEXT
            );
        """) else {
            throw SQLiteError.openFailed(conn.lastErrorMessage)
        }
        _ = conn.exec("CREATE INDEX IF NOT EXISTS idx_wwff_active  ON wwff_refs(is_active);")
        _ = conn.exec("CREATE INDEX IF NOT EXISTS idx_wwff_program ON wwff_refs(program);")
        _ = conn.exec("""
            CREATE TABLE IF NOT EXISTS wwff_refs_meta (
                key   TEXT PRIMARY KEY,
                value TEXT
            );
        """)
    }

    // MARK: - Bulk-Replace

    /// Ersetzt den kompletten Ref-Bestand atomar. Bei großen Imports
    /// (>10k Rows) ist eine Transaktion + Index-Drop signifikant schneller
    /// als Einzel-INSERTs.
    func replaceAll(_ refs: [WWFFReference]) throws {
        _ = conn.exec("BEGIN IMMEDIATE TRANSACTION;")
        defer {
            _ = conn.exec("ROLLBACK;")
        }

        _ = conn.exec("DELETE FROM wwff_refs;")
        _ = conn.exec("DROP INDEX IF EXISTS idx_wwff_active;")
        _ = conn.exec("DROP INDEX IF EXISTS idx_wwff_program;")

        let stmt = try conn.prepare("""
            INSERT INTO wwff_refs
              (reference, name, program, country, iuc_category,
               latitude, longitude, is_active, pota_link)
              VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9);
        """)

        for r in refs {
            stmt.reset()
            stmt.bind(1, r.reference)
            stmt.bind(2, r.name)
            stmt.bind(3, r.program)
            stmt.bind(4, r.country)
            stmt.bind(5, r.iucCategory)
            stmt.bind(6, r.latitude)
            stmt.bind(7, r.longitude)
            stmt.bind(8, r.isActive ? 1 : 0)
            stmt.bind(9, r.potaLink)
            if stmt.step() != SQLITE_DONE {
                throw SQLiteError.stepFailed(conn.lastErrorMessage)
            }
        }

        _ = conn.exec("CREATE INDEX IF NOT EXISTS idx_wwff_active  ON wwff_refs(is_active);")
        _ = conn.exec("CREATE INDEX IF NOT EXISTS idx_wwff_program ON wwff_refs(program);")
        _ = conn.exec("COMMIT;")
    }

    // MARK: - Lookup

    func ref(reference: String) -> WWFFReference? {
        guard let stmt = try? conn.prepare("""
            SELECT reference, name, program, country, iuc_category,
                   latitude, longitude, is_active, pota_link
              FROM wwff_refs WHERE reference = ?1;
        """) else { return nil }
        stmt.bind(1, reference)
        guard stmt.step() == SQLITE_ROW else { return nil }
        return makeRef(from: stmt)
    }

    /// Prefix-Suche für Autocomplete. Aktive Refs werden bevorzugt.
    func search(prefix: String, limit: Int = 30) -> [WWFFReference] {
        let q = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let upperPattern = q.uppercased() + "%"
        let lowerPattern = "%" + q.lowercased() + "%"

        guard let stmt = try? conn.prepare("""
            SELECT reference, name, program, country, iuc_category,
                   latitude, longitude, is_active, pota_link
              FROM wwff_refs
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

        var rows: [WWFFReference] = []
        while stmt.step() == SQLITE_ROW {
            if let r = makeRef(from: stmt) { rows.append(r) }
        }
        return rows
    }

    func totalCount() -> Int {
        guard let stmt = try? conn.prepare("SELECT COUNT(*) FROM wwff_refs;") else {
            return 0
        }
        guard stmt.step() == SQLITE_ROW else { return 0 }
        return stmt.columnInt(0) ?? 0
    }

    func activeCount() -> Int {
        guard let stmt = try? conn.prepare("SELECT COUNT(*) FROM wwff_refs WHERE is_active = 1;") else {
            return 0
        }
        guard stmt.step() == SQLITE_ROW else { return 0 }
        return stmt.columnInt(0) ?? 0
    }

    // MARK: - Meta

    func setMeta(_ key: String, value: String) {
        guard let stmt = try? conn.prepare("""
            INSERT INTO wwff_refs_meta(key, value) VALUES(?1, ?2)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
        """) else { return }
        stmt.bind(1, key)
        stmt.bind(2, value)
        _ = stmt.step()
    }

    func getMeta(_ key: String) -> String? {
        guard let stmt = try? conn.prepare("SELECT value FROM wwff_refs_meta WHERE key = ?1;") else {
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

    private func makeRef(from stmt: SQLiteStatement) -> WWFFReference? {
        guard let ref = stmt.columnText(0),
              let name = stmt.columnText(1),
              let program = stmt.columnText(2) else { return nil }
        return WWFFReference(
            reference: ref,
            name: name,
            program: program,
            country: stmt.columnText(3),
            iucCategory: stmt.columnText(4),
            latitude: stmt.columnDouble(5),
            longitude: stmt.columnDouble(6),
            isActive: (stmt.columnInt(7) ?? 0) != 0,
            potaLink: stmt.columnText(8)
        )
    }
}
