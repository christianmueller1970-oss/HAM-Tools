import Foundation

// wwff.co-konformer Export. WWFF nimmt Komma-Listen in MY_SIG_INFO an
// (anders als pota.app), also reicht ein einziges File pro Aktivierung
// auch bei Multi-Ref-Hopping. Bei mehreren Refs wird der primäre Ref
// (erster in der Liste) für den Filename verwendet.
//
// Filename-Schema: `{call}@{ref} YYYYMMDD.adi` — vom WWFF-FAQ vorgegeben,
// wird vom National-Coordinator-Workflow erwartet.
struct WWFFExporter: ProgramExporter {
    let menuTitle = "Für wwff.co exportieren"
    let iconName  = "leaf"

    static func applies(to logType: LogType) -> Bool {
        logType == .wwff
    }

    func export(qsos: [QSO], log: Log, exportsDir: URL) throws -> [URL] {
        // Activator-QSOs: alles mit eigener WWFF-Ref im QSO oder zumindest
        // der Log-Default-Ref (für QSOs, die vor der Per-QSO-Befüllung
        // angelegt wurden).
        let logRefs = ProgramExportRefs.split(primary: log.wwffRef, multi: log.wwffRefs)
        let qsosForUpload: [QSO] = qsos.filter { q in
            let qsoRefs = ProgramExportRefs.split(primary: q.myWwffRef, multi: q.myWwffRefs)
            return !qsoRefs.isEmpty || !logRefs.isEmpty
        }
        guard !qsosForUpload.isEmpty else { return [] }

        // Primärer Ref für den Filename — Log-Default schlägt QSO-Ref,
        // weil der Wizard den Hauptpark beim Log-Anlegen festgelegt hat.
        let primaryRef = logRefs.first
            ?? ProgramExportRefs.split(primary: qsosForUpload.first?.myWwffRef,
                                       multi: qsosForUpload.first?.myWwffRefs).first
        guard let ref = primaryRef else { return [] }

        let call = ProgramExportCallsign.resolve(log: log, qsos: qsos)
        let fileName = ProgramExportFilename.adif(
            call: call, reference: ref, date: log.startDate)
        let url = exportsDir.appendingPathComponent(fileName)
        let text = ADIFCodec.encode(qsos: qsosForUpload, logName: log.name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return [url]
    }
}
