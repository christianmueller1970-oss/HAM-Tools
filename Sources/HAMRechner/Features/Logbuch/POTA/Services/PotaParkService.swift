import Foundation
import Combine

// Orchestrator für die POTA-Park-Datenbank:
//   - Lädt all_parks_ext.csv von pota.app
//   - Parst das CSV und schreibt parks.sqlite atomar neu
//   - Hält Status (downloading / parsing / ready / error) als @Published
//   - Bietet Lookup + Search-API für UI
//
// Erste App-Inbetriebnahme: User wird beim ersten POTA-Modus zum Initial-
// Download aufgefordert. Spätere Refreshes via manueller Button oder
// automatischer Hinweis nach 14 Tagen.
@MainActor
final class PotaParkService: ObservableObject {

    enum Status: Equatable {
        case unknown                          // DB leer / nie geladen
        case downloading                      // Fetch läuft
        case parsing                          // CSV parsen + insert
        case ready(date: Date?, count: Int)   // einsatzbereit
        case errored(String)
    }

    @Published private(set) var status: Status = .unknown
    @Published private(set) var lastError: String?

    let db: PotaParkDatabase

    // Datenquelle. Wenn pota.app das CSV mal umzieht, hier zentral ändern.
    private let sourceURL = URL(string: "https://pota.app/all_parks_ext.csv")!

    // Schwellwert für "Aktualisierung anbieten" (in Tagen).
    static let refreshHintAfterDays: Int = 14

    init(dataRoot: AppDataRoot) throws {
        let url = dataRoot.cacheDir.appendingPathComponent("parks.sqlite")
        self.db = try PotaParkDatabase(fileURL: url)
        self.refreshStatusFromDB()
    }

    // MARK: - Public API

    func refresh() async {
        status = .downloading
        lastError = nil

        do {
            let (data, response) = try await URLSession.shared.data(from: sourceURL)
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                throw NSError(domain: "POTA", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey:
                                "HTTP \(http.statusCode) von pota.app"])
            }
            status = .parsing
            let parks = try Self.parseCSV(data: data)
            guard !parks.isEmpty else {
                throw NSError(domain: "POTA", code: 1,
                              userInfo: [NSLocalizedDescriptionKey:
                                "CSV enthielt 0 Parks"])
            }
            try db.replaceAll(parks)
            db.setMeta("last_update",
                       value: ISO8601DateFormatter().string(from: Date()))
            db.setMeta("source_url", value: sourceURL.absoluteString)
            db.setMeta("row_count", value: "\(parks.count)")
            status = .ready(date: Date(), count: parks.count)
        } catch {
            lastError = error.localizedDescription
            status = .errored(error.localizedDescription)
        }
    }

    func park(forReference ref: String) -> Park? {
        db.park(reference: ref)
    }

    func search(_ query: String) -> [Park] {
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
            status = .ready(date: db.lastUpdate, count: count)
        }
    }

    // MARK: - CSV-Parser
    //
    // Byte-basierter State-Machine-Parser. Verarbeitet:
    //   - CRLF + LF line endings
    //   - Quoted fields (",...,")
    //   - Escaped quotes innerhalb ("" = literal ")
    //   - Leere quoted fields ("")
    // pota.app/all_parks_ext.csv hat alle drei Patterns, deshalb robust nötig.
    static func parseCSV(data: Data) throws -> [Park] {
        let bytes = [UInt8](data)
        let n = bytes.count

        // Header-Spalten + Indices
        var iRef = 0, iName = 1, iActive = 2
        var iEntId: Int?, iLocDesc: Int?, iLat: Int?, iLon: Int?, iGrid: Int?
        var headerDetected = false

        var fields: [String] = []
        var fieldBytes: [UInt8] = []
        var inQuotes = false
        var rowIndex = 0
        var parks: [Park] = []
        parks.reserveCapacity(100_000)

        func currentField() -> String {
            String(decoding: fieldBytes, as: UTF8.self)
        }

        func commitField() {
            fields.append(currentField())
            fieldBytes.removeAll(keepingCapacity: true)
        }

        func commitRecord() {
            commitField()
            defer {
                fields.removeAll(keepingCapacity: true)
                rowIndex += 1
            }
            if !headerDetected {
                detectHeader(fields, iRef: &iRef, iName: &iName, iActive: &iActive,
                             iEntId: &iEntId, iLocDesc: &iLocDesc,
                             iLat: &iLat, iLon: &iLon, iGrid: &iGrid)
                headerDetected = true
                return
            }
            // Datenzeile
            if fields.count <= iRef { return }
            let ref = fields[iRef].trimmingCharacters(in: .whitespacesAndNewlines)
            if ref.isEmpty { return }
            let name = fields.count > iName ? fields[iName] : ""
            let active = fields.count > iActive
                && (fields[iActive] == "1" || fields[iActive].lowercased() == "true")
            func at(_ idx: Int?) -> String? {
                guard let idx, fields.count > idx else { return nil }
                let s = fields[idx]
                return s.isEmpty ? nil : s
            }
            parks.append(Park(
                reference: ref,
                name: name,
                active: active,
                entityId: at(iEntId).flatMap { Int($0) },
                locationDesc: at(iLocDesc),
                latitude: at(iLat).flatMap { Double($0) },
                longitude: at(iLon).flatMap { Double($0) },
                grid: at(iGrid)
            ))
        }

        var i = 0
        while i < n {
            let b = bytes[i]
            if inQuotes {
                if b == 0x22 {                          // "
                    if i + 1 < n && bytes[i + 1] == 0x22 {
                        // Escaped "" → literal "
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
                    break                               // skip, LF folgt
                default:
                    fieldBytes.append(b)
                }
            }
            i += 1
        }
        // Letzte Zeile ohne Trailing-Newline
        if !fieldBytes.isEmpty || !fields.isEmpty {
            commitRecord()
        }
        return parks
    }

    private static func detectHeader(_ header: [String],
                                     iRef: inout Int, iName: inout Int, iActive: inout Int,
                                     iEntId: inout Int?, iLocDesc: inout Int?,
                                     iLat: inout Int?, iLon: inout Int?, iGrid: inout Int?) {
        for (idx, col) in header.enumerated() {
            switch col.lowercased() {
            case "reference":                       iRef = idx
            case "name":                            iName = idx
            case "active":                          iActive = idx
            case "entityid", "entity_id":           iEntId = idx
            case "locationdesc", "location_desc":   iLocDesc = idx
            case "latitude":                        iLat = idx
            case "longitude":                       iLon = idx
            case "grid":                            iGrid = idx
            default: break
            }
        }
    }
}
