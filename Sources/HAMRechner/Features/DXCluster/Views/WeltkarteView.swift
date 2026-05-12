import SwiftUI
import MapKit

// MARK: - Mode colours (same palette as BandmapView)

private let MAP_MODE_COLORS: [String: Color] = [
    "FT8":  Color(hex: "#00ff88"),
    "FT4":  Color(hex: "#00ccff"),
    "CW":   Color(hex: "#ff6600"),
    "SSB":  Color(hex: "#ffcc00"),
    "RTTY": Color(hex: "#ff44ff"),
    "PSK31":Color(hex: "#44ffff"),
    "PSK63":Color(hex: "#44ffff"),
    "WSPR": Color(hex: "#aaaaff"),
    "JS8":  Color(hex: "#88ff44"),
    "FM":   Color(hex: "#ff8888"),
    "AM":   Color(hex: "#ffaa44"),
]
private func mapModeColor(_ mode: String) -> Color {
    MAP_MODE_COLORS[mode] ?? Color(hex: "#cccccc")
}

// MARK: - WeltkarteView

struct WeltkarteView: View {
    let spots: [DXSpot]
    let theme: AppTheme

    @AppStorage("qthLocator") private var qthLocator = "JN47PN"
    @AppStorage("map.style")  private var selectedMapStyle: MapStyleChoice = .standard

    @State private var selectedSpot:     DXSpot? = nil
    @State private var showSpotterLines  = false
    @State private var timeMinutes       = 60
    @State private var cameraPosition: MapCameraPosition = Self.initialCameraPosition()

    // Beim ersten Aufbau die Camera direkt auf den persistierten QTH
    // setzen — onAppear bewegt nachher nochmal nach, aber sonst sieht man
    // beim Tab-Switch kurz den globalen Default-View.
    private static func initialCameraPosition() -> MapCameraPosition {
        let loc = UserDefaults.standard.string(forKey: "qthLocator") ?? "JN47PN"
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

    private var recentSpots: [DXSpot] {
        let cutoff = Date().addingTimeInterval(-Double(timeMinutes) * 60)
        let base   = timeMinutes < 9999 ? spots.filter { $0.timestamp >= cutoff } : spots
        return base.filter { $0.lat != 0 || $0.lon != 0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ZStack(alignment: .bottom) {
                mapContent
                infoBar
            }
        }
        .background(theme.bgApp)
        .onAppear { centerOnQTH() }
        .onChange(of: qthLocator) { centerOnQTH() }
    }

    private func centerOnQTH() {
        guard let (lat, lon) = locatorToLatLon(qthLocator) else { return }
        cameraPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span:   MKCoordinateSpan(latitudeDelta: 80, longitudeDelta: 160)
        ))
    }

    // MARK: - Map

    private var mapContent: some View {
        Map(position: $cameraPosition) {
            if showSpotterLines {
                ForEach(recentSpots.filter { $0.spotterLat != 0 || $0.spotterLon != 0 }) { spot in
                    MapPolyline(coordinates: [
                        CLLocationCoordinate2D(latitude: spot.spotterLat, longitude: spot.spotterLon),
                        CLLocationCoordinate2D(latitude: spot.lat,        longitude: spot.lon)
                    ])
                    .stroke(mapModeColor(spot.mode).opacity(0.4), lineWidth: 1)
                }
            }
            ForEach(recentSpots) { spot in
                let coord = CLLocationCoordinate2D(latitude: spot.lat, longitude: spot.lon)
                Annotation("", coordinate: coord, anchor: .center) {
                    SpotDot(color:      mapModeColor(spot.mode),
                            isSelected: selectedSpot?.id == spot.id)
                        .onTapGesture { selectedSpot = spot }
                }
            }
        }
        .appMapStyle(selectedMapStyle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Toggle(isOn: $showSpotterLines) {
                Label("Spotter-Linien", systemImage: "line.diagonal")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .foregroundStyle(theme.textPrimary)

            Divider().frame(height: 20).padding(.horizontal, 4)

            Text("Zeit:").font(.caption).foregroundStyle(theme.textSecondary)
            Picker("", selection: $timeMinutes) {
                Text("15 min").tag(15)
                Text("30 min").tag(30)
                Text("60 min").tag(60)
                Text("Alle").tag(9999)
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            Spacer()

            Text("\(recentSpots.count) Spots")
                .font(.caption.bold())
                .foregroundStyle(theme.accentBlue)
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(theme.bgPanel)
    }

    // MARK: - Info bar

    private var infoBar: some View {
        HStack {
            if let spot = selectedSpot {
                Group {
                    Text("DX: ").bold() + Text(spot.dxCall)
                    Text("  |  \(spot.displayFreq) kHz")
                    Text("  |  \(spot.mode)")
                    Text("  |  \(spot.country)")
                    if !spot.comment.isEmpty {
                        Text("  |  \(spot.comment.prefix(40))")
                    }
                    Text("  |  Spotter: \(spot.spotter)")
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.accentBlue)
                Spacer()
                Button("✕") { selectedSpot = nil }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textDim)
            } else {
                Text("Auf einen Spot klicken für Details")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textDim)
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(theme.bgApp.opacity(0.88))
    }
}

// MARK: - SpotDot

private struct SpotDot: View {
    let color:      Color
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: 24, height: 24)
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 16, height: 16)
            }
            Circle()
                .fill(color)
                .frame(width: isSelected ? 12 : 8,
                       height: isSelected ? 12 : 8)
        }
    }
}
