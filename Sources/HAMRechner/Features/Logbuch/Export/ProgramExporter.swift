import Foundation

// Programm-spezifischer Log-Exporter für Outdoor-Programme, deren
// Upload-Format strukturell vom generischen ADIF-Export abweicht.
// Aktuell genutzt für SOTA (sotadata.org.uk CSV V2, kein ADIF).
// POTA/WWFF/WWBOTA brauchen keinen eigenen Exporter mehr — der
// generische ADIFCodec ist seit Phase 1+1b plattform-konform.
//
// Ein Exporter darf MEHRERE Files schreiben (z.B. künftiger POTA-
// Multi-Park-Split), gibt aber alle URLs zurück, damit das UI sie
// im Finder revealen kann.
protocol ProgramExporter {
    /// Anzeige-Titel im UI-Button bzw. Menü, z.B. "Für pota.app exportieren".
    var menuTitle: String { get }

    /// SF-Symbol für den UI-Button.
    var iconName: String { get }

    /// Greift dieser Exporter für den gegebenen Log-Typ?
    static func applies(to logType: LogType) -> Bool

    /// Schreibt das Log-Output und liefert die geschriebenen URLs zurück
    /// (mind. eine; mehrere bei Programmen mit Split-pro-Ref wie POTA).
    func export(qsos: [QSO], log: Log, exportsDir: URL) throws -> [URL]
}

// MARK: - Filename-Helper

enum ProgramExportFilename {
    /// Bildet das Plattform-übliche Filename-Schema `{call}@{ref} YYYYMMDD.adi`
    /// (WWFF-Original, von POTA & WWBOTA übernommen). `/` im Call wird zu
    /// `_`, weil macOS-Dateisystem keine Slashes im Filename erlaubt.
    static func adif(call: String, reference: String, date: Date) -> String {
        let safeCall = call.replacingOccurrences(of: "/", with: "_")
        let safeRef  = reference.replacingOccurrences(of: "/", with: "_")
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        return "\(safeCall)@\(safeRef) \(df.string(from: date)).adi"
    }
}

// MARK: - Callsign-Resolver

enum ProgramExportCallsign {
    /// Activator-Call für Filename und Header. Reihenfolge:
    /// 1. Log.usedCallsign (Pro-Log-Override, z.B. HB9HJI/P)
    /// 2. Erster QSO mit operatorCall/stationCall (Fallback wenn Log keinen Override hat)
    /// 3. UserDefaults "callsign" (globaler Default aus Stations-Tab)
    /// 4. "UNKNOWN" — sollte praktisch nie passieren, weil Wizard das verlangt
    static func resolve(log: Log, qsos: [QSO]) -> String {
        if let c = log.usedCallsign?.trimmingCharacters(in: .whitespaces),
           !c.isEmpty { return c.uppercased() }
        for q in qsos {
            if let c = q.operatorCall?.trimmingCharacters(in: .whitespaces),
               !c.isEmpty { return c.uppercased() }
            if let c = q.stationCall?.trimmingCharacters(in: .whitespaces),
               !c.isEmpty { return c.uppercased() }
        }
        if let c = UserDefaults.standard.string(forKey: "callsign")?
            .trimmingCharacters(in: .whitespaces), !c.isEmpty {
            return c.uppercased()
        }
        return "UNKNOWN"
    }
}

// MARK: - Factory

enum ProgramExporterFactory {
    /// Liefert den passenden Exporter für einen Log-Typ — oder nil, wenn
    /// das Programm bereits durch den generischen ADIF-Export abgedeckt
    /// ist. Aktuell nur SOTA, weil sotadata.org.uk kein ADIF frisst und
    /// das CSV-V2-Format strukturell anders ist. Für POTA/WWFF/WWBOTA
    /// reicht der generische ADIFCodec-Export (seit Phase 1+1b plattform-
    /// konform).
    static func exporter(for logType: LogType) -> ProgramExporter? {
        if SOTACSVExporter.applies(to: logType) { return SOTACSVExporter() }
        return nil
    }
}

// MARK: - Reference-Splitter

enum ProgramExportRefs {
    /// Zerlegt das primäre Ref-Feld + die optionale Komma-Liste in ein
    /// dedupliziertes Array. Erhält die Reihenfolge (primärer Ref zuerst).
    static func split(primary: String?, multi: String?) -> [String] {
        var seen: Set<String> = []
        var out: [String] = []
        let cleanedPrimary = primary?.trimmingCharacters(in: .whitespaces)
        if let p = cleanedPrimary, !p.isEmpty, seen.insert(p).inserted {
            out.append(p)
        }
        if let raw = multi {
            for piece in raw.split(separator: ",") {
                let r = piece.trimmingCharacters(in: .whitespaces)
                if !r.isEmpty, seen.insert(r).inserted { out.append(r) }
            }
        }
        return out
    }
}
