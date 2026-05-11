import SwiftUI

struct NewMemorySheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var memoryStore: MemoryStore
    @Environment(\.dismiss) private var dismiss

    let existing: Memory?

    @State private var label: String = ""
    @State private var call: String = ""
    @State private var name: String = ""
    @State private var frequencyMHzText: String = ""
    @State private var bandRaw: String = "Alle"
    @State private var mode: String = ""
    @State private var hasSked: Bool = false
    @State private var skedDate: Date = Date().addingTimeInterval(3600)
    @State private var notes: String = ""
    @State private var pinned: Bool = false

    private var theme: AppTheme { themeManager.theme }

    private static let modes = ["", "SSB", "CW", "FM", "AM", "RTTY",
                                "FT8", "FT4", "JT65", "JS8", "PSK31"]

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
            && !call.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(existing == nil ? "Neue Memory" : "Memory bearbeiten")
                .font(.title2.bold())
                .foregroundStyle(theme.textPrimary)

            VStack(spacing: 8) {
                row("Label *", value: $label, placeholder: "z.B. »HB9XYZ Field Day«")
                row("Call *",  value: $call,  placeholder: "HB9HJI",
                    monospaced: true, uppercased: true)
                row("Name",    value: $name,  placeholder: "Vorname")

                HStack {
                    Text("Frequenz").frame(width: 90, alignment: .trailing).foregroundStyle(theme.textSecondary)
                    TextField("14.200", text: $frequencyMHzText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: 110)
                    Text("MHz").foregroundStyle(theme.textDim)
                    Spacer()
                }

                HStack {
                    Text("Band").frame(width: 90, alignment: .trailing).foregroundStyle(theme.textSecondary)
                    Picker("Band", selection: $bandRaw) {
                        Text("—").tag("Alle")
                        ForEach(HamBand.allCases) { b in Text(b.displayName).tag(b.rawValue) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 120)
                    Text("Mode").foregroundStyle(theme.textSecondary).padding(.leading, 8)
                    Picker("Mode", selection: $mode) {
                        Text("—").tag("")
                        ForEach(Self.modes.filter { !$0.isEmpty }, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 110)
                    Spacer()
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("Sked").frame(width: 90, alignment: .trailing).foregroundStyle(theme.textSecondary)
                    Toggle("Termin gesetzt", isOn: $hasSked)
                        .toggleStyle(.checkbox)
                    Spacer()
                }
                if hasSked {
                    HStack {
                        Text("").frame(width: 90)
                        DatePicker("", selection: $skedDate,
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .environment(\.timeZone, TimeZone(identifier: "UTC") ?? .current)
                        Text("UTC").foregroundStyle(theme.textDim).font(.caption)
                        Spacer()
                    }
                }

                row("Notizen", value: $notes, placeholder: "z.B. »wöchentlich 80m SSB Sked«")

                HStack {
                    Text("").frame(width: 90)
                    Toggle("Pinnen (oben in der Liste)", isOn: $pinned)
                        .toggleStyle(.checkbox)
                    Spacer()
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(existing == nil ? "Anlegen" : "Speichern") {
                    commit()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 520)
        .background(theme.bgCard)
        .onAppear(perform: hydrate)
    }

    private func row(_ labelText: String,
                     value: Binding<String>,
                     placeholder: String = "",
                     monospaced: Bool = false,
                     uppercased: Bool = false) -> some View {
        HStack {
            Text(labelText)
                .frame(width: 90, alignment: .trailing)
                .foregroundStyle(theme.textSecondary)
            TextField(placeholder, text: value)
                .textFieldStyle(.roundedBorder)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .onChange(of: value.wrappedValue) { _, new in
                    if uppercased, new != new.uppercased() {
                        value.wrappedValue = new.uppercased()
                    }
                }
            Spacer()
        }
    }

    private func hydrate() {
        guard let m = existing else { return }
        label = m.label
        call = m.call
        name = m.name ?? ""
        frequencyMHzText = m.frequencyMHz.map { String(format: "%.3f", $0) } ?? ""
        bandRaw = m.band ?? "Alle"
        mode = m.mode ?? ""
        hasSked = m.skedDate != nil
        if let d = m.skedDate { skedDate = d }
        notes = m.notes ?? ""
        pinned = m.pinned
    }

    private func commit() {
        let freq = Double(frequencyMHzText.replacingOccurrences(of: ",", with: "."))
        let memory = Memory(
            id: existing?.id ?? UUID(),
            label: label.trimmingCharacters(in: .whitespaces),
            call: call.trimmingCharacters(in: .whitespaces).uppercased(),
            name: name.isEmpty ? nil : name,
            frequencyMHz: freq,
            band: bandRaw == "Alle" ? nil : bandRaw,
            mode: mode.isEmpty ? nil : mode,
            skedDate: hasSked ? skedDate : nil,
            notes: notes.isEmpty ? nil : notes,
            pinned: pinned,
            createdAt: existing?.createdAt ?? Date(),
            lastUsedAt: existing?.lastUsedAt
        )
        if existing == nil {
            memoryStore.add(memory)
        } else {
            memoryStore.update(memory)
        }
    }
}
