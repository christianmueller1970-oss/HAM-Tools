import SwiftUI

struct QSOFormSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @Environment(\.dismiss) private var dismiss

    let qso: QSO?           // nil = neu anlegen
    let log: Log

    @State private var call: String = ""
    @State private var datetimeUTC: Date = Date()
    @State private var frequencyMHzText: String = "14.200"
    @State private var bandRaw: String = "20m"
    @State private var mode: String = "SSB"
    @State private var rstSent: String = "59"
    @State private var rstReceived: String = "59"
    @State private var name: String = ""
    @State private var qth: String = ""
    @State private var locator: String = ""
    @State private var comment: String = ""
    @State private var powerText: String = ""
    @State private var antenna: String = ""

    private var theme: AppTheme { themeManager.theme }
    private var isEdit: Bool { qso != nil }

    private var frequencyMHz: Double? {
        Double(frequencyMHzText.replacingOccurrences(of: ",", with: "."))
    }
    private var powerW: Double? {
        guard !powerText.isEmpty else { return nil }
        return Double(powerText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        let trimmedCall = call.trimmingCharacters(in: .whitespaces)
        return !trimmedCall.isEmpty
            && frequencyMHz != nil && (frequencyMHz ?? 0) > 0
            && !bandRaw.isEmpty
            && !mode.isEmpty
    }

    private static let modes = ["SSB", "CW", "AM", "FM", "RTTY",
                                "FT8", "FT4", "JT65", "JS8", "PSK31", "MFSK", "OLIVIA"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(theme.separator)
            ScrollView {
                VStack(spacing: 14) {
                    primaryFields
                    Divider().background(theme.separator)
                    optionalFields
                }
                .padding(20)
            }
            Divider().background(theme.separator)
            footer
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 540, idealHeight: 640)
        .background(theme.bgCard)
        .onAppear(perform: hydrate)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(isEdit ? "QSO bearbeiten" : "Neues QSO")
                    .font(.title2.bold())
                    .foregroundStyle(theme.textPrimary)
                Text("Log: \(log.name)")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: Primary

    private var primaryFields: some View {
        VStack(spacing: 12) {
            // Reihe 1: Call, UTC-Datum
            HStack(alignment: .top, spacing: 12) {
                fieldLabel("Call *", width: 110)
                TextField("Call", text: $call)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: call) { _, newValue in
                        call = newValue.uppercased()
                    }
                    .frame(maxWidth: 200)

                fieldLabel("UTC", width: 50)
                DatePicker("",
                           selection: $datetimeUTC,
                           displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .environment(\.timeZone, TimeZone(identifier: "UTC") ?? .current)

                Button {
                    datetimeUTC = Date()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .help("Aktuelle Zeit (UTC) übernehmen")
            }

            // Reihe 2: Frequenz + Band + Mode
            HStack(alignment: .top, spacing: 12) {
                fieldLabel("Freq (MHz) *", width: 110)
                TextField("14.200", text: $frequencyMHzText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 120)
                    .onChange(of: frequencyMHzText) { _, _ in
                        if let f = frequencyMHz, let b = HamBand.from(frequencyMHz: f) {
                            bandRaw = b.rawValue
                        }
                    }

                fieldLabel("Band", width: 50)
                Picker("Band", selection: $bandRaw) {
                    ForEach(HamBand.allCases) { b in
                        Text(b.displayName).tag(b.rawValue)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 100)

                fieldLabel("Mode *", width: 55)
                Picker("Mode", selection: $mode) {
                    ForEach(Self.modes, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 110)
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

            // Reihe 3: RST sent + received
            HStack(alignment: .top, spacing: 12) {
                fieldLabel("RST sent", width: 110)
                TextField("59", text: $rstSent)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 80)
                fieldLabel("RST rcvd", width: 80)
                TextField("59", text: $rstReceived)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 80)
                Spacer()
            }
        }
    }

    private var optionalFields: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                fieldLabel("Name", width: 110)
                TextField("Vorname", text: $name)
                    .textFieldStyle(.roundedBorder)
                fieldLabel("QTH", width: 50)
                TextField("Stadt", text: $qth)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(alignment: .top, spacing: 12) {
                fieldLabel("Locator", width: 110)
                TextField("Locator", text: $locator)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 130)
                    .onChange(of: locator) { _, newValue in
                        locator = newValue.uppercased()
                    }
                fieldLabel("Power (W)", width: 80)
                TextField("100", text: $powerText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 80)
                fieldLabel("Antenne", width: 70)
                TextField("EFHW 40-10m", text: $antenna)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(alignment: .top, spacing: 12) {
                fieldLabel("Bemerkung", width: 110)
                TextField("Notiz zum QSO", text: $comment, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        }
    }

    private func fieldLabel(_ s: String, width: CGFloat) -> some View {
        Text(s)
            .font(.subheadline)
            .foregroundStyle(theme.textSecondary)
            .frame(width: width, alignment: .trailing)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if let f = frequencyMHz,
               let b = HamBand.from(frequencyMHz: f),
               b.rawValue != bandRaw {
                Label("Band aus Frequenz: \(b.displayName)", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(theme.accentOrange)
            }
            Spacer()
            Button("Abbrechen") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(isEdit ? "Speichern" : "QSO anlegen") {
                commit()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: Hydrate / Commit

    private func hydrate() {
        if let q = qso {
            call = q.call
            datetimeUTC = q.datetime
            frequencyMHzText = String(format: "%.3f", q.frequencyMHz)
            bandRaw = q.band
            mode = q.mode
            rstSent = q.rstSent
            rstReceived = q.rstReceived
            name = q.name ?? ""
            qth = q.qth ?? ""
            locator = q.locator ?? ""
            comment = q.comment ?? ""
            powerText = q.powerW.map { String(format: "%g", $0) } ?? ""
            antenna = q.antenna ?? ""
        } else {
            datetimeUTC = Date()
            rstSent = "59"
            rstReceived = "59"
        }
    }

    private func commit() {
        guard let f = frequencyMHz else { return }
        let trimmedCall = call.trimmingCharacters(in: .whitespaces).uppercased()

        if var q = qso {
            q.call = trimmedCall
            q.datetime = datetimeUTC
            q.frequencyMHz = f
            q.band = bandRaw
            q.mode = mode
            q.rstSent = rstSent
            q.rstReceived = rstReceived
            q.name = name.isEmpty ? nil : name
            q.qth = qth.isEmpty ? nil : qth
            q.locator = locator.isEmpty ? nil : locator
            q.comment = comment.isEmpty ? nil : comment
            q.powerW = powerW
            q.antenna = antenna.isEmpty ? nil : antenna
            q.modifiedAt = Date()
            manager.updateQSO(q)
        } else {
            let q = QSO(
                logID: log.id,
                call: trimmedCall,
                datetime: datetimeUTC,
                frequencyMHz: f,
                band: bandRaw,
                mode: mode,
                rstSent: rstSent,
                rstReceived: rstReceived,
                name: name.isEmpty ? nil : name,
                qth: qth.isEmpty ? nil : qth,
                locator: locator.isEmpty ? nil : locator,
                comment: comment.isEmpty ? nil : comment,
                powerW: powerW,
                antenna: antenna.isEmpty ? nil : antenna
            )
            manager.addQSO(q)
        }
    }
}
