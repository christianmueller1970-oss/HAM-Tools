import SwiftUI

// MARK: - Root

struct EinstellungenView: View {
    var body: some View {
        TabView {
            StationTab()
                .tabItem { Label("Station", systemImage: "antenna.radiowaves.left.and.right") }
            ClusterTab()
                .tabItem { Label("Cluster", systemImage: "server.rack") }
            DatenTab()
                .tabItem { Label("Daten", systemImage: "internaldrive") }
            CallbookTab()
                .tabItem { Label("Callbook", systemImage: "person.text.rectangle") }
            DarstellungTab()
                .tabItem { Label("Darstellung", systemImage: "paintpalette") }
            AlertsTab()
                .tabItem { Label("Alerts", systemImage: "bell.badge") }
        }
        .frame(width: 580, height: 440)
    }
}

// MARK: - Callbook (QRZ.com etc.)

private struct CallbookTab: View {
    @EnvironmentObject var settings: CallbookSettings
    @EnvironmentObject var manager:  CallbookManager
    @State private var testCall: String = ""
    @State private var testResult: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("QRZ.com — Zugangsdaten") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Benutzername").frame(width: 110, alignment: .leading)
                            TextField("HB9HJI", text: $settings.qrzUsername)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: 220)
                        }
                        HStack {
                            Text("Passwort").frame(width: 110, alignment: .leading)
                            SecureField("", text: $settings.qrzPassword)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 220)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: settings.qrzIsConfigured
                                  ? "checkmark.circle.fill" : "exclamationmark.circle")
                                .foregroundStyle(settings.qrzIsConfigured ? .green : .orange)
                            Text(settings.qrzIsConfigured
                                 ? "Konfiguriert — bereit für Lookups"
                                 : "Noch keine Zugangsdaten hinterlegt")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("QRZ.com benötigt einen kostenlosen Account für Basis-Lookups (Name, QTH, Locator, Country). Erweiterte Daten (E-Mail, Bio, Bild) brauchen ein XML-Subscription-Abo.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                }

                GroupBox("Verhalten") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Auto-Lookup beim TAB im Call-Feld",
                               isOn: $settings.autoLookupOnTab)
                            .toggleStyle(.checkbox)
                        Text("Wenn aktiv: sobald du einen Call eintippst und mit TAB ins nächste Feld springst, werden die Daten online abgefragt und leere Felder ausgefüllt. Bereits eingetragene Werte werden nicht überschrieben.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                }

                GroupBox("Test-Lookup") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Call", text: $testCall)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: 160)
                                .onChange(of: testCall) { _, v in testCall = v.uppercased() }
                            Button("Lookup") { runTestLookup() }
                                .disabled(testCall.isEmpty)
                            Spacer()
                        }
                        if let r = testResult {
                            Text(r)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(8)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(4)
                }

                GroupBox("Cache") {
                    HStack {
                        Image(systemName: "tray.full")
                            .foregroundStyle(.blue)
                        Text("\(manager.cacheCount) Calls im Cache (30 Tage TTL)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Cache leeren") { manager.clearCache() }
                            .disabled(manager.cacheCount == 0)
                    }
                    .padding(4)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func runTestLookup() {
        let call = testCall
        testResult = "Frage QRZ ab …"
        Task {
            let result = await manager.lookup(call: call, forceRefresh: true)
            await MainActor.run {
                if let r = result {
                    testResult = """
                    \(r.firstName ?? "") \(r.lastName ?? "")
                    \(r.qth ?? "") \(r.state ?? "")
                    \(r.country ?? "") (\(r.continent ?? "?"))
                    Locator: \(r.locator ?? "—") · CQ: \(r.cqZone.map(String.init) ?? "—") · ITU: \(r.ituZone.map(String.init) ?? "—")
                    """
                } else {
                    testResult = "Keine Daten oder Fehler: \(manager.lastError ?? "unbekannt")"
                }
            }
        }
    }
}

// MARK: - Daten (zentraler App-Datenordner)

private struct DatenTab: View {
    @EnvironmentObject var dataRoot: AppDataRoot
    @EnvironmentObject var manager:  LogbookManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Datenordner") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Pfad").frame(width: 60, alignment: .leading)
                            Text(dataRoot.rootURL.path)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(2)
                            Spacer()
                        }
                        HStack {
                            Button("Ordner wählen …") { pickRoot() }
                            Button("Im Finder zeigen") {
                                NSWorkspace.shared.activateFileViewerSelecting([dataRoot.rootURL])
                            }
                            Button("Auf Standard zurücksetzen") {
                                dataRoot.rootURL = AppDataRoot.defaultRoot
                            }
                        }
                        Text("Alle Daten der App liegen unter diesem Ordner — Logbücher, Spot-Cache, künftig auch Exporte/Backups/Audio. Du kannst z.B. iCloud Drive wählen, dann ist alles automatisch zwischen deinen Macs synchronisiert.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                }

                GroupBox("Struktur") {
                    VStack(alignment: .leading, spacing: 5) {
                        subdirRow("Logs",    "Logbuch-SQLite-Dateien (.htlog)",     url: dataRoot.logsDir)
                        subdirRow("Cache",   "DX-Cluster-Spot-Cache (spots.json)",   url: dataRoot.cacheDir)
                        subdirRow("Exports", "ADIF / Cabrillo / CSV (Phase 2)",      url: dataRoot.exportsDir)
                        subdirRow("Backups", "Auto-Backups vor riskanten Aktionen",   url: dataRoot.backupsDir)
                        subdirRow("Audio",   "QSO-Recordings / Voice-Keyer (Phase 10)", url: dataRoot.audioDir)
                    }
                    .padding(4)
                }

                GroupBox("Bestandsaufnahme") {
                    HStack {
                        Image(systemName: "books.vertical").foregroundStyle(.blue)
                        Text("\(manager.logs.count) Logbuch\(manager.logs.count == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(4)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func subdirRow(_ name: String, _ desc: String, url: URL) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.blue)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                Text(desc)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .buttonStyle(.borderless)
            .help("Im Finder zeigen")
        }
    }

    private func pickRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = dataRoot.rootURL
        panel.prompt = "Wählen"
        panel.message = "Datenordner wählen (alle HAM-Tools-Daten liegen hier)"
        if panel.runModal() == .OK, let url = panel.url {
            dataRoot.rootURL = url
        }
    }
}

// MARK: - Station

private struct StationTab: View {
    @AppStorage("callsign")   private var callsign   = "HB9HJI"
    @AppStorage("qthLocator") private var qthLocator = "JN47PN"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Eigene Station") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Rufzeichen").frame(width: 110, alignment: .leading)
                            TextField("HB9HJI", text: $callsign)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 160)
                                .onChange(of: callsign) { callsign = callsign.uppercased() }
                        }
                        HStack {
                            Text("QTH-Locator").frame(width: 110, alignment: .leading)
                            TextField("JN47PN", text: $qthLocator)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 160)
                                .onChange(of: qthLocator) { qthLocator = qthLocator.uppercased() }
                        }
                        Text("Das Rufzeichen wird für den Cluster-Login und das Senden von DX-Spots verwendet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Cluster

private struct ClusterTab: View {
    @EnvironmentObject var store: ClusterSettingsStore
    @State private var selectedID:  UUID?
    @State private var editNode:    ClusterNode?
    @State private var showAdd      = false

    var body: some View {
        VStack(spacing: 0) {
            Table(store.nodes, selection: $selectedID) {
                TableColumn("") { node in
                    Image(systemName: store.activeNodeID == node.id
                          ? "circle.fill" : "circle")
                        .foregroundStyle(store.activeNodeID == node.id
                                         ? Color.green : Color.secondary)
                        .font(.system(size: 9))
                }
                .width(18)

                TableColumn("Name") { node in
                    HStack(spacing: 4) {
                        if node.autoConnect {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.yellow)
                                .font(.system(size: 9))
                        }
                        Text(node.name)
                    }
                }

                TableColumn("Host") { node in
                    Text(node.host)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                TableColumn("Port") { node in
                    Text(String(node.port))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .width(50)
            }
            .tableStyle(.bordered)

            Divider()

            HStack(spacing: 6) {
                // +/-  buttons
                Button { showAdd = true } label: {
                    Image(systemName: "plus").frame(width: 16)
                }
                .buttonStyle(.borderless)

                Button(action: removeSelected) {
                    Image(systemName: "minus").frame(width: 16)
                }
                .buttonStyle(.borderless)
                .disabled(selectedID == nil)

                Divider().frame(height: 18).padding(.horizontal, 4)

                Button("Bearbeiten…") {
                    editNode = store.nodes.first { $0.id == selectedID }
                }
                .disabled(selectedID == nil)

                Spacer()

                if let id = selectedID {
                    if store.activeNodeID == id {
                        Label("Aktiv", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    } else {
                        Button("Als aktiv") {
                            store.activeNodeID = id
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .sheet(isPresented: $showAdd) {
            NodeEditSheet(node: ClusterNode(name: "", host: "")) { node in
                store.add(node)
                selectedID = node.id
            }
        }
        .sheet(item: $editNode) { node in
            NodeEditSheet(node: node) { updated in
                store.update(updated)
            }
        }
    }

    private func removeSelected() {
        guard let id = selectedID,
              let idx = store.nodes.firstIndex(where: { $0.id == id }) else { return }
        store.remove(at: IndexSet(integer: idx))
        selectedID = nil
    }
}

// MARK: - NodeEditSheet

private struct NodeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var node: ClusterNode
    let onSave: (ClusterNode) -> Void

    init(node: ClusterNode, onSave: @escaping (ClusterNode) -> Void) {
        _node    = State(initialValue: node)
        self.onSave = onSave
    }

    private var isValid: Bool {
        !node.name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !node.host.trimmingCharacters(in: .whitespaces).isEmpty &&
        (1...65535).contains(node.port)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "server.rack")
                    .foregroundStyle(.white)
                Text(node.name.isEmpty ? "Neuer Cluster" : node.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue)

            // Form
            Form {
                Section {
                    HStack {
                        Text("Name").frame(width: 60, alignment: .leading)
                        TextField("z.B. DXSpider Funkwelt", text: $node.name)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Host").frame(width: 60, alignment: .leading)
                        TextField("z.B. dxspider.funkwelt.net", text: $node.host)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack {
                        Text("Port").frame(width: 60, alignment: .leading)
                        TextField("7300", value: $node.port, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    Toggle("Automatisch verbinden beim Start", isOn: $node.autoConnect)
                }
            }
            .formStyle(.grouped)

            Divider()

            // Buttons
            HStack {
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Speichern") { onSave(node); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 420, height: 310)
    }
}

// MARK: - Darstellung

private struct DarstellungTab: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Form {
            Section("Design-Variante") {
                ForEach(AppTheme.allCases) { t in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(t.bgApp)
                                .frame(width: 36, height: 22)
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(t.accentBlue, lineWidth: 1.5)
                                .frame(width: 36, height: 22)
                            HStack(spacing: 2) {
                                Rectangle().fill(t.bgLog)   .frame(width: 12, height: 14)
                                Rectangle().fill(t.bgPanel) .frame(width: 10, height: 14)
                            }
                            .cornerRadius(2)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.displayName).font(.body)
                            Text(themeSubtitle(t)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if themeManager.theme == t {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { themeManager.setTheme(t) }
                    .padding(.vertical, 4)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func themeSubtitle(_ t: AppTheme) -> String {
        switch t {
        case .hamStyle:   return "Helles Design — weiße Tabelle, schwarzes Terminal"
        case .dark:       return "Dunkles Design — blau-grauer Hintergrund"
        case .hamClassic: return "Ham Classic — bernsteinfarbenes Terminal"
        }
    }
}

// MARK: - Alerts

private struct AlertsTab: View {
    @EnvironmentObject var watchList: WatchListStore
    @State private var newEntry = ""
    @State private var newDXCC = MOST_WANTED_DXCC.first ?? ""
    @AppStorage("alertCooldownMin") private var alertCooldownMin = 15

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                GroupBox("Watch-Liste (Rufzeichen / Präfix)") {
                    VStack(alignment: .leading, spacing: 8) {
                        if watchList.entries.isEmpty {
                            Text("Noch keine Einträge")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(watchList.entries, id: \.self) { entry in
                                HStack {
                                    Text(entry)
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                    Button {
                                        if let idx = watchList.entries.firstIndex(of: entry) {
                                            watchList.remove(at: IndexSet(integer: idx))
                                        }
                                    } label: {
                                        Image(systemName: "trash").foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 2)
                                Divider()
                            }
                        }

                        HStack(spacing: 8) {
                            TextField("Rufzeichen oder Präfix (z.B. DL, HB9HJI)", text: $newEntry)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .onSubmit { addEntry() }
                            Button("Hinzufügen", action: addEntry)
                                .disabled(newEntry.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        Text("Spots mit übereinstimmendem DX-Rufzeichen werden gold markiert.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                }

                GroupBox("DXCC-Watch (seltene Entitäten)") {
                    VStack(alignment: .leading, spacing: 8) {
                        if watchList.dxccEntries.isEmpty {
                            Text("Noch keine DXCC-Einträge")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(watchList.dxccEntries, id: \.self) { country in
                                HStack {
                                    Text(country).font(.body)
                                    Spacer()
                                    Button {
                                        if let idx = watchList.dxccEntries.firstIndex(of: country) {
                                            watchList.removeDXCC(at: IndexSet(integer: idx))
                                        }
                                    } label: {
                                        Image(systemName: "trash").foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 2)
                                Divider()
                            }
                        }

                        HStack(spacing: 8) {
                            Picker("", selection: $newDXCC) {
                                ForEach(MOST_WANTED_DXCC, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            Button("Hinzufügen") { addDXCC() }
                                .disabled(newDXCC.isEmpty || watchList.dxccEntries.contains(newDXCC))
                        }

                        Text("Alert wenn ein Spot aus diesem Land erscheint (z.B. seltene Insel-DXCCs).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                }

                GroupBox("Benachrichtigungen") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("macOS-Benachrichtigungen aktivieren",
                               isOn: $watchList.notificationsEnabled)
                        Text("Beim Erscheinen eines überwachten Spots wird eine System-Benachrichtigung gesendet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider().padding(.vertical, 2)

                        HStack {
                            Text("Cooldown:").frame(width: 90, alignment: .leading)
                            Slider(value: Binding(
                                get: { Double(alertCooldownMin) },
                                set: { alertCooldownMin = Int($0) }
                            ), in: 1...60, step: 1)
                            Text("\(alertCooldownMin) Min")
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 60, alignment: .trailing)
                        }
                        Text("Derselbe Call/DXCC wird frühestens nach Ablauf des Cooldowns erneut alarmiert (verhindert Spam bei Pile-Ups).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addEntry() {
        let trimmed = newEntry.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        watchList.add(trimmed.uppercased())
        newEntry = ""
    }

    private func addDXCC() {
        watchList.addDXCC(newDXCC)
    }
}
