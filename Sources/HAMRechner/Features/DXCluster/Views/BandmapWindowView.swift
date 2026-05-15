import SwiftUI

// Wrapper für ein Pop-up-Bandmap-Fenster. Hängt am globalen DXClusterViewModel
// (gleiche Spot-Quelle wie das Hauptfenster) und ist auf ein festes Band
// geclickt. Single-Instance-pro-Band wird vom SwiftUI WindowGroup(for:)-
// Mechanismus garantiert: ein zweiter openWindow(value: "20m")-Aufruf bringt
// das existierende Fenster nach vorn statt ein neues zu öffnen.
struct BandmapWindowView: View {
    let band: String

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var clusterVM:    DXClusterViewModel

    var body: some View {
        VerticalBandmapView(spots: clusterVM.spots,
                            theme: themeManager.theme,
                            band:  band)
            .navigationTitle("Bandmap (\(band))")
            .background(themeManager.theme.bgApp)
            .preferredColorScheme(themeManager.theme.colorScheme)
    }
}
