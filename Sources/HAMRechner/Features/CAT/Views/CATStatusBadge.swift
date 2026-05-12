import SwiftUI

// Kleiner Indikator (Ampel + Status-Text), wiederverwendbar im Header und
// im RadioControlPanel.
struct CATStatusBadge: View {
    @EnvironmentObject var cat: CATController

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
        .help(detailHelp)
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
        if let err = cat.lastError { return err }
        switch cat.status {
        case .disconnected: return "CAT nicht aktiv"
        case .starting:     return "Verbinde mit Radio…"
        case .connected:    return "CAT verbunden"
        case .errored(let m): return m
        }
    }
}
