import SwiftUI
import MapKit

// Welt-Karte mit Tag/Nacht-Linie für DX-Propagations-Planning.
// Nutzt MapKit für Kontinent-Outlines und überlagert ein Grid-Sampling
// von Tag/Dämmerungs/Nacht-Zonen (4 Stufen) als semi-transparente
// MapPolygons. QTH-Marker aus Settings.qthLocator und Sonnen-Marker
// am Subsolar-Punkt.
struct GraylineView: View {
    @EnvironmentObject var themeManager: ThemeManager

    @AppStorage("qthLocator") private var qthLocator = "JN47PN"

    @State private var displayDate: Date = Date()
    @State private var isLiveNow:   Bool = true

    // Initial-View: ganze Welt. MKMapRect.world zeigt die volle Mercator-
    // Projektion (Polkappen leicht abgeschnitten — Mercator-Limitation).
    @State private var cameraPosition: MapCameraPosition = .rect(.world)

    // 1-Minuten-Tick für Live-Modus.
    private let liveTick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private let gridStep: Double = 5.0     // Grad; 5° = 2592 Polygone — smoothe Dämmerungs-Zonen
    private let nightAlpha: [Double] = [
        0.0,    // day
        0.25,   // civil
        0.50,   // nautical
        0.70,   // astronomical
        0.85    // night
    ]

    private var qthCoord: CLLocationCoordinate2D? {
        guard let (lat, lon) = locatorToLatLon(qthLocator) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private var subSolar: CLLocationCoordinate2D {
        let p = SunTerminator.subSolarPoint(at: displayDate)
        return CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon)
    }

    // Lat/Lon-Grid-Cells mit ihrer Dämmerungs-Klasse. Nur Cells mit
    // alpha > 0 werden gerendert (Day-Cells sind transparent → die echte
    // Map scheint durch).
    private struct NightCell: Identifiable {
        let id = UUID()
        let corners: [CLLocationCoordinate2D]
        let alpha:   Double
    }

    private var nightCells: [NightCell] {
        var result: [NightCell] = []
        var lat = -90.0
        while lat < 90.0 {
            var lon = -180.0
            while lon < 180.0 {
                let h = SunTerminator.solarAltitude(
                    latDeg: lat + gridStep/2,
                    lonDeg: lon + gridStep/2,
                    at: displayDate)
                let cls = SunTerminator.classify(altitudeDeg: h)
                let alpha = nightAlpha[classIndex(cls)]
                if alpha > 0 {
                    let corners: [CLLocationCoordinate2D] = [
                        .init(latitude: lat,             longitude: lon),
                        .init(latitude: lat + gridStep,  longitude: lon),
                        .init(latitude: lat + gridStep,  longitude: lon + gridStep),
                        .init(latitude: lat,             longitude: lon + gridStep),
                    ]
                    result.append(NightCell(corners: corners, alpha: alpha))
                }
                lon += gridStep
            }
            lat += gridStep
        }
        return result
    }

    private func classIndex(_ c: SunTerminator.DaylightClass) -> Int {
        switch c {
        case .day:           return 0
        case .civil:         return 1
        case .nautical:      return 2
        case .astronomical:  return 3
        case .night:         return 4
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            mapView
            Divider()
            toolbar
        }
        .navigationTitle("Grayline")
        .onReceive(liveTick) { _ in
            if isLiveNow {
                displayDate = Date()
            }
        }
        .onChange(of: displayDate) { _, _ in
            // Wenn User Datum manuell verstellt, automatisch raus aus
            // Live-Modus. Klick auf "Jetzt" stellt das wieder her.
        }
    }

    // MARK: - Karte

    private var terminatorCoords: [CLLocationCoordinate2D] {
        SunTerminator.terminatorLine(at: displayDate).map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
        }
    }

    private var mapView: some View {
        Map(position: $cameraPosition) {
            // Nacht-/Dämmerungs-Polygone via Grid-Sampling
            ForEach(nightCells) { cell in
                MapPolygon(coordinates: cell.corners)
                    .foregroundStyle(Color.black.opacity(cell.alpha))
                    .stroke(Color.clear, lineWidth: 0)
            }

            // Scharfe Terminator-Linie (Großkreis Tag/Nacht-Grenze)
            MapPolyline(coordinates: terminatorCoords)
                .stroke(Color.orange.opacity(0.85), lineWidth: 1.5)

            // Sonne (Subsolar-Punkt)
            Annotation("Sonne", coordinate: subSolar) {
                Image(systemName: "sun.max.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                    .shadow(color: .orange, radius: 4)
            }

            // QTH-Marker
            if let qth = qthCoord {
                Annotation(qthLocator, coordinate: qth) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 14, height: 14)
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 14, height: 14)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            DatePicker("", selection: $displayDate, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .onChange(of: displayDate) { _, _ in
                    // Manuelle Eingabe verlässt den Live-Modus
                    if isLiveNow && abs(displayDate.timeIntervalSinceNow) > 5 {
                        isLiveNow = false
                    }
                }

            Button {
                isLiveNow = true
                displayDate = Date()
            } label: {
                Label("Jetzt", systemImage: "clock.arrow.circlepath")
                    .labelStyle(.titleAndIcon)
            }
            .keyboardShortcut("n", modifiers: [.command])

            if isLiveNow {
                Text("LIVE")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())
            }

            Spacer()

            Text(utcLabel)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(themeManager.theme.bgPanel)
    }

    private var utcLabel: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm 'UTC'"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: displayDate)
    }
}
