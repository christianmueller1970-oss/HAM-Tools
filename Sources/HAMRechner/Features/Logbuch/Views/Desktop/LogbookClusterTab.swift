import SwiftUI

// DX-Cluster-Tab innerhalb des Logbuch-Moduls. Zeigt die gefilterten Spots
// (volle Cluster-Filter-Logik via VM) im SpotListView — Rechtsklick/Doppelklick
// öffnet das Logbuch-Eingabe-Panel mit vorausgefülltem QSO.
struct LogbookClusterTab: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var clusterVM: DXClusterViewModel
    @EnvironmentObject var watchList: WatchListStore

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            Divider().background(theme.separator)
            SpotListView(spots: clusterVM.filteredSpots,
                         theme: theme,
                         watchList: watchList)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.bgApp)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            connectionBadge
            Text("\(clusterVM.filteredSpots.count) Spots")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text("Rechtsklick → »Ins Logbuch eintragen« · Doppelklick übernimmt direkt")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(theme.bgPanel)
    }

    private var connectionBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusLabel)
                .font(.caption2.bold())
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var statusColor: Color {
        switch clusterVM.clusterStatus {
        case .connected:                  return theme.accentGreen
        case .connecting, .loggingIn:     return theme.accentYellow
        case .disconnected:               return theme.textDim
        case .error:                      return theme.accentRed
        }
    }

    private var statusLabel: String {
        clusterVM.clusterStatus.rawValue
    }
}
