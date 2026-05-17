import Foundation

// Programm-spezifischer Log-Exporter. Jedes Outdoor-Programm (POTA, SOTA,
// WWFF, WWBOTA) hat seine eigenen Tag-/Format-/Filename-Anforderungen für
// den Upload zur jeweiligen Plattform. Ein generisches "Export ADIF"
// reicht nicht — pota.app z.B. verlangt pro Park ein eigenes File mit
// Filename-Pattern `{call}@{ref} YYYYMMDD.adi`.
//
// Ein Exporter darf MEHRERE Files schreiben (Multi-Park-Hopping bei POTA),
// gibt aber genau eine repräsentative URL zurück, die im UI angezeigt
// wird — bei Mehrfach-Output ist das der Exports-Ordner selbst.
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
    /// das Programm keinen eigenen Export-Pfad hat (Standard/Contest).
    static func exporter(for logType: LogType) -> ProgramExporter? {
        if POTAExporter.applies(to: logType)   { return POTAExporter() }
        if WWFFExporter.applies(to: logType)   { return WWFFExporter() }
        if WWBOTAExporter.applies(to: logType) { return WWBOTAExporter() }
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
