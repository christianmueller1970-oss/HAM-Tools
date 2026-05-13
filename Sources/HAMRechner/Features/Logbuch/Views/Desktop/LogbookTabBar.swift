import SwiftUI

// Untere Tab-Bar im Desktop-Logger-Stil. Wechselt die Ansicht der
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
    case potaMap     = "POTA-Map"
    case bandplan    = "Bandplan"
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
        case .potaMap:    return "tree.circle"
        case .bandplan:   return "chart.bar.xaxis"
        case .labels:     return "tag"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .log, .dxClusters, .awards, .map, .bands,
             .history, .memories, .potaMap, .bandplan:                      return true
        default:                                                            return false
        }
    }
}

struct LogbookTabBar: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @Binding var selected: LogbookBottomTab

    private var theme: AppTheme { themeManager.theme }

    private var currentLogType: LogType? {
        guard let id = manager.currentLogID,
              let log = manager.logs.first(where: { $0.id == id }) else { return nil }
        return log.type
    }

    // Im Contest-Modus werden Tabs ausgeblendet, die keinen Mehrwert bringen
    // (Awards/Memories/POTA-Map/History) — sonst lenkt das beim Loggen ab.
    private var visibleTabs: [LogbookBottomTab] {
        LogbookBottomTab.allCases.filter { tab in
            guard tab.isAvailable else { return false }
            if currentLogType == .contest {
                switch tab {
                case .awards, .memories, .potaMap, .history: return false
                default: return true
                }
            }
            return true
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(visibleTabs) { tab in
                tabButton(tab)
            }
            Spacer()
            awardCounter
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(theme.bgPanel)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.separator)
                .frame(height: 1)
        }
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
            .background(isSelected ? theme.accentBlue.opacity(0.18) : Color.clear)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(theme.accentBlue)
                        .frame(height: 2)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(!tab.isAvailable)
        .help(tab.isAvailable ? "" : "\(tab.rawValue) — kommt in späterer Phase")
    }

    // Live-Award-Counter. Im Contest nur QSO-Anzahl des aktiven Logs +
    // Anzahl unique Bänder — DXCC/WAZ/WAS sind dort nicht relevant.
    // In Standard/POTA wie bisher: globale Worked/Confirmed-Zahlen.
    @ViewBuilder
    private var awardCounter: some View {
        if currentLogType == .contest {
            contestCounter
        } else {
            let a = manager.awards
            HStack(spacing: 10) {
                awardBadge("DXCC", worked: a.dxccWorked, confirmed: a.dxccConfirmed,
                           tooltip: "DXCC: \(a.dxccWorked) Länder gearbeitet, \(a.dxccConfirmed) bestätigt (LoTW/eQSL)")
                awardBadge("WAZ",  worked: a.wazWorked,  confirmed: a.wazConfirmed,
                           tooltip: "WAZ: \(a.wazWorked) CQ-Zonen gearbeitet, \(a.wazConfirmed) bestätigt")
                awardBadge("WAS",  worked: a.wasWorked,  confirmed: a.wasConfirmed,
                           tooltip: "WAS: \(a.wasWorked) US-States gearbeitet (nur QSOs aus den USA)")
                awardBadge("QSOs", worked: a.totalQSOs,  confirmed: nil,
                           tooltip: "Gesamt-QSOs über alle Logs")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(theme.bgCard2)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private var contestCounter: some View {
        let total = manager.currentQSOs.count
        let bands = Set(manager.currentQSOs.map { $0.band }.filter { !$0.isEmpty }).count
        return HStack(spacing: 10) {
            awardBadge("QSOs", worked: total, confirmed: nil,
                       tooltip: "QSOs im aktiven Contest-Log")
            awardBadge("Bands", worked: bands, confirmed: nil,
                       tooltip: "Anzahl Bänder im aktiven Contest-Log")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(theme.bgCard2)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func awardBadge(_ name: String,
                            worked: Int,
                            confirmed: Int?,
                            tooltip: String) -> some View {
        HStack(spacing: 3) {
            Text(name)
                .font(.caption2.weight(.medium))
                .foregroundStyle(theme.textDim)
            if let c = confirmed {
                HStack(spacing: 1) {
                    Text("\(worked)")
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(worked > 0 ? theme.textPrimary : theme.textDim)
                    Text("/")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                    Text("\(c)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(c > 0 ? theme.accentGreen : theme.textDim)
                }
            } else {
                Text("\(worked)")
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(worked > 0 ? theme.textPrimary : theme.textDim)
            }
        }
        .help(tooltip)
    }
}
