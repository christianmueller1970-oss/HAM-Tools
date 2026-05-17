import SwiftUI

// Schlanke WWFF-QSO-Entry-Form. Aktiv wenn Logbuch ein WWFF-Log ist.
// Speichert QSOs mit den WWFF-konformen Feldern (myWwffRef + Multi-Ref-
// Hopping + theirWwffRef für R2R / Reference-to-Reference).
//
// Strukturell parallel zur SOTAEntryForm. Wichtigster Unterschied:
//   - 44-QSO-Counter (WWFF-Aktivierungs-Regel — strikter als POTA(10)/SOTA(4))
//   - Kein Punkte-System, kein Winterbonus
//   - Their Reference mit Autocomplete + Country-Anzeige aus WWFFRefService
struct WWFFEntryForm: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var radio:        RadioState
    @EnvironmentObject var manager:      LogbookManager
    @EnvironmentObject var wwff:         WWFFRefService
    @EnvironmentObject var callbook:     CallbookManager
    @EnvironmentObject var logBridge:    LogEntryBridge

    @State private var call: String = ""
    @State private var theirRef: String = ""
    @State private var theirRefMatch: WWFFReference?
    @State private var rstSent: String = "59"
    @State private var rstReceived: String = "59"
    @State private var powerW: String = "100"
    @State private var comments: String = ""
    @State private var notes: String = ""
    @State private var timeOn: Date = Date()
    @State private var lastSavedConfirmation: String?
    @State private var timeTicker = Date()

    @State private var lookupResult: CallbookResult?
    @State private var lookupInFlight: Bool = false
    @State private var lookupTask: Task<Void, Never>?

    /// Kombinierter Vor-+Nachname aus dem Callbook-Lookup — wird unter
    /// dem Call-Feld als »QRZ aufgelöst«-Hinweis angezeigt. Der Rest des
    /// Results (qth, country, locator, cqZone …) wird beim Commit per
    /// applyFillingEmpty stillschweigend ans QSO gehängt.
    private var lookupName: String? {
        guard let r = lookupResult else { return nil }
        let combined = [r.firstName, r.lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return combined.isEmpty ? nil : combined
    }

    // WWFF-Dupe-Regel: gleicher Call+Band+Mode im aktiven Log. WWFF zählt
    // QSOs pro Band/Mode getrennt — mehrfach mit dem gleichen Call ist OK
    // wenn Band oder Mode wechselt.
    @State private var lastSaveWasDupe: Bool = false

    @FocusState private var focusedField: Field?
    enum Field { case call, theirRef, rstS, rstR, power, comments }

    private var theme: AppTheme { themeManager.theme }
    private let utcTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var currentLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    private var isActivator: Bool {
        currentLog?.role == "Activator"
    }

    private var myRef: WWFFReference? {
        guard let ref = currentLog?.wwffRef else { return nil }
        return wwff.ref(forReference: ref)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sessionBar
            formGrid
            actionRow
            if let conf = lastSavedConfirmation {
                Text(conf)
                    .font(.caption)
                    .foregroundStyle(lastSaveWasDupe ? .orange : .green)
            }
        }
        .padding(12)
        .onAppear {
            call = ""
            timeOn = Date()
            consumeDXDraftIfPending()
        }
        .onChange(of: logBridge.pendingWwffSpot) { _, spot in
            if let s = spot { applySpot(s); logBridge.pendingWwffSpot = nil }
        }
        .onChange(of: logBridge.navigationRequest) { _, _ in
            consumeDXDraftIfPending()
        }
        .onReceive(utcTimer) { _ in
            timeTicker = Date()
            if call.trimmingCharacters(in: .whitespaces).isEmpty {
                timeOn = Date()
            }
        }
    }

    // MARK: - Session-Status-Bar

    private var sessionBar: some View {
        let log = currentLog
        let role = log?.role ?? "—"
        let myRefLabel: String = {
            if let multi = log?.wwffRefs, !multi.isEmpty { return multi }
            return log?.wwffRef ?? "—"
        }()
        let freq = radio.frequencyMHz > 0
            ? String(format: "%.5f MHz", radio.frequencyMHz)
            : "—"
        let utc = utcString(timeTicker)
        let band = radio.band.isEmpty ? "—" : radio.band

        return HStack(spacing: 16) {
            statusPill(icon: "clock", text: "\(utc) UTC")
            statusPill(icon: "antenna.radiowaves.left.and.right", text: "\(freq) (\(band))")
            statusPill(icon: "waveform", text: radio.mode)
            statusPill(icon: "bolt", text: powerW.isEmpty ? "0 W" : "\(powerW) W")
            statusPill(icon: "person", text: log?.name ?? "—")
            statusPill(icon: "leaf",
                       text: "\(role) · \(myRefLabel)\(refCountrySuffix)",
                       color: role == "Activator" ? theme.colorWWFF : .blue)
        }
        .padding(8)
        .background(theme.bgCard2)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // Suffix " · Germany" wenn Activator und Ref in der DB gefunden.
    private var refCountrySuffix: String {
        guard isActivator, let r = myRef, let c = r.country, !c.isEmpty else { return "" }
        return " · \(c)"
    }

    private func statusPill(icon: String, text: String, color: Color = .accentColor) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text)
                .font(.caption.monospaced())
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: - Form Grid

    private var formGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                labeled("Their Call") {
                    VStack(alignment: .leading, spacing: 2) {
                        TextField("DL1ABC", text: $call)
                            .focused($focusedField, equals: .call)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: call) { _, n in
                                let up = n.uppercased()
                                if up != n { call = up; return }
                                scheduleLookup(for: up)
                            }
                            .onSubmit {
                                if canSave { saveQSO() }
                            }
                        if let name = lookupName {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.caption2)
                                Text(name)
                                    .font(.caption.italic())
                            }
                            .foregroundStyle(.green)
                        } else if lookupInFlight {
                            Text("QRZ-Lookup läuft …")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                labeled("RST/S") {
                    TextField("59", text: $rstSent)
                        .focused($focusedField, equals: .rstS)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                labeled("RST/R") {
                    TextField("59", text: $rstReceived)
                        .focused($focusedField, equals: .rstR)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }
            GridRow {
                labeled("Their Reference") {
                    VStack(alignment: .leading, spacing: 2) {
                        TextField("DLFF-0001 (R2R oder Hunter)", text: $theirRef)
                            .focused($focusedField, equals: .theirRef)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: theirRef) { _, n in
                                let up = n.uppercased()
                                if up != n { theirRef = up; return }
                                resolveTheirRef(up)
                            }
                        if let r = theirRefMatch {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text(r.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                if let c = r.country, !c.isEmpty {
                                    Text("·").foregroundStyle(.secondary)
                                    Text(c).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        } else if !theirRef.isEmpty {
                            Text("Reference unbekannt — wird trotzdem gespeichert")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                labeled("Power (W)") {
                    TextField("100", text: $powerW)
                        .focused($focusedField, equals: .power)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                Color.clear.frame(height: 1)
            }
            GridRow {
                labeled("Comments") {
                    TextField("optional", text: $comments)
                        .focused($focusedField, equals: .comments)
                        .textFieldStyle(.roundedBorder)
                }
                .gridCellColumns(3)
            }
            GridRow {
                labeled("Notes") {
                    TextField("optional", text: $notes)
                        .textFieldStyle(.roundedBorder)
                }
                .gridCellColumns(3)
            }
        }
    }

    private func labeled<Content: View>(_ label: String,
                                        @ViewBuilder _ content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.bold()).foregroundStyle(theme.textSecondary)
            content()
        }
    }

    // MARK: - Action Row

    private var actionRow: some View {
        let qsoCount = currentLog.map { manager.qsoCount(for: $0) } ?? 0
        let validation = qsoCount >= 44
        let missing = max(0, 44 - qsoCount)
        return HStack(spacing: 12) {
            if isActivator {
                HStack(spacing: 4) {
                    Image(systemName: validation ? "checkmark.seal.fill" : "circle")
                        .foregroundStyle(validation ? .green : .orange)
                    Text("\(qsoCount)/44 QSOs")
                        .font(.callout.monospaced())
                        .foregroundStyle(validation ? .green : theme.textSecondary)
                    if validation {
                        Text("Aktivierung gültig")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    } else if missing > 0 {
                        Text("noch \(missing) bis Aktivierung")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
            Button("Clear") { resetForm() }
            Button(action: saveQSO) {
                HStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.down")
                    Text("Log QSO")
                    Text("↩").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
        }
    }

    private var canSave: Bool {
        !call.trimmingCharacters(in: .whitespaces).isEmpty
            && radio.frequencyMHz > 0
            && manager.currentLogID != nil
    }

    // MARK: - Save

    private func isDupeNow() -> Bool {
        let trimmedCall = call.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmedCall.isEmpty else { return false }
        let currentBand = radio.band
        guard !currentBand.isEmpty, currentBand != "—" else { return false }
        return manager.findQSOs(forCall: trimmedCall).contains {
            $0.logID == manager.currentLogID
                && $0.qso.band == currentBand
                && $0.qso.mode == radio.mode
        }
    }

    private func saveQSO() {
        guard let logID = manager.currentLogID,
              let log = currentLog else { return }
        let trimmedCall = call.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmedCall.isEmpty, radio.frequencyMHz > 0 else { return }

        let dupe = isDupeNow()
        lastSaveWasDupe = dupe

        var qso = QSO(
            logID: logID,
            call: trimmedCall,
            datetime: timeOn,
            frequencyMHz: radio.frequencyMHz,
            band: radio.band.isEmpty ? "—" : radio.band,
            mode: radio.mode,
            rstSent: rstSent,
            rstReceived: rstReceived
        )
        qso.powerW = Double(powerW.replacingOccurrences(of: ",", with: "."))
        qso.comment = comments.isEmpty ? nil : comments

        let myCall: String = {
            if let logCall = currentLog?.usedCallsign?
                .trimmingCharacters(in: .whitespaces), !logCall.isEmpty {
                return logCall.uppercased()
            }
            return UserDefaults.standard.string(forKey: "callsign")?
                .trimmingCharacters(in: .whitespaces).uppercased() ?? ""
        }()
        if !myCall.isEmpty {
            qso.operatorCall = myCall
            qso.stationCall  = myCall
        }

        // Callbook-Auto-Fill: NAME, QTH, COUNTRY, GRIDSQUARE, CONTINENT,
        // CQ/ITU-Zone. applyFillingEmpty überschreibt keine vom User
        // selbst getippten Felder.
        lookupResult?.applyFillingEmpty(to: &qso)

        // WWFF-Felder. Beim Activator wird myWwffRef aus dem Log getragen;
        // bei Multi-Ref-Hopping zusätzlich myWwffRefs (Komma-Liste).
        if isActivator {
            qso.myWwffRef  = log.wwffRef
            qso.myWwffRefs = log.wwffRefs
        }
        let trimmedTheirs = theirRef.trimmingCharacters(in: .whitespaces)
        if !trimmedTheirs.isEmpty {
            qso.theirWwffRef = trimmedTheirs.uppercased()
        }

        manager.addQSO(qso)
        lastSavedConfirmation = dupe
            ? "⚠ Dupe gespeichert: \(trimmedCall) bereits auf \(qso.band)/\(qso.mode) im Log"
            : "✓ QSO gespeichert: \(trimmedCall)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if lastSavedConfirmation?.contains(trimmedCall) == true {
                lastSavedConfirmation = nil
            }
        }
        resetForm(keepLastConfirmation: true)
        focusedField = .call
    }

    /// WWFF-Spot wurde im Spots-Tab via Copy-Button übernommen.
    /// Activator-Call + WWFF-Ref + Frequenz vorausfüllen.
    private func applySpot(_ s: WWFFSpot) {
        call = s.dxCall.uppercased()
        theirRef = s.reference
        if s.frequencyMHz > 0 {
            radio.frequencyMHz = s.frequencyMHz
        }
        resolveTheirRef(theirRef)
        scheduleLookup(for: call)
    }

    /// Generischer DX-Cluster-Spot wurde geklickt während WWFF-Log aktiv.
    private func consumeDXDraftIfPending() {
        guard let draft = logBridge.consume() else { return }
        call = draft.call.uppercased()
        if let f = draft.frequencyMHz, f > 0 {
            radio.frequencyMHz = f
        }
        if let w = draft.myWwffRef, theirRef.isEmpty {
            theirRef = w.uppercased()
            resolveTheirRef(theirRef)
        }
        scheduleLookup(for: call)
    }

    private func resolveTheirRef(_ ref: String) {
        let trimmed = ref.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            theirRefMatch = nil
            return
        }
        theirRefMatch = wwff.ref(forReference: trimmed)
    }

    private func resetForm(keepLastConfirmation: Bool = false) {
        call = ""
        rstSent = "59"
        rstReceived = "59"
        theirRef = ""
        theirRefMatch = nil
        comments = ""
        notes = ""
        timeOn = Date()
        lookupResult = nil
        lookupTask?.cancel()
        if !keepLastConfirmation { lastSavedConfirmation = nil }
    }

    private func scheduleLookup(for trimmedCall: String) {
        lookupTask?.cancel()
        let target = trimmedCall.trimmingCharacters(in: .whitespaces).uppercased()
        guard target.count >= 3 else {
            lookupResult = nil
            lookupInFlight = false
            return
        }
        lookupTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            if Task.isCancelled { return }
            if call.uppercased() != target { return }
            lookupInFlight = true
            let result = await callbook.lookup(call: target)
            if Task.isCancelled || call.uppercased() != target {
                lookupInFlight = false
                return
            }
            lookupResult = result
            lookupInFlight = false
        }
    }

    private func utcString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: d)
    }
}
