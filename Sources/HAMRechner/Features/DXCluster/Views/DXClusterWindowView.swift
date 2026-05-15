import SwiftUI

// DX-Cluster als eigenes Pop-up-Fenster (analog zu BandmapWindowView).
// Zeigt die volle, VM-gefilterte Spot-Liste — ohne Contest-spezifische
// Mode/Band-Einschränkung und ohne Dupe-/Mult-Färbung. Wer Contest-
// Farbcodierung will, nutzt das separate Contest-Cluster-Fenster.
//
// Single-Instance via WindowGroup(id: "dxcluster"), Position + Größe
// werden über NSWindow-Restoration gemerkt.
struct DXClusterWindowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var clusterVM:    DXClusterViewModel
    @EnvironmentObject var watchList:    WatchListStore

    var body: some View {
        SpotListView(spots:     clusterVM.filteredSpots,
                     theme:     themeManager.theme,
                     watchList: watchList)
            .navigationTitle("DX-Cluster")
            .background(themeManager.theme.bgApp)
            .preferredColorScheme(themeManager.theme.colorScheme)
    }
}
