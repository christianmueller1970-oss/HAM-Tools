import Foundation
import Combine

// Orchestrator für die SOTA-Summit-Datenbank:
//   - Lädt summitslist.csv von sotadata.org.uk
//   - Parst das CSV (17 Spalten, DD/MM/YYYY-Datumsformat) und schreibt
//     summits.sqlite atomar neu
//   - Hält Status (downloading / parsing / ready / error) als @Published
//   - Bietet Lookup + Search-API für UI
//
// Erste App-Inbetriebnahme: User wird beim ersten SOTA-Modus zum Initial-
// Download aufgefordert. Spätere Refreshes via manueller Button oder
// automatischer Hinweis nach 30 Tagen (Summits-Liste ist stabiler als POTA).
@MainActor
final class SotaSummitService: ObservableObject {

    enum Status: Equatable {
        case unknown
        case downloading
        case parsing
        case ready(date: Date?, count: Int, activeCount: Int)
        case errored(String)
    }

    @Published private(set) var status: Status = .unknown
    @Published private(set) var lastError: String?

    let db: SotaSummitDatabase

    // Datenquelle. Wenn sotadata.org.uk das CSV mal umzieht, hier zentral ändern.
    private let sourceURL = URL(string: "https://www.sotadata.org.uk/summitslist.csv")!

    // Schwellwert für "Aktualisierung anbieten" (in Tagen).
    static let refreshHintAfterDays: Int = 30

    init(dataRoot: AppDataRoot) throws {
        let url = dataRoot.cacheDir.appendingPathComponent("summits.sqlite")
        self.db = try SotaSummitDatabase(fileURL: url)
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
                throw NSError(domain: "SOTA", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey:
                                "HTTP \(http.statusCode) von sotadata.org.uk"])
            }
            status = .parsing
            let summits = try Self.parseCSV(data: data)
            guard !summits.isEmpty else {
                throw NSError(domain: "SOTA", code: 1,
                              userInfo: [NSLocalizedDescriptionKey:
                                "CSV enthielt 0 Summits"])
            }
            try db.replaceAll(summits)
            db.setMeta("last_update",
                       value: ISO8601DateFormatter().string(from: Date()))
            db.setMeta("source_url", value: sourceURL.absoluteString)
            db.setMeta("row_count", value: "\(summits.count)")
            status = .ready(date: Date(),
                            count: summits.count,
                            activeCount: summits.filter(\.isActive).count)
        } catch {
            lastError = error.localizedDescription
            status = .errored(error.localizedDescription)
        }
    }

    func summit(forReference ref: String) -> Summit? {
        db.summit(reference: ref)
    }

    func search(_ query: String) -> [Summit] {
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
    // Format sotadata.org.uk/summitslist.csv (Stand 2026-05-14):
    //   Zeile 1: "SOTA Summits List (Date=DD/MM/YYYY)"  ← skippen
    //   Zeile 2: Header (17 Spalten)
    //   Ab Zeile 3: Daten
    //
    // Spalten:
    //   0 SummitCode, 1 AssociationName, 2 RegionName, 3 SummitName,
    //   4 AltM, 5 AltFt, 6 GridRef1, 7 GridRef2,
    //   8 Longitude, 9 Latitude,
    //   10 Points, 11 BonusPoints,
    //   12 ValidFrom, 13 ValidTo,
    //   14 ActivationCount, 15 ActivationDate, 16 ActivationCall
    //
    // Datumsformat: DD/MM/YYYY (britisch)
    // is_active: valid_to >= today
    static func parseCSV(data: Data) throws -> [Summit] {
        let bytes = [UInt8](data)
        let n = bytes.count

        // Header-Spalten + Indices (mit Defaults für den dokumentierten Schema-Fall).
        var iRef = 0, iAssoc = 1, iRegion = 2, iName = 3
        var iAltM = 4, iAltFt = 5
        var iLon = 8, iLat = 9
        var iPoints = 10, iBonus = 11
        var iValidFrom = 12, iValidTo = 13
        var iActCount: Int? = 14, iLastAct: Int? = 15
        var headerDetected = false
        var skippedTitleRow = false

        var fields: [String] = []
        var fieldBytes: [UInt8] = []
        var inQuotes = false
        var summits: [Summit] = []
        summits.reserveCapacity(200_000)

        let today = Calendar(identifier: .gregorian)
            .startOfDay(for: Date())

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
            }

            // Zeile 1 = Titel "SOTA Summits List (Date=…)" → überspringen
            if !skippedTitleRow {
                skippedTitleRow = true
                if fields.first?.uppercased().contains("SUMMITS LIST") == true {
                    return
                }
                // Wenn die Titelzeile fehlt (zukünftiges Format), trotzdem
                // weiter — der nächste Block prüft auf den Header.
            }

            if !headerDetected {
                detectHeader(fields,
                             iRef: &iRef, iAssoc: &iAssoc, iRegion: &iRegion, iName: &iName,
                             iAltM: &iAltM, iAltFt: &iAltFt,
                             iLon: &iLon, iLat: &iLat,
                             iPoints: &iPoints, iBonus: &iBonus,
                             iValidFrom: &iValidFrom, iValidTo: &iValidTo,
                             iActCount: &iActCount, iLastAct: &iLastAct)
                headerDetected = true
                return
            }

            // Datenzeile
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

            let validFrom = at(iValidFrom).flatMap(Self.parseUKDate)
            let validTo   = at(iValidTo).flatMap(Self.parseUKDate)
            let isActive  = (validTo.map { $0 >= today }) ?? true

            summits.append(Summit(
                reference: ref,
                association: at(iAssoc) ?? "",
                region: at(iRegion) ?? "",
                name: at(iName) ?? "",
                altitudeM: at(iAltM).flatMap { Int($0) },
                altitudeFt: at(iAltFt).flatMap { Int($0) },
                latitude: at(iLat).flatMap { Double($0) },
                longitude: at(iLon).flatMap { Double($0) },
                points: at(iPoints).flatMap { Int($0) } ?? 0,
                bonusPoints: at(iBonus).flatMap { Int($0) } ?? 0,
                validFrom: validFrom,
                validTo: validTo,
                isActive: isActive,
                activationCount: atOpt(iActCount).flatMap { Int($0) },
                lastActivation: atOpt(iLastAct).flatMap(Self.parseUKDate)
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
        return summits
    }

    private static func detectHeader(_ header: [String],
                                     iRef: inout Int, iAssoc: inout Int,
                                     iRegion: inout Int, iName: inout Int,
                                     iAltM: inout Int, iAltFt: inout Int,
                                     iLon: inout Int, iLat: inout Int,
                                     iPoints: inout Int, iBonus: inout Int,
                                     iValidFrom: inout Int, iValidTo: inout Int,
                                     iActCount: inout Int?, iLastAct: inout Int?) {
        for (idx, col) in header.enumerated() {
            switch col.lowercased().replacingOccurrences(of: " ", with: "") {
            case "summitcode":                              iRef = idx
            case "associationname", "association":          iAssoc = idx
            case "regionname", "region":                    iRegion = idx
            case "summitname", "name":                      iName = idx
            case "altm":                                    iAltM = idx
            case "altft":                                   iAltFt = idx
            case "longitude":                               iLon = idx
            case "latitude":                                iLat = idx
            case "points":                                  iPoints = idx
            case "bonuspoints":                             iBonus = idx
            case "validfrom":                               iValidFrom = idx
            case "validto":                                 iValidTo = idx
            case "activationcount":                         iActCount = idx
            case "activationdate":                          iLastAct = idx
            default: break
            }
        }
    }

    // sotadata.org.uk liefert Daten als DD/MM/YYYY (UK-Format)
    private static func parseUKDate(_ s: String) -> Date? {
        let parts = s.split(separator: "/").map(String.init)
        guard parts.count == 3,
              let d = Int(parts[0]),
              let m = Int(parts[1]),
              let y = Int(parts[2]) else { return nil }
        var comps = DateComponents()
        comps.day = d
        comps.month = m
        comps.year = y
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)
    }
}
