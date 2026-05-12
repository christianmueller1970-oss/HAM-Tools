import SwiftUI
import MapKit

// History-Tab: Karte der eigenen QSOs aus dem aktiven Log. Pro QSO ein
// Punkt am DX-Standort (aus dem Locator), Linie von QTH zur Gegenstation,
// Mode-Farbe. Filter live aus der HistoryContextBar.
struct HistoryTab: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager

    @AppStorage("qthLocator")            private var qthLocator       = ""
    @AppStorage("logbook.history.lines") private var showLines: Bool  = true
    @AppStorage("logbook.history.mode")  private var modeFilter       = "Alle"
    @AppStorage("logbook.history.band")  private var bandFilter       = "Alle"
    @AppStorage("logbook.history.days")  private var daysFilter: Int  = 365
    @AppStorage("map.style")             private var selectedMapStyle: MapStyleChoice = .standard

    @State private var selectedQSO: QSO? = nil
    @State private var cameraPosition: MapCameraPosition = HistoryTab.initialCameraPosition()

    private var theme: AppTheme { themeManager.theme }

    // QTH-Koordinaten (aus dem Locator) für Linien-Start
    private var qthCoord: CLLocationCoordinate2D? {
        guard let (lat, lon) = locatorToLatLon(qthLocator) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // Mapping QSO → Geo (nur QSOs mit Locator kommen auf die Karte).
    private struct MappedQSO: Identifiable {
        let id: UUID
        let qso: QSO
        let coord: CLLocationCoordinate2D
    }

    private var mappedQSOs: [MappedQSO] {
        let cutoff = daysFilter > 0
            ? Date().addingTimeInterval(-Double(daysFilter) * 86400)
            : Date.distantPast
        return manager.currentQSOs.compactMap { qso in
            guard let loc = qso.locator,
                  let (lat, lon) = locatorToLatLon(loc) else { return nil }
            guard qso.datetime >= cutoff else { return nil }
            if modeFilter != "Alle", qso.mode != modeFilter { return nil }
            if bandFilter != "Alle", qso.band != bandFilter { return nil }
            return MappedQSO(id: qso.id, qso: qso,
                             coord: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            mapContent
            if let q = selectedQSO {
                infoPopup(for: q)
                    .padding(12)
            }
        }
        .background(theme.bgApp)
        .onChange(of: qthLocator) { centerOnQTH() }
    }

    // MARK: - Map

    private var mapContent: some View {
        Map(position: $cameraPosition) {
            // QTH-Marker
            if let home = qthCoord {
                Annotation("QTH", coordinate: home) {
                    Image(systemName: "house.circle.fill")
                        .foregroundStyle(theme.accentBlue)
                        .background(Circle().fill(.white).frame(width: 20, height: 20))
                        .font(.title2)
                }
            }
            // Linien Home → DX (wenn aktiv)
            if showLines, let home = qthCoord {
                ForEach(mappedQSOs) { m in
                    MapPolyline(coordinates: [home, m.coord])
                        .stroke(modeColor(m.qso.mode).opacity(0.55), lineWidth: 1)
                }
            }
            // DX-Punkte
            ForEach(mappedQSOs) { m in
                Annotation("", coordinate: m.coord, anchor: .center) {
                    Circle()
                        .fill(modeColor(m.qso.mode))
                        .stroke(.white, lineWidth: 1)
                        .frame(width: selectedQSO?.id == m.qso.id ? 14 : 9,
                               height: selectedQSO?.id == m.qso.id ? 14 : 9)
                        .onTapGesture { selectedQSO = m.qso }
                }
            }
        }
        .appMapStyle(selectedMapStyle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Info-Popup

    private func infoPopup(for qso: QSO) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(qso.call)
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundStyle(theme.accentBlue)
                    Text("·")
                        .foregroundStyle(theme.textDim)
                    Text(qso.band)
                    Text("·")
                        .foregroundStyle(theme.textDim)
                    Text(qso.mode)
                        .foregroundStyle(modeColor(qso.mode))
                }
                .font(.body)
                if let name = qso.name, !name.isEmpty {
                    Text(name).font(.caption).foregroundStyle(theme.textSecondary)
                }
                HStack(spacing: 6) {
                    if let qth = qso.qth, !qth.isEmpty {
                        Text(qth).font(.caption)
                    }
                    if let country = qso.country, !country.isEmpty {
                        Text("·").foregroundStyle(theme.textDim)
                        Text(country).font(.caption)
                    }
                    if let loc = qso.locator, !loc.isEmpty {
                        Text("·").foregroundStyle(theme.textDim)
                        Text(loc).font(.caption.monospaced())
                    }
                }
                .foregroundStyle(theme.textSecondary)
                Text(formatUTC(qso.datetime))
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.textDim)
            }
            Spacer()
            Button {
                selectedQSO = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(theme.textDim)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(theme.bgCard.opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: 360)
    }

    // MARK: - Helpers

    private func centerOnQTH() {
        guard let home = qthCoord else { return }
        cameraPosition = .region(MKCoordinateRegion(
            center: home,
            span:   MKCoordinateSpan(latitudeDelta: 80, longitudeDelta: 160)
        ))
    }

    private static func initialCameraPosition() -> MapCameraPosition {
        let loc = UserDefaults.standard.string(forKey: "qthLocator") ?? ""
        let center: CLLocationCoordinate2D
        if let (lat, lon) = locatorToLatLon(loc) {
            center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            center = CLLocationCoordinate2D(latitude: 47, longitude: 8)
        }
        return .region(MKCoordinateRegion(
            center: center,
            span:   MKCoordinateSpan(latitudeDelta: 80, longitudeDelta: 160)
        ))
    }

    private func formatUTC(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm 'UTC'"
        return f.string(from: date)
    }

    // Mode-Farben (gleiche Palette wie WeltkarteView / BandmapView)
    private func modeColor(_ mode: String) -> Color {
        switch mode.uppercased() {
        case "FT8":   return Color(hex: "#00ff88")
        case "FT4":   return Color(hex: "#00ccff")
        case "CW":    return Color(hex: "#ff6600")
        case "SSB", "USB", "LSB": return Color(hex: "#ffcc00")
        case "RTTY":  return Color(hex: "#ff44ff")
        case "PSK31","PSK63": return Color(hex: "#44ffff")
        case "WSPR":  return Color(hex: "#aaaaff")
        case "JS8":   return Color(hex: "#88ff44")
        case "FM":    return Color(hex: "#ff8888")
        case "AM":    return Color(hex: "#ffaa44")
        default:      return Color(hex: "#cccccc")
        }
    }
}
