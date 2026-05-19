import SwiftUI

// Kompaktes Status-Badge für die LogbookTopBar. Zeigt:
//   • bei genau einer aktiven Bridge: deren Name + Status-Dot
//   • bei mehreren: »N Bridges« mit dem schlechtesten Status der aktiven
//   • bei null: gar nichts (verschwindet komplett)
//
// Klick öffnet die App-Einstellungen — von dort wechselt der User selbst
// auf den »Externe Logger«-Tab.
struct UDPBridgesStatusBadge: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settings:     UDPBridgesSettings
    @EnvironmentObject var service:      UDPBridgesService

    @Environment(\.openSettings) private var openSettings

    private var theme: AppTheme { themeManager.theme }

    private var activeBridges: [UDPBridge] {
        settings.bridges.filter { $0.enabled }
    }

    var body: some View {
        if !activeBridges.isEmpty {
            Button(action: { openSettings() }) {
                HStack(spacing: 5) {
                    Circle().fill(dotColor).frame(width: 8, height: 8)
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    let qsoTotal = activeBridges.reduce(0) {
                        $0 + (service.runtime[$1.id]?.datagramCount ?? 0)
                    }
                    if qsoTotal > 0 {
                        Text("·\(qsoTotal)")
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

    private var label: String {
        if activeBridges.count == 1 {
            return activeBridges[0].name
        }
        return "\(activeBridges.count) Bridges"
    }

    private var dotColor: Color {
        // Schlechtester Status gewinnt: failed > stopped > listening > linked
        var hasError = false
        var hasStopped = false
        var hasListening = false
        var hasLinked = false
        for b in activeBridges {
            switch service.runtime[b.id]?.state ?? .stopped {
            case .failed:    hasError = true
            case .stopped:   hasStopped = true
            case .listening: hasListening = true
            case .linked:    hasLinked = true
            }
        }
        if hasError { return .red }
        if hasStopped { return .gray }
        if hasLinked && !hasListening { return .green }
        if hasLinked { return .green }
        return .yellow
    }

    private var helpText: String {
        if activeBridges.count == 1 {
            let b = activeBridges[0]
            let rt = service.runtime[b.id]
            let state = rt?.state ?? .stopped
            let port = Int(b.port)
            switch state {
            case .stopped:           return "\(b.name): inaktiv. Klick → Einstellungen."
            case .listening:         return "\(b.name): lauscht auf Port \(port)."
            case .linked:
                let cnt = rt?.datagramCount ?? 0
                if let v = rt?.version, !v.isEmpty {
                    return "\(b.name) (\(v)) aktiv. \(cnt) Datagramme."
                }
                return "\(b.name) aktiv. \(cnt) Datagramme."
            case .failed(let err):   return "\(b.name): Fehler — \(err)"
            }
        }
        let parts = activeBridges.map { b -> String in
            let st = service.runtime[b.id]?.state ?? .stopped
            return "\(b.name): \(shortState(st))"
        }
        return parts.joined(separator: " · ")
    }

    private func shortState(_ s: UDPListener.State) -> String {
        switch s {
        case .stopped: return "aus"
        case .listening: return "lauscht"
        case .linked: return "aktiv"
        case .failed: return "Fehler"
        }
    }
}
