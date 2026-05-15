import SwiftUI

// Cluster-Terminal — eigenes Pop-up-Fenster mit Roh-Output-Stream, Eingabe-
// Feld, Schnellbefehl-Buttons und persistenter Befehls-History (Up/Down).
//
// Hängt am bestehenden DXClusterViewModel (Single-Cluster, gleicher Stream
// wie überall sonst). Antworten auf "sh/dx" etc. fließen automatisch
// zusätzlich in den globalen Spot-Stream — der ClusterClient parst Lines
// schon im SpotParser, unabhängig davon ob User-Befehl oder Live-Feed.
//
// History wird in UserDefaults persistiert (max 50 Einträge).
struct ClusterTerminalView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var clusterVM:    DXClusterViewModel
    @AppStorage("callsign") private var ownCall: String = ""

    @State private var input:        String = ""
    @State private var historyIndex: Int    = -1     // -1 = aktuelle Eingabe, 0...N = History-Eintrag
    @State private var draft:        String = ""     // Speichert was getippt war bevor ↑ in History sprang
    @State private var autoScroll:   Bool   = true

    // Persistente Befehls-History (Newest-first, max 50).
    @AppStorage("cluster.terminal.history") private var historyJSON: String = "[]"
    private var history: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(historyJSON.utf8))) ?? [] }
    }

    private var theme: AppTheme { themeManager.theme }

    // Fest verdrahtete Schnellbefehl-Buttons. Werden in die Eingabe-Zeile
    // geschrieben, nicht direkt gesendet — der User kann sie noch anpassen
    // (z.B. "show/dx 30" hinten dranhängen).
    private let quickCommands: [(label: String, cmd: String)] = [
        ("sh/dx",  "sh/dx"),
        ("dx",     "dx "),
        ("wwv",    "sh/wwv"),
        ("qrg",    "sh/qrg "),
        ("Grid4",  "set/grid4 "),
        ("Grid6",  "set/grid6 "),
        ("Mgr",    "show/mgr "),
        ("help",   "help"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            Divider().background(theme.separator)
            outputPane
            Divider().background(theme.separator)
            quickButtons
            inputBar
        }
        .background(theme.bgApp)
        .preferredColorScheme(theme.colorScheme)
        .navigationTitle("Cluster-Terminal")
    }

    // MARK: - Status-Bar oben

    private var statusBar: some View {
        HStack(spacing: 8) {
            statusBadge
            Text("\(clusterVM.logMessages.count) Lines · \(clusterVM.spots.count) Spots")
                .font(.caption2.monospaced())
                .foregroundStyle(theme.textDim)
            Spacer()
            Toggle("Auto-Scroll", isOn: $autoScroll)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.caption2)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(theme.bgPanel)
    }

    private var statusColor: Color {
        switch clusterVM.clusterStatus {
        case .connected:            return theme.accentGreen
        case .disconnected, .error: return theme.accentRed
        default:                    return theme.accentYellow
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Text(clusterVM.clusterStatus.rawValue)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Output (scrollable Lines)

    private var outputPane: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(clusterVM.logMessages.enumerated()), id: \.offset) { idx, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(color(for: line))
                            .textSelection(.enabled)
                            .id(idx)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.bgApp)
            .onChange(of: clusterVM.logMessages.count) { _, newCount in
                guard autoScroll, newCount > 0 else { return }
                withAnimation(.linear(duration: 0.1)) {
                    proxy.scrollTo(newCount - 1, anchor: .bottom)
                }
            }
        }
    }

    private func color(for line: String) -> Color {
        if line.hasPrefix("[SENT]")           { return theme.accentBlue }
        if line.contains(">>> EINGELOGGT")    { return theme.accentGreen }
        if line.contains("Verbindungsfehler") { return theme.accentRed }
        if line.contains("Empfangsfehler")    { return theme.accentRed }
        if line.hasPrefix("════════")          { return theme.accentYellow }
        return theme.textPrimary
    }

    // MARK: - Schnellbefehl-Buttons

    private var quickButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(quickCommands, id: \.label) { item in
                    Button(item.label) {
                        // Aktuelles Input überschreiben; bei Befehlen mit
                        // trailing Space (z.B. "dx ") landet der Cursor
                        // dahinter, sodass der User direkt weitertippen kann.
                        input = item.cmd
                        historyIndex = -1
                    }
                    .font(.caption.monospaced())
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                // Eigener Call als Schnell-Button, wenn gesetzt
                if !ownCall.isEmpty {
                    Divider().frame(height: 14)
                    Button(ownCall.uppercased()) {
                        input = ownCall.uppercased()
                        historyIndex = -1
                    }
                    .font(.caption.monospaced().bold())
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(theme.accentBlue)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
        }
        .background(theme.bgPanel)
    }

    // MARK: - Eingabe-Zeile

    private var inputBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .foregroundStyle(theme.accentGreen)
                .font(.caption.bold())

            TextField("Befehl … (⏎ = senden, ↑/↓ = History)",
                      text: $input)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .onSubmit { submitCurrent() }
                .onKeyPress(.upArrow) {
                    historyUp(); return .handled
                }
                .onKeyPress(.downArrow) {
                    historyDown(); return .handled
                }
                .disabled(clusterVM.clusterStatus != .connected)

            Button {
                submitCurrent()
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty
                      || clusterVM.clusterStatus != .connected)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(theme.bgPanel)
    }

    // MARK: - Actions

    private func submitCurrent() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        clusterVM.sendCommand(trimmed)
        pushHistory(trimmed)
        input = ""
        draft = ""
        historyIndex = -1
    }

    private func pushHistory(_ cmd: String) {
        var list = history
        // Duplikate raus, Neuestes vorne
        list.removeAll { $0 == cmd }
        list.insert(cmd, at: 0)
        if list.count > 50 { list.removeLast(list.count - 50) }
        if let data = try? JSONEncoder().encode(list),
           let json = String(data: data, encoding: .utf8) {
            historyJSON = json
        }
    }

    private func historyUp() {
        let list = history
        guard !list.isEmpty else { return }
        if historyIndex == -1 { draft = input }       // aktuelle Eingabe merken
        let next = min(historyIndex + 1, list.count - 1)
        historyIndex = next
        input = list[next]
    }

    private func historyDown() {
        let list = history
        guard historyIndex >= 0 else { return }
        let next = historyIndex - 1
        historyIndex = next
        if next < 0 {
            input = draft
        } else {
            input = list[next]
        }
    }
}
