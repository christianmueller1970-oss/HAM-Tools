import SwiftUI
import AppKit
import UniformTypeIdentifiers

// Popover hinter dem Log-Selector in der Top-Bar. Zeigt alle bekannten
// Logs, erlaubt Anlegen, Import, Löschen + Sprung in den Standard-Ordner.
struct LogsPopover: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var settings: LogbookSettings

    @Binding var showNewLogSheet: Bool
    let onClose: () -> Void

    @State private var deleteCandidate: Log?

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Logs")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button {
                    showNewLogSheet = true
                    onClose()
                } label: {
                    Label("Neu", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(theme.accentGreen)
            }
            .padding(10)
            Divider().background(theme.separator)

            if manager.logs.isEmpty {
                Text("Noch kein Log angelegt.")
                    .font(.callout)
                    .foregroundStyle(theme.textDim)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(manager.logs) { log in
                            row(for: log)
                            Divider().background(theme.separator.opacity(0.5))
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            Divider().background(theme.separator)
            HStack(spacing: 10) {
                Button {
                    importLog()
                } label: {
                    Label("Importieren …", systemImage: "square.and.arrow.down")
                        .font(.caption)
                }
                Button {
                    NSWorkspace.shared.open(settings.logbookDirectory)
                } label: {
                    Label("Ordner zeigen", systemImage: "folder")
                        .font(.caption)
                }
                Spacer()
            }
            .padding(10)
        }
        .frame(width: 380)
        .background(theme.bgCard)
        .alert(item: $deleteCandidate) { log in
            let count = manager.qsoCount(for: log)
            return Alert(
                title: Text("Logbuch löschen?"),
                message: Text(count == 0
                    ? "»\(log.name)« ist leer und wird gelöscht."
                    : "»\(log.name)« enthält \(count) QSO\(count == 1 ? "" : "s"). Vor dem Löschen wird ein ADIF-Backup nach Backups/ geschrieben.\n\nDie .htlog-Datei wird endgültig entfernt."),
                primaryButton: .destructive(Text(count == 0 ? "Löschen" : "Backup + Löschen")) {
                    manager.deleteLog(log)
                },
                secondaryButton: .cancel(Text("Abbrechen"))
            )
        }
    }

    private func row(for log: Log) -> some View {
        let isActive = manager.currentLogID == log.id
        let qsoCount = manager.qsoCount(for: log)
        let url = manager.fileURL(for: log)
        let isCustomLocation: Bool = {
            guard let url else { return false }
            return url.deletingLastPathComponent().standardized
                != settings.logbookDirectory.standardized
        }()

        return Button {
            manager.openLog(log)
            onClose()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: log.type.systemImage)
                    .foregroundStyle(theme.accentBlue)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(log.name)
                            .font(.subheadline.weight(isActive ? .bold : .regular))
                            .foregroundStyle(theme.textPrimary)
                        if isCustomLocation {
                            Image(systemName: "folder.badge.gearshape")
                                .font(.caption2)
                                .foregroundStyle(theme.accentOrange)
                        }
                        if isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(theme.accentGreen)
                        }
                    }
                    HStack(spacing: 6) {
                        Text(log.type.displayName)
                        Text("·")
                        Text("\(qsoCount) QSO\(qsoCount == 1 ? "" : "s")")
                    }
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    if let url, isCustomLocation {
                        Text(url.path)
                            .font(.caption2.monospaced())
                            .foregroundStyle(theme.textDim)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? theme.bgHover : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let url {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Label("Im Finder zeigen", systemImage: "folder")
                }
            }
            Divider()
            Button(role: .destructive) {
                deleteCandidate = log
            } label: {
                Label("Log löschen …", systemImage: "trash")
            }
        }
    }

    private func importLog() {
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
}
