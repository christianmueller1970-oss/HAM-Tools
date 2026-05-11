import SwiftUI

// Oberste Leiste: Zurück-Button, aktives Log + Log-Verwaltung,
// UTC-Uhr, eigenes Rufzeichen.
struct LogbookTopBar: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @AppStorage("callsign") private var callsign = "HB9HJI"

    let onBackToHome: () -> Void
    let onShowLogs: () -> Void

    @State private var nowUTC: String = ""

    private var theme: AppTheme { themeManager.theme }
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var activeLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                onBackToHome()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Startseite")
                }
                .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(theme.accentBlue)

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
            }
            .buttonStyle(.borderless)
            .help("Logs verwalten")

            Spacer()

            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    Text(nowUTC)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("UTC")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                }

                HStack(spacing: 4) {
                    Image(systemName: "person.crop.square")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    Text(callsign)
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                        .foregroundStyle(theme.accentBlue)
                }

                Text("HAM-Tools")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
