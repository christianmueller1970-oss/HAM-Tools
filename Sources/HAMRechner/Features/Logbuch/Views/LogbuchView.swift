import SwiftUI

// Root-View für das Logbuch-Modul. Zweispaltig:
// Links: Liste aller Logs. Rechts: QSOs des gewählten Logs + Form.
struct LogbuchView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var store: LogbuchStore

    @State private var selectedLogID: UUID?
    @State private var showNewLogSheet: Bool = false

    private var theme: AppTheme { themeManager.theme }

    private var selectedLog: Log? {
        guard let id = selectedLogID else { return nil }
        return store.logs.first(where: { $0.id == id })
    }

    var body: some View {
        HSplitView {
            logListSidebar
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 380)

            if let log = selectedLog {
                LogDetailView(log: log)
                    .frame(minWidth: 480)
            } else {
                emptyDetail
            }
        }
        .navigationTitle("Logbuch")
        .background(theme.bgApp)
        .onAppear {
            if selectedLogID == nil { selectedLogID = store.logs.first?.id }
        }
        .sheet(isPresented: $showNewLogSheet) {
            NewLogSheet { newLog in
                store.addLog(newLog)
                selectedLogID = newLog.id
            }
            .environmentObject(themeManager)
        }
    }

    // MARK: Sidebar

    private var logListSidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader

            Divider().background(theme.separator)

            List(selection: $selectedLogID) {
                ForEach(store.logs) { log in
                    LogRow(log: log,
                           qsoCount: store.qsoCount(for: log))
                        .tag(log.id)
                        .listRowBackground(
                            selectedLogID == log.id ? theme.bgHover : Color.clear
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteLog(log)
                            } label: {
                                Label("Log löschen", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.bgPanel)
        }
        .background(theme.bgPanel)
    }

    private var sidebarHeader: some View {
        HStack {
            Text("Meine Logs")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Button {
                showNewLogSheet = true
            } label: {
                Label("Neu", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(theme.accentGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgApp)
    }

    // MARK: Helpers

    private func deleteLog(_ log: Log) {
        if selectedLogID == log.id { selectedLogID = nil }
        store.deleteLog(log)
    }
}

// MARK: - Row

private struct LogRow: View {
    let log: Log
    let qsoCount: Int
    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: log.type.systemImage)
                .foregroundStyle(theme.accentBlue)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(log.name)
                    .font(.body)
                    .foregroundStyle(theme.textPrimary)
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
