import SwiftUI

// Settings-Tab für CAT. Radio-Profil, Serial-Port, Baudrate, Poll-Intervall,
// Start/Stop, Status-Anzeige. Discovery der Serial-Ports bei jedem Refresh.
struct CATSettingsView: View {
    @EnvironmentObject var settings: CATSettings
    @EnvironmentObject var cat: CATController

    @State private var availablePorts: [String] = []
    @State private var profiles: [TRXProfile] = []

    private static let supportedBauds: [Int] = [4800, 9600, 19200, 38400, 57600, 115200]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusSection
                profileSection
                connectionSection
                pollSection
                diagnosticsSection
            }
            .padding(16)
        }
        .onAppear {
            refreshPorts()
            refreshProfiles()
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        GroupBox("Status") {
            HStack {
                CATStatusBadge()
                Spacer()
                if cat.status == .connected || cat.status == .starting {
                    Button("Stop") { cat.stop() }
                } else {
                    Button("Start") {
                        Task { await cat.start() }
                    }
                    .disabled(!canStart)
                }
            }
            .padding(.vertical, 4)

            if let err = cat.lastError, case .errored = cat.status {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }
    }

    private var profileSection: some View {
        GroupBox("Radio-Profil") {
            Picker("Modell", selection: profileBinding) {
                Text("— bitte wählen —").tag(String?.none)
                ForEach(profiles) { p in
                    Text(p.name).tag(Optional(p.id))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let selected = profiles.first(where: { $0.id == settings.selectedProfileID }) {
                Text("Hamlib-Rig-Nr.: \(selected.hamlibRigNumber) · Default-Baud: \(selected.defaultBaud)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var connectionSection: some View {
        let selected = profiles.first(where: { $0.id == settings.selectedProfileID })
        let needsPort = selected?.needsSerialPort ?? true

        return GroupBox("Verbindung") {
            if needsPort {
                HStack {
                    Picker("Serial-Port", selection: portBinding) {
                        Text("— wählen —").tag(String?.none)
                        ForEach(availablePorts, id: \.self) { p in
                            Text(p).tag(Optional(p))
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Refresh") { refreshPorts() }
                }

                Picker("Baudrate", selection: $settings.baudRate) {
                    ForEach(Self.supportedBauds, id: \.self) { b in
                        Text("\(b)").tag(b)
                    }
                }
                .pickerStyle(.menu)
                .padding(.top, 4)

                if availablePorts.isEmpty {
                    Text("Keine USB-Serial-Ports gefunden (kein Radio angeschlossen oder Treiber fehlt).")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }
            } else {
                Text("Dummy-Rig benötigt keinen Serial-Port. Hamlib simuliert ein Funkgerät auf 145.000 MHz / FM.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var pollSection: some View {
        GroupBox("Polling") {
            HStack {
                Text("Intervall: \(settings.pollIntervalMillis) ms")
                Spacer()
                Slider(value: pollMsBinding, in: 200...2000, step: 100)
                    .frame(width: 220)
            }
            Text("Wie oft Frequenz/Mode vom Radio gelesen werden. Höher = weniger USB-Last.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var diagnosticsSection: some View {
        GroupBox("Diagnose") {
            if cat.lastPolledHz > 0 {
                Text("Zuletzt empfangen: \(String(format: "%.6f", Double(cat.lastPolledHz) / 1_000_000.0)) MHz, Mode \(cat.lastPolledMode.isEmpty ? "—" : cat.lastPolledMode)")
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Noch keine Daten empfangen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Bindings + Helpers

    private var canStart: Bool {
        guard let id = settings.selectedProfileID,
              let p = profiles.first(where: { $0.id == id }) else { return false }
        if !p.needsSerialPort { return true }
        return settings.serialPort != nil && !(settings.serialPort?.isEmpty ?? true)
    }

    private var profileBinding: Binding<String?> {
        Binding(
            get: { settings.selectedProfileID },
            set: { newID in
                settings.selectedProfileID = newID
                if let id = newID,
                   let p = profiles.first(where: { $0.id == id }) {
                    settings.baudRate = p.defaultBaud
                }
            }
        )
    }

    private var portBinding: Binding<String?> {
        Binding(
            get: { settings.serialPort },
            set: { settings.serialPort = $0 }
        )
    }

    private var pollMsBinding: Binding<Double> {
        Binding(
            get: { Double(settings.pollIntervalMillis) },
            set: { settings.pollIntervalMillis = Int($0) }
        )
    }

    private func refreshPorts() {
        availablePorts = SerialPortDiscovery.availablePorts()
    }

    private func refreshProfiles() {
        profiles = TRXProfileLoader.shared.profiles
    }
}
