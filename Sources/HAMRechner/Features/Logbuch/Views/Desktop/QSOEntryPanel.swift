import SwiftUI

// Inline-QSO-Erfassungs-Panel im MacLoggerDX-Look. Drei Spalten mit
// allen relevanten QSO-Feldern. Funktion: bei "Log QSO" wird das aktive
// QSO ins gerade geöffnete Log committed.
struct QSOEntryPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var logBridge: LogEntryBridge

    @State private var entryMode: EntryMode = .dx
    @State private var lastFilledFromSpot: Date? = nil

    // Pflichtfelder
    @State private var call: String = ""
    @State private var timeOn: Date = Date()
    @State private var timeOff: Date? = nil
    @State private var freqMHz: String = "14.200"
    @State private var bandRaw: String = "20m"
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
            && Double(freqMHz.replacingOccurrences(of: ",", with: ".")) != nil
            && manager.currentLogID != nil
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
                onLogQSO: commitQSO,
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
            freqMHz = String(format: "%.3f", f)
        }
        if let b = draft.band, !b.isEmpty {
            bandRaw = b
        } else if let f = draft.frequencyMHz,
                  let auto = HamBand.from(frequencyMHz: f) {
            bandRaw = auto.rawValue
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
        HStack(alignment: .top, spacing: 14) {
            // Spalte 1: Call + Personen / Adresse
            VStack(spacing: 5) {
                fieldRow("Call",     value: $call, monospaced: true, uppercased: true, accent: true)
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
            VStack(spacing: 5) {
                timeFieldRow("Time On",  value: $timeOn)
                timeFieldRow("Time Off", value: Binding(
                    get: { timeOff ?? Date() },
                    set: { timeOff = $0 }
                ), enabled: timeOff != nil)
                fieldRow("MHz",     value: $freqMHz, monospaced: true) { _ in autoUpdateBand() }
                bandPickerRow
                modePickerRow
                fieldRow("RST S",   value: $rstSent, monospaced: true)
                fieldRow("RST R",   value: $rstReceived, monospaced: true)
                fieldRow("Power",   value: $powerW, monospaced: true)
                fieldRow("Locator", value: $locator, monospaced: true, uppercased: true)
                fieldRow("QSL Via", value: $qslVia)
            }
            .frame(maxWidth: .infinity)

            // Spalte 3: Award-Refs + Zonen
            VStack(spacing: 5) {
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
        }
    }

    // MARK: - Field Helpers

    private static let labelColumnWidth: CGFloat = 65

    private func fieldRow(_ label: String,
                          value: Binding<String>,
                          placeholder: String = "",
                          monospaced: Bool = false,
                          uppercased: Bool = false,
                          accent: Bool = false,
                          onChange: ((String) -> Void)? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: Self.labelColumnWidth, alignment: .trailing)
            TextField(placeholder, text: value)
                .textFieldStyle(.plain)
                .font(monospaced
                      ? .system(.caption, design: .monospaced)
                      : .caption)
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
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: Self.labelColumnWidth, alignment: .trailing)
            Text(enabled ? formatUTC(value.wrappedValue) : "—")
                .font(.system(.caption, design: .monospaced))
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
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: Self.labelColumnWidth, alignment: .trailing)
            Picker("Mode", selection: $mode) {
                ForEach(Self.modes, id: \.self) { m in
                    Text(m).tag(m)
                }
            }
            .labelsHidden()
            .controlSize(.mini)
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

    private var bandPickerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Band")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: Self.labelColumnWidth, alignment: .trailing)
            Picker("Band", selection: $bandRaw) {
                ForEach(HamBand.allCases) { b in
                    Text(b.displayName).tag(b.rawValue)
                }
            }
            .labelsHidden()
            .controlSize(.mini)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Logic

    private func autoUpdateBand() {
        if let f = Double(freqMHz.replacingOccurrences(of: ",", with: ".")),
           let b = HamBand.from(frequencyMHz: f) {
            bandRaw = b.rawValue
        }
    }

    private func formatUTC(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    private func commitQSO() {
        guard let logID = manager.currentLogID,
              let f = Double(freqMHz.replacingOccurrences(of: ",", with: ".")) else { return }
        let trimmedCall = call.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmedCall.isEmpty else { return }

        var qso = QSO(
            logID: logID,
            call: trimmedCall,
            datetime: timeOn,
            frequencyMHz: f,
            band: bandRaw,
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
        qso.myPotaRef = pota.isEmpty ? nil : pota
        qso.mySotaRef = sota.isEmpty ? nil : sota
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
        // freqMHz/band/mode/rst/power bleiben (Run-Mode)
    }
}
