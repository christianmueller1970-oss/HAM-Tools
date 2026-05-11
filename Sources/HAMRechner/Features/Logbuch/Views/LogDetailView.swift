import SwiftUI

struct LogDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager

    let log: Log

    @State private var showNewQSOSheet: Bool = false
    @State private var editingQSO: QSO?

    private var theme: AppTheme { themeManager.theme }

    private var qsos: [QSO] {
        manager.currentQSOs.sorted { $0.datetime > $1.datetime }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(theme.separator)
            if qsos.isEmpty {
                emptyState
            } else {
                qsoTable
            }
        }
        .background(theme.bgApp)
        .sheet(isPresented: $showNewQSOSheet) {
            QSOFormSheet(qso: nil, log: log)
                .environmentObject(themeManager)
                .environmentObject(manager)
        }
        .sheet(item: $editingQSO) { qso in
            QSOFormSheet(qso: qso, log: log)
                .environmentObject(themeManager)
                .environmentObject(manager)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: log.type.systemImage)
                        .foregroundStyle(theme.accentBlue)
                    Text(log.name)
                        .font(.title2.bold())
                        .foregroundStyle(theme.textPrimary)
                }
                HStack(spacing: 6) {
                    Text(log.type.displayName)
                    Text("·")
                    Text("\(qsos.count) QSO\(qsos.count == 1 ? "" : "s")")
                    if let last = qsos.first?.datetime {
                        Text("·")
                        Text("Letzter Eintrag: \(last.formatted(date: .abbreviated, time: .shortened))")
                    }
                }
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Button {
                showNewQSOSheet = true
            } label: {
                Label("Neues QSO", systemImage: "plus.circle.fill")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: [.command])
        }
        .padding(16)
        .background(theme.bgCard)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundStyle(theme.textDim)
            Text("Noch keine QSOs in diesem Log")
                .font(.title3)
                .foregroundStyle(theme.textSecondary)
            Text("Klicke oben rechts auf »Neues QSO« um den ersten Eintrag anzulegen.")
                .font(.callout)
                .foregroundStyle(theme.textDim)
            Button {
                showNewQSOSheet = true
            } label: {
                Label("Erstes QSO eintragen", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var qsoTable: some View {
        Table(qsos) {
            TableColumn("Datum / UTC") { qso in
                Text(formatUTC(qso.datetime))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
            }
            .width(min: 140, ideal: 160)

            TableColumn("Call") { qso in
                Text(qso.call)
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(theme.accentBlue)
            }
            .width(min: 90, ideal: 110)

            TableColumn("Band") { qso in
                Text(qso.band).foregroundStyle(theme.textPrimary)
            }
            .width(min: 60, ideal: 70)

            TableColumn("Freq (MHz)") { qso in
                Text(String(format: "%.3f", qso.frequencyMHz))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
            }
            .width(min: 90, ideal: 100)

            TableColumn("Mode") { qso in
                Text(qso.mode).foregroundStyle(theme.textPrimary)
            }
            .width(min: 60, ideal: 70)

            TableColumn("RST S/E") { qso in
                Text("\(qso.rstSent) / \(qso.rstReceived)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
            }
            .width(min: 90, ideal: 100)

            TableColumn("Name") { qso in
                Text(qso.name ?? "").foregroundStyle(theme.textSecondary)
            }

            TableColumn("QTH / Locator") { qso in
                HStack(spacing: 6) {
                    if let qth = qso.qth, !qth.isEmpty {
                        Text(qth)
                    }
                    if let loc = qso.locator, !loc.isEmpty {
                        Text(loc)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(theme.textDim)
                    }
                }
                .foregroundStyle(theme.textSecondary)
            }

            TableColumn("") { qso in
                HStack(spacing: 6) {
                    Button {
                        editingQSO = qso
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Bearbeiten")

                    Button(role: .destructive) {
                        manager.deleteQSO(qso)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.accentRed)
                    .help("Löschen")
                }
            }
            .width(60)
        }
        .scrollContentBackground(.hidden)
        .background(theme.bgApp)
    }

    private func formatUTC(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm'z'"
        return f.string(from: date)
    }
}
