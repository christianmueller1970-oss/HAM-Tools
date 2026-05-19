import SwiftUI

// Inline-QSO-Erfassungs-Panel im Desktop-Logger-Look. Drei Spalten mit
// allen relevanten QSO-Feldern. Funktion: bei "Log QSO" wird das aktive
// QSO ins gerade geöffnete Log committed.
struct QSOEntryPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var logBridge: LogEntryBridge
    @EnvironmentObject var callbookSettings: CallbookSettings
    @EnvironmentObject var callbookManager: CallbookManager
    @EnvironmentObject var clusterVM: DXClusterViewModel
    @EnvironmentObject var radio: RadioState

    // entryMode wird aus dem aktiven Log abgeleitet, damit der DX/Contest/
    // Outdoor-Tab oben *und* der DX-Cluster-Tab unten immer dieselbe Welt
    // zeigen. POTA/SOTA (und künftig WWFF/BOTA) sind Sub-Modi unter Outdoor
    // — sichtbar als zweite Tab-Bar wenn entryMode == .outdoor.
    private var entryMode: EntryMode {
        if isContestLogActive                                                       { return .contest }
        if isPOTALogActive || isSOTALogActive || isWWFFLogActive || isBOTALogActive { return .outdoor }
        return .dx
    }

    // Wenn entryMode == .outdoor: welcher Sub-Mode ist aktiv?
    private var outdoorMode: OutdoorMode {
        if isPOTALogActive { return .pota }
        if isSOTALogActive { return .sota }
        if isWWFFLogActive { return .wwff }
        if isBOTALogActive { return .bota }
        return .pota
    }
    @State private var lastFilledFromSpot: Date? = nil
    @State private var lastFilledFromCallbook: Date? = nil
    @State private var showNewPOTASheet: Bool = false
    @State private var showNewContestSheet: Bool = false
    @State private var showNewSOTASheet: Bool = false
    @State private var showNewWWFFSheet: Bool = false
    @State private var showNewBOTASheet: Bool = false

    // Aktive Log-Variante (Log-Objekt, nicht nur ID) für Render-Entscheidungen
    private var activeLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }
    private var isPOTALogActive: Bool {
        activeLog?.type == .pota
    }
    private var isContestLogActive: Bool {
        activeLog?.type == .contest
    }
    private var isSOTALogActive: Bool {
        activeLog?.type == .sota
    }
    private var isWWFFLogActive: Bool {
        activeLog?.type == .wwff
    }
    private var isBOTALogActive: Bool {
        activeLog?.type == .bota
    }

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

    enum EntryMode: String { case dx = "DX", contest = "Contest", outdoor = "Outdoor" }

    // Sub-Modi unter Outdoor. POTA + SOTA sind live, WWFF/BOTA sind disabled
    // bis Phase 4e/4f. Sortierung nach Implementierungs-Reihenfolge.
    enum OutdoorMode: String, CaseIterable, Identifiable {
        case pota = "POTA"
        case sota = "SOTA"
        case wwff = "WWFF"
        case bota = "BOTA"

        var id: String { rawValue }
        var isAvailable: Bool { true }
        var comingSoonNote: String { "" }
    }

    private var theme: AppTheme { themeManager.theme }

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
            if isContestLogActive {
                // Schlanke Contest-Form ersetzt das DX-Grid + ActionBar
                ContestEntryForm()
            } else if isPOTALogActive {
                // Schlanke POTA-Form ersetzt das DX-Grid + ActionBar
                POTAEntryForm()
            } else if isSOTALogActive {
                // Schlanke SOTA-Form ersetzt das DX-Grid + ActionBar
                SOTAEntryForm()
            } else if isWWFFLogActive {
                // Schlanke WWFF-Form ersetzt das DX-Grid + ActionBar
                WWFFEntryForm()
            } else if isBOTALogActive {
                // Schlanke BOTA-Form ersetzt das DX-Grid + ActionBar
                BOTAEntryForm()
            } else {
                if lastFilledFromSpot != nil {
                    spotBanner
                    Divider().background(theme.separator)
                }
                entryGrid
                    .padding(10)
                HStack {
                    Spacer()
                    BandplanStatusPill(frequencyMHz: radio.frequencyMHz, mode: radio.mode)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
                Divider().background(theme.separator)
                LogActionBar(
                    canLog: canLog,
                    canSendSpot: canSendSpot,
                    currentCall: call,
                    onLogQSO: performCommit,
                    onSendSpot: sendSpotToCluster,
                    onClear: resetForm,
                    onTimeOn: { timeOn = Date() },
                    onTimeOff: { timeOff = Date() }
                )
            }
        }
        .sheet(isPresented: $showNewPOTASheet) {
            NewPOTALogSheet()
        }
        .sheet(isPresented: $showNewContestSheet) {
            NewContestLogSheet()
        }
        .sheet(isPresented: $showNewSOTASheet) {
            NewSOTALogSheet()
        }
        .sheet(isPresented: $showNewWWFFSheet) {
            NewWWFFLogSheet()
        }
        .sheet(isPresented: $showNewBOTASheet) {
            NewBOTALogSheet()
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
        .onChange(of: radio.mode) { _, newMode in
            // Mode-abhängige RST-Defaults — Mode kommt aus CAT, daher hängen
            // wir die Default-Logik an radio.mode.
            if newMode == "CW" || newMode == "RTTY" || newMode == "PSK31" {
                if rstSent == "59" { rstSent = "599" }
                if rstReceived == "59" { rstReceived = "599" }
            } else {
                if rstSent == "599" { rstSent = "59" }
                if rstReceived == "599" { rstReceived = "59" }
            }
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
        // Im Contest-/POTA-/SOTA-/WWFF-/BOTA-Modus übernimmt das jeweilige
        // spezialisierte Form den Draft selbst.
        guard !isContestLogActive, !isPOTALogActive,
              !isSOTALogActive, !isWWFFLogActive, !isBOTALogActive else { return }
        guard let draft = logBridge.consume() else { return }
        applyDraft(draft)
    }

    private func applyDraft(_ draft: QSODraft) {
        call = draft.call.uppercased()
        if let f = draft.frequencyMHz {
            radio.frequencyMHz = f
        }
        if let m = draft.mode, !m.isEmpty {
            radio.mode = m
            // Mode-abhängige RST-Defaults
            if m == "CW" || m == "RTTY" || m == "PSK31" {
                rstSent = "599"; rstReceived = "599"
            }
        }
        // Spot-Klick wechselt die Station — Callbook-belegte Felder der
        // vorigen Station leeren, damit der frische QRZ-Lookup sie mit den
        // korrekten Daten neu befüllen kann. `applyCallbookResult` schreibt
        // nur leere Felder, daher müssen wir hier explizit räumen.
        clearCallbookFields()
        // Lookup-Guard zurücksetzen, damit derselbe Call (z.B. zweimal
        // hintereinander geklickter Spot) wieder einen frischen Lookup auslöst.
        lastLookedUpCall = ""

        if let c = draft.country, !c.isEmpty { country = c } else { country = "" }
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

        // Nach Spot-Klick automatisch QRZ-Lookup auslösen (Name, Locator,
        // QTH …). Respektiert callbookSettings.autoLookupOnTab und macht
        // keine doppelten Requests dank lastLookedUpCall-Guard.
        triggerCallbookLookup()
    }

    // MARK: - Header mit DX | Contest | Outdoor Tabs (+ Sub-Bar)

    private var modeTabs: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                modeTab(.dx, label: "DX")
                modeTab(.contest, label: "Contest")
                modeTab(.outdoor, label: "Outdoor")
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
            // Zweite Zeile: Sub-Picker für Outdoor-Programme (POTA/SOTA/WWFF/BOTA).
            // Nur sichtbar wenn Outdoor-Tab aktiv ist — sonst kostet das nur
            // vertikalen Platz ohne Nutzen.
            if entryMode == .outdoor {
                HStack(spacing: 4) {
                    ForEach(OutdoorMode.allCases) { sub in
                        outdoorSubTab(sub)
                    }
                    Spacer()
                }
                .padding(.leading, 16)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private func modeTab(_ m: EntryMode, label: String, enabled: Bool = true) -> some View {
        Button {
            guard enabled else { return }
            switch m {
            case .dx:
                // Outdoor/Contest → Standard: zurück zum zuletzt offenen Standard-Log.
                if isPOTALogActive || isContestLogActive || isSOTALogActive {
                    manager.switchToLastLog(of: .standard)
                }
            case .contest:
                // DX/Outdoor → Contest: zuletzt offenen Contest-Log öffnen,
                // sonst Wizard anbieten.
                if !isContestLogActive {
                    if manager.logs.contains(where: { $0.type == .contest }) {
                        manager.switchToLastLog(of: .contest)
                    } else {
                        showNewContestSheet = true
                    }
                }
            case .outdoor:
                // DX/Contest → Outdoor: wenn schon ein POTA- oder SOTA-Log
                // aktiv ist, machen wir nichts (entryMode ist dann schon
                // .outdoor). Sonst pragmatisch: letztes Outdoor-Programm
                // bevorzugen (POTA > SOTA — POTA ist im HB9HJI-Workflow
                // häufiger). Falls auch das fehlt: POTA-Wizard.
                if !isPOTALogActive && !isSOTALogActive {
                    if manager.logs.contains(where: { $0.type == .pota }) {
                        manager.switchToLastLog(of: .pota)
                    } else if manager.logs.contains(where: { $0.type == .sota }) {
                        manager.switchToLastLog(of: .sota)
                    } else {
                        showNewPOTASheet = true
                    }
                }
            }
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

    // Sub-Tab unter dem Outdoor-Haupt-Tab. Klick wechselt das aktive Log
    // zum jeweiligen Programm bzw. zeigt den Anlege-Wizard wenn noch keine
    // Session existiert. WWFF/BOTA sind disabled bis Phase 4e/4f — Klick
    // gibt einen Tooltip-Hinweis.
    private func outdoorSubTab(_ sub: OutdoorMode) -> some View {
        let isActiveSub = entryMode == .outdoor && outdoorMode == sub
        let enabled = sub.isAvailable
        return Button {
            guard enabled else { return }
            switch sub {
            case .pota:
                if !isPOTALogActive {
                    if manager.logs.contains(where: { $0.type == .pota }) {
                        manager.switchToLastLog(of: .pota)
                    } else {
                        showNewPOTASheet = true
                    }
                }
            case .sota:
                if !isSOTALogActive {
                    if manager.logs.contains(where: { $0.type == .sota }) {
                        manager.switchToLastLog(of: .sota)
                    } else {
                        showNewSOTASheet = true
                    }
                }
            case .wwff:
                if !isWWFFLogActive {
                    if manager.logs.contains(where: { $0.type == .wwff }) {
                        manager.switchToLastLog(of: .wwff)
                    } else {
                        showNewWWFFSheet = true
                    }
                }
            case .bota:
                if !isBOTALogActive {
                    if manager.logs.contains(where: { $0.type == .bota }) {
                        manager.switchToLastLog(of: .bota)
                    } else {
                        showNewBOTASheet = true
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(sub.rawValue)
                if !enabled {
                    // Mini-Marker für „kommt bald"
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                }
            }
            .font(.caption2.bold())
            .foregroundStyle(
                !enabled ? theme.textDim
                : isActiveSub ? .white
                : theme.textSecondary
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(isActiveSub && enabled ? theme.colorPOTA.opacity(0.85) : theme.bgCard2)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isActiveSub && enabled ? theme.colorPOTA : theme.separator.opacity(0.6),
                            lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .opacity(enabled ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(enabled ? "" : "\(sub.comingSoonNote) — kommt bald")
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

            // Spalte 2: Zeit + Frequenz / Band / RST / Power
            // Mode kommt aus dem CAT-Bereich (radio.mode), kein separates Feld hier.
            VStack(spacing: 4) {
                timeFieldRow("Time On",  value: $timeOn)
                timeFieldRow("Time Off", value: Binding(
                    get: { timeOff ?? Date() },
                    set: { timeOff = $0 }
                ), enabled: timeOff != nil)
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
                CachedQRZImage(url: imgURL, theme: theme)
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
                    // Sidebar "DX-Spot senden" liest diesen Wert und übernimmt
                    // ihn automatisch ins DX-Call-Feld — Spot-Workflow ohne
                    // doppeltes Tippen.
                    logBridge.draftCallLive = call
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
        // Call hat sich gegenüber dem letzten Lookup geändert → Reste der
        // vorigen Station räumen, damit applyCallbookResult sie neu befüllt.
        clearCallbookFields()
        Task {
            guard let result = await callbookManager.lookup(call: trimmed) else { return }
            await MainActor.run { applyCallbookResult(result) }
        }
    }

    /// Räumt alle Felder, die `applyCallbookResult` befüllt — wird vor
    /// einem frischen Lookup (Spot-Klick oder manuelle Call-Änderung)
    /// aufgerufen, damit nicht Reste der vorigen Station stehen bleiben.
    private func clearCallbookFields() {
        firstName = ""; lastName = ""
        street = ""; city = ""; county = ""; state = ""
        email = ""; locator = ""
        dxcc = ""; cq = ""; itu = ""
        callbookImageURL = nil
        callbookQRZURL = nil
        callbookSummary = ""
        lastFilledFromCallbook = nil
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
        let parts = [radio.mode, notes].filter { !$0.isEmpty }
        let comment = parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        clusterVM.sendSpot(freq: freqKHz, call: trimmedCall, comment: comment)
    }

    // Standard-DX-Log committed direkt ohne Dupe-Warnung: hier ist es
    // legitim, denselben Call mehrfach zu loggen (Stammrunde, Lebens-Log).
    // Programm- und Contest-Logs haben ihre eigenen Dupe-Regeln in den
    // jeweiligen EntryForms (POTA-Band-Dupe, SOTA-Call-Band-Mode,
    // Contest-Multiplier-Logik).
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
            mode: radio.mode,
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

        // stationCall/operatorCall: bevorzugt Log.usedCallsign (Pro-Log-Override
        // für Portabel/Ausland), Fallback auf Settings-Default. Konsistent mit
        // den Award-EntryForms (POTA/SOTA/WWFF/BOTA).
        let myCall: String = {
            if let logCall = activeLog?.usedCallsign?
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

        manager.addQSO(qso)
        resetForm()
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
