import SwiftUI
import MapKit

// POTA-Map-Tab: Grafische Live-Ansicht des AKTIVEN POTA-Logs.
//
//   - Park-Pin(s): die Park-Reference(n) aus myPotaRef / myPotaRefs der QSOs
//     im aktiven Log (meist genau einer; bei Park-Hopping mehrere).
//   - DX-Pins: jede in diesem Log erreichte Station mit Locator.
//   - Linien Park → DX: zeigen welche Stationen aus welchem Park gearbeitet
//     wurden (Multi-Park-Hopping: ein QSO kann zu mehreren Parks gehören).
//
// Wenn das aktive Log kein POTA-Log ist oder keine Park-Refs enthält, wird
// ein Empty-State angezeigt mit Hinweis zur Auswahl eines POTA-Logs.
struct POTAMapTab: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager:      LogbookManager
    @EnvironmentObject var pota:         PotaParkService
    @EnvironmentObject var callbook:     CallbookManager

    @AppStorage("logbook.potaMap.qsoLines") private var showQsoLines: Bool = true
    @AppStorage("logbook.potaMap.band")     private var bandFilter         = "Alle"

    @State private var selectedQSO: QSO? = nil
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47, longitude: 8),
            span:   MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 60)
        )
    )
    @State private var didCenterOnPark: Bool = false

    private var theme: AppTheme { themeManager.theme }

    // MARK: - Datenaufbereitung

    private struct ParkPin: Identifiable {
        let id: String   // Park-Reference
        let park: Park
        let coord: CLLocationCoordinate2D
    }

    private struct MappedQSO: Identifiable {
        let id: UUID
        let qso: QSO
        let coord: CLLocationCoordinate2D
        let parkRefs: [String]   // an welche Parks dieses QSO geht (für Linien)
    }

    // Splittet myPotaRef + myPotaRefs in eine Liste eindeutiger Park-Refs.
    private func myParks(for qso: QSO) -> [String] {
        var refs: [String] = []
        var seen: Set<String> = []
        if let r = qso.myPotaRef?.trimmingCharacters(in: .whitespaces), !r.isEmpty {
            let u = r.uppercased()
            if seen.insert(u).inserted { refs.append(u) }
        }
        if let list = qso.myPotaRefs {
            for r in list.split(separator: ",") {
                let s = r.trimmingCharacters(in: .whitespaces).uppercased()
                if !s.isEmpty, seen.insert(s).inserted { refs.append(s) }
            }
        }
        return refs
    }

    // Alle QSOs im aktiven Log, die einem Park zugeordnet sind und auf der
    // Karte landen können. Band-Filter wird hier angewandt.
    private var qsosWithParks: [(qso: QSO, parkRefs: [String])] {
        manager.currentQSOs.compactMap { q in
            if bandFilter != "Alle", q.band != bandFilter { return nil }
            let refs = myParks(for: q)
            return refs.isEmpty ? nil : (q, refs)
        }
    }

    // Park-Pins: alle Parks, die in den QSOs des aktiven Logs vorkommen.
    private var parkPins: [ParkPin] {
        var seen: Set<String> = []
        var pins: [ParkPin] = []
        for (_, refs) in qsosWithParks {
            for ref in refs where seen.insert(ref).inserted {
                guard let p = pota.park(forReference: ref),
                      let lat = p.latitude, let lon = p.longitude else { continue }
                pins.append(ParkPin(id: ref, park: p,
                                    coord: CLLocationCoordinate2D(latitude: lat,
                                                                  longitude: lon)))
            }
        }
        return pins
    }

    // DX-QSOs mit auflösbarer Position — für Pins + Linien.
    // Auflösungs-Reihenfolge:
    //   1. qso.locator → Maidenhead-Mitte
    //   2. Callbook-Cache lat/lon (QRZ/HamQTH-Treffer)
    //   3. Callbook-Cache locator → Maidenhead-Mitte
    //   sonst: kein Pin (bleibt im Sidebar-Listing als "ohne Position")
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

    private var mappedQSOs: [MappedQSO] {
        qsosWithParks.compactMap { item in
            guard let coord = resolveCoord(for: item.qso) else { return nil }
            return MappedQSO(id: item.qso.id, qso: item.qso,
                             coord: coord, parkRefs: item.parkRefs)
        }
    }

    private var qsosWithoutPositionCount: Int {
        qsosWithParks.count - mappedQSOs.count
    }

    // Schnelle Lookup-Map Park-Ref → Coord (für Linien).
    private var parkCoordByRef: [String: CLLocationCoordinate2D] {
        Dictionary(uniqueKeysWithValues: parkPins.map { ($0.id, $0.coord) })
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if parkPins.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    mapContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Divider()
                    qsoSidebar
                        .frame(width: 240)
                }
            }
        }
        .background(theme.bgApp)
        .onAppear { centerOnFirstPark() }
        .onChange(of: parkPins.map(\.id)) { centerOnFirstPark(force: false) }
    }

    // MARK: - Filter-Bar

    private var filterBar: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $showQsoLines) { Text("QSO-Linien").font(.caption) }
                .toggleStyle(.checkbox)

            Divider().frame(height: 16)

            Picker("Band", selection: $bandFilter) {
                Text("Alle Bänder").tag("Alle")
                ForEach(HamBand.allCases, id: \.rawValue) { b in
                    Text(b.rawValue).tag(b.rawValue)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
            .font(.caption)

            Spacer()

            if !parkPins.isEmpty {
                Text("\(parkPins.count) \(parkPins.count == 1 ? "Park" : "Parks") · \(qsosWithParks.count) QSOs")
                    .font(.caption.monospaced())
                    .foregroundStyle(theme.textSecondary)
                if qsosWithoutPositionCount > 0 {
                    Text("· \(qsosWithoutPositionCount) ohne Position")
                        .font(.caption.monospaced())
                        .foregroundStyle(theme.accentOrange)
                        .help("Diese QSOs haben weder Locator noch Callbook-Cache-Eintrag. Tipp: in der Tabelle markieren und 'QRZ-Lookup' ausführen.")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.bgPanel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.separator).frame(height: 1)
        }
    }

    // MARK: - Map

    private var mapContent: some View {
        Map(position: $cameraPosition) {
            // Linien Park → DX-QSO
            if showQsoLines {
                ForEach(mappedQSOs) { m in
                    ForEach(Array(m.parkRefs.enumerated()), id: \.offset) { _, ref in
                        if let parkCoord = parkCoordByRef[ref] {
                            MapPolyline(coordinates: [parkCoord, m.coord])
                                .stroke(theme.colorPOTA.opacity(0.55), lineWidth: 1)
                        }
                    }
                }
            }
            // DX-QSO-Endpoints
            ForEach(mappedQSOs) { m in
                Annotation("", coordinate: m.coord, anchor: .center) {
                    Circle()
                        .fill(modeColor(m.qso.mode))
                        .stroke(.white, lineWidth: 1)
                        .frame(width: selectedQSO?.id == m.qso.id ? 14 : 9,
                               height: selectedQSO?.id == m.qso.id ? 14 : 9)
                        .contentShape(Circle().inset(by: -4))
                        .onTapGesture { selectedQSO = m.qso }
                        .help(qsoHoverText(m.qso))
                }
            }
            // Park-Pins (immer oben)
            ForEach(parkPins) { pin in
                Annotation(pin.id, coordinate: pin.coord, anchor: .bottom) {
                    parkPinView(pin)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .overlay(alignment: .bottomLeading) {
            if let q = selectedQSO {
                infoPopup(for: q).padding(12)
            }
        }
    }

    private func parkPinView(_ pin: ParkPin) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Image(systemName: "tree.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(Circle().fill(theme.colorPOTA))
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
            }
            Text(pin.id)
                .font(.caption2.monospaced().bold())
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(theme.colorPOTA)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .help("\(pin.id) — \(pin.park.name)")
    }

    // Tooltip-Text für einen DX-Pin: Call + Band + Mode + Country (falls da).
    private func qsoHoverText(_ qso: QSO) -> String {
        var parts: [String] = [qso.call, qso.band, qso.mode]
        if let c = qso.country, !c.isEmpty { parts.append(c) }
        if let n = qso.name, !n.isEmpty    { parts.append(n) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Info-Popup für ein DX-QSO

    private func infoPopup(for qso: QSO) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(qso.call)
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundStyle(theme.accentBlue)
                    Text("·").foregroundStyle(theme.textDim)
                    Text(qso.band)
                    Text("·").foregroundStyle(theme.textDim)
                    Text(qso.mode).foregroundStyle(modeColor(qso.mode))
                }
                .font(.body)
                if let name = qso.name, !name.isEmpty {
                    Text(name).font(.caption).foregroundStyle(theme.textSecondary)
                }
                HStack(spacing: 6) {
                    if let qth = qso.qth, !qth.isEmpty { Text(qth).font(.caption) }
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
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.separator, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: 360)
    }

    // MARK: - Sidebar: QSO-Liste

    private var qsoSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader
            Divider()
            if qsosWithParks.isEmpty {
                Spacer()
                Text("Keine QSOs im Filter").font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(qsosWithParks.sorted { $0.qso.datetime > $1.qso.datetime },
                                id: \.qso.id) { item in
                            sidebarRow(item.qso)
                        }
                    }
                }
            }
        }
        .background(theme.bgPanel)
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("QSOs im Log")
                .font(.caption.bold())
                .foregroundStyle(theme.textSecondary)
            if let firstRef = parkPins.first?.id,
               let park = pota.park(forReference: firstRef) {
                Text(park.name)
                    .font(.caption2)
                    .foregroundStyle(theme.colorPOTA)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sidebarRow(_ qso: QSO) -> some View {
        let isSelected = selectedQSO?.id == qso.id
        let coord      = resolveCoord(for: qso)
        return Button {
            selectedQSO = (isSelected ? nil : qso)
            if !isSelected, let c = coord {
                cameraPosition = .region(MKCoordinateRegion(
                    center: c,
                    span:   MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 60)
                ))
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(coord == nil ? theme.textDim.opacity(0.4) : modeColor(qso.mode))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(qso.call)
                            .font(.caption.monospaced().weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                        if coord == nil {
                            Image(systemName: "location.slash")
                                .font(.caption2)
                                .foregroundStyle(theme.accentOrange)
                                .help("Keine Position — Locator und Callbook-Cache leer")
                        }
                    }
                    HStack(spacing: 4) {
                        Text(qso.band)
                        Text("·").foregroundStyle(theme.textDim)
                        Text(qso.mode)
                        Text("·").foregroundStyle(theme.textDim)
                        Text(shortTime(qso.datetime))
                    }
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? theme.accentBlue.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty-State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tree.circle")
                .font(.system(size: 44))
                .foregroundStyle(theme.textDim)
            Text("Keine POTA-Aktivierung im aktiven Log")
                .font(.callout)
                .foregroundStyle(theme.textSecondary)
            Text("Lege ein POTA-Log an oder wechsle in eines, das myPotaRef enthält.")
                .font(.caption)
                .foregroundStyle(theme.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func centerOnFirstPark(force: Bool = true) {
        guard let first = parkPins.first else {
            didCenterOnPark = false
            return
        }
        if !force, didCenterOnPark { return }
        cameraPosition = .region(MKCoordinateRegion(
            center: first.coord,
            span:   MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 60)
        ))
        didCenterOnPark = true
    }

    private func formatUTC(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm 'UTC'"
        return f.string(from: date)
    }

    private func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "HH:mmZ"
        return f.string(from: date)
    }

    private func modeColor(_ mode: String) -> Color {
        switch mode.uppercased() {
        case "FT8":               return Color(hex: "#00ff88")
        case "FT4":               return Color(hex: "#00ccff")
        case "CW":                return Color(hex: "#ff6600")
        case "SSB", "USB", "LSB": return Color(hex: "#ffcc00")
        case "RTTY":              return Color(hex: "#ff44ff")
        case "PSK31","PSK63":     return Color(hex: "#44ffff")
        case "FM":                return Color(hex: "#ff8888")
        case "AM":                return Color(hex: "#ffaa44")
        default:                  return Color(hex: "#cccccc")
        }
    }
}
