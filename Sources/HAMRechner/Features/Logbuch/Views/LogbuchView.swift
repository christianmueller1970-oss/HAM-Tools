import SwiftUI
import UniformTypeIdentifiers

// Vollbild-Logbuch-Modul. Wenn der User in der Haupt-Sidebar "Logbuch"
// klickt, übernimmt diese View das ganze Fenster:
// links eine Log-Liste, oben ein "Zurück"-Button, rechts die Log-Detail-View.
// So gewinnen wir Platz für Logbuch-eigene Funktionen die noch kommen.
struct LogbuchView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var settings: LogbookSettings

    let onBackToHome: () -> Void

    @State private var showNewLogSheet: Bool = false

    private var theme: AppTheme { themeManager.theme }

    private var selectedLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    var body: some View {
        HSplitView {
            logbookSidebar
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 380)

            if let log = selectedLog {
                LogDetailView(log: log)
                    .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyDetail
            }
        }
        .navigationTitle("Logbuch")
        .background(theme.bgApp)
        .onAppear {
            if manager.currentLogID == nil, let first = manager.logs.first {
                manager.openLog(first)
            }
        }
        .sheet(isPresented: $showNewLogSheet) {
            NewLogSheet { newLog, customDir in
                manager.createLog(newLog, in: customDir)
            }
            .environmentObject(themeManager)
            .environmentObject(settings)
        }
    }

    // MARK: Sidebar

    private var logbookSidebar: some View {
        VStack(spacing: 0) {
            sidebarTopBar
            Divider().background(theme.separator)
            logListSection
            Divider().background(theme.separator)
            sidebarFooter
        }
        .background(theme.bgPanel)
    }

    private var sidebarTopBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    onBackToHome()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Startseite")
                    }
                    .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(theme.accentBlue)
                Spacer()
            }
            HStack(spacing: 8) {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(theme.accentBlue)
                Text("Logbuch")
                    .font(.title3.bold())
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button {
                    showNewLogSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(theme.accentGreen)
                .help("Neues Log anlegen")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var logListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Meine Logs")
                .font(.caption.bold())
                .foregroundStyle(theme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 4)

            if manager.logs.isEmpty {
                Text("Noch kein Log angelegt.")
                    .font(.callout)
                    .foregroundStyle(theme.textDim)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                Spacer()
            } else {
                List {
                    ForEach(manager.logs) { log in
                        LogRow(log: log,
                               qsoCount: manager.qsoCount(for: log),
                               fileURL: manager.fileURL(for: log),
                               defaultDir: settings.logbookDirectory,
                               selected: log.id == manager.currentLogID)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                manager.openLog(log)
                            }
                            .listRowBackground(
                                log.id == manager.currentLogID
                                    ? theme.bgHover : Color.clear
                            )
                            .contextMenu {
                                if let url = manager.fileURL(for: log) {
                                    Button {
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                    } label: {
                                        Label("Im Finder zeigen", systemImage: "folder")
                                    }
                                }
                                Divider()
                                Button(role: .destructive) {
                                    manager.deleteLog(log)
                                } label: {
                                    Label("Log löschen (Datei wird entfernt)",
                                          systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                importExistingLog()
            } label: {
                Label("Bestehendes Log importieren …", systemImage: "square.and.arrow.down")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(theme.accentBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Standard-Speicherort")
                    .font(.caption2.bold())
                    .foregroundStyle(theme.textSecondary)
                    .textCase(.uppercase)
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                    Text(settings.logbookDirectory.lastPathComponent)
                        .font(.caption.monospaced())
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(settings.logbookDirectory)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderless)
                    .help("Ordner im Finder öffnen")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func importExistingLog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let htlog = UTType(filenameExtension: LogbookDatabase.fileExtension) {
            panel.allowedContentTypes = [htlog]
        }
        panel.prompt = "Importieren"
        panel.message = "Bestehendes .\(LogbookDatabase.fileExtension)-Logbuch auswählen"
        if panel.runModal() == .OK, let url = panel.url {
            manager.importLog(at: url)
        }
    }

    private var emptyDetail: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 56))
                .foregroundStyle(theme.textDim)
            Text("Kein Log gewählt")
                .font(.title3)
                .foregroundStyle(theme.textSecondary)
            Text("Wähle links ein Log oder lege ein neues an.")
                .font(.callout)
                .foregroundStyle(theme.textDim)
            Button {
                showNewLogSheet = true
            } label: {
                Label("Neues Log anlegen", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgApp)
    }
}

// MARK: - Row

private struct LogRow: View {
    let log: Log
    let qsoCount: Int
    let fileURL: URL?
    let defaultDir: URL
    let selected: Bool

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.theme }

    private var isCustomLocation: Bool {
        guard let fileURL else { return false }
        return fileURL.deletingLastPathComponent().standardized != defaultDir.standardized
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: log.type.systemImage)
                .foregroundStyle(theme.accentBlue)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(log.name)
                        .font(.body)
                        .foregroundStyle(theme.textPrimary)
                    if isCustomLocation {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.caption2)
                            .foregroundStyle(theme.accentOrange)
                            .help(fileURL?.deletingLastPathComponent().path ?? "")
                    }
                }
                HStack(spacing: 6) {
                    Text(log.type.displayName)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    Text("·")
                        .foregroundStyle(theme.textDim)
                    Text("\(qsoCount) QSO\(qsoCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(theme.textDim)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
