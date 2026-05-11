import SwiftUI

// Inline-QSO-Erfassungs-Panel im MacLoggerDX-Look. Drei Spalten mit
// allen relevanten QSO-Feldern. Funktion: bei "Log QSO" wird das aktive
// QSO ins gerade geöffnete Log committed.
// Treffer für die Dupe-Warnung. Wird via .alert(item:) angezeigt.
struct DupeWarning: Identifiable {
    enum Kind {
        case exactInLog       // Call+Band+Mode bereits im aktiven Log
        case recentlySeen     // selber Call irgendwo, < 30 min her
    }
    let id = UUID()
    let kind: Kind
    let match: QSOMatch

    var title: String {
        switch kind {
        case .exactInLog:    return "Dupe — schon gearbeitet"
        case .recentlySeen:  return "Kürzlich schon gesehen"
        }
    }

    var message: String {
        let q = match.qso
        let when = DupeWarning.format(q.datetime)
        let band = q.band, mode = q.mode
        let log = match.logName
        switch kind {
        case .exactInLog:
            return "\(q.call) wurde am \(when) bereits auf \(band) \(mode) im Log »\(log)« geloggt. Trotzdem nochmal eintragen?"
        case .recentlySeen:
            return "\(q.call) wurde vor wenigen Minuten geloggt (\(when), \(band) \(mode), Log »\(log)«). Versehentliches Doppel-Loggen?"
        }
    }

    private static func format(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm 'UTC'"
        return f.string(from: d)
    }
}

struct QSOEntryPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var logBridge: LogEntryBridge
    @EnvironmentObject var callbookSettings: CallbookSettings
    @EnvironmentObject var callbookManager: CallbookManager
    @EnvironmentObject var clusterVM: DXClusterViewModel
    @EnvironmentObject var radio: RadioState

    @State private var entryMode: EntryMode = .dx
    @State private var lastFilledFromSpot: Date? = nil
    @State private var lastFilledFromCallbook: Date? = nil
    @State private var pendingDupe: DupeWarning? = nil

    // Callbook-Lookup-Resultat: Bild-URL + QRZ-Link für die Header-Anzeige
    @State private var callbookImageURL: String? = nil
    @State private var callbookQRZURL: String? = nil
    @State private var callbookSummary: String = ""

    // Focus-State für Call-Feld — Wechsel raus = Auto-Lookup-Trigger
    @FocusState private var callFieldFocused: Bool
    @State private var lastLookedUpCall: String = ""

    // Time On läuft sekündlich mit — wird beim Loggen mit dem aktuellen
    // Wert übernommen. So muss der User nicht manuell die Zeit setzen.
    private let timeOnTimer = Timer.publish(every: 1, on: .main, in: .common)
        .autoconnect()

    // Pflichtfelder
    @State private var call: String = ""
    @State private var timeOn: Date = Date()
    @State private var timeOff: Date? = nil
    @State private var mode: String = "SSB"
    @State private var rstSent: String = "59"
    @State private var rstReceived: String = "59"
    @State private var powerW: String = "100"

    // Personendaten
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var locator: String = ""
    @State private var street: String = ""
    @State private var city: String = ""
    @State private var county: String = ""
    @State private var state: String = ""
    @State private var country: String = ""
    @State private var email: String = ""
    @State private var notes: String = ""

    // Award-Refs
    @State private var iota: String = ""
    @State private var sota: String = ""
    @State private var pota: String = ""
    @State private var wwff: String = ""
    @State private var skcc: String = ""
    @State private var dxcc: String = ""
    @State private var cq: String = ""
    @State private var itu: String = ""
    @State private var qslVia: String = ""
    @State private var url: String = ""
    @State private var dxDe: String = ""

    enum EntryMode: String { case dx = "DX", contest = "Contest" }

    private var theme: AppTheme { themeManager.theme }

    private static let modes = ["SSB", "USB", "LSB", "CW", "AM", "FM", "RTTY",
                                "FT8", "FT4", "JT65", "JS8", "PSK31"]

    private var canLog: Bool {
        !call.trimmingCharacters(in: .whitespaces).isEmpty
            && radio.frequencyMHz > 0
            && manager.currentLogID != nil
    }

    private var canSendSpot: Bool {
        !call.trimmingCharacters(in: .whitespaces).isEmpty
            && radio.frequencyMHz > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            modeTabs
            Divider().background(theme.separator)
            if lastFilledFromSpot != nil {
                spotBanner
                Divider().background(theme.separator)
            }
            entryGrid
                .padding(10)
            Divider().background(theme.separator)
            LogActionBar(
                canLog: canLog,
                canSendSpot: canSendSpot,
                currentCall: call,
                onLogQSO: commitQSO,
                onSendSpot: sendSpotToCluster,
                onClear: resetForm,
                onTimeOn: { timeOn = Date() },
                onTimeOff: { timeOff = Date() }
            )
        }
        .background(theme.bgCard)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear(perform: consumeBridge)
        .onChange(of: logBridge.navigationRequest) {
            consumeBridge()
        }
        .onReceive(timeOnTimer) { _ in
            // Time On läuft mit — wird auf Date() gesetzt bis der QSO
            // geloggt oder das Form resettet wird. Time Off bleibt
            // userkontrolliert.
            timeOn = Date()
        }
        .alert(item: $pendingDupe) { dupe in
            Alert(
                title: Text(dupe.title),
                message: Text(dupe.message),
                primaryButton: .default(Text("Trotzdem loggen")) {
                    performCommit()
                },
                secondaryButton: .cancel(Text("Abbrechen"))
            )
        }
    }

    // Spot-Banner: zeigt an dass Daten aus dem DX-Cluster vorausgefüllt wurden
    private var spotBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                .foregroundStyle(theme.accentBlue)
            Text("Vorausgefüllt aus DX-Cluster-Spot")
                .font(.caption2.weight(.medium))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Button {
                resetForm()
                lastFilledFromSpot = nil
            } label: {
                Text("Verwerfen")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(theme.accentBlue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(theme.accentBlue.opacity(0.12))
    }

    private func consumeBridge() {
        guard let draft = logBridge.consume() else { return }
        applyDraft(draft)
    }

    private func applyDraft(_ draft: QSODraft) {
        call = draft.call.uppercased()
        if let f = draft.frequencyMHz {
            radio.frequencyMHz = f
        }
        if let m = draft.mode, !m.isEmpty {
            mode = m
            // Mode-abhängige RST-Defaults
            if m == "CW" || m == "RTTY" || m == "PSK31" {
                rstSent = "599"; rstReceived = "599"
            }
        }
        if let c = draft.country, !c.isEmpty { country = c }
        // Beim Hunten: der Spot zeigt einen Activator-Park/-Summit — das
        // landet im "their"-Feld des QSOs (wir sind Hunter).
        // Im Eingabeformular gibt es aktuell nur ein generisches POTA/SOTA-
        // Feld pro Award; das nutzen wir.
        if let s = draft.mySotaRef { sota = s }
        if let p = draft.myPotaRef { pota = p }
        if let w = draft.myWwffRef { wwff = w }
        if let dx = draft.spotterCall { dxDe = dx }
        if let cmt = draft.spotComment, !cmt.isEmpty { notes = cmt }
        timeOn = Date()
        lastFilledFromSpot = Date()
    }

    // MARK: - Header mit DX | Contest-Tabs

    private var modeTabs: some View {
        HStack(spacing: 4) {
            modeTab(.dx, label: "DX")
            modeTab(.contest, label: "Contest", enabled: false)
            Spacer()
            if !canLog {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                    Text("Pflichtfelder: Call + Frequenz")
                }
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private func modeTab(_ m: EntryMode, label: String, enabled: Bool = true) -> some View {
        Button {
            if enabled { entryMode = m }
        } label: {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(
                    !enabled ? theme.textDim
                    : entryMode == m ? .white
                    : theme.textSecondary
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(entryMode == m && enabled ? theme.accentBlue : theme.bgCard2)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(entryMode == m && enabled ? theme.accentBlue : theme.separator,
                                lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .opacity(enabled ? 1.0 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(enabled ? "" : "Contest-Modus · Phase 4")
    }

    // MARK: - Entry-Grid (drei Spalten)

    private var entryGrid: some View {
        HStack(alignment: .top, spacing: 8) {
            // Spalte 1: Call + Personen / Adresse
            VStack(spacing: 4) {
                callFieldRow
                fieldRow("First",    value: $firstName)
                fieldRow("Last",     value: $lastName)
                fieldRow("Street",   value: $street)
                fieldRow("City",     value: $city)
                fieldRow("County",   value: $county)
                fieldRow("State",    value: $state)
                fieldRow("Country",  value: $country)
                fieldRow("Email",    value: $email)
                fieldRow("Notes",    value: $notes)
            }
            .frame(maxWidth: .infinity)

            // Spalte 2: Zeit + Frequenz / Band / Mode / RST / Power
            VStack(spacing: 4) {
                timeFieldRow("Time On",  value: $timeOn)
                timeFieldRow("Time Off", value: Binding(
                    get: { timeOff ?? Date() },
                    set: { timeOff = $0 }
                ), enabled: timeOff != nil)
                modePickerRow
                fieldRow("RST S",   value: $rstSent, monospaced: true)
                fieldRow("RST R",   value: $rstReceived, monospaced: true)
                fieldRow("Power",   value: $powerW, monospaced: true)
                fieldRow("Locator", value: $locator, monospaced: true, uppercased: true)
                fieldRow("QSL Via", value: $qslVia)
            }
            .frame(maxWidth: .infinity)

            // Spalte 3: Award-Refs + Zonen
            VStack(spacing: 4) {
                fieldRow("DXCC",  value: $dxcc)
                fieldRow("CQ",    value: $cq)
                fieldRow("ITU",   value: $itu)
                fieldRow("IOTA",  value: $iota)
                fieldRow("POTA",  value: $pota)
                fieldRow("SOTA",  value: $sota)
                fieldRow("WWFF",  value: $wwff)
                fieldRow("SKCC",  value: $skcc)
                fieldRow("URL",   value: $url)
                fieldRow("DX de", value: $dxDe)
            }
            .frame(maxWidth: .infinity)

            // Spalte 4: Callbook-Profil-Karte (Bild + Summary + Link)
            callbookCard
                .frame(width: 250)
        }
    }

    @ViewBuilder
    private var callbookCard: some View {
        if let urlString = callbookImageURL, let imgURL = URL(string: urlString) {
            VStack(alignment: .leading, spacing: 6) {
                AsyncImage(url: imgURL) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Rectangle().fill(theme.bgCard2)
                            ProgressView().controlSize(.small)
                        }
                    case .success(let img):
                        img.resizable().scaledToFit()
                    case .failure:
                        ZStack {
                            Rectangle().fill(theme.bgCard2)
                            Image(systemName: "person.crop.square")
                                .font(.title)
                                .foregroundStyle(theme.textDim)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 250, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(theme.separator, lineWidth: 1)
                )

                if !callbookSummary.isEmpty {
                    Text(callbookSummary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)
                }
                if let qrz = callbookQRZURL, let url = URL(string: qrz) {
                    Link(destination: url) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                            Text("QRZ-Profil öffnen")
                                .font(.caption)
                        }
                        .foregroundStyle(theme.accentBlue)
                    }
                }
                Spacer(minLength: 0)
            }
        } else if !call.isEmpty, callbookManager.isInFlight(call) {
            // Während Lookup läuft: Platzhalter
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    Rectangle().fill(theme.bgCard2)
                    ProgressView().controlSize(.small)
                }
                .frame(width: 250, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                Text("QRZ-Lookup …")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Field Helpers

    private static let labelColumnWidth: CGFloat = 70
    private static let fieldFont: Font = .body
    private static let fieldFontMono: Font = .system(.body, design: .monospaced)

    // Spezial-Row für das Call-Feld: zusätzlich FocusState (TAB-Wechsel
    // triggert Callbook-Lookup) und Lookup-Spinner rechts.
    private var callFieldRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Call")
                .font(Self.fieldFont)
                .foregroundStyle(theme.textSecondary)
                .frame(width: Self.labelColumnWidth, alignment: .trailing)
            TextField("Call", text: $call)
                .textFieldStyle(.plain)
                .font(Self.fieldFontMono)
                .foregroundStyle(theme.accentBlue)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(theme.bgCard2)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(theme.separator.opacity(0.5), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .focused($callFieldFocused)
                .onChange(of: call) { _, newValue in
                    if newValue != newValue.uppercased() {
                        call = newValue.uppercased()
                    }
                }
                .onChange(of: callFieldFocused) { _, focused in
                    // Fokus raus = User hat TAB gedrückt (oder anders weg)
                    if !focused { triggerCallbookLookup() }
                }
            // Lookup-Indikator
            if callbookManager.isInFlight(call) {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 14, height: 14)
            } else if lastFilledFromCallbook != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(theme.accentGreen)
                    .help("Vom Callbook ausgefüllt")
            }
        }
    }

    private func triggerCallbookLookup() {
        guard callbookSettings.autoLookupOnTab,
              callbookSettings.qrzIsConfigured else { return }
        let trimmed = call.trimmingCharacters(in: .whitespaces).uppercased()
        // Nur lookup wenn Call nicht trivial und sich geändert hat
        guard trimmed.count >= 3, trimmed != lastLookedUpCall else { return }
        lastLookedUpCall = trimmed
        Task {
            guard let result = await callbookManager.lookup(call: trimmed) else { return }
            await MainActor.run { applyCallbookResult(result) }
        }
    }

    private func applyCallbookResult(_ r: CallbookResult) {
        // Nur leere Felder befüllen — überschreibt nichts vom User
        if firstName.isEmpty, let v = r.firstName, !v.isEmpty { firstName = v }
        if lastName.isEmpty,  let v = r.lastName,  !v.isEmpty { lastName  = v }
        if let v = r.qth,     city.isEmpty    { city    = v }
        if let v = r.country, country.isEmpty { country = v }
        if let v = r.street,  street.isEmpty  { street  = v }
        if let v = r.state,   state.isEmpty   { state   = v }
        if let v = r.locator, locator.isEmpty { locator = v.uppercased() }
        if let v = r.email,   email.isEmpty   { email   = v }
        // Zonen + DXCC-Entity-Nummer (alle als String im Form)
        if cq.isEmpty,   let v = r.cqZone   { cq   = String(v) }
        if itu.isEmpty,  let v = r.ituZone  { itu  = String(v) }
        if dxcc.isEmpty, let v = r.dxccCode { dxcc = String(v) }
        // Header-Anzeige
        callbookImageURL = r.imageURL
        callbookQRZURL   = r.qrzURL
        callbookSummary  = r.summary
        lastFilledFromCallbook = Date()
    }

    private func fieldRow(_ label: String,
                          value: Binding<String>,
                          placeholder: String = "",
                          monospaced: Bool = false,
                          uppercased: Bool = false,
                          accent: Bool = false,
                          onChange: ((String) -> Void)? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(Self.fieldFont)
                .foregroundStyle(theme.textSecondary)
                .frame(width: Self.labelColumnWidth, alignment: .trailing)
            TextField(placeholder, text: value)
                .textFieldStyle(.plain)
                .font(monospaced ? Self.fieldFontMono : Self.fieldFont)
                .foregroundStyle(accent ? theme.accentBlue : theme.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(theme.bgCard2)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(theme.separator.opacity(0.5), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .onChange(of: value.wrappedValue) { _, newValue in
                    if uppercased && newValue != newValue.uppercased() {
                        value.wrappedValue = newValue.uppercased()
                    }
                    onChange?(newValue)
                }
        }
    }

    private func timeFieldRow(_ label: String,
                              value: Binding<Date>,
                              enabled: Bool = true) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(Self.fieldFont)
                .foregroundStyle(theme.textSecondary)
                .frame(width: Self.labelColumnWidth, alignment: .trailing)
            Text(enabled ? formatUTC(value.wrappedValue) : "—")
                .font(Self.fieldFontMono)
                .foregroundStyle(enabled ? theme.textPrimary : theme.textDim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(theme.bgCard2)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }

    private var modePickerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Mode")
                .font(Self.fieldFont)
                .foregroundStyle(theme.textSecondary)
                .frame(width: Self.labelColumnWidth, alignment: .trailing)
            Picker("Mode", selection: $mode) {
                ForEach(Self.modes, id: \.self) { m in
                    Text(m).tag(m)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: mode) { _, newMode in
                if newMode == "CW" || newMode == "RTTY" || newMode == "PSK31" {
                    if rstSent == "59" { rstSent = "599" }
                    if rstReceived == "59" { rstReceived = "599" }
                } else {
                    if rstSent == "599" { rstSent = "59" }
                    if rstReceived == "599" { rstReceived = "59" }
                }
            }
        }
    }

    // MARK: - Logic

    private func formatUTC(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    /// Sendet die aktuellen Form-Daten als DX-Spot ans Cluster.
    /// Voraussetzung: Call + Frequenz. Frequenz wird MHz → kHz konvertiert
    /// (das DX-Spider-Protokoll erwartet kHz).
    private func sendSpotToCluster() {
        let trimmedCall = call.trimmingCharacters(in: .whitespaces).uppercased()
        let mhz = radio.frequencyMHz
        guard !trimmedCall.isEmpty, mhz > 0 else { return }
        let freqKHz = mhz * 1000.0
        let parts = [mode, notes].filter { !$0.isEmpty }
        let comment = parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        clusterVM.sendSpot(freq: freqKHz, call: trimmedCall, comment: comment)
    }

    private func commitQSO() {
        // Erst Dupe-Check — wenn was gefunden, Alert anzeigen.
        // Wenn nicht, direkt commiten.
        if let dupe = findDuplicate() {
            pendingDupe = dupe
            return
        }
        performCommit()
    }

    private func performCommit() {
        guard let logID = manager.currentLogID else { return }
        let f = radio.frequencyMHz
        guard f > 0 else { return }
        let trimmedCall = call.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmedCall.isEmpty else { return }

        var qso = QSO(
            logID: logID,
            call: trimmedCall,
            datetime: timeOn,
            frequencyMHz: f,
            band: radio.band.isEmpty ? "—" : radio.band,
            mode: mode,
            rstSent: rstSent,
            rstReceived: rstReceived
        )
        let combinedName = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        qso.name = combinedName.isEmpty ? nil : combinedName
        qso.qth = city.isEmpty ? nil : city
        qso.locator = locator.isEmpty ? nil : locator
        qso.country = country.isEmpty ? nil : country
        qso.comment = notes.isEmpty ? nil : notes
        qso.powerW = Double(powerW.replacingOccurrences(of: ",", with: "."))
        qso.cqZone  = Int(cq.trimmingCharacters(in: .whitespaces))
        qso.ituZone = Int(itu.trimmingCharacters(in: .whitespaces))
        qso.myPotaRef = pota.isEmpty ? nil : pota
        qso.mySotaRef = sota.isEmpty ? nil : sota
        manager.addQSO(qso)
        resetForm()
    }

    /// Findet potenzielle Duplikate:
    ///  - Exakter Match (Call+Band+Mode) im aktiven Log → "schon mal gearbeitet"
    ///  - Recent Match (selber Call irgendwo, letzte 30 min) → "Doppel-Log?"
    private func findDuplicate() -> DupeWarning? {
        let trimmedCall = call.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmedCall.isEmpty else { return nil }

        let matches = manager.findQSOs(forCall: trimmedCall)
        guard !matches.isEmpty else { return nil }

        // 1) Exakter Band+Mode-Match im aktiven Log → klassischer Dupe
        let currentBand = radio.band
        if let exact = matches.first(where: {
            $0.logID == manager.currentLogID
                && $0.qso.band == currentBand
                && $0.qso.mode == mode
        }) {
            return DupeWarning(kind: .exactInLog, match: exact)
        }

        // 2) Sehr kurz vorher schonmal (selber Call irgendwo) → Doppel-Log?
        let cutoff = Date().addingTimeInterval(-30 * 60)
        if let recent = matches.first(where: { $0.qso.datetime > cutoff }) {
            return DupeWarning(kind: .recentlySeen, match: recent)
        }

        return nil
    }

    private func resetForm() {
        call = ""
        timeOn = Date()
        timeOff = nil
        firstName = ""
        lastName = ""
        street = ""
        city = ""
        county = ""
        state = ""
        country = ""
        email = ""
        notes = ""
        locator = ""
        iota = ""
        sota = ""
        pota = ""
        wwff = ""
        skcc = ""
        dxcc = ""
        cq = ""
        itu = ""
        qslVia = ""
        url = ""
        dxDe = ""
        lastFilledFromSpot = nil
        lastFilledFromCallbook = nil
        lastLookedUpCall = ""
        callbookImageURL = nil
        callbookQRZURL = nil
        callbookSummary = ""
        // freqMHz/band/mode/rst/power bleiben (Run-Mode)
    }
}
