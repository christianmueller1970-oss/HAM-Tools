import SwiftUI

// Wizard zum Anlegen eines neuen Contest-Logs.
// Schritt 1: Template aus contests.json wählen (mit Suche).
// Schritt 2: Cabrillo-Kategorien festlegen (mit Defaults aus Template).
// Bestätigung erzeugt einen Log mit type=.contest, contestID, contestCategory.
struct NewContestLogSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager:      LogbookManager
    @EnvironmentObject var contests:     ContestService

    @Environment(\.dismiss) private var dismiss

    enum Mode: String, CaseIterable, Identifiable {
        case open = "Bestehende öffnen"
        case new  = "Neuen Contest"
        var id: String { rawValue }
    }

    enum Step: Int { case template = 0, categories = 1 }

    @State private var mode: Mode = .new
    @State private var step: Step = .template
    @State private var search: String = ""
    @State private var selected: ContestTemplate?
    @State private var logName: String = ""

    // Cabrillo-Kategorien (mit Defaults aus dem Template gefüllt)
    @State private var catOperator: String = "SINGLE-OP"
    @State private var catPower:    String = "LOW"
    @State private var catBand:     String = "ALL"
    @State private var catMode:     String = "MIXED"
    @State private var catStation:  String = "FIXED"
    @State private var catAssisted: String = "NON-ASSISTED"
    @State private var catTime:     String = "24-HOURS"

    private var theme: AppTheme { themeManager.theme }

    private var existingContestLogs: [Log] {
        manager.logs
            .filter { $0.type == .contest }
            .sorted { $0.startDate > $1.startDate }
    }

    private var filteredTemplates: [ContestTemplate] {
        if search.trimmingCharacters(in: .whitespaces).isEmpty { return contests.templates }
        let q = search.lowercased()
        return contests.templates.filter {
            $0.name.lowercased().contains(q)
                || $0.id.lowercased().contains(q)
                || ($0.sponsor?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(headerTitle)
                .font(.title3.bold())
                .foregroundStyle(theme.textPrimary)

            if !existingContestLogs.isEmpty && step == .template {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)
            }

            if mode == .open {
                openExistingSection
            } else {
                switch step {
                case .template:   templateStep
                case .categories: categoryStep
                }
            }
        }
        .padding(20)
        .frame(width: 560, height: 560)
        .background(theme.bgCard)
        .onAppear {
            mode = existingContestLogs.isEmpty ? .new : .open
        }
    }

    private var headerTitle: String {
        if mode == .open { return "Contest-Log öffnen" }
        switch step {
        case .template:   return "Neuen Contest anlegen — Schritt 1: Contest"
        case .categories: return "Neuen Contest anlegen — Schritt 2: Kategorie"
        }
    }

    // MARK: - Schritt 1: Template-Picker

    private var templateStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textDim)
                TextField("Suche (Name, ID, Sponsor)…", text: $search)
                    .textFieldStyle(.roundedBorder)
            }

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(filteredTemplates) { tpl in
                        templateRow(tpl)
                    }
                    if filteredTemplates.isEmpty {
                        Text(contests.loadError ?? "Keine Treffer.")
                            .font(.caption)
                            .foregroundStyle(theme.textDim)
                            .padding(.top, 20)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: .infinity)
            .background(theme.bgCard2)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Weiter") {
                    applyTemplateDefaults()
                    step = .categories
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selected == nil)
            }
        }
    }

    private func templateRow(_ tpl: ContestTemplate) -> some View {
        let isSel = selected?.id == tpl.id
        return Button {
            selected = tpl
            if logName.isEmpty {
                logName = "\(tpl.name) — \(currentYearString())"
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "stopwatch")
                    .foregroundStyle(isSel ? theme.accentBlue : theme.textDim)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(tpl.name)
                            .font(.subheadline.bold())
                            .foregroundStyle(theme.textPrimary)
                        if let sponsor = tpl.sponsor {
                            Text("· \(sponsor)")
                                .font(.caption2)
                                .foregroundStyle(theme.textDim)
                        }
                    }
                    if let period = tpl.periodHint {
                        Text(period)
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                Spacer()
                if isSel {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accentBlue)
                }
            }
            .padding(8)
            .background(isSel ? theme.bgHover : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSel ? theme.accentBlue : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Schritt 2: Kategorien

    private var categoryStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let tpl = selected {
                HStack(spacing: 6) {
                    Image(systemName: "stopwatch")
                        .foregroundStyle(theme.accentBlue)
                    Text(tpl.name)
                        .font(.subheadline.bold())
                    Spacer()
                    if let info = tpl.infoURL, let url = URL(string: info) {
                        Link("Regelwerk ↗", destination: url)
                            .font(.caption)
                    }
                }
                if let notes = tpl.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Divider()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Log-Name")
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.textSecondary)
                TextField("Anzeigename", text: $logName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Cabrillo-Kategorien")
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.textSecondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 8) {
                    catPicker("Operator", $catOperator, [
                        "SINGLE-OP", "SINGLE-OP-ASSISTED",
                        "MULTI-SINGLE", "MULTI-TWO", "MULTI-UNLIMITED",
                        "MULTI-DISTRIBUTED", "CHECKLOG"
                    ])
                    catPicker("Power", $catPower, ["HIGH", "LOW", "QRP"])
                    catPicker("Band", $catBand, [
                        "ALL", "160M", "80M", "40M", "20M", "15M", "10M", "6M", "2M", "70CM"
                    ])
                    catPicker("Mode", $catMode, ["MIXED", "CW", "PH", "RY", "DG", "FM"])
                    catPicker("Station", $catStation, [
                        "FIXED", "MOBILE", "PORTABLE", "ROVER", "EXPEDITION", "HQ"
                    ])
                    catPicker("Assisted", $catAssisted, ["NON-ASSISTED", "ASSISTED"])
                    catPicker("Zeit", $catTime, ["24-HOURS", "12-HOURS", "8-HOURS", "6-HOURS", "48-HOURS"])
                }
            }

            // Serial-Scope-Hinweis
            if let tpl = selected {
                let scope = scopeForSelection(template: tpl)
                HStack(spacing: 6) {
                    Image(systemName: "number")
                        .foregroundStyle(theme.accentOrange)
                    Text("Serial-Counter: \(scope == .log ? "pro Log durchgehend" : "pro Band einzeln")")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Button("Zurück") { step = .template }
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Anlegen") {
                    createLog()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selected == nil
                          || logName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func catPicker(_ label: String, _ binding: Binding<String>,
                           _ options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(theme.textDim)
            Picker("", selection: binding) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Bestehende öffnen

    private var openExistingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Klick auf einen Contest, um ihn weiter zu führen:")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(existingContestLogs) { log in
                        Button {
                            manager.openLog(log)
                            dismiss()
                        } label: {
                            existingLogRow(log)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .background(theme.bgCard2)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                Button("Neuer Contest") { mode = .new }
            }
        }
    }

    private func existingLogRow(_ log: Log) -> some View {
        let count = manager.qsoCount(for: log)
        let df = DateFormatter(); df.dateStyle = .medium
        return HStack(spacing: 10) {
            Image(systemName: "stopwatch")
                .foregroundStyle(theme.accentBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(log.name).font(.subheadline.bold())
                HStack(spacing: 6) {
                    if let id = log.contestID {
                        Text(id).font(.caption2)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(theme.bgCard2)
                            .clipShape(Capsule())
                    }
                    Text(df.string(from: log.startDate))
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                }
            }
            Spacer()
            Text("\(count) QSO")
                .font(.caption.monospaced())
                .foregroundStyle(theme.textSecondary)
        }
        .padding(8)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - Logik

    private func applyTemplateDefaults() {
        guard let tpl = selected, let d = tpl.defaultCategories else { return }
        if let v = d.op       { catOperator = v }
        if let v = d.power    { catPower    = v }
        if let v = d.band     { catBand     = v }
        if let v = d.mode     { catMode     = v }
        if let v = d.station  { catStation  = v }
        if let v = d.assisted { catAssisted = v }
        if let v = d.time     { catTime     = v }
    }

    private func scopeForSelection(template tpl: ContestTemplate) -> SerialScope {
        if let mapped = tpl.serialScopeByOperator?[catOperator] { return mapped }
        return tpl.defaultSerialScope
    }

    private func createLog() {
        guard let tpl = selected else { return }
        let scope = scopeForSelection(template: tpl)
        let log = Log(
            name: logName.trimmingCharacters(in: .whitespaces),
            type: .contest,
            contestID: tpl.id,
            contestCategory: catOperator,
            contestSerialScope: scope.rawValue,
            contestModeCategory: catMode
        )
        manager.createLog(log)
        dismiss()
    }

    private func currentYearString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy"
        return f.string(from: Date())
    }
}
