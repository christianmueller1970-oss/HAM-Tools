import SwiftUI
import MapKit

// Contest-Map: QTH-zentrierte Karte mit Linien zu allen QSOs im aktiven
// Contest-Log. Schlankere Variante des POTAMapTab — kein Park-Konzept,
// dafür der eigene Standort als Knoten in der Mitte.
//
// Auflösungs-Reihenfolge für DX-Koordinaten:
//   1. qso.locator (Maidenhead)
//   2. Callbook-Cache lat/lon (QRZ/HamQTH)
//   3. Callbook-Cache locator
//   Kein Treffer → kein Marker (QSO bleibt nur in der Tabelle sichtbar)
struct ContestMapTab: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager:      LogbookManager
    @EnvironmentObject var callbook:     CallbookManager

    @AppStorage("qthLocator")                private var qthLocator       = ""
    @AppStorage("map.style")                 private var selectedMapStyle: MapStyleChoice = .standard
    @AppStorage("logbook.contestMap.band")   private var bandFilter        = "Alle"

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47, longitude: 8),
            span:   MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 120)
        )
    )
    @State private var didCenterOnQTH: Bool = false

    private var theme: AppTheme { themeManager.theme }

    private struct MappedQSO: Identifiable {
        let id: UUID
        let qso: QSO
        let coord: CLLocationCoordinate2D
    }

    private var qthCoord: CLLocationCoordinate2D? {
        guard !qthLocator.isEmpty,
              let (lat, lon) = locatorToLatLon(qthLocator) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func resolveCoord(for qso: QSO) -> CLLocationCoordinate2D? {
        if let loc = qso.locator, !loc.isEmpty,
           let (la, lo) = locatorToLatLon(loc) {
            return CLLocationCoordinate2D(latitude: la, longitude: lo)
        }
        if let cb = callbook.cachedResult(forCall: qso.call) {
            if let la = cb.lat, let lo = cb.lon {
                return CLLocationCoordinate2D(latitude: la, longitude: lo)
            }
            if let g = cb.locator, !g.isEmpty,
               let (la, lo) = locatorToLatLon(g) {
                return CLLocationCoordinate2D(latitude: la, longitude: lo)
            }
        }
        return nil
    }

    private var bandOptions: [String] {
        ["Alle"] + Array(Set(manager.currentQSOs.map(\.band))).filter { !$0.isEmpty }.sorted()
    }

    private var allMappedQSOs: [MappedQSO] {
        manager.currentQSOs.compactMap { q in
            if bandFilter != "Alle", q.band != bandFilter { return nil }
            guard let c = resolveCoord(for: q) else { return nil }
            return MappedQSO(id: q.id, qso: q, coord: c)
        }
    }

    private var mappedQSOs: [MappedQSO] {
        allMappedQSOs.cappedByDate(max: MapRenderLimits.maxAnnotations,
                                   dateKey: { $0.qso.datetime })
    }

    private var isOverflow: Bool { allMappedQSOs.count > MapRenderLimits.maxAnnotations }
    private var linesAllowed: Bool { mappedQSOs.count <= MapRenderLimits.maxLines }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().background(theme.separator)
            mapView
        }
        .background(theme.bgApp)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "map.fill")
                .foregroundStyle(theme.accentBlue)
            Text("Contest-Map · \(allMappedQSOs.count) / \(manager.currentQSOs.count) QSO geomappt")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            HStack(spacing: 4) {
                Text("Band").font(.caption2).foregroundStyle(theme.textDim)
                Picker("Band", selection: $bandFilter) {
                    ForEach(bandOptions, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .controlSize(.mini)
                .frame(width: 90)
            }
            Button {
                centerOnQTH(animated: true)
            } label: {
                Label("QTH", systemImage: "scope")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Karte auf eigenen Standort zentrieren")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.bgPanel)
    }

    private var mapView: some View {
        Map(position: $cameraPosition) {
            if let q = qthCoord {
                Marker("QTH", systemImage: "antenna.radiowaves.left.and.right",
                       coordinate: q)
                    .tint(.orange)
            }
            ForEach(mappedQSOs) { item in
                Marker(item.qso.call, coordinate: item.coord)
                    .tint(.blue)
                if linesAllowed, let qth = qthCoord {
                    MapPolyline(coordinates: [qth, item.coord])
                        .stroke(.blue.opacity(0.35), lineWidth: 1)
                }
            }
        }
        .appMapStyle(selectedMapStyle)
        .overlay(alignment: .bottomLeading) {
            if isOverflow {
                MapOverflowBanner(totalMatched: allMappedQSOs.count,
                                  shown: mappedQSOs.count)
                    .padding(12)
            }
        }
        .onAppear {
            if !didCenterOnQTH {
                centerOnQTH(animated: false)
                didCenterOnQTH = true
            }
        }
    }

    private func centerOnQTH(animated: Bool) {
        let center = qthCoord ?? CLLocationCoordinate2D(latitude: 47, longitude: 8)
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 120)
        )
        if animated {
            withAnimation(.easeInOut(duration: 0.4)) {
                cameraPosition = .region(region)
            }
        } else {
            cameraPosition = .region(region)
        }
    }
}
