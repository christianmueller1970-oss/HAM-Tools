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

    // Self-Spot. Button erscheint in der Status-Bar nur im Activator-Modus
    // mit gesetztem Park. Sheet fragt nach Comments + sendet POST an
    // api.pota.app/spot/ (anonym, kein Auth).
    @State private var showSpotSheet: Bool = false
    @State private var spotComments: String = ""
    @State private var spotInFlight: Bool = false
    @State private var spotResult: SpotResult?

    struct SpotResult: Identifiable {
        let id = UUID()
        let success: Bool
        let title: String
        let message: String
    }

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
        .sheet(isPresented: $showSpotSheet) {
            spotSheet
        }
        .alert(spotResult?.title ?? "",
               isPresented: Binding(
                   get: { spotResult != nil },
                   set: { if !$0 { spotResult = nil } }
               ),
               presenting: spotResult) { _ in
            Button("OK", role: .cancel) {}
        } message: { entry in
            Text(entry.message)
        }
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
            Spacer()
            BandplanStatusPill(frequencyMHz: radio.frequencyMHz, mode: radio.mode)
            if canSelfSpot {
                Button {
                    spotComments = ""
                    showSpotSheet = true
                } label: {
                    Label("Spot senden", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Self-Spot an pota.app senden (\(role == "Activator" ? "Activator" : "Hunter")-Modus)")
            }
        }
        .padding(8)
        .background(theme.bgCard2)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    /// Self-Spot ist nur sinnvoll wenn wir Activator sind, einen Park
    /// haben, der TRX eine Frequenz kennt und ein Mode gesetzt ist.
    private var canSelfSpot: Bool {
        guard let log = currentLog else { return false }
        guard log.role == "Activator" else { return false }
        guard let ref = log.potaParkRef?.trimmingCharacters(in: .whitespaces),
              !ref.isEmpty else { return false }
        guard radio.frequencyMHz > 0 else { return false }
        guard !radio.mode.isEmpty else { return false }
        return true
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

        // Operator + Station-Call: bevorzugt Log.usedCallsign (Pro-Log-Override
        // für Portabel/Ausland/Club), Fallback auf den globalen Settings-Default.
        // pota.app braucht das in der Upload-ADIF (OPERATOR + STATION_CALLSIGN).
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

        // Callbook-Auto-Fill silently anwenden (im Form nicht angezeigt,
        // aber für ADIF-Upload + DXCC-Aggregation wichtig: NAME, QTH,
        // COUNTRY, GRIDSQUARE, CONTINENT, CQ/ITU-Zone). applyFillingEmpty
        // überschreibt keine vom User selbst getippten Felder.
        lookupResult?.applyFillingEmpty(to: &qso)

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
        lookupResult = nil
        lookupTask?.cancel()
        if !keepLastConfirmation { lastSavedConfirmation = nil }
    }

    // QRZ/HamQTH-Lookup mit Debounce. Wenn der User tippt, warten wir 600 ms
    // bevor wir die Anfrage feuern, sonst hagelt's API-Calls bei jedem Buchstaben.
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
            // Bei Race: nur weitermachen wenn der Call noch derselbe ist
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

    // MARK: - Self-Spot Sheet

    @ViewBuilder
    private var spotSheet: some View {
        let activatorCall = resolveActivatorCall()
        let park = currentLog?.potaParkRef ?? "—"
        let freqKHz = Int((radio.frequencyMHz * 1000).rounded())
        let mode = radio.mode.uppercased()
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("POTA Self-Spot")
                    .font(.title3.bold())
            }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Activator").foregroundStyle(.secondary)
                    Text(activatorCall).font(.body.monospaced())
                }
                GridRow {
                    Text("Park").foregroundStyle(.secondary)
                    Text(park).font(.body.monospaced())
                }
                GridRow {
                    Text("Frequenz").foregroundStyle(.secondary)
                    Text("\(freqKHz) kHz · \(String(format: "%.5f MHz", radio.frequencyMHz))")
                        .font(.body.monospaced())
                }
                GridRow {
                    Text("Mode").foregroundStyle(.secondary)
                    Text(mode).font(.body.monospaced())
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Comment (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("z.B. QRT 5min, QSY 14260, …", text: $spotComments)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Button("Abbrechen") { showSpotSheet = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    Task { await sendSpot() }
                } label: {
                    if spotInFlight {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Senden", systemImage: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(spotInFlight)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func resolveActivatorCall() -> String {
        if let c = currentLog?.usedCallsign?.trimmingCharacters(in: .whitespaces),
           !c.isEmpty {
            return c.uppercased()
        }
        return UserDefaults.standard.string(forKey: "callsign")?
            .trimmingCharacters(in: .whitespaces).uppercased() ?? ""
    }

    @MainActor
    private func sendSpot() async {
        guard let log = currentLog,
              let park = log.potaParkRef?.trimmingCharacters(in: .whitespaces),
              !park.isEmpty else { return }
        let call = resolveActivatorCall()
        let freqKHz = Int((radio.frequencyMHz * 1000).rounded())
        let mode = radio.mode.uppercased()
        let comments = spotComments.trimmingCharacters(in: .whitespaces)
        spotInFlight = true
        defer { spotInFlight = false }
        do {
            try await POTASelfSpotService.sendSpot(
                activator: call,
                spotter: call,
                frequencyKHz: freqKHz,
                reference: park,
                mode: mode,
                comments: comments.isEmpty ? nil : comments)
            showSpotSheet = false
            spotResult = SpotResult(
                success: true,
                title: "Spot gesendet",
                message: "\(call) @ \(park) auf \(freqKHz) kHz \(mode) ist auf pota.app sichtbar.")
        } catch {
            spotResult = SpotResult(
                success: false,
                title: "Spot fehlgeschlagen",
                message: error.localizedDescription)
        }
    }
}
