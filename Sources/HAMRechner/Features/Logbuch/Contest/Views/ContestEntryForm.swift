import SwiftUI

// Schlankes Eingabeformular fürs aktive Contest-Log. Liest das passende
// Template aus ContestService, rendert sent/recv-Felder dynamisch und
// schaltet zwischen HB- und DX-spezifischen Recv-Feldern live um.
// Pattern-Twin zu POTAEntryForm.
struct ContestEntryForm: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager:      LogbookManager
    @EnvironmentObject var contests:     ContestService
    @EnvironmentObject var radio:        RadioState
    @EnvironmentObject var logBridge:    LogEntryBridge

    // User-Profil (Auto-Fill-Quellen)
    @AppStorage("callsign")    private var myCallsign = ""
    @AppStorage("qthLocator")  private var myLocator  = ""
    @AppStorage("myCanton")    private var myCanton   = ""
    @AppStorage("myCQZone")    private var myCQZone   = 14    // 14 = CH/EU
    @AppStorage("operatorCall") private var operatorCall = ""

    // Form-Status
    @State private var theirCall: String = ""
    @State private var mode: String = "SSB"
    @State private var values: [String: String] = [:]
    @State private var notes: String = ""
    @State private var lastError: String?
    // Multi-Op: aktuell aktiver Operator (aus log.contestOperators).
    // Leer → kein Switcher sichtbar oder Single-Op-Modus (Fallback auf
    // AppStorage `operatorCall`).
    @State private var selectedOperator: String = ""

    // Etappe 2: Run vs Search&Pounce — persistiert in QSO.contestIsRun.
    // Default: Run (eigene Frequenz, CQ-Modus). User togglet beim Wechsel
    // in den S&P-Modus (Spots abklappern).
    @AppStorage("logbook.contest.runMode") private var isRunMode: Bool = true

    private var theme: AppTheme { themeManager.theme }

    private var activeLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    /// Pro-Log-Override (1.8.2) → globaler Settings-Call → "". Wird als
    /// stationCall in jedes QSO geschrieben.
    private var effectiveStationCall: String {
        if let logCall = activeLog?.usedCallsign?
            .trimmingCharacters(in: .whitespaces), !logCall.isEmpty {
            return logCall.uppercased()
        }
        return myCallsign.trimmingCharacters(in: .whitespaces).uppercased()
    }

    /// OP-Liste aus log.contestOperators (Komma-getrennt). Leer = Single-Op.
    /// Reihenfolge wie eingetragen; Duplikate werden im Wizard schon entfernt.
    private var operatorOptions: [String] {
        guard let raw = activeLog?.contestOperators else { return [] }
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }

    /// Welcher Operator wird ins QSO geschrieben? Vorrang: OP-Switcher → AppStorage
    /// `operatorCall` → leer (Single-Op ohne separaten Operator).
    private var effectiveOperator: String {
        if !selectedOperator.isEmpty { return selectedOperator }
        return operatorCall.trimmingCharacters(in: .whitespaces).uppercased()
    }

    private var template: ContestTemplate? {
        guard let id = activeLog?.contestID else { return nil }
        return contests.template(forID: id)
    }

    private var currentBand: String {
        HamBand.from(frequencyMHz: radio.frequencyMHz)?.rawValue ?? ""
    }

    private var effectiveScope: SerialScope {
        guard let log = activeLog, let tpl = template else { return .log }
        return contests.effectiveScope(template: tpl, log: log)
    }

    // Mode-Auswahl im Contest folgt der Cabrillo-Kategorie aus dem Wizard.
    // Quelle: log.contestModeCategory (vom Wizard explizit gewählt) — falls
    // leer fallback auf template.defaultCategories.mode.
    private var allowedModes: [String] {
        let category = (activeLog?.contestModeCategory
                        ?? template?.defaultCategories?.mode
                        ?? "MIXED").uppercased()
        switch category {
        case "CW":     return ["CW"]
        case "PH":     return ["SSB", "USB", "LSB"]
        case "RY":     return ["RTTY"]
        case "DG":     return ["FT8", "FT4", "PSK31", "JS8", "RTTY"]
        case "FM":     return ["FM"]
        case "MIXED":  return ["SSB", "CW", "RTTY", "FT8", "FT4", "PSK31", "FM"]
        default:       return ["SSB", "CW", "RTTY", "FT8", "FT4", "PSK31", "FM"]
        }
    }

    // Soft-Dupe: existiert die Kombination Call + Band + Mode schon im Log?
    // Visuell red-flash am Call-Feld + Toast unter dem Form. QSO kann
    // trotzdem geloggt werden (Hard-Block ist eine spätere Option).
    private var dupeMatch: QSO? {
        guard !theirCall.isEmpty, !currentBand.isEmpty else { return nil }
        return DupeChecker.findDupe(call: theirCall,
                                    band: currentBand,
                                    mode: mode,
                                    in: manager.currentQSOs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerBar
            Divider().background(theme.separator)
            entryRow
            exchangeRow
            footerRow
        }
        .padding(10)
        .onAppear {
            // Mode auf einen vom Template erlaubten Wert setzen, falls der
            // letzte State (SSB-Default) nicht zum Contest passt (z.B. CW-only).
            if !allowedModes.contains(mode), let first = allowedModes.first {
                mode = first
            }
            // OP-Switcher initialisieren: Default = erster Eintrag. Falls
            // der letzte aktive Operator nicht mehr in der Liste ist (Log
            // gewechselt), auf den ersten Eintrag zurückspringen.
            if !operatorOptions.contains(selectedOperator) {
                selectedOperator = operatorOptions.first ?? ""
            }
            refreshAutoFills()
            consumeBridgeIfPending()
        }
        .onChange(of: theirCall)            { _, _ in refreshAutoFills() }
        .onChange(of: mode)                 { _, _ in refreshAutoFills() }
        .onChange(of: radio.frequencyMHz)   { _, _ in refreshAutoFills() }
        .onChange(of: manager.currentQSOs.count) { _, _ in refreshAutoFills() }
        .onChange(of: logBridge.navigationRequest) { _, _ in
            consumeBridgeIfPending()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "stopwatch")
                .foregroundStyle(theme.accentBlue)
            if let tpl = template {
                Text(tpl.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.textPrimary)
                if let cat = activeLog?.contestCategory {
                    Text(cat)
                        .font(.caption2.bold())
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(theme.bgCard2)
                        .clipShape(Capsule())
                        .foregroundStyle(theme.textSecondary)
                }
            } else {
                Text("Kein Contest-Template geladen")
                    .font(.subheadline)
                    .foregroundStyle(theme.textDim)
            }
            Spacer()
            // OP-Switcher: nur sichtbar wenn das Log eine OP-Liste hat
            // (Multi-Op-Workflow). Wechsel betrifft das nächste QSO.
            if !operatorOptions.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(theme.accentBlue)
                    Picker("OP", selection: $selectedOperator) {
                        ForEach(operatorOptions, id: \.self) { op in
                            Text(op).tag(op)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 110)
                }
            }
            Text("Scope: \(effectiveScope == .log ? "pro Log" : "pro Band")")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            BandplanStatusPill(frequencyMHz: radio.frequencyMHz, mode: mode)
        }
    }

    // MARK: - Eingabe

    private var entryRow: some View {
        HStack(alignment: .top, spacing: 12) {
            callField
            // Freq-Anzeige weggelassen — wird im CAT-Panel links angezeigt
            // und ist beim Loggen redundant.
            VStack(alignment: .leading, spacing: 2) {
                Text("Band")
                    .font(.caption2).foregroundStyle(theme.textDim)
                Text(currentBand.isEmpty ? "—" : currentBand)
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(width: 60, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Mode")
                    .font(.caption2).foregroundStyle(theme.textDim)
                Picker("", selection: $mode) {
                    ForEach(allowedModes, id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .labelsHidden()
                .frame(width: 90)
                .disabled(allowedModes.count <= 1)
            }
            Spacer()
        }
    }

    private var exchangeRow: some View {
        guard let tpl = template else {
            return AnyView(EmptyView())
        }
        let recvIsHB = isHBCallsign(theirCall)
        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                // Sent-Felder
                HStack(alignment: .top, spacing: 6) {
                    Text("Sent")
                        .font(.caption.bold())
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 38, alignment: .leading)
                    ForEach(visibleFields(tpl: tpl, role: .sent, recvIsHB: recvIsHB), id: \.key) { f in
                        fieldFromSpec(f)
                    }
                    Spacer()
                }
                // Recv-Felder
                HStack(alignment: .top, spacing: 6) {
                    Text("Recv")
                        .font(.caption.bold())
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 38, alignment: .leading)
                    ForEach(visibleFields(tpl: tpl, role: .recv, recvIsHB: recvIsHB), id: \.key) { f in
                        fieldFromSpec(f)
                    }
                    Spacer()
                }
            }
        )
    }

    private var footerRow: some View {
        HStack(spacing: 8) {
            // Run / S&P Toggle — definiert die Operating-Modus-Flag pro QSO.
            Picker("", selection: $isRunMode) {
                Text("Run").tag(true)
                Text("S&P").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 110)
            .help("Run: eigene Frequenz / CQ rufen. S&P: Spots abklappern (Search & Pounce).")

            if let dupe = dupeMatch {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.accentRed)
                    Text("Dupe — \(dupe.call) bereits auf \(dupe.band) \(dupe.mode)")
                        .font(.caption)
                        .foregroundStyle(theme.accentRed)
                }
            } else if let err = lastError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.accentOrange)
                Text(err)
                    .font(.caption)
                    .foregroundStyle(theme.accentOrange)
            }

            Spacer()
            Button("Zurücksetzen") { resetForm() }
                .controlSize(.small)
            Button {
                commitQSO()
            } label: {
                Label("Log QSO", systemImage: "checkmark.circle.fill")
            }
            .keyboardShortcut(.return, modifiers: [])
            .controlSize(.regular)
            .disabled(!canLog)
        }
        .padding(.top, 4)
    }

    // MARK: - Field-Helper

    private func visibleFields(tpl: ContestTemplate,
                               role: FieldRole,
                               recvIsHB: Bool) -> [ExchangeFieldSpec] {
        tpl.exchangeFields.filter { f in
            guard f.role == role else { return false }
            switch f.visibility ?? .always {
            case .always:            return true
            case .onlyIfRecvIsHB:    return recvIsHB
            case .onlyIfRecvIsDX:    return !recvIsHB
            }
        }
    }

    @ViewBuilder
    private func fieldFromSpec(_ f: ExchangeFieldSpec) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(f.label)
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            TextField(f.placeholder ?? "", text: bindingFor(f.key))
                .textFieldStyle(.roundedBorder)
                .font(f.kind == .serial || f.kind == .rst
                      ? .system(.subheadline, design: .monospaced)
                      : .subheadline)
                .frame(width: CGFloat(f.width ?? 80))
        }
    }

    // Eigenes Call-Feld mit Dupe-Hervorhebung: rote Border + leicht rote
    // Hintergrund-Tönung wenn das Call schon auf demselben Band+Mode geloggt ist.
    private var callField: some View {
        let isDupe = dupeMatch != nil
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("Call")
                    .font(.caption2).foregroundStyle(theme.textDim)
                if isDupe {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(theme.accentRed)
                }
            }
            TextField("", text: Binding(
                get: { theirCall },
                set: { theirCall = $0.uppercased() }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(.subheadline, design: .monospaced))
            .frame(width: 130)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isDupe ? theme.accentRed : Color.clear, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isDupe ? theme.accentRed.opacity(0.12) : Color.clear)
            )
        }
    }

    private func field(label: String,
                       text: Binding<String>,
                       width: CGFloat,
                       monospaced: Bool = false,
                       uppercase: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2).foregroundStyle(theme.textDim)
            TextField("", text: Binding(
                get: { text.wrappedValue },
                set: { text.wrappedValue = uppercase ? $0.uppercased() : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .font(monospaced ? .system(.subheadline, design: .monospaced) : .subheadline)
            .frame(width: width)
        }
    }

    private func bindingFor(_ key: String) -> Binding<String> {
        Binding(
            get: { values[key] ?? "" },
            set: { values[key] = $0 }
        )
    }

    // MARK: - Auto-Fill

    private func refreshAutoFills() {
        guard let tpl = template else { return }
        for f in tpl.exchangeFields {
            guard let auto = f.autoFill else { continue }
            // Nur überschreiben wenn das Feld leer ist — der User darf manuell ändern.
            if !(values[f.key]?.isEmpty ?? true) { continue }
            switch auto {
            case .rstFromMode:
                values[f.key] = ContestService.defaultRST(forMode: mode)
            case .serialNext:
                let n = contests.nextSerial(qsos: manager.currentQSOs,
                                            scope: effectiveScope,
                                            currentBand: currentBand)
                values[f.key] = String(format: "%03d", n)
            case .myCanton:
                values[f.key] = myCanton
            case .myGrid:
                values[f.key] = f.kind == .grid && f.width.map { $0 >= 90 } ?? false
                    ? myLocator.uppercased()
                    : String(myLocator.prefix(4).uppercased())
            case .myZone:
                values[f.key] = String(myCQZone)
            }
        }
    }

    // MARK: - Commit

    private var canLog: Bool {
        !theirCall.trimmingCharacters(in: .whitespaces).isEmpty
            && radio.frequencyMHz > 0
            && template != nil
            && manager.currentLogID != nil
    }

    private func commitQSO() {
        guard let tpl = template,
              let log = activeLog else { return }
        let recvIsHB = isHBCallsign(theirCall)

        let sentParts: [String] = visibleFields(tpl: tpl, role: .sent, recvIsHB: recvIsHB)
            .map { values[$0.key] ?? "" }
            .filter { !$0.isEmpty }
        let recvParts: [String] = visibleFields(tpl: tpl, role: .recv, recvIsHB: recvIsHB)
            .map { values[$0.key] ?? "" }
            .filter { !$0.isEmpty }

        let sentExchange = sentParts.joined(separator: " ")
        let recvExchange = recvParts.joined(separator: " ")

        // Erstes RST-Feld füllt das Pflicht-Feld auf QSO.
        let rstSent = sentParts.first ?? ContestService.defaultRST(forMode: mode)
        let rstRecv = recvParts.first ?? ContestService.defaultRST(forMode: mode)

        // Eigene Serial — nur wenn das Template ein serial_sent hat
        let serialSentStr = values["serial_sent"] ?? ""
        let serialSent: Int? = Int(serialSentStr)

        var qso = QSO(
            logID: log.id,
            call: theirCall.uppercased(),
            datetime: Date(),
            frequencyMHz: radio.frequencyMHz,
            band: currentBand,
            mode: mode,
            rstSent: rstSent,
            rstReceived: rstRecv,
            comment: notes.isEmpty ? nil : notes,
            operatorCall: effectiveOperator.isEmpty ? nil : effectiveOperator,
            stationCall: effectiveStationCall.isEmpty ? nil : effectiveStationCall
        )
        qso.contest = tpl.id
        qso.contestSerial = serialSent
        qso.contestExchangeSent = sentExchange.isEmpty ? nil : sentExchange
        qso.contestExchangeRecv = recvExchange.isEmpty ? nil : recvExchange
        qso.contestIsRun = isRunMode

        manager.addQSO(qso)
        resetEntryButKeepSentDefaults()
    }

    /// Holt einen vom DX-Cluster-Click bereitgestellten Draft (call/freq/mode)
    /// und füllt das Contest-Form. Frequenz fließt zusätzlich ins Radio,
    /// damit der CAT-State synchron ist.
    private func consumeBridgeIfPending() {
        guard let draft = logBridge.consume() else { return }
        theirCall = draft.call.uppercased()
        if let f = draft.frequencyMHz, f > 0 {
            radio.frequencyMHz = f
        }
        if let m = draft.mode, !m.isEmpty {
            if allowedModes.contains(m) { mode = m }
        }
        refreshAutoFills()
    }

    private func resetForm() {
        theirCall = ""
        values.removeAll()
        lastError = nil
        refreshAutoFills()
    }

    /// Nach erfolgreichem Log: theirCall + Recv-Felder löschen, Sent-Defaults
    /// neu aus Auto-Fill aufbauen (für die nächste Serial-Nummer).
    private func resetEntryButKeepSentDefaults() {
        theirCall = ""
        for key in values.keys where key.hasSuffix("_recv") {
            values[key] = ""
        }
        // Serial-Sent: leer machen, refreshAutoFills holt die nächste Nummer.
        values["serial_sent"] = ""
        refreshAutoFills()
    }
}
