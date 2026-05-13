import SwiftUI
import AppKit

struct CabrilloExportSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var contests: ContestService
    @Environment(\.dismiss) private var dismiss

    @AppStorage("callsign")   private var stationCall = ""
    @AppStorage("qthLocator") private var qthLocator  = ""

    // Header-Felder (persistiert pro App-Start, damit User nicht jedes Mal alles tippen muss)
    @AppStorage("cabrillo.contestID")        private var contestID:        String = ""
    @AppStorage("cabrillo.operatorName")     private var operatorName:     String = ""
    @AppStorage("cabrillo.email")            private var email:            String = ""
    @AppStorage("cabrillo.location")         private var location:         String = ""
    @AppStorage("cabrillo.categoryOperator") private var categoryOperator: String = "SINGLE-OP"
    @AppStorage("cabrillo.categoryBand")     private var categoryBand:     String = "ALL"
    @AppStorage("cabrillo.categoryMode")     private var categoryMode:     String = "MIXED"
    @AppStorage("cabrillo.categoryPower")    private var categoryPower:    String = "LOW"
    @AppStorage("cabrillo.categoryStation")  private var categoryStation:  String = "FIXED"
    @AppStorage("cabrillo.categoryTime")     private var categoryTime:     String = "24-HOURS"
    @AppStorage("cabrillo.claimedScore")     private var claimedScore:     String = ""
    @AppStorage("cabrillo.club")             private var club:             String = ""
    @AppStorage("cabrillo.sentExchange")     private var sentExchange:     String = ""
    @State private var soapbox: String = ""

    @State private var resultURL: URL? = nil
    @State private var showAlert: Bool = false

    private var theme: AppTheme { themeManager.theme }

    private static let contestIDExamples = [
        "CQ-WW-CW", "CQ-WW-SSB", "CQ-WPX-CW", "CQ-WPX-SSB", "CQ-WPX-RTTY",
        "ARRL-DX-CW", "ARRL-DX-SSB", "IARU-HF", "WAE-DX-CW", "WAE-DX-SSB",
        "ARRL-FD", "DARC-WAG", "HELVETIA"
    ]
    private static let categoriesOperator = ["SINGLE-OP", "MULTI-OP", "MULTI-OP-SINGLE", "CHECKLOG"]
    private static let categoriesBand     = ["ALL", "160M", "80M", "40M", "20M", "15M", "10M", "6M"]
    private static let categoriesMode     = ["MIXED", "CW", "SSB", "RTTY", "DIGI"]
    private static let categoriesPower    = ["HIGH", "LOW", "QRP"]
    private static let categoriesStation  = ["FIXED", "PORTABLE", "MOBILE", "EXPEDITION"]
    private static let categoriesTime     = ["24-HOURS", "12-HOURS", "8-HOURS", "6-HOURS"]

    private var canExport: Bool {
        !contestID.trimmingCharacters(in: .whitespaces).isEmpty
            && !stationCall.trimmingCharacters(in: .whitespaces).isEmpty
            && manager.currentLogID != nil
            && !manager.currentQSOs.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider().background(theme.separator)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    contestSection
                    categorySection
                    scoreSection
                    soapboxSection
                }
                .padding(.horizontal, 4)
            }
            Divider().background(theme.separator)
            footer
        }
        .padding(16)
        .frame(width: 560, height: 600)
        .background(theme.bgCard)
        .onAppear { prefillFromContestLogIfAvailable() }
        .alert("Cabrillo-Export erfolgreich", isPresented: $showAlert, presenting: resultURL) { url in
            Button("Im Finder zeigen") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            Button("Schliessen", role: .cancel) { dismiss() }
        } message: { url in
            Text("\(manager.currentQSOs.count) QSOs exportiert nach \(url.lastPathComponent)")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "stopwatch")
                .font(.title2)
                .foregroundStyle(theme.accentBlue)
            VStack(alignment: .leading, spacing: 1) {
                Text("Cabrillo V3 Export")
                    .font(.title3.bold())
                Text("Für Contest-Log-Einreichungen (ARRL, CQ, IARU, …)")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Text("\(manager.currentQSOs.count) QSOs im aktiven Log")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var contestSection: some View {
        GroupBox("Contest") {
            VStack(alignment: .leading, spacing: 8) {
                row("Contest-ID *") {
                    TextField("z.B. CQ-WW-CW", text: $contestID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Menu {
                        ForEach(Self.contestIDExamples, id: \.self) { id in
                            Button(id) { contestID = id }
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                    .menuStyle(.borderlessButton)
                }
                row("Callsign *") {
                    Text(stationCall.isEmpty ? "(in Einstellungen → Station setzen)" : stationCall)
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundStyle(stationCall.isEmpty ? theme.accentOrange : theme.accentBlue)
                }
                row("Name") {
                    TextField("Voller Name", text: $operatorName)
                        .textFieldStyle(.roundedBorder)
                }
                row("E-Mail") {
                    TextField("contest@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                }
                row("Grid-Locator") {
                    Text(qthLocator.isEmpty ? "(in Einstellungen → Station setzen)" : qthLocator)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(qthLocator.isEmpty ? theme.accentOrange : theme.textSecondary)
                }
                row("Location") {
                    TextField("z.B. HBR, Schweiz", text: $location)
                        .textFieldStyle(.roundedBorder)
                }
                row("Sent-Exchange") {
                    TextField("z.B. 14 (CQ-Zone), oder 599 + Serial", text: $sentExchange)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .padding(4)
        }
    }

    private var categorySection: some View {
        GroupBox("Kategorie") {
            VStack(alignment: .leading, spacing: 8) {
                row("Operator") {
                    Picker("", selection: $categoryOperator) {
                        ForEach(Self.categoriesOperator, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
                row("Band") {
                    Picker("", selection: $categoryBand) {
                        ForEach(Self.categoriesBand, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
                row("Mode") {
                    Picker("", selection: $categoryMode) {
                        ForEach(Self.categoriesMode, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
                row("Power") {
                    Picker("", selection: $categoryPower) {
                        ForEach(Self.categoriesPower, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
                row("Station") {
                    Picker("", selection: $categoryStation) {
                        ForEach(Self.categoriesStation, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
                row("Zeit") {
                    Picker("", selection: $categoryTime) {
                        ForEach(Self.categoriesTime, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
            }
            .padding(4)
        }
    }

    private var scoreSection: some View {
        GroupBox("Wertung") {
            VStack(alignment: .leading, spacing: 8) {
                row("Claimed Score") {
                    TextField("z.B. 123456", text: $claimedScore)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
                row("Club") {
                    TextField("z.B. HB9 Club", text: $club)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(4)
        }
    }

    private var soapboxSection: some View {
        GroupBox("Soapbox (Kommentar)") {
            TextEditor(text: $soapbox)
                .font(.body)
                .frame(minHeight: 60, maxHeight: 100)
                .padding(4)
                .background(theme.bgCard2)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }

    private var footer: some View {
        HStack {
            if !canExport {
                Label(missingHint, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(theme.accentOrange)
            }
            Spacer()
            Button("Abbrechen") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Exportieren") {
                exportNow()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!canExport)
        }
    }

    private var missingHint: String {
        if stationCall.isEmpty { return "Callsign fehlt — in Einstellungen → Station setzen" }
        if contestID.trimmingCharacters(in: .whitespaces).isEmpty { return "Contest-ID erforderlich" }
        if manager.currentQSOs.isEmpty { return "Aktives Log enthält keine QSOs" }
        return ""
    }

    private func row<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 110, alignment: .trailing)
            content()
            Spacer()
        }
    }

    /// Wenn das aktive Log ein Contest-Log ist, übernimm Contest-ID und alle Cabrillo-
    /// Kategorien direkt aus dem Log (vom Wizard gesetzt). Überschreibt die
    /// gespeicherten Defaults nur, wenn das Log echte Werte mitbringt.
    private func prefillFromContestLogIfAvailable() {
        guard let logID = manager.currentLogID,
              let log = manager.logs.first(where: { $0.id == logID }),
              log.type == .contest else { return }

        if let id = log.contestID, !id.isEmpty {
            contestID = id
        }
        if let cat = log.contestCategory, !cat.isEmpty {
            categoryOperator = cat
        }
        // Template-Defaults für die anderen Kategorien (Power/Band/Mode/Station/Time)
        // nachziehen, wenn der User sie noch nicht angetasst hat (also Default-State).
        if let id = log.contestID, let tpl = contests.template(forID: id),
           let d = tpl.defaultCategories {
            if let v = d.power,    categoryPower    == "LOW"        { categoryPower    = v }
            if let v = d.band,     categoryBand     == "ALL"        { categoryBand     = v }
            if let v = d.mode,     categoryMode     == "MIXED"      { categoryMode     = v }
            if let v = d.station,  categoryStation  == "FIXED"      { categoryStation  = v }
            if let v = d.time,     categoryTime     == "24-HOURS"   { categoryTime     = v }
        }
    }

    private func exportNow() {
        let header = CabrilloHeader(
            contestID:        contestID,
            callsign:         stationCall,
            operatorName:     operatorName,
            email:            email,
            gridLocator:      qthLocator,
            location:         location,
            categoryOperator: categoryOperator,
            categoryBand:     categoryBand,
            categoryMode:     categoryMode,
            categoryPower:    categoryPower,
            categoryStation:  categoryStation,
            categoryTime:     categoryTime,
            claimedScore:     Int(claimedScore.filter { $0.isNumber }),
            club:             club,
            soapbox:          soapbox,
            sentExchange:     sentExchange
        )
        if let url = manager.exportActiveLogAsCabrillo(header: header) {
            resultURL = url
            showAlert = true
        }
    }
}
