import SwiftUI

// MARK: - Root

struct EinstellungenView: View {
    var body: some View {
        TabView {
            StationTab()
                .tabItem { Label("Station", systemImage: "antenna.radiowaves.left.and.right") }
            ClusterTab()
                .tabItem { Label("Cluster", systemImage: "server.rack") }
            DarstellungTab()
                .tabItem { Label("Darstellung", systemImage: "paintpalette") }
            AlertsTab()
                .tabItem { Label("Alerts", systemImage: "bell.badge") }
        }
        .frame(width: 560, height: 460)
    }
}

// MARK: - Station

private struct StationTab: View {
    @AppStorage("callsign")   private var callsign   = "HB9HJI"
    @AppStorage("qthLocator") private var qthLocator = "JN47PN"

    var body: some View {
        Form {
            Section("Eigene Station") {
                LabeledContent("Rufzeichen") {
                    TextField("z.B. HB9HJI", text: $callsign)
                        .frame(width: 140)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: callsign) { callsign = callsign.uppercased() }
                }
                LabeledContent("QTH-Locator") {
                    TextField("z.B. JN47PN", text: $qthLocator)
                        .frame(width: 140)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: qthLocator) { qthLocator = qthLocator.uppercased() }
                }
            }
            Section {
                Text("Das Rufzeichen wird für den Cluster-Login und das Senden von DX-Spots verwendet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                LabeledContent("Name") {
                    TextField("z.B. DXSpider Schweiz", text: $node.name)
                        .frame(width: 220)
                }
                LabeledContent("Host") {
                    TextField("z.B. dxspider.funkwelt.net", text: $node.host)
                        .frame(width: 220)
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Port") {
                    TextField("7300", value: $node.port, format: .number)
                        .frame(width: 70)
                }
                Toggle("Automatisch verbinden beim Start", isOn: $node.autoConnect)
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
                ForEach(AppTheme.allCases) { theme in
                    HStack(spacing: 12) {
                        // Mini-Swatch
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.bgApp)
                                .frame(width: 36, height: 22)
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(theme.accentBlue, lineWidth: 1.5)
                                .frame(width: 36, height: 22)
                            HStack(spacing: 2) {
                                Rectangle().fill(theme.bgLog)   .frame(width: 12, height: 14)
                                Rectangle().fill(theme.bgPanel) .frame(width: 10, height: 14)
                            }
                            .cornerRadius(2)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(theme.displayName).font(.body)
                            Text(themeSubtitle(theme))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if themeManager.theme == theme {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { themeManager.setTheme(theme) }
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

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Watch-Liste") {
                    if watchList.entries.isEmpty {
                        Text("Noch keine Einträge")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } else {
                        List {
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
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .frame(height: min(CGFloat(watchList.entries.count) * 28 + 8, 140))
                    }

                    HStack(spacing: 6) {
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

                Section("Benachrichtigungen") {
                    Toggle("macOS-Benachrichtigungen aktivieren", isOn: $watchList.notificationsEnabled)
                    Text("Beim Erscheinen eines überwachten Spots wird eine System-Benachrichtigung gesendet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func addEntry() {
        let trimmed = newEntry.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        watchList.add(trimmed)
        newEntry = ""
    }
}
