import SwiftUI

// Action-Bar unter dem QSO-Eingabe-Panel im MacLoggerDX-Stil.
struct LogActionBar: View {
    @EnvironmentObject var themeManager: ThemeManager

    let canLog: Bool
    let onLogQSO: () -> Void
    let onClear: () -> Void
    let onTimeOn: () -> Void
    let onTimeOff: () -> Void

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        HStack(spacing: 8) {
            actionButton("LookUp", systemImage: "magnifyingglass",
                         tooltip: "QRZ.com-Lookup · Phase 3",
                         enabled: false) { }
            actionButton("Previous", systemImage: "clock.arrow.circlepath",
                         tooltip: "Frühere QSOs mit diesem Call · Phase 3",
                         enabled: false) { }

            Divider()
                .frame(height: 18)
                .background(theme.separator)

            actionButton("Time On", systemImage: "play.circle",
                         tooltip: "Aktuelle UTC als Time On setzen",
                         enabled: true,
                         action: onTimeOn)
            actionButton("Time Off", systemImage: "stop.circle",
                         tooltip: "Aktuelle UTC als Time Off setzen",
                         enabled: true,
                         action: onTimeOff)

            Divider()
                .frame(height: 18)
                .background(theme.separator)

            // Hauptaktion: Log QSO
            Button(action: onLogQSO) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("Log QSO")
                        .font(.caption.weight(.bold))
                    Text("⌘↩")
                        .font(.caption2.monospaced())
                        .opacity(0.8)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(canLog ? theme.accentGreen : theme.textDim)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .disabled(!canLog)
            .keyboardShortcut(.return, modifiers: [.command])
            .help("QSO speichern (⌘↩)")

            Divider()
                .frame(height: 18)
                .background(theme.separator)

            actionButton("Beam", systemImage: "location.north",
                         tooltip: "Beam-Heading · Phase 3",
                         enabled: false) { }
            actionButton("Reset", systemImage: "arrow.uturn.backward.circle",
                         tooltip: "Eingabe zurücksetzen",
                         enabled: true,
                         action: onClear)
            actionButton("Stacking", systemImage: "square.stack",
                         tooltip: "Run/S&P Stacking · Phase 4",
                         enabled: false) { }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func actionButton(_ label: String,
                              systemImage: String,
                              tooltip: String,
                              enabled: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(label)
                    .font(.caption)
            }
            .foregroundStyle(enabled ? theme.textPrimary : theme.textDim)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(theme.bgCard2)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.separator, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .opacity(enabled ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(tooltip)
    }
}
