import SwiftUI

// Merge-Dialog für ADIF-Import. Zeigt wie viele QSOs in der Datei sind,
// wie viele davon im Ziel-Log schon vorhanden scheinen, und lässt den
// User entscheiden was passieren soll.
struct ADIFImportSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @Environment(\.dismiss) private var dismiss

    let sourceURL: URL
    let parsedQSOs: [QSO]
    let targetLog: Log
    let onCompleted: (Int) -> Void   // Anzahl tatsächlich importierter QSOs

    @State private var mergeStrategy: Strategy = .skipDuplicates

    enum Strategy: String, CaseIterable, Identifiable {
        case skipDuplicates = "Nur neue importieren (Duplikate überspringen)"
        case importAll      = "Alle importieren (auch Duplikate)"
        case createNewLog   = "In neues Logbuch importieren"
        var id: String { rawValue }
    }

    private var theme: AppTheme { themeManager.theme }

    private var analysis: (new: [QSO], duplicates: [QSO]) {
        manager.detectDuplicates(parsedQSOs, in: targetLog.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider().background(theme.separator)
            summary
            Divider().background(theme.separator)
            strategyPicker
            Spacer(minLength: 8)
            footer
        }
        .padding(20)
        .frame(width: 540)
        .background(theme.bgCard)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down")
                .font(.title2)
                .foregroundStyle(theme.accentBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text("ADIF importieren")
                    .font(.title3.bold())
                    .foregroundStyle(theme.textPrimary)
                Text(sourceURL.lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
    }

    private var summary: some View {
        let a = analysis
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundStyle(theme.textDim)
                Text("\(parsedQSOs.count) QSOs in der Datei")
                    .font(.subheadline.weight(.semibold))
            }
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(theme.accentGreen)
                Text("\(a.new.count) neue QSOs")
                    .font(.subheadline)
            }
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(theme.accentYellow)
                Text("\(a.duplicates.count) Duplikate (bereits in »\(targetLog.name)«)")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
            .font(.caption)
            Text("Duplikat-Erkennung: gleicher Call + Band + Mode innerhalb 5 min Toleranz.")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
                .padding(.top, 2)
        }
    }

    private var strategyPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Strategie")
                .font(.subheadline.bold())
                .foregroundStyle(theme.textSecondary)
            ForEach(Strategy.allCases) { strat in
                Button {
                    mergeStrategy = strat
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: mergeStrategy == strat
                              ? "largecircle.fill.circle"
                              : "circle")
                            .foregroundStyle(theme.accentBlue)
                        Text(strat.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                    }
                    .padding(8)
                    .background(mergeStrategy == strat ? theme.bgHover : theme.bgCard2)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Abbrechen") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Importieren") {
                performImport()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(parsedQSOs.isEmpty)
        }
    }

    private func performImport() {
        let a = analysis
        switch mergeStrategy {
        case .skipDuplicates:
            let n = manager.importQSOs(a.new, into: targetLog.id)
            onCompleted(n)
        case .importAll:
            let n = manager.importQSOs(parsedQSOs, into: targetLog.id)
            onCompleted(n)
        case .createNewLog:
            let stamp: String = {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH-mm"
                return f.string(from: Date())
            }()
            let newLogName = "Import \(sourceURL.deletingPathExtension().lastPathComponent) (\(stamp))"
            let newLog = Log(name: newLogName, type: .standard,
                             notes: "Importiert aus \(sourceURL.lastPathComponent)")
            manager.createLog(newLog)
            // Nach createLog ist der neue Log automatisch der aktive (openLog läuft)
            let qsosForNewLog: [QSO] = parsedQSOs.map { q in
                var copy = q
                copy.logID = newLog.id
                return copy
            }
            let n = manager.importQSOs(qsosForNewLog, into: newLog.id)
            onCompleted(n)
        }
    }
}
