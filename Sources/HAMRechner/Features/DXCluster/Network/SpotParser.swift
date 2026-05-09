import Foundation

// Parses DXSpider telnet lines.
// Format: DX de SPOTTER: FREQ  DX_CALL  COMMENT  HHMZ
struct SpotParser {
    // Allow # @ _ in callsigns — DXSpider uses OE5XFM-# for routed spots
    private static let callChar = #"[A-Z0-9/\-#@_]+"#

    private static let pattern = try! NSRegularExpression(
        pattern: #"^DX\s+de\s+([A-Z0-9/\-#@_]+)\s*:\s*(\d+\.?\d*)\s+([A-Z0-9/\-#@_]+)\s+(.*?)\s+(\d{4}Z)\s*$"#,
        options: [.caseInsensitive]
    )
    private static let patternSimple = try! NSRegularExpression(
        pattern: #"^DX\s+de\s+([A-Z0-9/\-#@_]+)\s*:\s*(\d+\.?\d*)\s+([A-Z0-9/\-#@_]+)\s*(.*?)$"#,
        options: [.caseInsensitive]
    )

    static func parse(_ line: String, source: String) -> DXSpot? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.uppercased().hasPrefix("DX DE") else { return nil }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        var spotter, freqStr, dxCall, comment, spotTime: String
        spotter = ""; freqStr = ""; dxCall = ""; comment = ""; spotTime = ""

        if let m = pattern.firstMatch(in: trimmed, range: range) {
            spotter   = group(m, 1, in: trimmed)
            freqStr   = group(m, 2, in: trimmed)
            dxCall    = group(m, 3, in: trimmed)
            comment   = group(m, 4, in: trimmed)
            spotTime  = group(m, 5, in: trimmed)
        } else if let m = patternSimple.firstMatch(in: trimmed, range: range) {
            spotter  = group(m, 1, in: trimmed)
            freqStr  = group(m, 2, in: trimmed)
            dxCall   = group(m, 3, in: trimmed)
            comment  = group(m, 4, in: trimmed)
        } else {
            return nil
        }

        guard let frequency = Double(freqStr) else { return nil }

        let band = freqToBand(frequency)
        let mode = freqToMode(frequency, comment: comment)

        let dxEntry      = lookupPrefix(dxCall.uppercased())
        let spotterEntry = lookupPrefix(spotter.uppercased())

        var spot = DXSpot(
            spotter:    spotter.uppercased(),
            frequency:  frequency,
            dxCall:     dxCall.uppercased(),
            comment:    comment,
            spotTime:   spotTime,
            source:     source
        )
        spot.band       = band
        spot.mode       = mode
        spot.country    = dxEntry.country
        spot.continent  = dxEntry.continent
        spot.lat        = dxEntry.lat
        spot.lon        = dxEntry.lon
        spot.spotterLat = spotterEntry.lat
        spot.spotterLon = spotterEntry.lon
        spot.timestamp  = Date()

        return spot.isValid ? spot : nil
    }

    private static func group(_ match: NSTextCheckingResult, _ i: Int, in s: String) -> String {
        guard let r = Range(match.range(at: i), in: s) else { return "" }
        return String(s[r]).trimmingCharacters(in: .whitespaces)
    }
}
