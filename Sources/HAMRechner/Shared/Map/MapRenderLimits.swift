import SwiftUI

// Hard-Caps gegen MapKit-Overload bei sehr großen Logs. Kontext: vor 1.8.15
// brachte der History-Tab den initialen Render zum Erliegen, wenn man
// »Zeitraum = Alle« auf ein Standard-Log mit mehreren tausend QSOs los-
// ließ — pro QSO eine Annotation plus Polyline von QTH zur Gegenstation.
// Fenster wurde nie sichtbar, App-Prozess lebte ohne UI weiter.
//
// Die gleiche Schwachstelle haben strukturell auch die Programm-Maps
// (BOTA/POTA/WWFF/SOTA) sowie ContestMap. Damit der Schutz konsistent
// bleibt, leben die Limits + die Banner-View zentral hier.
enum MapRenderLimits {
    static let maxAnnotations = 1500
    static let maxLines       = 500
}

// Kompakter Hinweis-Banner für Overflow-Situationen. Wird vom Map-Tab als
// Overlay angezeigt, sobald `totalMatched > shown`. Beschreibungstext ist
// programm-neutral ("QSOs"), die Empfehlung zum Filter-Engerziehen passt
// für alle Map-Tabs.
struct MapOverflowBanner: View {
    @EnvironmentObject var themeManager: ThemeManager
    let totalMatched: Int
    let shown:        Int

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("\(totalMatched) Treffer — Karte zeigt nur die neuesten \(shown). Filter (Band/Mode/Zeitraum) enger setzen.")
                .font(.caption)
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.bgCard.opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.orange.opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

extension Array {
    // Bei Overflow die `max` Elemente mit dem jüngsten `dateKey` zurück-
    // geben — die ältesten fallen weg. Sortiert nur, wenn ein Cap nötig
    // ist, damit kleinere Logs nicht den Sortier-Overhead zahlen.
    func cappedByDate(max: Int, dateKey: (Element) -> Date) -> [Element] {
        guard count > max else { return self }
        return Array(self.sorted { dateKey($0) > dateKey($1) }.prefix(max))
    }
}
