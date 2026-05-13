import SwiftUI

// Oberste Leiste: Zurück-Button, aktives Log + Log-Verwaltung,
// UTC-Uhr, eigenes Rufzeichen.
struct LogbookTopBar: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @AppStorage("callsign") private var callsign = ""

    let onBackToHome: () -> Void
    let onShowLogs: () -> Void

    @State private var nowUTC: String = ""
    @Environment(\.openSettings) private var openSettings

    private var theme: AppTheme { themeManager.theme }
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var activeLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onBackToHome()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                    Text("Übersicht")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.accentBlue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accentBlue)
            .help("Zur Übersicht — Rechner und weitere Tools")

            Divider().frame(height: 18).background(theme.separator)

            Button(action: onShowLogs) {
                HStack(spacing: 6) {
                    Image(systemName: "books.vertical.fill")
                        .foregroundStyle(theme.accentBlue)
                    if let log = activeLog {
                        Text(log.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                    } else {
                        Text("Kein Log aktiv")
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.bgCard2)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(theme.separator, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("Logs verwalten")

            Spacer()

            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    Text(nowUTC)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("UTC")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.accentOrange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.bgCard2)
                .clipShape(RoundedRectangle(cornerRadius: 5))

                HStack(spacing: 5) {
                    Image(systemName: "person.crop.square")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    Text(callsign.isEmpty ? "Rufzeichen ?" : callsign)
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                        .foregroundStyle(callsign.isEmpty ? theme.textDim : theme.accentBlue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.accentBlue.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 5))

                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(theme.bgCard2)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Einstellungen (⌘,)")
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(theme.bgCard)
        .onAppear { updateClock() }
        .onReceive(timer) { _ in updateClock() }
    }

    private func updateClock() {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        nowUTC = f.string(from: Date())
    }
}
