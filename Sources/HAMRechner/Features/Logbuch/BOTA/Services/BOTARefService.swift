import Foundation
import Combine

// Orchestrator für die BOTA-Reference-Datenbank.
//
// Datenquelle: WWBOTA (api.wwbota.org) — globaler Bunker-Datensatz mit
// weltweit ~26.7k Refs im Format `B/XX-NNNN`. Beim ersten Start (oder
// nach einem App-Update mit neuerem Bundle-Snapshot) wird die CSV aus
// dem App-Bundle in die DB übernommen, danach kann der User über
// `refresh()` jederzeit gegen den Live-Endpoint aktualisieren oder per
// `importCSV` eine handgepflegte Datei laden.
@MainActor
final class BOTARefService: ObservableObject {

    enum Status: Equatable {
        case unknown
        case downloading
        case parsing
        case ready(date: Date?, count: Int, activeCount: Int)
        case errored(String)
    }

    @Published private(set) var status: Status = .unknown
    @Published private(set) var lastError: String?

    let db: BOTARefDatabase

    // WWBOTA Master Reference List, CSV-Export. ETag-Cache-Headers + 15-min
    // server-side caching → harmlos für mehrfache refresh()-Aufrufe.
    private let sourceURL = URL(string: "https://api.wwbota.org/bunkers/?format=CSV")!

    static let refreshHintAfterDays: Int = 30

    // Datum des im App-Bundle mitgelieferten CSV-Snapshots. Beim Init
    // vergleicht der Service diesen Wert mit `bundle_snapshot_date` in
    // der DB-Meta-Tabelle — ist die Konstante neuer (oder die DB leer),
    // wird der Bundle-Snapshot ingestet. So bekommen User nach einem
    // App-Update automatisch eine frische Initial-Liste, ohne den
    // CSV-Import manuell anstoßen zu müssen.
    private static let bundleSnapshotDate = "2026-05-17"
    private static let bundleResourceName = "bota-refs"

    init(dataRoot: AppDataRoot) throws {
        let url = dataRoot.cacheDir.appendingPathComponent("bota_refs.sqlite")
        self.db = try BOTARefDatabase(fileURL: url)
        self.refreshStatusFromDB()
        self.loadBundleSnapshotIfNeeded()
    }

    /// Lädt die im App-Bundle mitgelieferte CSV, wenn die DB entweder leer
    /// ist oder ein älterer Snapshot drinsteht. Silent: scheitert der Load
    /// (Resource fehlt im Dev-Bundle, CSV korrupt), bleibt die DB im
    /// vorherigen Zustand und `refresh()` ist weiterhin der Weg zur
    /// frischen Liste.
    private func loadBundleSnapshotIfNeeded() {
        let dbSnapshot = db.getMeta("bundle_snapshot_date") ?? ""
        let dbCount    = db.totalCount()
        guard dbCount == 0 || dbSnapshot < Self.bundleSnapshotDate else { return }
        guard let url = AppResource.url(forResource: Self.bundleResourceName,
                                        withExtension: "csv") else { return }
        do {
            let data = try Data(contentsOf: url)
            let refs = try Self.parseCSV(data: data)
            guard !refs.isEmpty else { return }
            try db.replaceAll(refs)
            db.setMeta("last_update",
                       value: ISO8601DateFormatter().string(from: Date()))
            db.setMeta("source", value: "Bundle-Snapshot \(Self.bundleSnapshotDate)")
            db.setMeta("row_count", value: "\(refs.count)")
            db.setMeta("bundle_snapshot_date", value: Self.bundleSnapshotDate)
            refreshStatusFromDB()
        } catch {
            lastError = "Bundle-Snapshot konnte nicht geladen werden: \(error.localizedDescription)"
        }
    }

    // MARK: - Public API

    /// Versucht URL-Download — wird fast immer fehlschlagen (kein API).
    /// Der File-Import ist der primäre Pfad für BOTA.
    func refresh() async {
        status = .downloading
        lastError = nil

        do {
            let (data, response) = try await URLSession.shared.data(from: sourceURL)
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                throw NSError(domain: "BOTA", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey:
                                "HTTP \(http.statusCode) vom WWBOTA-Endpoint — versuche es später erneut oder importiere eine CSV manuell."])
            }
            try ingestCSV(data: data, sourceLabel: sourceURL.absoluteString)
        } catch {
            lastError = error.localizedDescription
            status = .errored(error.localizedDescription)
        }
    }

    func importCSV(from fileURL: URL) async {
        status = .parsing
        lastError = nil
        do {
            let data = try Data(contentsOf: fileURL)
            try ingestCSV(data: data, sourceLabel: fileURL.lastPathComponent)
        } catch {
            lastError = error.localizedDescription
            status = .errored(error.localizedDescription)
        }
    }

    private func ingestCSV(data: Data, sourceLabel: String) throws {
        status = .parsing
        let refs = try Self.parseCSV(data: data)
        guard !refs.isEmpty else {
            throw NSError(domain: "BOTA", code: 1,
                          userInfo: [NSLocalizedDescriptionKey:
                            "CSV enthielt 0 Referenzen"])
        }
        try db.replaceAll(refs)
        db.setMeta("last_update",
                   value: ISO8601DateFormatter().string(from: Date()))
        db.setMeta("source", value: sourceLabel)
        db.setMeta("row_count", value: "\(refs.count)")
        // Live-Refresh überschreibt mind. den Bundle-Snapshot-Stand — sonst
        // würde der nächste App-Start den frischen Live-Stand wieder durch
        // den (älteren) Bundle-Snapshot ersetzen.
        db.setMeta("bundle_snapshot_date", value: Self.bundleSnapshotDate)
        status = .ready(date: Date(),
                        count: refs.count,
                        activeCount: refs.filter(\.isActive).count)
    }

    /// Lookup-Eintrag für eine Reference. Normalisiert die Eingabe auf das
    /// WWBOTA-Format (`B/XX-NNNN`) — wenn der User oder ein Cluster-Spot
    /// den `B/`-Präfix weglässt, wird er für den Lookup ergänzt.
    func ref(forReference reference: String) -> BOTAReference? {
        let key = Self.normalize(reference)
        return db.ref(reference: key)
    }

    /// Ergänzt fehlenden `B/`-Präfix. Eingaben ohne Präfix werden trotzdem
    /// gefunden, die DB hält WWBOTA-konforme Refs.
    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces).uppercased()
        if trimmed.hasPrefix("B/") { return trimmed }
        return "B/" + trimmed
    }

    func search(_ query: String) -> [BOTAReference] {
        db.search(prefix: query)
    }

    var isLoaded: Bool {
        if case .ready = status { return true }
        return false
    }

    var shouldOfferRefresh: Bool {
        guard let last = db.lastUpdate else { return true }
        let days = Calendar.current.dateComponents([.day],
                                                   from: last, to: Date()).day ?? 0
        return days >= Self.refreshHintAfterDays
    }

    // MARK: - Status-Reload

    private func refreshStatusFromDB() {
        let count = db.totalCount()
        if count == 0 {
            status = .unknown
        } else {
            status = .ready(date: db.lastUpdate,
                            count: count,
                            activeCount: db.activeCount())
        }
    }

    // MARK: - CSV-Parser
    //
    // Erwartete Spalten (tolerant gegen Reihenfolge + Synonyme):
    //   - Reference   → "reference", "bota_ref", "ref", "bunker_ref"
    //   - Name        → "name", "bunker_name"
    //   - Country     → "country", "land"
    //   - BunkerType  → "type", "bunker_type", "category"
    //   - Status      → "status", "state"
    //   - Latitude    → "lat", "latitude"
    //   - Longitude   → "lon", "long", "longitude"
    //
    // Format-Toleranz wie POTA/SOTA/WWFF: byte-basierte State-Machine.
    static func parseCSV(data: Data) throws -> [BOTAReference] {
        let bytes = [UInt8](data)
        let n = bytes.count

        var iRef = 0, iName = 1
        var iCountry: Int? = nil
        var iType: Int? = nil
        var iStatus: Int? = nil
        var iLat: Int? = nil
        var iLon: Int? = nil
        var headerDetected = false

        var fields: [String] = []
        var fieldBytes: [UInt8] = []
        var inQuotes = false
        var refs: [BOTAReference] = []
        refs.reserveCapacity(20_000)

        func currentField() -> String {
            String(decoding: fieldBytes, as: UTF8.self)
        }
        func commitField() {
            fields.append(currentField())
            fieldBytes.removeAll(keepingCapacity: true)
        }
        func commitRecord() {
            commitField()
            defer { fields.removeAll(keepingCapacity: true) }

            if !headerDetected {
                detectHeader(fields,
                             iRef: &iRef, iName: &iName,
                             iCountry: &iCountry, iType: &iType,
                             iStatus: &iStatus, iLat: &iLat, iLon: &iLon)
                headerDetected = true
                return
            }

            if fields.count <= iRef { return }
            let ref = fields[iRef].trimmingCharacters(in: .whitespacesAndNewlines)
            if ref.isEmpty { return }

            func at(_ idx: Int) -> String? {
                guard fields.count > idx else { return nil }
                let s = fields[idx]
                return s.isEmpty ? nil : s
            }
            func atOpt(_ idx: Int?) -> String? {
                guard let idx else { return nil }
                return at(idx)
            }

            let statusRaw = atOpt(iStatus)?.lowercased() ?? ""
            let isActive = !(statusRaw.contains("delet")
                          || statusRaw.contains("defer")
                          || statusRaw.contains("inactive"))

            refs.append(BOTAReference(
                reference: ref,
                name: at(iName) ?? "",
                program: BOTAReference.programFromRef(ref),
                country: atOpt(iCountry),
                bunkerType: atOpt(iType),
                latitude: atOpt(iLat).flatMap(parseCoord),
                longitude: atOpt(iLon).flatMap(parseCoord),
                isActive: isActive
            ))
        }

        var i = 0
        while i < n {
            let b = bytes[i]
            if inQuotes {
                if b == 0x22 {
                    if i + 1 < n && bytes[i + 1] == 0x22 {
                        fieldBytes.append(0x22)
                        i += 2
                        continue
                    }
                    inQuotes = false
                } else {
                    fieldBytes.append(b)
                }
            } else {
                switch b {
                case 0x22: inQuotes = true
                case 0x2C: commitField()
                case 0x0A: commitRecord()
                case 0x0D: break
                default:   fieldBytes.append(b)
                }
            }
            i += 1
        }
        if !fieldBytes.isEmpty || !fields.isEmpty {
            commitRecord()
        }
        return refs
    }

    private static func detectHeader(_ header: [String],
                                     iRef: inout Int, iName: inout Int,
                                     iCountry: inout Int?, iType: inout Int?,
                                     iStatus: inout Int?,
                                     iLat: inout Int?, iLon: inout Int?) {
        for (idx, col) in header.enumerated() {
            let key = col.lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "_", with: "")
            switch key {
            case "reference", "botaref", "ref", "bunkerref":  iRef = idx
            case "name", "bunkername":                        iName = idx
            case "country", "land":                           iCountry = idx
            case "type", "bunkertype", "category":            iType = idx
            case "status", "state":                           iStatus = idx
            case "lat", "latitude":                           iLat = idx
            case "lon", "long", "longitude":                  iLon = idx
            default: break
            }
        }
    }

    private static func parseCoord(_ s: String) -> Double? {
        let cleaned = s.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }
}
