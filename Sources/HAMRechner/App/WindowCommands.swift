import SwiftUI

// CommandMenu-Inhalt für das macOS-Menubar-"Fenster"-Menü.
//
// Aktuell: "Neue Bandmap ▸" mit Untermenü aller HF-Bänder. Klick öffnet eine
// Pop-up-Bandmap (BandmapWindowView) als eigenes Fenster — ideal für
// Mehrmonitor-Setups, mehrere Bänder parallel zu beobachten.
//
// Pro Band gibt es maximal EIN Fenster: SwiftUI WindowGroup(for: String.self)
// nutzt den Band-Namen als Routing-Schlüssel, ein zweiter Klick auf dasselbe
// Band bringt das existierende Fenster nach vorn. NSWindow-Restoration sorgt
// dafür, dass offene Fenster nach App-Neustart wieder da sind, mit Position
// und Größe.
//
// Folge-Features ([[ERWEITERUNGEN_PLAN]] Ideen 3+4) hängen sich hier später
// an: Grayline-Fenster und Cluster-Terminal-Fenster.
struct WindowCommands: View {
    @Environment(\.openWindow) private var openWindow

    // Standard-HF-Bänder, die in der Bandmap angezeigt werden können —
    // gleiche Liste wie BandmapView.quickBands. WARC-Bänder (30/17/12m)
    // sind drin, weil dort durchaus Cluster-Spots auftauchen.
    private let bands = ["160m","80m","40m","30m","20m","17m","15m","12m","10m","6m"]

    var body: some View {
        // Flache Section statt verschachteltes Menu — auf macOS 14 schließt
        // sich ein offenes Submenu wenn das App-Body neu evaluiert wird
        // (passiert ständig durch Cluster-Spot-Updates).
        Section("Neue Bandmap") {
            ForEach(bands, id: \.self) { band in
                Button(band) {
                    openWindow(id: "bandmap", value: band)
                }
            }
        }
    }
}
