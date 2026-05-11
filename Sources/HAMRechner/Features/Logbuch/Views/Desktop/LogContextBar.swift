import SwiftUI
import AppKit
import UniformTypeIdentifiers

// Tab-Context-Bar für den »Log«-Tab. Filter über Call, Band, Mode, Country
// + Status-Zeile mit Anzahl/Pfad + ADIF Import/Export.
struct LogContextBar: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager

    @Binding var filterCall: String
    @Binding var filterBand: String
    @Binding var filterMode: String
    @Binding var filterCountry: String

    let totalCount: Int
    let filteredCount: Int

    @State private var pendingImport: PendingImport?
    @State private var lastExportURL: URL?
    @State private var showExportDoneAlert = false

    struct PendingImport: Identifiable {
        let id = UUID()
        let url: URL
        let qsos: [QSO]
        let targetLog: Log
    }

    private var theme: AppTheme { themeManager.theme }

    private var hasFilter: Bool {
        !filterCall.isEmpty || !filterBand.isEmpty
            || !filterMode.isEmpty || !filterCountry.isEmpty
    }

    private var currentLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    private var statusText: String {
        let fileName = currentLog.flatMap { manager.fileURL(for: $0)?.lastPathComponent } ?? ""
        if hasFilter && filteredCount != totalCount {
            return "\(fileName) · \(filteredCount) / \(totalCount) QSOs"
        }
        return "\(fileName) · \(totalCount) QSO\(totalCount == 1 ? "" : "s")"
    }

    var body: some View {
        TabContextBarShell {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                    .foregroundStyle(theme.textDim)
                filterField("Call", text: $filterCall, width: 110, monospaced: true)
                filterField("Band", text: $filterBand, width: 70)
                filterField("Mode", text: $filterMode, width: 70)
                filterField("Country", text: $filterCountry, width: 110)
                if hasFilter {
                    Button {
                        filterCall = ""; filterBand = ""
                        filterMode = ""; filterCountry = ""
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Filter zurücksetzen")
                        }
                        .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.accentBlue)
                }
                Divider().frame(height: 16).background(theme.separator)
                actionButton("Import…", icon: "square.and.arrow.down", action: openADIFImport)
                actionButton("Export ADIF", icon: "square.and.arrow.up", action: exportADIF)
            }
        }
        .sheet(item: $pendingImport) { p in
            ADIFImportSheet(sourceURL: p.url,
                            parsedQSOs: p.qsos,
                            targetLog: p.targetLog,
                            onCompleted: { _ in })
                .environmentObject(themeManager)
                .environmentObject(manager)
        }
        .alert("Export erfolgreich", isPresented: $showExportDoneAlert, presenting: lastExportURL) { url in
            Button("Im Finder zeigen") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            Button("OK", role: .cancel) {}
        } message: { url in
            Text("Log nach \(url.lastPathComponent) exportiert.")
        }
    }

    private func actionButton(_ label: String,
                              icon: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(theme.bgCard2)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.separator, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(manager.currentLogID == nil)
    }

    // MARK: - Export

    private func exportADIF() {
        guard let url = manager.exportActiveLogAsADIF() else { return }
        lastExportURL = url
        showExportDoneAlert = true
    }

    // MARK: - Import

    private func openADIFImport() {
        guard let activeID = manager.currentLogID,
              let activeLog = manager.logs.first(where: { $0.id == activeID })
        else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let adif = UTType(filenameExtension: "adi") {
            panel.allowedContentTypes = [adif, .text]
        }
        panel.prompt = "Importieren"
        panel.message = "ADIF-Datei (.adi) zum Import auswählen"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let qsos = manager.parseADIF(at: url, targetLogID: activeID)
        guard !qsos.isEmpty else {
            // Falls Parse fehlschlug, hier könnte ein Alert kommen
            return
        }
        pendingImport = PendingImport(url: url, qsos: qsos, targetLog: activeLog)
    }

    private func filterField(_ placeholder: String,
                             text: Binding<String>,
                             width: CGFloat,
                             monospaced: Bool = false) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(monospaced
                  ? .system(.caption, design: .monospaced)
                  : .caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(width: width)
            .background(theme.bgCard2)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(theme.separator.opacity(0.5), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// Gemeinsame Hülle für alle Tab-Context-Bars (konsistente Höhe, Padding,
// Background, Separator-Linie).
struct TabContextBarShell<Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ViewBuilder var content: () -> Content

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .background(theme.bgPanel)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(theme.separator)
                    .frame(height: 1)
            }
    }
}
