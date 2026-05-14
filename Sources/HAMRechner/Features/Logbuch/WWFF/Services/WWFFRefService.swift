import Foundation
import Combine

// Orchestrator für die WWFF-Reference-Datenbank.
//
// Doppelpfad-Strategie (vs. POTA/SOTA-Single-URL):
//   - refresh()      lädt von der konfigurierten URL (wwff-cc.org wenn online)
//   - importCSV(...) parst eine lokal vom User ausgewählte CSV-Datei
// Hintergrund: wwff-cc.org war beim Foundation-Bau zeitweise nicht erreichbar.
// Der File-Import-Pfad macht das Modul robust gegen Server-Ausfälle und
// erlaubt Country-Coordinator-CSVs, die nicht über die Haupt-Site verteilt
// werden.
//
// Beim ersten App-Start: User wird beim ersten WWFF-Modus zum Initial-
// Laden aufgefordert. Spätere Refreshes via Button oder automatischer
// Hinweis nach 30 Tagen.
@MainActor
final class WWFFRefService: ObservableObject {

    enum Status: Equatable {
        case unknown
        case downloading
        case parsing
        case ready(date: Date?, count: Int, activeCount: Int)
        case errored(String)
    }

    @Published private(set) var status: Status = .unknown
    @Published private(set) var lastError: String?

    let db: WWFFRefDatabase

    // Default-URL — sobald wwff-cc.org wieder erreichbar ist; sonst nutzt
    // der User den File-Picker-Pfad. Kann später ohne Code-Änderung
    // umgebogen werden (z.B. auf einen GitHub-Mirror).
    private let sourceURL = URL(string: "https://wwff-cc.org/dir.php?do=list_directory")!

    static let refreshHintAfterDays: Int = 30

    init(dataRoot: AppDataRoot) throws {
        let url = dataRoot.cacheDir.appendingPathComponent("wwff_refs.sqlite")
        self.db = try WWFFRefDatabase(fileURL: url)
        self.refreshStatusFromDB()
    }

    // MARK: - Public API

    /// Lädt das offizielle Directory-CSV. Wenn die URL nicht erreichbar
    /// ist, setzt der Service `.errored` und der User wird in den Settings
    /// zum File-Picker-Pfad verwiesen.
    func refresh() async {
        status = .downloading
        lastError = nil

        do {
            let (data, response) = try await URLSession.shared.data(from: sourceURL)
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                throw NSError(domain: "WWFF", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey:
                                "HTTP \(http.statusCode) von wwff-cc.org"])
            }
            try ingestCSV(data: data, sourceLabel: sourceURL.absoluteString)
        } catch {
            lastError = error.localizedDescription
            status = .errored(error.localizedDescription)
        }
    }

    /// Liest eine lokal vom User ausgewählte CSV-Datei. Fail-Safe-Pfad
    /// wenn die offizielle URL nicht erreichbar ist oder ein Country-
    /// Coordinator eine eigene CSV verteilt.
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
            throw NSError(domain: "WWFF", code: 1,
                          userInfo: [NSLocalizedDescriptionKey:
                            "CSV enthielt 0 Referenzen"])
        }
        try db.replaceAll(refs)
        db.setMeta("last_update",
                   value: ISO8601DateFormatter().string(from: Date()))
        db.setMeta("source", value: sourceLabel)
        db.setMeta("row_count", value: "\(refs.count)")
        status = .ready(date: Date(),
                        count: refs.count,
                        activeCount: refs.filter(\.isActive).count)
    }

    func ref(forReference reference: String) -> WWFFReference? {
        db.ref(reference: reference)
    }

    func search(_ query: String) -> [WWFFReference] {
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
    // Robust gegen verschiedene WWFF-Country-CSV-Formate. Erkennung läuft
    // über Header-Spaltennamen (case-insensitive, Whitespace ignoriert).
    // Erwartete Spalten (Reihenfolge variiert je nach Country-Coordinator):
    //   - Reference          → "reference", "wwff_ref", "ref"
    //   - Name               → "name", "park_name"
    //   - Country / DXCC     → "country", "dxcc"
    //   - IUCN-Category      → "iuc_cat", "category", "type"
    //   - Status             → "status" (active/inactive/deleted/deferred)
    //   - Latitude           → "lat", "latitude"
    //   - Longitude          → "lon", "long", "longitude"
    //
    // Format-Toleranz wie bei POTA/SOTA: byte-basierte State-Machine,
    // quoted fields mit Escaped-Quotes (""), CRLF + LF, leere Zeilen.
    static func parseCSV(data: Data) throws -> [WWFFReference] {
        let bytes = [UInt8](data)
        let n = bytes.count

        // Defaults für den dokumentierten Standard-Header. Werden bei
        // Header-Detection überschrieben.
        var iRef = 0, iName = 1
        var iCountry: Int? = nil
        var iCategory: Int? = nil
        var iStatus: Int? = nil
        var iLat: Int? = nil
        var iLon: Int? = nil
        var headerDetected = false

        var fields: [String] = []
        var fieldBytes: [UInt8] = []
        var inQuotes = false
        var refs: [WWFFReference] = []
        refs.reserveCapacity(50_000)

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
                             iCountry: &iCountry, iCategory: &iCategory,
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

            // Status: Active oder leerer String = aktiv. "deleted"/"deferred"/
            // "inactive" → false. Konservative Default-Annahme: aktiv.
            let statusRaw = atOpt(iStatus)?.lowercased() ?? ""
            let isActive = !(statusRaw.contains("delet")
                          || statusRaw.contains("defer")
                          || statusRaw.contains("inactive"))

            refs.append(WWFFReference(
                reference: ref,
                name: at(iName) ?? "",
                program: WWFFReference.programFromRef(ref),
                country: atOpt(iCountry),
                iucCategory: atOpt(iCategory),
                latitude: atOpt(iLat).flatMap(parseCoord),
                longitude: atOpt(iLon).flatMap(parseCoord),
                isActive: isActive,
                potaLink: nil
            ))
        }

        var i = 0
        while i < n {
            let b = bytes[i]
            if inQuotes {
                if b == 0x22 {                          // "
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
                case 0x22:                              // "
                    inQuotes = true
                case 0x2C:                              // ,
                    commitField()
                case 0x0A:                              // \n
                    commitRecord()
                case 0x0D:                              // \r
                    break
                default:
                    fieldBytes.append(b)
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
                                     iCountry: inout Int?, iCategory: inout Int?,
                                     iStatus: inout Int?,
                                     iLat: inout Int?, iLon: inout Int?) {
        for (idx, col) in header.enumerated() {
            let key = col.lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "_", with: "")
            switch key {
            case "reference", "wwffref", "ref":                     iRef = idx
            case "name", "parkname":                                iName = idx
            case "country", "dxcc", "dxccentity":                   iCountry = idx
            case "iuccat", "iuccategory", "category", "parktype", "type":
                                                                    iCategory = idx
            case "status", "state":                                 iStatus = idx
            case "lat", "latitude":                                 iLat = idx
            case "lon", "long", "longitude":                        iLon = idx
            default: break
            }
        }
    }

    /// Parst dezimale Lat/Lon-Strings. Manche WWFF-CSVs nutzen DMS-Format
    /// ("48°45'N 12°20'E") — vorerst nicht unterstützt, gibt nil zurück.
    /// Wenn das in der Praxis vorkommt, hier nachziehen.
    private static func parseCoord(_ s: String) -> Double? {
        let cleaned = s.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }
}
