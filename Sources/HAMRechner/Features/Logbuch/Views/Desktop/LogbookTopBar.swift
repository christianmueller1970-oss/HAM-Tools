import SwiftUI

// Oberste Leiste: Zurück-Button, aktives Log + Log-Verwaltung,
// UTC-Uhr, eigenes Rufzeichen.
struct LogbookTopBar: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @AppStorage("callsign") private var callsign = ""

    let onBackToHome: () -> Void
    let onShowLogs: () -> Void

    @State private var nowUTC:   String = ""
    @State private var nowLocal: String = ""

    @EnvironmentObject var batteryMonitor: BatteryMonitor

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
                    Text("·")
                        .foregroundStyle(theme.textDim)
                    Text(nowLocal)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                    Text("LT")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.textDim)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.bgCard2)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .help("Lokale Zeit-Zone: \(TimeZone.current.identifier)")

                batteryPill

                WsjtxStatusBadge()

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

                // Einstellungen-Button entfernt — Standard-Ort auf macOS ist
                // das App-Menü "HAMRechner → Einstellungen…" (⌘,), plus es
                // gibt einen direkten Eintrag im Transceiver-Menü.
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(theme.bgCard)
        .onAppear { updateClock() }
        .onReceive(timer) { _ in updateClock() }
    }

    private func updateClock() {
        let now = Date()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        nowUTC = f.string(from: now)
        // Local-Time-Anzeige kompakter ohne Datum — Datum steht schon im
        // UTC-Block links daneben, und Differenz ist meist nur Stunden.
        f.timeZone = TimeZone.current
        f.dateFormat = "HH:mm:ss"
        nowLocal = f.string(from: now)
    }

    /// Akku-Pille. Bei Desktop-Macs ohne internen Akku komplett unsichtbar
    /// (EmptyView), bei Laptops zeigt sie Prozent + ggf. Restzeit/Ladestatus.
    @ViewBuilder
    private var batteryPill: some View {
        switch batteryMonitor.status {
        case .noBattery:
            EmptyView()
        case .charging(let pct):
            batteryPillBody(icon: "bolt.fill",
                            color: theme.accentGreen,
                            text: "\(pct)%",
                            tooltip: "Akku lädt (\(pct) %)")
        case .acPower(let pct):
            batteryPillBody(icon: "powerplug.fill",
                            color: theme.textSecondary,
                            text: "\(pct)%",
                            tooltip: "Netz angeschlossen, Akku bei \(pct) %")
        case .onBattery(let pct, let remainingMin):
            let icon: String = {
                if pct >= 88 { return "battery.100" }
                if pct >= 63 { return "battery.75" }
                if pct >= 38 { return "battery.50" }
                if pct >= 13 { return "battery.25" }
                return "battery.0"
            }()
            let color: Color = {
                if pct <= 20 { return theme.accentRed }
                if pct <= 40 { return theme.accentOrange }
                return theme.textPrimary
            }()
            let suffix = remainingMin.flatMap { formatRemaining(min: $0) }
            let text   = suffix.map { "\(pct)% · \($0)" } ?? "\(pct)%"
            batteryPillBody(icon: icon, color: color, text: text,
                            tooltip: suffix.map { "Akku-Betrieb, ca. \($0) verbleibend" }
                                ?? "Akku-Betrieb (\(pct) %)")
        }
    }

    private func batteryPillBody(icon: String, color: Color,
                                 text: String, tooltip: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(text)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.bgCard2)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .help(tooltip)
    }

    private func formatRemaining(min: Int) -> String {
        let h = min / 60
        let m = min % 60
        return h > 0 ? "\(h)h \(m)min" : "\(m)min"
    }
}
