import SwiftUI

// Schlanke POTA-QSO-Entry-Form. Aktiv wenn Logbuch ein POTA-Log ist und
// im QSOEntryPanel der POTA-Tab gewählt wurde. Speichert QSOs mit den
// POTA-konformen Feldern (myPotaRef + theirPotaRef bzw. Komma-Liste für
// Multi-Park-Hopping).
struct POTAEntryForm: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var radio:        RadioState
    @EnvironmentObject var manager:      LogbookManager
    @EnvironmentObject var pota:         PotaParkService
    @EnvironmentObject var callbook:     CallbookManager
    @EnvironmentObject var logBridge:    LogEntryBridge

    @State private var call: String = ""
    @State private var theirPark: String = ""
    @State private var rstSent: String = "59"
    @State private var rstReceived: String = "59"
    @State private var powerW: String = "100"
    @State private var comments: String = ""
    @State private var notes: String = ""
    @State private var timeOn: Date = Date()
    @State private var lastSavedConfirmation: String?
    @State private var timeTicker = Date()

    // Callbook-Lookup (rein visuell, nicht ins QSO gespeichert — POTA-Upload
    // braucht den Namen nicht, aber während des QSO ist es nett "Hi John!").
    @State private var lookupName: String?
    @State private var lookupInFlight: Bool = false
    @State private var lookupTask: Task<Void, Never>?

    // Dupe-Hinweis. POTA-Regel: gleicher Call auf gleichem Band im aktiven
    // Log = Dupe (Mode irrelevant — POTA-Spec zählt pro Band, nicht pro Mode).
    // Wird NICHT blockierend angezeigt: das QSO wird trotzdem gespeichert,
    // die Tabelle markiert solche QSOs rot, das Form zeigt einen orangen
    // Banner statt grünem "gespeichert".
    @State private var lastSaveWasDupe: Bool = false

    @FocusState private var focusedField: Field?

    enum Field { case call, theirPark, rstS, rstR, power, comments }

    private var theme: AppTheme { themeManager.theme }
    private let utcTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var currentLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
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
        .onChange(of: logBridge.pendingPotaSpot) { _, spot in
            if let s = spot { applySpot(s); logBridge.pendingPotaSpot = nil }
        }
        .onChange(of: logBridge.navigationRequest) { _, _ in
            consumeDXDraftIfPending()
        }
        .onReceive(utcTimer) { _ in
            timeTicker = Date()
            // Time-On läuft mit, bis User loggt — dann wird beim Save fest.
            if call.trimmingCharacters(in: .whitespaces).isEmpty {
                timeOn = Date()
            }
        }
    }

    // MARK: - Session-Status-Bar (analog Referenz-Bild)

    private var sessionBar: some View {
        let log = currentLog
        let role = log?.role ?? "—"
        // Multi-Park-Hopping: zeige die Komma-Liste; ohne Hopping nur den einen Park.
        let myParkLabel: String = {
            if let multi = log?.potaParkRefs, !multi.isEmpty { return multi }
            return log?.potaParkRef ?? "—"
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
            statusPill(icon: "tree", text: "\(role) · \(myParkLabel)",
                       color: role == "Activator" ? .green : .blue)
        }
        .padding(8)
        .background(theme.bgCard2)
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
                labeled("Their Park") {
                    TextField("K-1234 oder K-1234,K-5678 (P2P)", text: $theirPark)
                        .focused($focusedField, equals: .theirPark)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: theirPark) { _, n in
                            theirPark = n.uppercased()
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
        let isActivator = currentLog?.role == "Activator"
        let qsoCount = currentLog.map { manager.qsoCount(for: $0) } ?? 0
        let validation = qsoCount >= 10
        return HStack(spacing: 12) {
            if isActivator {
                HStack(spacing: 4) {
                    Image(systemName: validation ? "checkmark.seal.fill" : "circle")
                        .foregroundStyle(validation ? .green : .orange)
                    Text("\(qsoCount)/10 QSOs")
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
                    Text("⌘↩").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
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

    /// POTA-Dupe-Logik: gleicher Call auf gleichem Band im aktiven Log.
    /// Mode wird bewusst ignoriert — POTA-Regeln zählen pro Band/Tag,
    /// nicht pro Band+Mode wie bei DXCC. Nicht blockierend: liefert nur
    /// Info ob der nächste Save ein Dupe wäre.
    private func isDupeNow() -> Bool {
        let trimmedCall = call.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmedCall.isEmpty else { return false }
        let currentBand = radio.band
        guard !currentBand.isEmpty, currentBand != "—" else { return false }
        return manager.findQSOs(forCall: trimmedCall).contains {
            $0.logID == manager.currentLogID && $0.qso.band == currentBand
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

        // Operator + Station-Call aus den App-Settings — pota.app braucht
        // dies in der Upload-ADIF (OPERATOR + STATION_CALLSIGN), sonst weiß
        // pota nicht WER aktiviert hat.
        let myCall = UserDefaults.standard.string(forKey: "callsign")?
            .trimmingCharacters(in: .whitespaces).uppercased() ?? ""
        if !myCall.isEmpty {
            qso.operatorCall = myCall
            qso.stationCall  = myCall
        }

        // Name aus QRZ-Lookup silently mitspeichern (im Form nicht angezeigt,
        // aber so kann die Tabelle einen "QRZ aufgelöst"-Haken zeigen).
        if let name = lookupName, !name.isEmpty {
            qso.name = name
        }

        // POTA-Felder:
        // - myPotaRef:  primärer Park aus dem Log (Activator)
        // - myPotaRefs: nur gesetzt wenn das Log Multi-Park-Hopping macht;
        //               Komma-Liste aller Parks (inkl. primärem).
        // - theirPotaRef: vom QSO eingegebene Gegen-Park-Ref(s); bei P2P-Multi
        //               als Komma-Liste laut POTA-ADIF-Spec direkt in dem
        //               einen Feld (kein eigenes theirPotaRefs nötig).
        qso.myPotaRef  = log.potaParkRef
        qso.myPotaRefs = log.potaParkRefs        // nil bei Single-Park-Logs
        let trimmedTheirs = theirPark.trimmingCharacters(in: .whitespaces)
        if !trimmedTheirs.isEmpty {
            let refs = trimmedTheirs.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
                .filter { !$0.isEmpty }
            qso.theirPotaRef = refs.isEmpty ? nil : refs.joined(separator: ",")
        }

        manager.addQSO(qso)
        lastSavedConfirmation = dupe
            ? "⚠ Dupe gespeichert: \(trimmedCall) bereits auf \(qso.band) im Log"
            : "✓ QSO gespeichert: \(trimmedCall)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if lastSavedConfirmation?.contains(trimmedCall) == true {
                lastSavedConfirmation = nil
            }
        }
        resetForm(keepLastConfirmation: true)
        focusedField = .call
    }

    // Vom POTA-Spots-Tab via LogEntryBridge eingespielter Spot füllt das
    // Form vor: Their Call + Their Park. RST und Power bleiben Defaults.
    private func applySpot(_ s: POTASpot) {
        call = s.activator.uppercased()
        theirPark = s.reference
        // Sofortiger Lookup für den Namen-Hinweis (debounce dauert sonst zu lang)
        scheduleLookup(for: call)
    }

    /// Generischer DX-Cluster-Spot wurde geklickt während ein POTA-Log aktiv ist.
    /// Call/Frequenz/POTA-Ref übernehmen, damit man den Hunter-Workflow ohne
    /// Tab-Wechsel abschließen kann.
    private func consumeDXDraftIfPending() {
        guard let draft = logBridge.consume() else { return }
        call = draft.call.uppercased()
        if let f = draft.frequencyMHz, f > 0 {
            radio.frequencyMHz = f
        }
        if let p = draft.myPotaRef, theirPark.isEmpty {
            theirPark = p
        }
        scheduleLookup(for: call)
    }

    private func resetForm(keepLastConfirmation: Bool = false) {
        call = ""
        rstSent = "59"
        rstReceived = "59"
        theirPark = ""
        comments = ""
        notes = ""
        timeOn = Date()
        lookupName = nil
        lookupTask?.cancel()
        if !keepLastConfirmation { lastSavedConfirmation = nil }
    }

    // QRZ/HamQTH-Lookup mit Debounce. Wenn der User tippt, warten wir 600 ms
    // bevor wir die Anfrage feuern, sonst hagelt's API-Calls bei jedem Buchstaben.
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
            // Bei Race: nur weitermachen wenn der Call noch derselbe ist
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
