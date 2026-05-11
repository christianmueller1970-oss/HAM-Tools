import SwiftUI

// Untere Tab-Bar im MacLoggerDX-Stil. Wechselt die Ansicht der
// Bottom-Section: Log-Tabelle, Karte, Bänder, Awards, …
// In Phase 1 ist nur "Log" funktional, der Rest ist Platzhalter.
enum LogbookBottomTab: String, CaseIterable, Identifiable {
    case log         = "Log"
    case map         = "Map"
    case bands       = "Bands"
    case dxClusters  = "DXClusters"
    case schedules   = "Schedules"
    case awards      = "Awards"
    case memories    = "Memories"
    case qsl         = "QSL"
    case history     = "History"
    case labels      = "Labels"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .log:        return "list.bullet.rectangle"
        case .map:        return "map"
        case .bands:      return "chart.bar"
        case .dxClusters: return "server.rack"
        case .schedules:  return "calendar"
        case .awards:     return "trophy"
        case .memories:   return "star"
        case .qsl:        return "envelope"
        case .history:    return "clock"
        case .labels:     return "tag"
        }
    }

    var isAvailable: Bool {
        self == .log    // Phase 1: nur Log-Ansicht funktional
    }
}

struct LogbookTabBar: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selected: LogbookBottomTab

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LogbookBottomTab.allCases) { tab in
                tabButton(tab)
            }
            Spacer()
            awardCounter
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.bgPanel)
    }

    private func tabButton(_ tab: LogbookBottomTab) -> some View {
        let isSelected = selected == tab
        return Button {
            if tab.isAvailable { selected = tab }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.caption2)
                Text(tab.rawValue)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(
                isSelected ? theme.accentBlue
                : tab.isAvailable ? theme.textPrimary
                                  : theme.textDim
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? theme.bgHover : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(!tab.isAvailable)
        .help(tab.isAvailable ? "" : "\(tab.rawValue) — kommt in späterer Phase")
    }

    // Platzhalter für Award-Counter (Phase 7) — visuelle Verankerung
    private var awardCounter: some View {
        HStack(spacing: 12) {
            awardBadge("DXCC", "0/0")
            awardBadge("WAZ",  "0/0")
            awardBadge("WAS",  "0/0")
            awardBadge("IOTA", "0/0")
        }
        .padding(.trailing, 4)
    }

    private func awardBadge(_ name: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(name + ":")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            Text(value)
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(theme.textSecondary)
        }
    }
}
