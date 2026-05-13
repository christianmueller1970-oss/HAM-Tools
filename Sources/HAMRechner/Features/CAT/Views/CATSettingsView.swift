import SwiftUI

// CAT-Settings-Tab. Multi-Config-Modell mit Hersteller/Modell-Picker,
// Auto-Fill der Werkseinstellungen, voller Serial-Parameter-Editor,
// Start/Stop-Button. Werte sind live editierbar nach dem Auto-Fill.
struct CATSettingsView: View {
    @EnvironmentObject var settings: CATSettings
    @EnvironmentObject var cat: CATController

    @State private var availablePorts: [String] = []
    @State private var selectedBrand: String = ""
    @State private var newConfigName: String = ""
    @State private var showNewConfigSheet: Bool = false

    private static let supportedBauds:    [Int]              = [1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200]
    private static let supportedDataBits: [Int]              = [7, 8]
    private static let supportedStopBits: [Int]              = [1, 2]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusSection
                configManagementSection
                profileSection
                serialSection
                civSection
                pollSection
                diagnosticsSection
            }
            .padding(16)
        }
        .onAppear {
            refreshPorts()
            syncBrandFromActiveProfile()
        }
        .sheet(isPresented: $showNewConfigSheet) {
            newConfigSheet
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

    private var configManagementSection: some View {
        GroupBox("Konfiguration") {
            HStack {
                Picker("Aktive Konfig", selection: activeConfigIDBinding) {
                    ForEach(settings.configs) { cfg in
                        Text(cfg.name).tag(Optional(cfg.id))
                    }
                }
                .pickerStyle(.menu)

                Button("Speichern unter…") {
                    // Default-Name vom aktiven Profil ableiten, dann editierbar.
                    let active = settings.activeConfig
                    let suggested = TRXProfileLoader.shared
                        .profile(forID: active?.profileID ?? "")?
                        .model ?? "Neue Konfig"
                    newConfigName = suggested
                    showNewConfigSheet = true
                }
                .help("Aktuelle Einstellungen als neue Konfiguration speichern.")
                Button("Löschen") {
                    if let id = settings.activeConfigID {
                        settings.removeConfig(id: id)
                        syncBrandFromActiveProfile()
                    }
                }
                .disabled(settings.configs.count <= 1)
            }

            if let cfg = settings.activeConfig {
                TextField("Name", text: nameBinding(for: cfg))
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 4)
            }

            Text("Mehrere Konfigurationen sind möglich — z.B. eine pro Radio. Änderungen werden in der aktuell ausgewählten Konfig gespeichert; zwischen Konfigs wechselst du oben im Picker.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    private var profileSection: some View {
        let brands = TRXProfileLoader.shared.brands

        return GroupBox("Radio") {
            HStack {
                Picker("Hersteller", selection: brandPickerBinding) {
                    ForEach(brands, id: \.self) { b in
                        Text(b).tag(b)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)

                Picker("Modell", selection: modelPickerBinding) {
                    ForEach(TRXProfileLoader.shared.profiles(forBrand: selectedBrand)) { p in
                        Text(p.model).tag(p.id)
                    }
                }
                .pickerStyle(.menu)
            }

            if let selected = TRXProfileLoader.shared.profile(forID: settings.activeConfig?.profileID ?? "") {
                HStack {
                    Text("Hamlib-Rig-Nr.: \(selected.hamlibRigNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Werkseinstellungen zurücksetzen") {
                        settings.applyProfileDefaultsToActive(selected)
                    }
                    .controlSize(.small)
                }
                .padding(.top, 2)
            }
        }
    }

    private var serialSection: some View {
        let activeProfile = TRXProfileLoader.shared.profile(forID: settings.activeConfig?.profileID ?? "")
        let needsPort = activeProfile?.needsSerialPort ?? false

        return GroupBox("Serielle Schnittstelle") {
            if !needsPort {
                Text("Aktuelles Profil benötigt keinen Serial-Port (Dummy).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    Picker("Port", selection: serialPortBinding) {
                        Text("— wählen —").tag(String?.none)
                        ForEach(availablePorts, id: \.self) { p in
                            Text(p).tag(Optional(p))
                        }
                    }
                    .pickerStyle(.menu)
                    Button("Refresh") { refreshPorts() }
                }

                if availablePorts.isEmpty {
                    Text("Keine USB-Serial-Ports gefunden.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }

                HStack {
                    Picker("Baudrate", selection: baudBinding) {
                        ForEach(Self.supportedBauds, id: \.self) { b in
                            Text("\(b)").tag(b)
                        }
                    }
                    Picker("Datenbits", selection: dataBitsBinding) {
                        ForEach(Self.supportedDataBits, id: \.self) { b in
                            Text("\(b)").tag(b)
                        }
                    }
                    .frame(maxWidth: 140)
                }
                .padding(.top, 4)

                HStack {
                    Picker("Stopbits", selection: stopBitsBinding) {
                        ForEach(Self.supportedStopBits, id: \.self) { b in
                            Text("\(b)").tag(b)
                        }
                    }
                    .frame(maxWidth: 140)
                    Picker("Parität", selection: parityBinding) {
                        ForEach(SerialParity.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                }
                .padding(.top, 4)

                Picker("Flusskontrolle", selection: handshakeBinding) {
                    ForEach(SerialHandshake.allCases) { h in
                        Text(h.displayName).tag(h)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // CI-V Address — nur für ICOM-Geräte. Default kommt aus dem Profil,
    // User kann überschreiben (z.B. wenn er das Default-CI-V der Firmware
    // selber umgestellt hat, oder mehrere ICOMs am selben Bus).
    @ViewBuilder
    private var civSection: some View {
        if let profile = TRXProfileLoader.shared.profile(forID: settings.activeConfig?.profileID ?? ""),
           profile.brand == "Icom" {
            GroupBox("CI-V (ICOM)") {
                HStack {
                    TextField("0x94", text: civBinding)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 110)
                    if let def = profile.defaultCIVAddress {
                        Button("Default (\(def))") {
                            guard var c = settings.activeConfig else { return }
                            c.civAddress = def
                            settings.activeConfig = c
                        }
                        .controlSize(.small)
                    }
                    Spacer()
                }
                Text("Hex-Wert wie auf dem Radio eingestellt (Menü → CI-V Address). Hamlib übernimmt den Wert beim Start; bei abweichendem Wert blinkt die Verbindung nicht auf.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pollSection: some View {
        GroupBox("Polling") {
            if let cfg = settings.activeConfig {
                HStack {
                    Text("Intervall: \(cfg.pollIntervalMillis) ms")
                    Spacer()
                    Slider(value: pollMsBinding, in: 200...2000, step: 100)
                        .frame(width: 220)
                }
                Text("Wie oft Frequenz/Mode vom Radio gelesen werden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var diagnosticsSection: some View {
        GroupBox("Diagnose") {
            VStack(alignment: .leading, spacing: 6) {
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
                // Letzte Fehlermeldung redundant zur Status-Section anzeigen,
                // damit sie auch sichtbar ist wenn weit nach unten gescrollt.
                if case .errored(let msg) = cat.status {
                    Divider()
                    Text("⚠ Fehler beim letzten Verbindungsversuch:")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    Text(msg)
                        .font(.caption.monospaced())
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var newConfigSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Konfiguration speichern unter…")
                .font(.headline)
            Text("Die aktuellen CAT-Einstellungen (Radio, Port, Baud, …) werden als neue Konfiguration unter dem hier eingegebenen Namen abgelegt. Vorhandene Konfigurationen bleiben unverändert.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Name (z.B. IC-705 Mobile)", text: $newConfigName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Abbrechen") { showNewConfigSheet = false }
                Spacer()
                Button("Speichern") {
                    let n = newConfigName.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    // 1:1-Kopie der aktiven Konfig — auch Port und Poll-Interval,
                    // damit der User nichts nochmal eingeben muss.
                    let template = settings.activeConfig
                    let newCfg = CATConfig(
                        name: n,
                        profileID: template?.profileID ?? "hamlib-dummy",
                        serialPort: template?.serialPort,
                        baudRate: template?.baudRate ?? 9600,
                        dataBits: template?.dataBits ?? 8,
                        stopBits: template?.stopBits ?? 1,
                        parity: template?.parity ?? .none,
                        handshake: template?.handshake ?? .none,
                        pollIntervalMillis: template?.pollIntervalMillis ?? 500
                    )
                    settings.addConfig(newCfg)
                    syncBrandFromActiveProfile()
                    showNewConfigSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newConfigName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    // MARK: - Bindings

    private var canStart: Bool {
        guard let cfg = settings.activeConfig,
              let p = TRXProfileLoader.shared.profile(forID: cfg.profileID) else { return false }
        if !p.needsSerialPort { return true }
        return cfg.serialPort != nil && !(cfg.serialPort?.isEmpty ?? true)
    }

    private var activeConfigIDBinding: Binding<UUID?> {
        Binding(
            get: { settings.activeConfigID },
            set: { newID in
                settings.activeConfigID = newID
                syncBrandFromActiveProfile()
            }
        )
    }

    private func nameBinding(for cfg: CATConfig) -> Binding<String> {
        Binding(
            get: { settings.activeConfig?.name ?? "" },
            set: { v in
                guard var c = settings.activeConfig else { return }
                c.name = v
                settings.activeConfig = c
            }
        )
    }

    // Hersteller-Picker: Setter wird NUR bei User-Action aufgerufen, NICHT
    // bei programmatischer Sync via syncBrandFromActiveProfile. Damit ist
    // Auto-Fill (erstes Modell der neuen Marke laden) sauber an die User-
    // Interaktion gekoppelt und überschreibt keine bestehenden Konfigs beim
    // Öffnen der Settings.
    private var brandPickerBinding: Binding<String> {
        Binding(
            get: { selectedBrand },
            set: { newBrand in
                selectedBrand = newBrand
                if let first = TRXProfileLoader.shared.profiles(forBrand: newBrand).first {
                    settings.applyProfileDefaultsToActive(first)
                }
            }
        )
    }

    // Modell-Picker: Setter wird NUR bei User-Action aufgerufen. Wendet
    // die Werkseinstellungen des gewählten Modells auf die aktive Konfig an.
    // Bei Config-Wechsel über "Aktive Konfig"-Dropdown läuft der Setter
    // NICHT — die UI updated nur über den Getter.
    private var modelPickerBinding: Binding<String> {
        Binding(
            get: { settings.activeConfig?.profileID ?? "" },
            set: { newID in
                if let p = TRXProfileLoader.shared.profile(forID: newID) {
                    settings.applyProfileDefaultsToActive(p)
                }
            }
        )
    }

    private var serialPortBinding: Binding<String?> {
        Binding(
            get: { settings.activeConfig?.serialPort },
            set: { v in
                guard var c = settings.activeConfig else { return }
                c.serialPort = v
                settings.activeConfig = c
            }
        )
    }

    private var baudBinding: Binding<Int> {
        Binding(
            get: { settings.activeConfig?.baudRate ?? 9600 },
            set: { v in
                guard var c = settings.activeConfig else { return }
                c.baudRate = v
                settings.activeConfig = c
            }
        )
    }

    private var dataBitsBinding: Binding<Int> {
        Binding(
            get: { settings.activeConfig?.dataBits ?? 8 },
            set: { v in
                guard var c = settings.activeConfig else { return }
                c.dataBits = v
                settings.activeConfig = c
            }
        )
    }

    private var stopBitsBinding: Binding<Int> {
        Binding(
            get: { settings.activeConfig?.stopBits ?? 1 },
            set: { v in
                guard var c = settings.activeConfig else { return }
                c.stopBits = v
                settings.activeConfig = c
            }
        )
    }

    private var parityBinding: Binding<SerialParity> {
        Binding(
            get: { settings.activeConfig?.parity ?? .none },
            set: { v in
                guard var c = settings.activeConfig else { return }
                c.parity = v
                settings.activeConfig = c
            }
        )
    }

    private var handshakeBinding: Binding<SerialHandshake> {
        Binding(
            get: { settings.activeConfig?.handshake ?? .none },
            set: { v in
                guard var c = settings.activeConfig else { return }
                c.handshake = v
                settings.activeConfig = c
            }
        )
    }

    private var pollMsBinding: Binding<Double> {
        Binding(
            get: { Double(settings.activeConfig?.pollIntervalMillis ?? 500) },
            set: { v in
                guard var c = settings.activeConfig else { return }
                c.pollIntervalMillis = Int(v)
                settings.activeConfig = c
            }
        )
    }

    private var civBinding: Binding<String> {
        Binding(
            get: { settings.activeConfig?.civAddress ?? "" },
            set: { v in
                guard var c = settings.activeConfig else { return }
                c.civAddress = v.trimmingCharacters(in: .whitespaces).isEmpty ? nil : v
                settings.activeConfig = c
            }
        )
    }

    // MARK: - Helpers

    private func refreshPorts() {
        availablePorts = SerialPortDiscovery.availablePorts()
    }

    private func syncBrandFromActiveProfile() {
        guard let cfg = settings.activeConfig,
              let p = TRXProfileLoader.shared.profile(forID: cfg.profileID) else {
            selectedBrand = TRXProfileLoader.shared.brands.first ?? ""
            return
        }
        selectedBrand = p.brand
    }
}
