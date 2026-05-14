import SwiftUI

// Action-Bar unter dem QSO-Eingabe-Panel im Desktop-Logger-Stil.
struct LogActionBar: View {
    @EnvironmentObject var themeManager: ThemeManager

    let canLog: Bool
    let canSendSpot: Bool          // Call + Frequenz da
    let currentCall: String        // für Previous-Button + Popover-Inhalt
    let onLogQSO: () -> Void
    let onSendSpot: () -> Void
    let onClear: () -> Void
    let onTimeOn: () -> Void
    let onTimeOff: () -> Void

    @State private var showPreviousPopover: Bool = false
    @State private var showSpotSentToast: Bool = false

    private var theme: AppTheme { themeManager.theme }

    private var hasCall: Bool {
        !currentCall.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            actionButton("LookUp", systemImage: "magnifyingglass",
                         tooltip: "QRZ.com-Lookup · Phase 3",
                         enabled: false) { }

            actionButton("Previous", systemImage: "clock.arrow.circlepath",
                         tooltip: hasCall
                            ? "Frühere QSOs mit \(currentCall) über alle Logs anzeigen"
                            : "Erst einen Call ins Form eintragen",
                         enabled: hasCall) {
                showPreviousPopover = true
            }
            .popover(isPresented: $showPreviousPopover, arrowEdge: .bottom) {
                PreviousQSOsPopover(call: currentCall)
                    .environmentObject(themeManager)
            }

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
            .keyboardShortcut(.return, modifiers: [])
            .help("QSO speichern (↩)")

            Divider()
                .frame(height: 18)
                .background(theme.separator)

            // Send Spot — Call + Frequenz Pflicht
            Button {
                onSendSpot()
                showSpotSentToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showSpotSentToast = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showSpotSentToast
                          ? "checkmark.circle.fill"
                          : "dot.radiowaves.right")
                        .font(.caption)
                    Text(showSpotSentToast ? "Gesendet" : "Send Spot")
                        .font(.caption)
                }
                .foregroundStyle(canSendSpot ? theme.textPrimary : theme.textDim)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(showSpotSentToast
                            ? theme.accentGreen.opacity(0.15)
                            : theme.bgCard2)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(showSpotSentToast ? theme.accentGreen : theme.separator,
                                lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .opacity(canSendSpot ? 1.0 : 0.5)
            }
            .buttonStyle(.plain)
            .disabled(!canSendSpot)
            .help(canSendSpot
                  ? "DX-Spot ans Cluster senden"
                  : "Pflichtfelder: Call + Frequenz")

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
