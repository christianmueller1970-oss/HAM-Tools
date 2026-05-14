import SwiftUI

// Schlanke SOTA-QSO-Entry-Form. Aktiv wenn Logbuch ein SOTA-Log ist.
// Speichert QSOs mit den SOTA-konformen Feldern (mySotaRef + theirSotaRef
// + theirSotaPoints).
//
// Strukturell parallel zur POTAEntryForm. Unterschiede:
//   - 4-QSO-Counter statt 10-QSO-Counter (SOTA-Aktivierung)
//   - Punkte-Live-Display für Activator (Base + Bonus, abhängig vom Datum)
//   - Their Summit hat Autocomplete + Auto-Fill der theirSotaPoints
struct SOTAEntryForm: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var radio:        RadioState
    @EnvironmentObject var manager:      LogbookManager
    @EnvironmentObject var sota:         SotaSummitService
    @EnvironmentObject var callbook:     CallbookManager
    @EnvironmentObject var logBridge:    LogEntryBridge

    @State private var call: String = ""
    @State private var theirSummit: String = ""
    @State private var theirSummitMatch: Summit?
    @State private var rstSent: String = "59"
    @State private var rstReceived: String = "59"
    @State private var powerW: String = "100"
    @State private var comments: String = ""
    @State private var notes: String = ""
    @State private var timeOn: Date = Date()
    @State private var lastSavedConfirmation: String?
    @State private var timeTicker = Date()

    @State private var lookupName: String?
    @State private var lookupInFlight: Bool = false
    @State private var lookupTask: Task<Void, Never>?

    // SOTA-Dupe-Regel: gleicher Call+Band+Mode im aktiven Log. (Activator
    // arbeitet typischerweise eine Frequenz/Mode lange durch — Mode-
    // Unterscheidung verhindert false-Dupes wenn dieselbe Station nach
    // QSY auf CW wechselt.)
    @State private var lastSaveWasDupe: Bool = false

    @FocusState private var focusedField: Field?
    enum Field { case call, theirSummit, rstS, rstR, power, comments }

    private var theme: AppTheme { themeManager.theme }
    private let utcTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var currentLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    private var isActivator: Bool {
        currentLog?.role == "Activator"
    }

    // Mein Summit aus dem Log (für Status-Bar + Punkte-Anzeige beim
    // Activator).
    private var mySummit: Summit? {
        guard let ref = currentLog?.sotaSummitRef else { return nil }
        return sota.summit(forReference: ref)
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
        .onChange(of: logBridge.pendingSotaSpot) { _, spot in
            if let s = spot { applySpot(s); logBridge.pendingSotaSpot = nil }
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
        // Multi-Summit-Hopping: Komma-Liste zeigen; ohne Hopping nur primärer Summit.
        let mySummitLabel: String = {
            if let multi = log?.sotaSummitRefs, !multi.isEmpty { return multi }
            return log?.sotaSummitRef ?? "—"
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
            statusPill(icon: "mountain.2",
                       text: "\(role) · \(mySummitLabel)\(summitPointsSuffix)",
                       color: role == "Activator" ? .brown : .blue)
        }
        .padding(8)
        .background(theme.bgCard2)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // Zusatz-Suffix für den Summit-Pill: " · 10p" oder " · 10+3p" wenn Activator
    // und Summit in der DB gefunden + Punkte > 0.
    private var summitPointsSuffix: String {
        guard isActivator, let s = mySummit, s.points > 0 else { return "" }
        let (base, bonus) = SOTAPointsCalculator.activatorPoints(for: s, on: timeOn)
        return bonus > 0 ? " · \(base)+\(bonus)p" : " · \(base)p"
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
                labeled("Their Summit") {
                    VStack(alignment: .leading, spacing: 2) {
                        TextField("HB/BE-001 (S2S oder Chaser)", text: $theirSummit)
                            .focused($focusedField, equals: .theirSummit)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: theirSummit) { _, n in
                                let up = n.uppercased()
                                if up != n { theirSummit = up; return }
                                resolveTheirSummit(up)
                            }
                        if let s = theirSummitMatch {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text(s.name)
                                    .font(.caption)
                                if let alt = s.altitudeM {
                                    Text("\(alt) m")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(s.points) p")
                                    .font(.caption.bold().monospaced())
                                    .foregroundStyle(.blue)
                            }
                        } else if !theirSummit.isEmpty {
                            Text("Summit unbekannt — wird trotzdem gespeichert")
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
        let validation = qsoCount >= 4
        return HStack(spacing: 12) {
            if isActivator {
                HStack(spacing: 4) {
                    Image(systemName: validation ? "checkmark.seal.fill" : "circle")
                        .foregroundStyle(validation ? .green : .orange)
                    Text("\(qsoCount)/4 QSOs")
                        .font(.callout.monospaced())
                        .foregroundStyle(validation ? .green : theme.textSecondary)
                    if validation {
                        Text("Aktivierung gültig")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
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

        if let name = lookupName, !name.isEmpty {
            qso.name = name
        }

        // SOTA-Felder. Beim Activator wird mySotaRef aus dem Log getragen,
        // damit jedes QSO der Aktivierung den Summit kennt (auch beim
        // späteren CSV-/ADIF-Export).
        if isActivator {
            qso.mySotaRef = log.sotaSummitRef
        }
        let trimmedTheirs = theirSummit.trimmingCharacters(in: .whitespaces)
        if !trimmedTheirs.isEmpty {
            qso.theirSotaRef = trimmedTheirs.uppercased()
            // Punkte des Gegen-Summits cachen, damit das spätere Awards-
            // Modul / der CSV-Export sie ohne Lookup kennt.
            if let match = theirSummitMatch
                ?? sota.summit(forReference: trimmedTheirs.uppercased()) {
                qso.theirSotaPoints = match.points
            }
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

    /// SOTA-Spot wurde im Spots-Tab via Copy-Button übernommen.
    /// Activator-Call + Summit-Ref + Frequenz vorausfüllen, Their-Summit
    /// gegen Summit-DB auflösen.
    private func applySpot(_ s: SOTASpot) {
        call = s.activatorCallsign.uppercased()
        theirSummit = s.fullReference
        if s.frequencyMHz > 0 {
            radio.frequencyMHz = s.frequencyMHz
        }
        resolveTheirSummit(theirSummit)
        scheduleLookup(for: call)
    }

    /// Generischer DX-Cluster-Spot wurde geklickt während SOTA-Log aktiv.
    /// Call/Frequenz/Summit-Ref übernehmen.
    private func consumeDXDraftIfPending() {
        guard let draft = logBridge.consume() else { return }
        call = draft.call.uppercased()
        if let f = draft.frequencyMHz, f > 0 {
            radio.frequencyMHz = f
        }
        if let s = draft.mySotaRef, theirSummit.isEmpty {
            theirSummit = s.uppercased()
            resolveTheirSummit(theirSummit)
        }
        scheduleLookup(for: call)
    }

    private func resolveTheirSummit(_ ref: String) {
        let trimmed = ref.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            theirSummitMatch = nil
            return
        }
        theirSummitMatch = sota.summit(forReference: trimmed)
    }

    private func resetForm(keepLastConfirmation: Bool = false) {
        call = ""
        rstSent = "59"
        rstReceived = "59"
        theirSummit = ""
        theirSummitMatch = nil
        comments = ""
        notes = ""
        timeOn = Date()
        lookupName = nil
        lookupTask?.cancel()
        if !keepLastConfirmation { lastSavedConfirmation = nil }
    }

    private func scheduleLookup(for trimmedCall: String) {
        lookupTask?.cancel()
        let target = trimmedCall.trimmingCharacters(in: .whitespaces).uppercased()
        guard target.count >= 3 else {
            lookupName = nil
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
            if let r = result {
                let combined = [r.firstName, r.lastName]
                    .compactMap { $0 }
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                lookupName = combined.isEmpty ? nil : combined
            } else {
                lookupName = nil
            }
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
