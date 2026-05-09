import SwiftUI
import MapKit
import Charts

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
            lon += Double(av-65)*(2.0/24.0) + (1.0/24.0)
            lat += Double(bv-65)*(1.0/24.0) + (0.5/24.0)
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
        let s5 = Int(la/(1.0/24.0))
        let L = Array("ABCDEFGHIJKLMNOPQRSTUVWX")
        return "\(L[f0])\(L[f1])\(c2)\(c3)\(L[s4].lowercased())\(L[s5].lowercased())"
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
    @State private var locSource  = ""
    @State private var locDest    = "IO51"
    @State private var clickMode  = 0          // 0 = Quelle setzen, 1 = Ziel setzen
    @State private var mapCamera: MapCameraPosition = .automatic

    // — Overlays —
    @State private var showSOTA      = false
    @State private var showPOTA      = false
    @State private var overlayRadius = 20
    @State private var sotaResults:  [SOTASummit] = []
    @State private var potaResults:  [POTAPark]   = []
    @State private var overlayBusy   = false
    @State private var overlayError: String?

    // — Converter (Tab 1) —
    @State private var convModus = 0
    @State private var locText   = "JN47"
    @State private var latText   = "47.5"
    @State private var lonText   = "8.5"
    @State private var loc1Text  = ""
    @State private var loc2Text  = "IO51"

    // — Elevation (Tab 2) —
    @State private var elevPoints: [ElevPoint] = []
    @State private var elevBusy   = false
    @State private var elevError: String?
    @State private var elevDist   = 0.0

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
                    VStack(alignment: .leading, spacing: 20) { converterTab }
                        .padding(24)
                }
            case 2:
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
            loc1Text  = homeLocator
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
            tabBtn("Karte & Locator",  icon: "map",                        idx: 0)
            tabBtn("Konverter",        icon: "arrow.left.arrow.right",      idx: 1)
            tabBtn("Höhenprofil",      icon: "chart.line.uptrend.xyaxis",   idx: 2)
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

    @ViewBuilder
    private var karteTab: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()
            let hasResults = (showSOTA && !sotaResults.isEmpty) || (showPOTA && !potaResults.isEmpty)
            if hasResults {
                VSplitView {
                    interactiveMap.frame(minHeight: 260)
                    resultsPanel.frame(minHeight: 80, idealHeight: 200, maxHeight: 260)
                }
            } else {
                interactiveMap
            }
        }
    }

    // Control bar
    private var controlBar: some View {
        HStack(spacing: 8) {
            // Click-mode picker
            Picker("", selection: $clickMode) {
                Label("Quelle", systemImage: "mappin").tag(0)
                Label("Ziel",   systemImage: "mappin.circle").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            .help("Bestimmt, was per Kartenklick gesetzt wird")

            Divider().frame(height: 28)

            // Source field
            VStack(alignment: .leading, spacing: 1) {
                Text("Quelle").font(.caption2).foregroundStyle(.blue)
                TextField("JN47PN", text: $locSource)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout.monospaced())
                    .frame(width: 90)
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

            // Dest field
            VStack(alignment: .leading, spacing: 1) {
                Text("Ziel").font(.caption2).foregroundStyle(.red)
                TextField("IO51", text: $locDest)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout.monospaced())
                    .frame(width: 90)
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

                // Line source → dest
                if let s = sourceCoord, let d = destCoord {
                    MapPolyline(coordinates: [s, d])
                        .stroke(.purple.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
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
                            VStack(spacing: 1) {
                                Image(systemName: "triangle.fill")
                                    .font(.system(size: 10)).foregroundStyle(.orange)
                                Text(s.code)
                                    .font(.system(size: 7, design: .monospaced))
                                    .foregroundStyle(.orange)
                                    .padding(1)
                                    .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 2))
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
                            VStack(spacing: 1) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 10)).foregroundStyle(.green)
                                Text(p.reference)
                                    .font(.system(size: 7, design: .monospaced))
                                    .foregroundStyle(.green)
                                    .padding(1)
                                    .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 2))
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onTapGesture { screenPt in
                guard let coord = proxy.convert(screenPt, from: .local) else { return }
                let loc = String(Maidenhead.fromLatLon(lat: coord.latitude, lon: coord.longitude).prefix(6))
                if clickMode == 0 { locSource = loc }
                else              { locDest   = loc }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Compact results panel (below map)
    private var resultsPanel: some View {
        ScrollView {
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
        .background(.bar)
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

    // MARK: Tab 1 – Converter

    private var converterTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(title: "Konvertierung") {
                Picker("", selection: $convModus) {
                    Text("Locator → Koordinaten").tag(0)
                    Text("Koordinaten → Locator").tag(1)
                }
                .pickerStyle(.segmented)
            }
            if convModus == 0 { locToCoordSection } else { coordToLocSection }
            distanzSection
        }
    }

    private var locToCoordSection: some View {
        let res = Maidenhead.toLatLon(locText)
        return SectionCard(title: "Locator → Koordinaten") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maidenhead-Locator").font(.caption).foregroundStyle(.secondary)
                    TextField("z.B. JN47QM", text: $locText)
                        .textFieldStyle(.roundedBorder).font(.title3.monospaced()).frame(maxWidth: 200)
                    Text("4 oder 6 Zeichen").font(.caption2).foregroundStyle(.secondary)
                }
                Divider()
                if let r = res {
                    ResultRow(label: "Breitengrad",
                              value: String(format: "%.5f°  %@", abs(r.lat), r.lat >= 0 ? "N" : "S"), highlight: true)
                    ResultRow(label: "Längengrad",
                              value: String(format: "%.5f°  %@", abs(r.lon), r.lon >= 0 ? "E" : "W"), highlight: true)
                    ResultRow(label: "DMS Lat", value: dms(r.lat, isLat: true))
                    ResultRow(label: "DMS Lon", value: dms(r.lon, isLat: false))
                    ResultRow(label: "6-stelliger Locator", value: Maidenhead.fromLatLon(lat: r.lat, lon: r.lon))
                } else if !locText.isEmpty {
                    Text("Ungültiger Locator").foregroundStyle(.red)
                }
            }
        }
    }

    private var coordToLocSection: some View {
        let lat = Double(latText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let lon = Double(lonText.replacingOccurrences(of: ",", with: ".")) ?? 0
        return SectionCard(title: "Koordinaten → Locator") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Breitengrad (N+, S−)").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("47.5", text: $latText).textFieldStyle(.roundedBorder)
                            Text("°").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Längengrad (E+, W−)").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("8.5", text: $lonText).textFieldStyle(.roundedBorder)
                            Text("°").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Divider()
                ResultRow(label: "Locator (6-stlg.)", value: Maidenhead.fromLatLon(lat: lat, lon: lon), highlight: true)
                ResultRow(label: "Locator (4-stlg.)", value: String(Maidenhead.fromLatLon(lat: lat, lon: lon).prefix(4)))
            }
        }
    }

    private var distanzSection: some View {
        let a = Maidenhead.toLatLon(loc1Text)
        let b = Maidenhead.toLatLon(loc2Text)
        return SectionCard(title: "Distanz & Richtung") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Locator 1 (Quelle)").font(.caption).foregroundStyle(.secondary)
                        TextField("JN47PN", text: $loc1Text)
                            .textFieldStyle(.roundedBorder).font(.body.monospaced())
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Locator 2 (Ziel)").font(.caption).foregroundStyle(.secondary)
                        TextField("IO51", text: $loc2Text)
                            .textFieldStyle(.roundedBorder).font(.body.monospaced())
                    }
                }
                Divider()
                if let pa = a, let pb = b {
                    let dist = Maidenhead.distKm(pa, pb)
                    let bear = Maidenhead.bearing(pa, pb)
                    ResultRow(label: "Distanz", value: String(format: "%.1f km", dist), highlight: true)
                    ResultRow(label: "Richtung (Bearing)",
                              value: String(format: "%.1f°  %@", bear, compassDir(bear)))
                    ResultRow(label: "Gegenrichtung",
                              value: String(format: "%.1f°  %@",
                                           (bear+180).truncatingRemainder(dividingBy: 360),
                                           compassDir((bear+180).truncatingRemainder(dividingBy: 360))))
                } else {
                    Text("Bitte beide Locatoren eingeben").foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Tab 2 – Elevation Profile

    private var elevationTab: some View {
        let aValid = Maidenhead.toLatLon(locSource) != nil
        let bValid = Maidenhead.toLatLon(locDest)   != nil
        return VStack(alignment: .leading, spacing: 20) {
            SectionCard(title: "Geländeprofil – Quelle → Ziel") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Quelle").font(.caption).foregroundStyle(.blue)
                            Text(locSource.isEmpty ? "–" : locSource)
                                .font(.body.monospaced().bold())
                        }
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ziel").font(.caption).foregroundStyle(.red)
                            Text(locDest.isEmpty ? "–" : locDest)
                                .font(.body.monospaced().bold())
                        }
                        Text("(auf Karte auswählbar)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            Task { await computeElevation() }
                        } label: {
                            if elevBusy {
                                HStack(spacing: 4) { ProgressView().controlSize(.small); Text("Berechne...") }
                            } else {
                                Label("Profil laden", systemImage: "chart.line.uptrend.xyaxis")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(elevBusy || !aValid || !bValid)
                    }
                    if let err = elevError {
                        Label(err, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.callout)
                    }
                    Text("Höhendaten: open-elevation.com (NASA SRTM, global 90 m Raster)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            if !elevPoints.isEmpty {
                SectionCard(title: "Geländeprofil – \(String(format: "%.1f km", elevDist)) Distanz") {
                    VStack(alignment: .leading, spacing: 12) {
                        Chart(elevPoints) { pt in
                            AreaMark(x: .value("Distanz (km)", pt.distKm),
                                     y: .value("Höhe (m)", pt.elevM))
                                .foregroundStyle(LinearGradient(
                                    colors: [.brown.opacity(0.5), .brown.opacity(0.05)],
                                    startPoint: .top, endPoint: .bottom))
                            LineMark(x: .value("Distanz (km)", pt.distKm),
                                     y: .value("Höhe (m)", pt.elevM))
                                .foregroundStyle(.brown)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                        .chartXAxisLabel("Distanz (km)")
                        .chartYAxisLabel("Höhe (m ü. NN)")
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 220)

                        let elevs = elevPoints.map { $0.elevM }
                        HStack(spacing: 8) {
                            StatTile(value: String(format: "%.0f m", elevs.min() ?? 0), label: "Min. Höhe")
                            StatTile(value: String(format: "%.0f m", elevs.max() ?? 0), label: "Max. Höhe")
                            StatTile(value: String(format: "%.0f m", (elevs.max() ?? 0) - (elevs.min() ?? 0)),
                                     label: "Differenz")
                            StatTile(value: String(format: "%.1f km", elevDist), label: "Distanz")
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
            elevPoints = pts
            elevDist   = Maidenhead.distKm(llA, llB)
        } catch {
            elevError = "Fehler: \(error.localizedDescription). Bitte nochmals versuchen."
        }
        elevBusy = false
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
