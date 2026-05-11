import SwiftUI

// Inline-QSO-Erfassungs-Panel im MacLoggerDX-Look. Drei Spalten mit
// allen relevanten QSO-Feldern. Funktion: bei "Log QSO" wird das aktive
// QSO ins gerade geöffnete Log committed.
struct QSOEntryPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager

    @State private var entryMode: EntryMode = .dx

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
    }

    // MARK: - Mode-Tabs (DX | Contest)

    private var modeTabs: some View {
        HStack(spacing: 0) {
            modeTab(.dx, label: "DX")
            modeTab(.contest, label: "Contest")
            Spacer()
            Text("QSO-Erfassung")
                .font(.caption.bold())
                .foregroundStyle(theme.textDim)
                .padding(.horizontal, 10)
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 0)
    }

    private func modeTab(_ m: EntryMode, label: String) -> some View {
        Button {
            entryMode = m
        } label: {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(entryMode == m ? theme.textPrimary : theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(entryMode == m ? theme.accentBlue.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Entry-Grid (drei Spalten)

    private var entryGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            // Spalte 1: Personen/Adresse
            VStack(spacing: 4) {
                fieldRow("Call",     value: $call, monospaced: true, uppercased: true, accent: true)
                fieldRow("Local",    value: .constant(""), placeholder: "(automatisch)")
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

            // Spalte 2: Zeit, Frequenz, Award-Refs
            VStack(spacing: 4) {
                timeFieldRow("Time On",  value: $timeOn)
                timeFieldRow("Time Off", value: Binding(
                    get: { timeOff ?? Date() },
                    set: { timeOff = $0 }
                ), enabled: timeOff != nil)
                fieldRow("MHz",   value: $freqMHz, monospaced: true) { _ in autoUpdateBand() }
                fieldRow("Power", value: $powerW, monospaced: true)
                fieldRow("Grid",  value: $locator, monospaced: true, uppercased: true)
                fieldRow("ITU",   value: $itu)
                fieldRow("SOTA",  value: $sota)
                fieldRow("QSL Via", value: $qslVia)
                fieldRow("DXCC",  value: $dxcc)
                fieldRow("URL",   value: $url)
            }
            .frame(maxWidth: .infinity)

            // Spalte 3: Mode, RST, restl. Refs
            VStack(spacing: 4) {
                modePickerRow
                fieldRow("RST S", value: $rstSent, monospaced: true)
                fieldRow("RST R", value: $rstReceived, monospaced: true)
                bandPickerRow
                fieldRow("Locator", value: $locator, monospaced: true, uppercased: true)
                fieldRow("IOTA", value: $iota)
                fieldRow("POTA", value: $pota)
                fieldRow("SKCC", value: $skcc)
                fieldRow("WWFF", value: $wwff)
                fieldRow("CQ",   value: $cq)
                fieldRow("DX de", value: $dxDe)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Field Helpers

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
                .frame(width: 60, alignment: .trailing)
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
                .frame(width: 60, alignment: .trailing)
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
                .frame(width: 60, alignment: .trailing)
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
                .frame(width: 60, alignment: .trailing)
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
        // freqMHz/band/mode/rst/power bleiben (Run-Mode)
    }
}
