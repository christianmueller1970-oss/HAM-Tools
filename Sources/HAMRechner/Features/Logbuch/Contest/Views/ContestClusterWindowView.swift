import SwiftUI

// Contest-Cluster als eigenes Pop-up-Fenster. Nutzt die bestehende
// LogbookClusterTab-Logik (Contest-Mode/Band-Filter + Dupe-rot/Mult-grün-
// Färbung wenn ein Contest-Log aktiv ist; ansonsten normale Spot-Liste).
//
// Single-Instance via WindowGroup(id: "contestcluster"), Position + Größe
// werden über NSWindow-Restoration gemerkt.
struct ContestClusterWindowView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        LogbookClusterTab()
            .navigationTitle("Contest-Cluster")
            .background(themeManager.theme.bgApp)
            .preferredColorScheme(themeManager.theme.colorScheme)
    }
}
