import SwiftUI

// DX-Cluster-Tab innerhalb des Logbuch-Moduls. Zeigt die gefilterten Spots
// (volle Cluster-Filter-Logik via VM) im SpotListView. Status + Filter
// leben oberhalb in der ClusterContextBar.
struct LogbookClusterTab: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var clusterVM: DXClusterViewModel
    @EnvironmentObject var watchList: WatchListStore

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        SpotListView(spots: clusterVM.filteredSpots,
                     theme: theme,
                     watchList: watchList)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.bgApp)
    }
}
