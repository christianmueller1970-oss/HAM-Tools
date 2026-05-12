import SwiftUI

// Klickbarer Status-Indikator. In Settings nur Anzeige, in der Sidebar
// als One-Click-Toggle für schnelles Reconnect nach Fehlern.
struct CATStatusBadge: View {
    @EnvironmentObject var cat: CATController

    var isClickable: Bool = false

    var body: some View {
        if isClickable {
            Button { Task { await cat.toggle() } } label: {
                content
            }
            .buttonStyle(.plain)
            .help(detailHelp)
        } else {
            content
                .help(detailHelp)
        }
    }

    private var content: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        switch cat.status {
        case .disconnected:   return .gray
        case .starting:       return .orange
        case .connected:      return .green
        case .errored:        return .red
        }
    }

    private var label: String {
        switch cat.status {
        case .disconnected:   return "CAT off"
        case .starting:       return "CAT…"
        case .connected:      return "CAT"
        case .errored:        return "CAT err"
        }
    }

    private var detailHelp: String {
        let base: String = {
            switch cat.status {
            case .disconnected:   return "CAT nicht aktiv"
            case .starting:       return "Verbinde mit Radio…"
            case .connected:      return "CAT verbunden"
            case .errored(let m): return m
            }
        }()
        return isClickable ? base + " · Klick zum Umschalten" : base
    }
}
