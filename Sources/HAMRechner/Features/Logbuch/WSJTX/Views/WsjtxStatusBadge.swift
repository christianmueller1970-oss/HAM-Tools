import SwiftUI

// Kompaktes Status-Badge für die LogbookTopBar. Nur sichtbar wenn die
// WSJT-X-Brücke eingeschaltet ist. Klick öffnet direkt die Einstellungen
// (App-weit, der User landet im zuletzt offenen Tab — falls nötig manuell
// auf "WSJT-X" wechseln).
struct WsjtxStatusBadge: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settings:     WsjtxBridgeSettings
    @EnvironmentObject var bridge:       WsjtxBridgeService

    @Environment(\.openSettings) private var openSettings

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        if settings.enabled {
            Button(action: { openSettings() }) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 8, height: 8)
                    Text("WSJT-X")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    if bridge.qsosLoggedCount > 0 {
                        Text("·\(bridge.qsosLoggedCount)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(theme.textSecondary)
                            .monospacedDigit()
                    }
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
            .help(helpText)
        }
    }

    private var dotColor: Color {
        switch bridge.connectionState {
        case .stopped:    return .gray
        case .listening:  return .yellow
        case .linked:     return .green
        case .failed:     return .red
        }
    }

    private var helpText: String {
        switch bridge.connectionState {
        case .stopped:
            return "WSJT-X-Brücke: inaktiv. Klick für Einstellungen."
        case .listening:
            return "WSJT-X-Brücke: lauscht auf Port \(Int(settings.port)). Warte auf Verbindung."
        case .linked:
            if let v = bridge.wsjtxVersion {
                return "WSJT-X verbunden (\(v)). \(bridge.qsosLoggedCount) QSOs empfangen."
            } else {
                return "WSJT-X verbunden. \(bridge.qsosLoggedCount) QSOs empfangen."
            }
        case .failed(let err):
            return "WSJT-X-Brücke: Fehler — \(err)"
        }
    }
}
