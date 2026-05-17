import Foundation

// wwbota.net-konformer Export. Der WWBOTA-ADIF-Guide erlaubt ausdrücklich
// Komma-Listen in MY_SIG_INFO ("B/G-1524,B/G-0001"), also reicht ein
// einziges File pro Aktivierung — anders als bei pota.app.
//
// Filename-Schema: gleiches Muster wie WWFF (`{call}@{ref} YYYYMMDD.adi`).
// WWBOTA hat keine eigene Vorgabe dazu, aber das Pattern ist über die
// Outdoor-Community vertraut.
struct WWBOTAExporter: ProgramExporter {
    let menuTitle = "Für wwbota.net exportieren"
    let iconName  = "shield"

    static func applies(to logType: LogType) -> Bool {
        logType == .bota
    }

    func export(qsos: [QSO], log: Log, exportsDir: URL) throws -> [URL] {
        let logRefs = ProgramExportRefs.split(primary: log.botaRef, multi: log.botaRefs)
        let qsosForUpload: [QSO] = qsos.filter { q in
            let qsoRefs = ProgramExportRefs.split(primary: q.myBotaRef, multi: q.myBotaRefs)
            return !qsoRefs.isEmpty || !logRefs.isEmpty
        }
        guard !qsosForUpload.isEmpty else { return [] }

        let primaryRef = logRefs.first
            ?? ProgramExportRefs.split(primary: qsosForUpload.first?.myBotaRef,
                                       multi: qsosForUpload.first?.myBotaRefs).first
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
