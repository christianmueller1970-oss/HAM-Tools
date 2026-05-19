import Foundation
import Combine

// Super-Check-Partial-Service. Lädt eine Master-Call-Liste (MASTER.SCP-Format,
// plain ASCII, ein Call pro Zeile) und bietet Suggest-Lookup beim Tippen im
// Contest-Form.
//
// Zwei öffentliche Quellen werden unterstützt — beide Public Domain, beide
// wöchentlich aktualisiert:
//
// • supercheckpartial.com/MASTER.SCP — ~50k aktive Contest-Calls aus
//   Cabrillo-Uploads der letzten 24 Monate. Contest-Standard.
// • cdn.clublog.org/clublog.scp.gz — ~180k Calls, alle DXCC-Entities mit
//   >40 QSOs in 3 Jahren (Club Log). Breiter, fängt auch non-Contester.
//
// Beim ersten App-Start wird die im Bundle ausgelieferte MASTER.SCP geladen,
// damit die User sofort Vorschläge bekommen. Updates per HTTPS-Download
// landen in `<DataRoot>/Cache/SCP/` und überschreiben den Bundle-Stand.
@MainActor
final class SCPService: ObservableObject {

    enum Source: String, CaseIterable, Identifiable {
        case supercheckpartial
        case clublog

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .supercheckpartial: return "supercheckpartial.com"
            case .clublog:           return "Club Log"
            }
        }

        var downloadURL: URL {
            switch self {
            case .supercheckpartial: return URL(string: "https://www.supercheckpartial.com/MASTER.SCP")!
            case .clublog:           return URL(string: "https://cdn.clublog.org/clublog.scp.gz")!
            }
        }

        var isGzipped: Bool {
            self == .clublog
        }

        fileprivate var enabledDefaultsKey: String  { "scp.\(rawValue).enabled" }
        fileprivate var lastUpdateDefaultsKey: String { "scp.\(rawValue).lastUpdate" }
        fileprivate var cacheFileName: String       { "\(rawValue).scp" }
    }

    /// Wieviele Tage darf eine Quelle alt sein, bevor wir das Stale-Popup
    /// anzeigen?
    static let staleThresholdDays: Int = 14

    /// Alle geladenen Calls über alle aktiven Quellen (deduplicated).
    /// Substring-Lookup läuft direkt auf der sortierten Liste — bei ~180k
    /// Einträgen reicht ein Linear-Scan mit Early-Exit nach ~50 Treffern.
    @Published private(set) var allCalls: [String] = []
    @Published private(set) var lastError: String?
    @Published private(set) var isUpdating: Bool = false

    /// Pro Quelle: Anzahl Calls + Last-Update-Date. Settings-View bindet
    /// daran für die Live-Anzeige.
    @Published private(set) var perSourceStats: [Source: SourceStats] = [:]

    struct SourceStats: Equatable {
        var callCount: Int
        var lastUpdate: Date?
        var isFromBundle: Bool
    }

    private let dataRoot: AppDataRoot

    init(dataRoot: AppDataRoot) {
        self.dataRoot = dataRoot
        // Default-aktiviert: beide Quellen. User kann in Settings ausschalten.
        for source in Source.allCases {
            if UserDefaults.standard.object(forKey: source.enabledDefaultsKey) == nil {
                UserDefaults.standard.set(true, forKey: source.enabledDefaultsKey)
            }
        }
        Task { await reloadAll() }
    }

    // MARK: - Public API

    func isEnabled(_ source: Source) -> Bool {
        UserDefaults.standard.bool(forKey: source.enabledDefaultsKey)
    }

    func setEnabled(_ source: Source, _ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: source.enabledDefaultsKey)
        Task { await reloadAll() }
    }

    func lastUpdate(of source: Source) -> Date? {
        let ts = UserDefaults.standard.double(forKey: source.lastUpdateDefaultsKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    /// Sind alle aktiven Quellen älter als staleThresholdDays?
    /// Genutzt vom Auto-Stale-Popup beim App-Start.
    ///
    /// Bundle-Stand (noch kein User-Update) zählt als FRISCH — beim Build-
    /// Zeitpunkt ist die MASTER.SCP aktuell, also nerven wir den User nicht
    /// gleich beim ersten Start. Stale wird die Quelle erst, wenn der User
    /// einmal manuell aktualisiert hat und das mindestens 14 Tage zurückliegt.
    func allActiveSourcesStale() -> Bool {
        let active = Source.allCases.filter { isEnabled($0) }
        guard !active.isEmpty else { return false }
        let threshold = Date().addingTimeInterval(-Double(Self.staleThresholdDays * 86400))
        // Wenn keine Quelle je vom User aktualisiert wurde → nicht stale.
        let anyEverUpdated = active.contains { lastUpdate(of: $0) != nil }
        guard anyEverUpdated else { return false }
        // Mindestens ein User-Update gab es schon — jetzt prüfen ob ALLE
        // bekannten Updates älter als die Schwelle sind.
        return active.allSatisfy { source in
            guard let last = lastUpdate(of: source) else { return true }
            return last < threshold
        }
    }

    /// Suggestions zum Tipp-Pattern. Sortierung: exakte Präfix-Matches zuerst
    /// (kürzeste zuerst), dann Substring-Matches, dann nach Länge.
    ///
    /// Performance: Prefix-Matches via Binary-Search auf der sortierten Liste
    /// → O(log n). Substring-Match nur als Fallback wenn die Prefix-Treffer
    /// das Limit noch nicht erfüllen, und auch dann mit Early-Exit. Damit
    /// bleibt jeder Tastendruck im Sub-Millisekunden-Bereich, auch wenn beide
    /// Quellen (~230k Calls) aktiv sind.
    func suggestions(for partial: String, limit: Int = 8) -> [String] {
        let pat = partial.trimmingCharacters(in: .whitespaces).uppercased()
        guard pat.count >= 2 else { return [] }

        // Prefix-Match: Binary-Search nach erstem ≥pat, dann linear vorwärts
        // solange das Element noch mit pat beginnt.
        let prefixHits = prefixRange(pat: pat).map { allCalls[$0] }
            .sorted { $0.count < $1.count }

        if prefixHits.count >= limit {
            return Array(prefixHits.prefix(limit))
        }

        // Substring-Match-Fallback: linear, aber Prefix-Treffer überspringen
        // wir (die haben wir schon). Early-Exit sobald wir genug Kandidaten
        // gesammelt haben — 4× Limit reicht für stabile Sortierung.
        let prefixSet = Set(prefixHits)
        var substringHits: [String] = []
        let cap = limit * 4
        for call in allCalls {
            if prefixSet.contains(call) { continue }
            if call.contains(pat) {
                substringHits.append(call)
                if substringHits.count >= cap { break }
            }
        }
        substringHits.sort { $0.count < $1.count }

        let combined = prefixHits + substringHits
        return Array(combined.prefix(limit))
    }

    /// Binary-Search auf `allCalls` (sortiert): Range aller Indizes deren
    /// Element mit `pat` beginnt. Leerer Range wenn nichts matcht.
    private func prefixRange(pat: String) -> Range<Int> {
        let calls = allCalls
        guard !calls.isEmpty else { return 0..<0 }
        // Lower bound: erstes Element >= pat
        var lo = 0
        var hi = calls.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if calls[mid] < pat { lo = mid + 1 } else { hi = mid }
        }
        let start = lo
        // Upper bound: erstes Element das NICHT mit pat beginnt
        hi = calls.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if calls[mid].hasPrefix(pat) { lo = mid + 1 } else { hi = mid }
        }
        return start..<lo
    }

    /// Manueller Update-Trigger pro Quelle. Lädt die Datei, parsed sie,
    /// schreibt sie ins Cache-Verzeichnis und merkt sich den Timestamp.
    func updateFromSource(_ source: Source) async {
        isUpdating = true
        defer { isUpdating = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: source.downloadURL)
            let raw = source.isGzipped ? try gunzip(data) : data
            try persistRawFile(raw, for: source)
            UserDefaults.standard.set(Date().timeIntervalSince1970,
                                       forKey: source.lastUpdateDefaultsKey)
            await reloadAll()
            lastError = nil
        } catch {
            lastError = "Update von \(source.displayName) fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    /// Beide aktiven Quellen sequenziell aktualisieren — bequemer Master-Update.
    func updateAllActive() async {
        for source in Source.allCases where isEnabled(source) {
            await updateFromSource(source)
        }
    }

    // MARK: - Internals

    private var scpCacheDir: URL {
        let dir = dataRoot.cacheDir.appendingPathComponent("SCP", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cacheFileURL(for source: Source) -> URL {
        scpCacheDir.appendingPathComponent(source.cacheFileName)
    }

    private func persistRawFile(_ data: Data, for source: Source) throws {
        let url = cacheFileURL(for: source)
        try data.write(to: url, options: .atomic)
    }

    /// Lädt für die übergebene Quelle den besten verfügbaren Datenstand:
    /// 1. Cache-Datei wenn vorhanden, sonst
    /// 2. Bundle-Datei (Sources/HAMRechner/Content/MASTER.SCP — nur für die
    ///    Default-Quelle supercheckpartial, andere haben keinen Bundle-Stand).
    private func loadRawFile(for source: Source) -> (calls: Set<String>, fromBundle: Bool) {
        let cacheURL = cacheFileURL(for: source)
        if FileManager.default.fileExists(atPath: cacheURL.path),
           let data = try? Data(contentsOf: cacheURL),
           let text = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8) {
            return (parseCallList(text), false)
        }
        if source == .supercheckpartial,
           let bundleURL = Bundle.module.url(forResource: "MASTER", withExtension: "SCP"),
           let data = try? Data(contentsOf: bundleURL),
           let text = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8) {
            return (parseCallList(text), true)
        }
        return ([], false)
    }

    private func parseCallList(_ text: String) -> Set<String> {
        var out: Set<String> = []
        out.reserveCapacity(200_000)
        // Wichtig: supercheckpartial.com und Club Log liefern CRLF. Mit
        // `components(separatedBy: .newlines)` werden beide LF und CRLF
        // sauber zerlegt (anders als String.split(whereSeparator:), das in
        // einigen Swift-Versionen die ganze Datei als ein Element liefert).
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("!") { continue }
            let upper = line.uppercased()
            // Defensiv: Calls bestehen aus alphanum + optional "/". Linien mit
            // Spaces oder anderen Sonderzeichen sind keine echten Calls.
            if upper.unicodeScalars.allSatisfy({ Self.isCallChar($0) }) {
                out.insert(upper)
            }
        }
        return out
    }

    private static func isCallChar(_ s: Unicode.Scalar) -> Bool {
        (s >= "0" && s <= "9") || (s >= "A" && s <= "Z") || s == "/"
    }

    /// Lädt beide Quellen, deduplicated über Union, schreibt in `allCalls`
    /// (sortiert für deterministisches Suggest-Verhalten) + `perSourceStats`.
    private func reloadAll() async {
        let activeSources = Source.allCases.filter { isEnabled($0) }
        var combined: Set<String> = []
        var stats: [Source: SourceStats] = [:]
        for source in activeSources {
            let (calls, fromBundle) = loadRawFile(for: source)
            combined.formUnion(calls)
            stats[source] = SourceStats(
                callCount: calls.count,
                lastUpdate: lastUpdate(of: source),
                isFromBundle: fromBundle
            )
        }
        let sorted = combined.sorted()
        self.allCalls = sorted
        self.perSourceStats = stats
    }

    // MARK: - GZip-Decode (Club Log liefert clublog.scp.gz)

    /// Minimaler GZIP-Decoder via `Compression.framework`. Erwartet das
    /// 10-Byte GZIP-Header-Format (RFC 1952) — die Club-Log-Datei nutzt
    /// keine Optional-Felder, daher reicht der einfache Stripping-Pfad.
    private func gunzip(_ data: Data) throws -> Data {
        try GZipDecoder.decode(data)
    }
}

// MARK: - GZip-Decoder

import Compression

private enum GZipDecoder {

    enum DecodeError: Error, LocalizedError {
        case notGzipped
        case decompressFailed
        var errorDescription: String? {
            switch self {
            case .notGzipped:        return "Datei ist kein gültiges GZIP."
            case .decompressFailed:  return "GZIP-Dekompression fehlgeschlagen."
            }
        }
    }

    /// Strippt den GZIP-Header (RFC 1952) und führt rohe DEFLATE-Dekompression
    /// über Compression.framework aus. Funktioniert für `clublog.scp.gz`
    /// (keine optionalen Header-Felder).
    static func decode(_ data: Data) throws -> Data {
        guard data.count > 18 else { throw DecodeError.notGzipped }
        guard data[0] == 0x1f, data[1] == 0x8b else { throw DecodeError.notGzipped }
        let flg = data[3]
        var offset = 10
        if flg & 0x04 != 0 {                       // FEXTRA
            let xlen = Int(data[offset]) | (Int(data[offset+1]) << 8)
            offset += 2 + xlen
        }
        if flg & 0x08 != 0 {                       // FNAME
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flg & 0x10 != 0 {                       // FCOMMENT
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flg & 0x02 != 0 { offset += 2 }         // FHCRC
        // Letzte 8 Bytes = CRC32 + ISIZE, abschneiden
        let payload = data.subdata(in: offset..<(data.count - 8))

        // Großzügig dimensionierter Output-Buffer — clublog.scp.gz hat
        // typischerweise ~5x Expansionsfaktor.
        let capacity = max(payload.count * 8, 4 * 1024 * 1024)
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { dst.deallocate() }

        let written = payload.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Int in
            guard let base = raw.baseAddress else { return 0 }
            return compression_decode_buffer(
                dst, capacity,
                base.assumingMemoryBound(to: UInt8.self), payload.count,
                nil, COMPRESSION_ZLIB
            )
        }
        guard written > 0 else { throw DecodeError.decompressFailed }
        return Data(bytes: dst, count: written)
    }
}
