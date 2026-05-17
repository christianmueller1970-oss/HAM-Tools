import Foundation

// pota.app-konformer Export. Die offizielle Doku verlangt **pro Park ein
// eigenes File** — Komma-Listen in MY_SIG_INFO sind nicht erlaubt. Wenn
// das Log ein Multi-Park-Hopping enthält (`myPotaRefs`), erzeugt der
// Exporter entsprechend N Files, jeweils mit allen QSOs, die diesen Park
// zugewiesen bekommen, und einem QSO-Datensatz, der nur den jeweiligen
// Park als `myPotaRef` führt (keine Komma-Liste).
//
// Filename-Schema: `{call}@{ref} YYYYMMDD.adi` — pota.app erkennt das
// Pattern und ordnet die Datei beim Hochladen automatisch zu.
struct POTAExporter: ProgramExporter {
    let menuTitle = "Für pota.app exportieren"
    let iconName  = "tree"

    static func applies(to logType: LogType) -> Bool {
        logType == .pota
    }

    func export(qsos: [QSO], log: Log, exportsDir: URL) throws -> [URL] {
        // Welche Parks aktiviert das Log überhaupt? Reihenfolge: Log-Setup
        // zuerst (Wizard hat sie definiert), dann QSO-spezifische Refs
        // (z.B. Multi-Park-Hopping mit Park-Switching während der Session).
        var allParks: [String] = ProgramExportRefs.split(
            primary: log.potaParkRef,
            multi: log.potaParkRefs)
        var seen = Set(allParks)
        for q in qsos {
            for ref in ProgramExportRefs.split(primary: q.myPotaRef, multi: q.myPotaRefs) {
                if seen.insert(ref).inserted { allParks.append(ref) }
            }
        }
        guard !allParks.isEmpty else { return [] }

        let call = ProgramExportCallsign.resolve(log: log, qsos: qsos)
        var written: [URL] = []

        for park in allParks {
            // QSOs, die diesen Park aktiviert haben — entweder direkt als
            // myPotaRef oder als Teil der myPotaRefs-Komma-Liste.
            let parkQSOs: [QSO] = qsos.compactMap { q in
                let refs = ProgramExportRefs.split(primary: q.myPotaRef, multi: q.myPotaRefs)
                let activatesThisPark = refs.contains(park)
                    || (refs.isEmpty && log.potaParkRef == park)
                guard activatesThisPark else { return nil }
                // Single-Park-Variante: nur diesen Park als myPotaRef,
                // keine Komma-Liste. Damit schreibt der ADIFCodec ein
                // pota.app-konformes MY_SIG_INFO ohne Komma.
                var copy = q
                copy.myPotaRef  = park
                copy.myPotaRefs = nil
                return copy
            }
            guard !parkQSOs.isEmpty else { continue }

            let fileName = ProgramExportFilename.adif(
                call: call, reference: park, date: log.startDate)
            let url = exportsDir.appendingPathComponent(fileName)
            let text = ADIFCodec.encode(qsos: parkQSOs, logName: "\(log.name) — \(park)")
            try text.write(to: url, atomically: true, encoding: .utf8)
            written.append(url)
        }

        return written
    }
}
