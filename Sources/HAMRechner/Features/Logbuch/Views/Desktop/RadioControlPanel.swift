import SwiftUI

// Platzhalter für CAT/Radio-Steuerung (Phase 5: Hamlib-Subprocess).
// Visuell schon im Look — Funktion folgt.
struct RadioControlPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        VStack(spacing: 8) {
            // Header mit Mode-Wahl
            HStack {
                Toggle(isOn: .constant(false)) {
                    Text("Radio")
                        .font(.caption.bold())
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(true)
                Spacer()
                Text("CAT")
                    .font(.caption2.bold())
                    .foregroundStyle(theme.textDim)
            }

            // TRX-Auswahl (Picker-Look)
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(theme.textDim)
                Text("Kein Radio konfiguriert")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }
            .padding(8)
            .background(theme.bgCard2)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            // Frequenz-Anzeige (groß, prominent)
            VStack(alignment: .leading, spacing: 2) {
                Text("0.000.00")
                    .font(.system(.title, design: .monospaced).weight(.bold))
                    .foregroundStyle(theme.textDim)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.bgLog)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            // VFO / Mode / Split / Keyer Buttons
            VStack(spacing: 4) {
                fakeButton("VFO A")
                fakeButton("USB")
                fakeButton("Split Off")
                fakeButton("Keyer")
            }

            // S-Meter Platzhalter
            VStack(alignment: .leading, spacing: 4) {
                Text("S-Meter")
                    .font(.caption2.bold())
                    .foregroundStyle(theme.textSecondary)
                HStack(spacing: 1) {
                    ForEach(0..<14) { _ in
                        Rectangle()
                            .fill(theme.bgSubPanel)
                            .frame(height: 8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }

            // RX/TX/PWR
            HStack(spacing: 6) {
                statusBadge("RX", on: false, color: theme.accentGreen)
                statusBadge("TX", on: false, color: theme.accentRed)
                statusBadge("PWR", on: false, color: theme.accentYellow)
            }

            Spacer(minLength: 0)

            // Footer-Status
            HStack {
                Circle()
                    .fill(theme.textDim)
                    .frame(width: 6, height: 6)
                Text("Idle")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
                Spacer()
            }
        }
        .padding(10)
        .background(theme.bgCard)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func fakeButton(_ label: String) -> some View {
        Text(label)
            .font(.caption)
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(theme.bgCard2)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.separator, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .opacity(0.6)
    }

    private func statusBadge(_ label: String, on: Bool, color: Color) -> some View {
        Text(label)
            .font(.caption2.bold())
            .foregroundStyle(on ? color : theme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .background(on ? color.opacity(0.15) : theme.bgCard2)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
