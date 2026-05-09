import SwiftUI
import MapKit
import Charts
import AppKit

// MARK: - Map click capture (macOS: SwiftUI tap gestures are swallowed by MapKit's AppKit recognizers)

private class MapClickNSView: NSView {
    var isCapturing = false
    var onTap: ((CGPoint) -> Void)?

    override var isFlipped: Bool { true }   // top-left origin — matches SwiftUI .local space

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Transparent when idle so map pan/zoom events pass through
        isCapturing ? super.hitTest(point) : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard isCapturing else { return }
        let loc = convert(event.locationInWindow, from: nil)
        onTap?(CGPoint(x: loc.x, y: loc.y))
    }

    override func resetCursorRects() {
        if isCapturing { addCursorRect(bounds, cursor: .crosshair) }
    }
}

private struct MapClickCapture: NSViewRepresentable {
    var isCapturing: Bool
    var onTap: (CGPoint) -> Void

    func makeNSView(context: Context) -> MapClickNSView {
        let v = MapClickNSView()
        v.onTap = onTap
        return v
    }

    func updateNSView(_ v: MapClickNSView, context: Context) {
        v.isCapturing = isCapturing
        v.onTap = onTap
        v.window?.invalidateCursorRects(for: v)
    }
}

// MARK: - Maidenhead

private enum Maidenhead {
    static func toLatLon(_ loc: String) -> (lat: Double, lon: Double)? {
        let s = loc.uppercased().trimmingCharacters(in: .whitespaces)
        guard s.count >= 4 else { return nil }
        let c = Array(s)
        guard let f0 = c[0].asciiValue, let f1 = c[1].asciiValue,
              let c2 = c[2].wholeNumberValue, let c3 = c[3].wholeNumberValue,
              f0 >= 65, f0 <= 82, f1 >= 65, f1 <= 82 else { return nil }
        var lon = Double(f0-65)*20.0 - 180.0 + Double(c2)*2.0
        var lat = Double(f1-65)*10.0 -  90.0 + Double(c3)*1.0
        if s.count >= 6, let av = c[4].asciiValue, let bv = c[5].asciiValue, av >= 65, bv >= 65 {
            lon += Double(av-65)*(2.0/24.0)
            lat += Double(bv-65)*(1.0/24.0)
            if s.count >= 8, let d6 = c[6].wholeNumberValue, let d7 = c[7].wholeNumberValue {
                // Extended square center
                lon += Double(d6)*(2.0/240.0) + (1.0/240.0)
                lat += Double(d7)*(1.0/240.0) + (0.5/240.0)
            } else {
                // Subsquare center
                lon += 1.0/24.0
                lat += 0.5/24.0
            }
        } else { lon += 1.0; lat += 0.5 }
        return (lat, lon)
    }

    static func fromLatLon(lat: Double, lon: Double) -> String {
        var lo = lon+180.0, la = lat+90.0
        let f0 = Int(lo/20); lo -= Double(f0)*20.0
        let f1 = Int(la/10); la -= Double(f1)*10.0
        let c2 = Int(lo/2);  lo -= Double(c2)*2.0
        let c3 = Int(la/1);  la -= Double(c3)*1.0
        let s4 = Int(lo/(2.0/24.0)); lo -= Double(s4)*(2.0/24.0)
        let s5 = Int(la/(1.0/24.0)); la -= Double(s5)*(1.0/24.0)
        // Extended square: each subsquare split 10×10 → digits 0–9
        let e6 = min(9, Int(lo / (2.0/240.0)))
        let e7 = min(9, Int(la / (1.0/240.0)))
        let L = Array("ABCDEFGHIJKLMNOPQRSTUVWX")
        return "\(L[f0])\(L[f1])\(c2)\(c3)\(L[s4].lowercased())\(L[s5].lowercased())\(e6)\(e7)"
    }

    static func distKm(_ a: (lat: Double, lon: Double), _ b: (lat: Double, lon: Double)) -> Double {
        let d2r = Double.pi/180, R = 6371.0
        let dLat=(b.lat-a.lat)*d2r, dLon=(b.lon-a.lon)*d2r
        let h=sin(dLat/2)*sin(dLat/2)+cos(a.lat*d2r)*cos(b.lat*d2r)*sin(dLon/2)*sin(dLon/2)
        return 2*R*asin(min(1,sqrt(h)))
    }

    static func bearing(_ a: (lat: Double, lon: Double), _ b: (lat: Double, lon: Double)) -> Double {
        let dLon=(b.lon-a.lon)*Double.pi/180
        let y=sin(dLon)*cos(b.lat*Double.pi/180)
        let x=cos(a.lat*Double.pi/180)*sin(b.lat*Double.pi/180) - sin(a.lat*Double.pi/180)*cos(b.lat*Double.pi/180)*cos(dLon)
        return (atan2(y,x)*180/Double.pi+360).truncatingRemainder(dividingBy: 360)
    }
}

// MARK: - Map grid helpers

private struct GridLabel: Identifiable {
    let id:    String
    let coord: CLLocationCoordinate2D
}

private struct MapGrid {
    let vLines: [[CLLocationCoordinate2D]]
    let hLines: [[CLLocationCoordinate2D]]
    let labels: [GridLabel]
}

// MARK: - LOS / Fresnel helpers

private struct LOSPt: Identifiable {
    let id: Int; let distKm: Double; let losM: Double
}
private struct FresnelPt: Identifiable {
    let id: String; let distKm: Double; let upper: Double; let lower: Double
}

// MARK: - Stat tile

private struct StatTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.headline.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - QTHLocatorView

struct QTHLocatorView: View {
    @AppStorage("qthLocator") private var homeLocator = "JN47PN"
    @State private var selectedTab = 0

    // — Map & Locator (Tab 0) —
    @State private var locSource     = ""
    @State private var locDest       = "IO51"
    @State private var captureTarget: Int? = nil   // nil=idle, 0=set source, 1=set dest
    @State private var mapCamera: MapCameraPosition = .automatic

    // — Overlays —
    @State private var showSOTA      = false
    @State private var showPOTA      = false
    @State private var overlayRadius = 20
    @State private var sotaResults:  [SOTASummit] = []
    @State private var potaResults:  [POTAPark]   = []
    @State private var overlayBusy   = false
    @State private var overlayError: String?

    // — Elevation (Tab 1) —
    @State private var elevPoints:  [ElevPoint] = []
    @State private var losPoints:   [LOSPt]     = []
    @State private var elevBusy     = false
    @State private var elevError:   String?
    @State private var elevDist     = 0.0
    @State private var showFresnel  = false
    @State private var activeBands: Set<String> = ["2m", "70cm"]

    private let bandDefs: [(name: String, freqMHz: Double, color: Color)] = [
        ("6m",   50.5, .purple),
        ("4m",   70.2, .teal),
        ("2m",  144.3, .green),
        ("70cm", 432.1, .orange),
    ]

    // MARK: Helpers

    private var sourceLL: (lat: Double, lon: Double)? { Maidenhead.toLatLon(locSource) }
    private var destLL:   (lat: Double, lon: Double)? { Maidenhead.toLatLon(locDest) }

    private var sourceCoord: CLLocationCoordinate2D? {
        sourceLL.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }
    private var destCoord: CLLocationCoordinate2D? {
        destLL.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }

    private func buildGrid() -> MapGrid {
        guard let coord = sourceCoord else { return MapGrid(vLines:[], hLines:[], labels:[]) }
        let lat = coord.latitude, lon = coord.longitude
        let baseLon = floor(lon / 2.0) * 2.0
        let baseLat = floor(lat / 1.0) * 1.0
        let hExt = 10.0; let vExt = 5.0
        var vLines: [[CLLocationCoordinate2D]] = []
        var hLines: [[CLLocationCoordinate2D]] = []
        var labels: [GridLabel] = []

        var lo = baseLon - hExt
        while lo <= baseLon + hExt {
            vLines.append([CLLocationCoordinate2D(latitude: baseLat-vExt-1, longitude: lo),
                           CLLocationCoordinate2D(latitude: baseLat+vExt+1, longitude: lo)])
            lo += 2.0
        }
        var la = baseLat - vExt
        while la <= baseLat + vExt {
            hLines.append([CLLocationCoordinate2D(latitude: la, longitude: baseLon-hExt-2),
                           CLLocationCoordinate2D(latitude: la, longitude: baseLon+hExt+2)])
            la += 1.0
        }
        la = baseLat - vExt + 0.5
        while la < baseLat + vExt {
            lo = baseLon - hExt + 1.0
            while lo < baseLon + hExt {
                let sq = String(Maidenhead.fromLatLon(lat: la, lon: lo).prefix(4))
                labels.append(GridLabel(id: sq, coord: CLLocationCoordinate2D(latitude: la, longitude: lo)))
                lo += 2.0
            }
            la += 1.0
        }
        return MapGrid(vLines: vLines, hLines: hLines, labels: labels)
    }

    private func distBearStr() -> String? {
        guard let a = sourceLL, let b = destLL else { return nil }
        let dist = Maidenhead.distKm(a, b)
        let bear = Maidenhead.bearing(a, b)
        return String(format: "%.0f km  %.0f°", dist, bear)
    }

    private func zoomSpanForRadius(_ km: Int) -> MKCoordinateSpan {
        let deg = Double(km) / 55.0 * 2.5
        return MKCoordinateSpan(latitudeDelta: deg, longitudeDelta: deg * 1.8)
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            switch selectedTab {
            case 0:
                karteTab.frame(maxWidth: .infinity, maxHeight: .infinity)
            case 1:
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) { elevationTab }
                        .padding(24)
                }
            default: EmptyView()
            }
        }
        .navigationTitle("QTH-Locator")
        .onAppear {
            locSource = homeLocator
            if let coord = sourceCoord {
                mapCamera = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 16)))
            }
        }
    }

    // MARK: Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabBtn("Karte & Locator", icon: "map",                       idx: 0)
            tabBtn("Höhenprofil",     icon: "chart.line.uptrend.xyaxis", idx: 1)
            Spacer()
        }
        .background(.bar)
    }

    private func tabBtn(_ label: String, icon: String, idx: Int) -> some View {
        Button { selectedTab = idx } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(label).font(selectedTab == idx ? .callout.bold() : .callout)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(selectedTab == idx ? Color.accentColor.opacity(0.12) : .clear)
            .foregroundStyle(selectedTab == idx ? Color.accentColor : Color.secondary)
            .overlay(alignment: .bottom) {
                if selectedTab == idx { Rectangle().fill(Color.accentColor).frame(height: 2) }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Tab 0 – Karte & Locator

    private var karteTab: some View {
        let hasInfo    = sourceLL != nil || destLL != nil
        let hasResults = (showSOTA && !sotaResults.isEmpty) || (showPOTA && !potaResults.isEmpty)
        return VStack(spacing: 0) {
            controlBar
            if hasInfo {
                Divider()
                koordinatenPanel
            }
            Divider()
            if hasResults {
                VSplitView {
                    interactiveMap.frame(minHeight: 220)
                    resultsContent
                        .frame(minHeight: 80, idealHeight: 180, maxHeight: 260)
                        .background(.bar)
                }
            } else {
                interactiveMap
            }
        }
    }

    // Control bar
    private var controlBar: some View {
        HStack(spacing: 8) {
            // Source locator
            VStack(alignment: .leading, spacing: 2) {
                Text("Quelle").font(.caption2).foregroundStyle(.blue)
                HStack(spacing: 4) {
                    TextField("JN47PN", text: $locSource)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout.monospaced())
                        .frame(width: 84)
                    Button {
                        captureTarget = captureTarget == 0 ? nil : 0
                    } label: {
                        Label("Karte", systemImage: captureTarget == 0 ? "mappin.circle.fill" : "mappin.circle")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(captureTarget == 0 ? .blue : nil)
                    .controlSize(.small)
                    .help(captureTarget == 0 ? "Kartenklick abbrechen" : "Quelle auf Karte klicken")
                }
            }

            // Distance / bearing readout
            VStack(spacing: 0) {
                if let info = distBearStr() {
                    Text(info)
                        .font(.system(size: 9, design: .monospaced).bold())
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary).font(.caption)
                }
            }
            .frame(minWidth: 80)

            // Dest locator
            VStack(alignment: .leading, spacing: 2) {
                Text("Ziel").font(.caption2).foregroundStyle(.red)
                HStack(spacing: 4) {
                    TextField("IO51", text: $locDest)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout.monospaced())
                        .frame(width: 84)
                    Button {
                        captureTarget = captureTarget == 1 ? nil : 1
                    } label: {
                        Label("Karte", systemImage: captureTarget == 1 ? "mappin.circle.fill" : "mappin.circle")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(captureTarget == 1 ? .red : nil)
                    .controlSize(.small)
                    .help(captureTarget == 1 ? "Kartenklick abbrechen" : "Ziel auf Karte klicken")
                }
            }

            Divider().frame(height: 28)

            // SOTA toggle
            Toggle(isOn: $showSOTA) {
                HStack(spacing: 3) {
                    Image(systemName: "triangle.fill").foregroundStyle(.orange).font(.caption)
                    Text("SOTA").font(.caption)
                }
            }
            .toggleStyle(.checkbox)

            // POTA toggle
            Toggle(isOn: $showPOTA) {
                HStack(spacing: 3) {
                    Image(systemName: "leaf.fill").foregroundStyle(.green).font(.caption)
                    Text("POTA").font(.caption)
                }
            }
            .toggleStyle(.checkbox)

            // Radius
            Picker("", selection: $overlayRadius) {
                Text("5 km").tag(5)
                Text("10 km").tag(10)
                Text("15 km").tag(15)
                Text("20 km").tag(20)
                Text("50 km").tag(50)
            }
            .pickerStyle(.menu).frame(width: 80)

            // Load
            Button {
                Task { await loadOverlays() }
            } label: {
                if overlayBusy {
                    ProgressView().controlSize(.mini).frame(width: 40)
                } else {
                    Text("Laden")
                }
            }
            .buttonStyle(.bordered)
            .disabled(overlayBusy || (!showSOTA && !showPOTA))

            if let err = overlayError {
                Text(err)
                    .font(.caption).foregroundStyle(.red).lineLimit(1)
                    .frame(maxWidth: 200)
            }

            Spacer()

            // Center button
            Button("Zentrieren") {
                if let coord = sourceCoord {
                    withAnimation {
                        mapCamera = .region(MKCoordinateRegion(
                            center: coord,
                            span: (showSOTA || showPOTA)
                                ? zoomSpanForRadius(overlayRadius)
                                : MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 16)))
                    }
                }
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.bar)
    }

    // Map with tap-to-set-locator
    private var interactiveMap: some View {
        let grid = buildGrid()
        return MapReader { proxy in
            Map(position: $mapCamera) {
                // Source marker
                if let coord = sourceCoord {
                    Annotation("Quelle: \(locSource)", coordinate: coord, anchor: .bottom) {
                        VStack(spacing: 2) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2).foregroundStyle(.blue)
                            Text(locSource)
                                .font(.system(size: 8, design: .monospaced).bold())
                                .padding(2)
                                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }

                // Destination marker
                if let coord = destCoord {
                    Annotation("Ziel: \(locDest)", coordinate: coord, anchor: .bottom) {
                        VStack(spacing: 2) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2).foregroundStyle(.red)
                            Text(locDest)
                                .font(.system(size: 8, design: .monospaced).bold())
                                .padding(2)
                                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }

                // Line source → dest — thick, high-contrast
                if let s = sourceCoord, let d = destCoord {
                    MapPolyline(coordinates: [s, d])
                        .stroke(.white.opacity(0.6), lineWidth: 6)
                    MapPolyline(coordinates: [s, d])
                        .stroke(Color(red: 1.0, green: 0.45, blue: 0.0), lineWidth: 3)
                }

                // Radius circle around source
                if let coord = sourceCoord, showSOTA || showPOTA {
                    MapCircle(center: coord, radius: Double(overlayRadius) * 1000)
                        .foregroundStyle(.blue.opacity(0.05))
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                }

                // Maidenhead grid
                ForEach(0..<grid.vLines.count, id: \.self) { i in
                    MapPolyline(coordinates: grid.vLines[i])
                        .stroke(.gray.opacity(0.3), lineWidth: 0.5)
                }
                ForEach(0..<grid.hLines.count, id: \.self) { i in
                    MapPolyline(coordinates: grid.hLines[i])
                        .stroke(.gray.opacity(0.3), lineWidth: 0.5)
                }
                ForEach(grid.labels) { lbl in
                    Annotation("", coordinate: lbl.coord) {
                        Text(lbl.id)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(2)
                            .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 2))
                    }
                }

                // SOTA markers
                if showSOTA {
                    ForEach(sotaResults.prefix(150)) { s in
                        Annotation(s.code,
                                   coordinate: CLLocationCoordinate2D(latitude: s.lat, longitude: s.lng),
                                   anchor: .bottom) {
                            VStack(spacing: 2) {
                                Image(systemName: "triangle.fill")
                                    .font(.system(size: 14)).foregroundStyle(.orange)
                                Text(s.code)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 3).padding(.vertical, 1)
                                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }
                }

                // POTA markers
                if showPOTA {
                    ForEach(potaResults.prefix(150)) { p in
                        Annotation(p.reference,
                                   coordinate: CLLocationCoordinate2D(latitude: p.lat, longitude: p.lng),
                                   anchor: .bottom) {
                            VStack(spacing: 2) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 14)).foregroundStyle(.green)
                                Text(p.reference)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 3).padding(.vertical, 1)
                                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .overlay {
                MapClickCapture(isCapturing: captureTarget != nil) { pt in
                    guard let coord = proxy.convert(pt, from: .local) else { return }
                    // Full 8-char extended square (~500 m resolution)
                    let loc = Maidenhead.fromLatLon(lat: coord.latitude, lon: coord.longitude)
                    if captureTarget == 0      { locSource = loc }
                    else if captureTarget == 1 { locDest   = loc }
                    captureTarget = nil
                }
            }
            .overlay(alignment: .top) {
                if captureTarget != nil {
                    Text(captureTarget == 0 ? "📍 Klicken um Quelle zu setzen — Esc oder 📍 zum Abbrechen"
                                            : "📍 Klicken um Ziel zu setzen — Esc oder 📍 zum Abbrechen")
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 8)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: captureTarget)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Compact coordinate / distance strip — sits between control bar and map
    private var koordinatenPanel: some View {
        HStack(spacing: 0) {
            // Source info
            if let ll = sourceLL {
                HStack(spacing: 10) {
                    Label(locSource, systemImage: "mappin.circle.fill")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "%.5f° %@  %.5f° %@",
                                    abs(ll.lat), ll.lat >= 0 ? "N" : "S",
                                    abs(ll.lon), ll.lon >= 0 ? "E" : "W"))
                            .font(.system(size: 10, design: .monospaced))
                        Text("\(dms(ll.lat, isLat: true))   \(dms(ll.lon, isLat: false))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
            }

            // Distance / bearing — center
            if let a = sourceLL, let b = destLL {
                let dist = Maidenhead.distKm(a, b)
                let bear = Maidenhead.bearing(a, b)
                let rev  = (bear + 180).truncatingRemainder(dividingBy: 360)
                Divider().frame(height: 36)
                VStack(spacing: 1) {
                    HStack(spacing: 6) {
                        Text(String(format: "%.0f km", dist))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.blue)
                        Text(String(format: "▶ %.0f° %@", bear, compassDir(bear)))
                            .font(.system(size: 10, design: .monospaced))
                        Text(String(format: "◀ %.0f° %@", rev, compassDir(rev)))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                Divider().frame(height: 36)
            }

            // Dest info
            if let ll = destLL {
                HStack(spacing: 10) {
                    Label(locDest, systemImage: "mappin.circle.fill")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "%.5f° %@  %.5f° %@",
                                    abs(ll.lat), ll.lat >= 0 ? "N" : "S",
                                    abs(ll.lon), ll.lon >= 0 ? "E" : "W"))
                            .font(.system(size: 10, design: .monospaced))
                        Text("\(dms(ll.lat, isLat: true))   \(dms(ll.lon, isLat: false))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    // SOTA / POTA result rows (no outer ScrollView — lives inside bottomPanel)
    private var resultsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
                if showSOTA && !sotaResults.isEmpty {
                    HStack {
                        Image(systemName: "triangle.fill").foregroundStyle(.orange).font(.caption)
                        Text("SOTA – \(sotaResults.count) Gipfel im \(overlayRadius)-km-Radius")
                            .font(.caption.bold())
                        Spacer()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.08))

                    ForEach(Array(sotaResults.prefix(50).enumerated()), id: \.element.id) { idx, s in
                        HStack(spacing: 6) {
                            Text(String(format: "%.1f km", s.distKm))
                                .font(.system(size: 10, design: .monospaced))
                                .frame(width: 54).foregroundStyle(.secondary)
                            Text(s.code)
                                .font(.system(size: 10, design: .monospaced).bold())
                                .frame(width: 80, alignment: .leading).foregroundStyle(.orange)
                            Text(s.name)
                                .font(.system(size: 10)).lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(s.altM) m")
                                .font(.system(size: 10, design: .monospaced))
                                .frame(width: 55).foregroundStyle(.secondary)
                            Text("\(s.points) Pkt")
                                .font(.system(size: 10).bold()).frame(width: 48)
                                .foregroundStyle(.orange)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(idx % 2 == 0 ? Color.clear : Color.secondary.opacity(0.04))
                    }
                }

                if showPOTA && !potaResults.isEmpty {
                    HStack {
                        Image(systemName: "leaf.fill").foregroundStyle(.green).font(.caption)
                        Text("POTA – \(potaResults.count) Parks im \(overlayRadius)-km-Radius")
                            .font(.caption.bold())
                        Spacer()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.green.opacity(0.08))

                    ForEach(Array(potaResults.prefix(50).enumerated()), id: \.element.id) { idx, p in
                        HStack(spacing: 6) {
                            Text(String(format: "%.1f km", p.distKm))
                                .font(.system(size: 10, design: .monospaced))
                                .frame(width: 54).foregroundStyle(.secondary)
                            Text(p.reference)
                                .font(.system(size: 10, design: .monospaced).bold())
                                .frame(width: 90, alignment: .leading).foregroundStyle(.green)
                            Text(p.name)
                                .font(.system(size: 10)).lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(idx % 2 == 0 ? Color.clear : Color.secondary.opacity(0.04))
                    }
                }
        }
    }

    private func loadOverlays() async {
        guard let ll = sourceLL else { overlayError = "Ungültiger Quell-Locator"; return }
        overlayBusy = true; overlayError = nil
        await withTaskGroup(of: Void.self) { group in
            if showSOTA {
                group.addTask {
                    do {
                        let res = try await QTHService.shared.nearbySOTA(
                            lat: ll.lat, lng: ll.lon, radiusKm: overlayRadius)
                        await MainActor.run { sotaResults = res }
                    } catch {
                        await MainActor.run { overlayError = "SOTA: \(error.localizedDescription)" }
                    }
                }
            }
            if showPOTA {
                group.addTask {
                    do {
                        let res = try await QTHService.shared.nearbyPOTA(
                            lat: ll.lat, lng: ll.lon, radiusKm: overlayRadius)
                        await MainActor.run { potaResults = res }
                    } catch {
                        await MainActor.run { overlayError = "POTA: \(error.localizedDescription)" }
                    }
                }
            }
        }
        if !showSOTA { sotaResults = [] }
        if !showPOTA { potaResults = [] }
        overlayBusy = false
        // Zoom to radius after loading
        if let coord = sourceCoord {
            withAnimation {
                mapCamera = .region(MKCoordinateRegion(
                    center: coord, span: zoomSpanForRadius(overlayRadius)))
            }
        }
    }

    // MARK: Tab 1 – Elevation Profile

    private var elevationTab: some View {
        let aValid = Maidenhead.toLatLon(locSource) != nil
        let bValid = Maidenhead.toLatLon(locDest)   != nil
        return VStack(alignment: .leading, spacing: 20) {

            // — Controls card —
            SectionCard(title: "Geländeprofil – Quelle → Ziel") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        // Source / Dest
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Quelle").font(.caption2).foregroundStyle(.blue)
                                Text(locSource.isEmpty ? "–" : locSource)
                                    .font(.callout.monospaced().bold())
                            }
                            Image(systemName: "arrow.right").foregroundStyle(.secondary).font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ziel").font(.caption2).foregroundStyle(.red)
                                Text(locDest.isEmpty ? "–" : locDest)
                                    .font(.callout.monospaced().bold())
                            }
                            Text("(Karte)").font(.caption2).foregroundStyle(.secondary)
                        }

                        Divider().frame(height: 28)

                        // Fresnel toggle
                        Toggle(isOn: $showFresnel) {
                            Label("Fresnel-Zonen", systemImage: "waveform.path")
                                .font(.caption)
                        }
                        .toggleStyle(.checkbox)
                        .help("Fresnel-Zonen & LOS mit Erdkrümmung anzeigen")

                        // Band selector (visible only when Fresnel active)
                        if showFresnel {
                            ForEach(bandDefs, id: \.name) { band in
                                Toggle(isOn: Binding(
                                    get: { activeBands.contains(band.name) },
                                    set: { if $0 { activeBands.insert(band.name) }
                                           else  { activeBands.remove(band.name) } }
                                )) {
                                    HStack(spacing: 3) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(band.color)
                                            .frame(width: 10, height: 10)
                                        Text(band.name).font(.caption)
                                    }
                                }
                                .toggleStyle(.checkbox)
                            }
                        }

                        Spacer()

                        // Load button
                        Button {
                            Task { await computeElevation() }
                        } label: {
                            if elevBusy {
                                HStack(spacing: 4) { ProgressView().controlSize(.mini); Text("Lädt...") }
                            } else {
                                Label("Profil laden", systemImage: "chart.line.uptrend.xyaxis")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(elevBusy || !aValid || !bValid)
                    }

                    if let err = elevError {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red).font(.callout)
                    }
                    Text("Höhendaten: open-elevation.com (NASA SRTM, global 90 m Raster)")
                        .font(.caption2).foregroundStyle(.secondary)
                    if showFresnel {
                        Text("Gelbe Linie = Sichtverbindung mit Erdkrümmungskorrektur (k = 4/3). Farbige Bänder = 1. Fresnel-Zone.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            // — Profile card (only when data is loaded) —
            if !elevPoints.isEmpty {
                SectionCard(title: "Geländeprofil – \(String(format: "%.1f km", elevDist))") {
                    VStack(alignment: .leading, spacing: 10) {

                        // Chart
                        let elevs  = elevPoints.map { $0.elevM }
                        let losMax = losPoints.map { $0.losM }.max() ?? 0
                        let frMax  = showFresnel
                            ? bandDefs.filter { activeBands.contains($0.name) }
                                .flatMap { b in fresnelSeries(freqMHz: b.freqMHz, tag: b.name).map { $0.upper } }
                                .max() ?? losMax
                            : losMax
                        let yMin = (elevs.min() ?? 0) - 20
                        let yMax = max(elevs.max() ?? 0, frMax) + 50

                        Chart {
                            // 1. Terrain (drawn first as base)
                            ForEach(elevPoints) { pt in
                                AreaMark(x: .value("Distanz (km)", pt.distKm),
                                         y: .value("Höhe (m)", pt.elevM))
                                    .foregroundStyle(LinearGradient(
                                        colors: [.brown.opacity(0.75), .brown.opacity(0.15)],
                                        startPoint: .top, endPoint: .bottom))
                                LineMark(x: .value("Distanz (km)", pt.distKm),
                                         y: .value("Höhe (m)", pt.elevM))
                                    .foregroundStyle(.brown)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                    .interpolationMethod(.catmullRom)
                            }
                            // 2. LOS line
                            ForEach(losPoints) { pt in
                                LineMark(x: .value("d", pt.distKm),
                                         y: .value("h", pt.losM),
                                         series: .value("S", "LOS"))
                                    .foregroundStyle(.yellow.opacity(0.9))
                                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 3]))
                            }
                            // 3. Fresnel zone boundary lines per band (upper + lower)
                            if showFresnel {
                                ForEach(bandDefs.filter { activeBands.contains($0.name) }, id: \.name) { band in
                                    let series = fresnelSeries(freqMHz: band.freqMHz, tag: band.name)
                                    ForEach(series) { pt in
                                        LineMark(
                                            x: .value("d", pt.distKm),
                                            y: .value("h", min(pt.upper, yMax)),
                                            series: .value("S", "\(band.name)_hi")
                                        )
                                        .foregroundStyle(band.color)
                                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                                    }
                                    ForEach(series) { pt in
                                        LineMark(
                                            x: .value("d", pt.distKm),
                                            y: .value("h", max(pt.lower, yMin)),
                                            series: .value("S", "\(band.name)_lo")
                                        )
                                        .foregroundStyle(band.color)
                                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                                    }
                                }
                            }
                        }
                        .chartXAxisLabel("Distanz (km)")
                        .chartYAxisLabel("Höhe (m ü. NN)")
                        .chartYScale(domain: yMin...yMax)
                        .chartLegend(.hidden)
                        .clipped()
                        .frame(height: 260)

                        // Legend
                        HStack(spacing: 14) {
                            HStack(spacing: 5) {
                                // LOS: dashed yellow line
                                Canvas { ctx, sz in
                                    var p = Path(); p.move(to: .init(x: 0, y: sz.height/2))
                                    p.addLine(to: .init(x: sz.width, y: sz.height/2))
                                    ctx.stroke(p, with: .color(.yellow.opacity(0.9)),
                                               style: StrokeStyle(lineWidth: 2, dash: [5,3]))
                                }
                                .frame(width: 24, height: 8)
                                Text("LOS (k=4/3)").font(.caption2).foregroundStyle(.secondary)
                            }
                            if showFresnel {
                                ForEach(bandDefs.filter { activeBands.contains($0.name) }, id: \.name) { band in
                                    HStack(spacing: 4) {
                                        Canvas { ctx, sz in
                                            let y = sz.height/2
                                            var top = Path(); top.move(to: .init(x: 0, y: y-3))
                                            top.addLine(to: .init(x: sz.width, y: y-3))
                                            var bot = Path(); bot.move(to: .init(x: 0, y: y+3))
                                            bot.addLine(to: .init(x: sz.width, y: y+3))
                                            ctx.stroke(top, with: .color(band.color), lineWidth: 1.5)
                                            ctx.stroke(bot, with: .color(band.color), lineWidth: 1.5)
                                        }
                                        .frame(width: 24, height: 10)
                                        Text("1.FZ \(band.name)").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                        }

                        // Stats: 2×2 grid (no overflow)
                        let eMin = elevs.min() ?? 0
                        let eMax = elevs.max() ?? 0
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            StatTile(value: String(format: "%.0f m", eMin),        label: "Min. Höhe")
                            StatTile(value: String(format: "%.0f m", eMax),        label: "Max. Höhe")
                            StatTile(value: String(format: "%.0f m", eMax - eMin), label: "Differenz")
                            StatTile(value: String(format: "%.1f km", elevDist),   label: "Distanz")
                        }
                    }
                }
            }
        }
    }

    private func computeElevation() async {
        guard let llA = Maidenhead.toLatLon(locSource),
              let llB = Maidenhead.toLatLon(locDest) else {
            elevError = "Ungültiger Locator"; return
        }
        elevBusy = true; elevError = nil
        do {
            let pts = try await QTHService.shared.elevationProfile(
                lat1: llA.lat, lng1: llA.lon, lat2: llB.lat, lng2: llB.lon)
            let dist = Maidenhead.distKm(llA, llB)
            elevPoints = pts
            elevDist   = dist
            // LOS with earth-curvature correction (k=4/3 standard atmosphere)
            let h0 = pts.first?.elevM ?? 0
            let hN = pts.last?.elevM  ?? 0
            let D  = dist * 1000          // km → m
            losPoints = pts.enumerated().map { i, pt in
                let d = pt.distKm * 1000
                let linear = D > 0 ? h0 + (hN - h0) * (d / D) : h0
                let bulge  = D > 0 ? d * (D - d) / (2 * 6_371_000 * 1.333) : 0
                return LOSPt(id: i, distKm: pt.distKm, losM: linear + bulge)
            }
        } catch {
            elevError = "Fehler: \(error.localizedDescription). Bitte nochmals versuchen."
        }
        elevBusy = false
    }

    private func fresnelSeries(freqMHz: Double, tag: String) -> [FresnelPt] {
        guard !losPoints.isEmpty, elevDist > 0 else { return [] }
        let D = elevDist * 1000
        let lambda = 3e8 / (freqMHz * 1e6)
        return losPoints.map { pt in
            let d = pt.distKm * 1000, d2 = D - d
            let r = (d > 0 && d2 > 0) ? sqrt(lambda * d * d2 / (d + d2)) : 0.0
            return FresnelPt(id: "\(tag)_\(pt.id)", distKm: pt.distKm,
                             upper: pt.losM + r, lower: pt.losM - r)
        }
    }

    // MARK: Helpers

    private func dms(_ deg: Double, isLat: Bool) -> String {
        let d = Int(abs(deg)), m = Int((abs(deg) - Double(d)) * 60)
        let s = ((abs(deg) - Double(d)) * 60 - Double(m)) * 60
        let dir = isLat ? (deg >= 0 ? "N" : "S") : (deg >= 0 ? "E" : "W")
        return String(format: "%d° %d' %.1f\" %@", d, m, s, dir)
    }

    private func compassDir(_ deg: Double) -> String {
        let dirs = ["N","NNO","NO","ONO","O","OSO","SO","SSO","S","SSW","SW","WSW","W","WNW","NW","NNW"]
        return dirs[Int((deg + 11.25) / 22.5) % 16]
    }
}
