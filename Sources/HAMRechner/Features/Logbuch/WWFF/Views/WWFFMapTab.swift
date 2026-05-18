import SwiftUI
import MapKit

// WWFF-Map-Tab: Grafische Live-Ansicht des AKTIVEN WWFF-Logs.
//
//   - Reference-Pin(s): die Ref(s) aus myWwffRef / myWwffRefs der QSOs
//     im aktiven Log (meist genau einer; bei Multi-Ref-Hopping mehrere).
//   - DX-Pins: jede in diesem Log erreichte Station mit Locator/Callbook-
//     Auflösung.
//   - Linien Ref → DX, R2R-Indikator (Reference-to-Reference) pro QSO.
//
// Strukturell parallel zu SOTAMapTab. Unterschiede: Leaf-Icon, WWFF-Color
// (pink), Pin-Label mit Country statt Höhe+Punkten.
struct WWFFMapTab: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager:      LogbookManager
    @EnvironmentObject var wwff:         WWFFRefService
    @EnvironmentObject var callbook:     CallbookManager

    @AppStorage("logbook.wwffMap.qsoLines") private var showQsoLines: Bool = false
    @AppStorage("logbook.wwffMap.band")     private var bandFilter         = "Alle"
    @AppStorage("map.style")                private var selectedMapStyle: MapStyleChoice = .standard

    @State private var selectedQSO: QSO? = nil
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47, longitude: 8),
            span:   MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 60)
        )
    )
    @State private var didCenterOnRef: Bool = false

    private var theme: AppTheme { themeManager.theme }

    // MARK: - Datenaufbereitung

    private struct RefPin: Identifiable {
        let id: String   // WWFF-Reference
        let ref: WWFFReference
        let coord: CLLocationCoordinate2D
    }

    private struct MappedQSO: Identifiable {
        let id: UUID
        let qso: QSO
        let coord: CLLocationCoordinate2D
        let refs: [String]   // an welche Refs dieses QSO geht (Linien)
    }

    private func myRefs(for qso: QSO) -> [String] {
        var refs: [String] = []
        var seen: Set<String> = []
        if let r = qso.myWwffRef?.trimmingCharacters(in: .whitespaces), !r.isEmpty {
            let u = r.uppercased()
            if seen.insert(u).inserted { refs.append(u) }
        }
        if let list = qso.myWwffRefs {
            for r in list.split(separator: ",") {
                let s = r.trimmingCharacters(in: .whitespaces).uppercased()
                if !s.isEmpty, seen.insert(s).inserted { refs.append(s) }
            }
        }
        return refs
    }

    private var qsosWithRefs: [(qso: QSO, refs: [String])] {
        manager.currentQSOs.compactMap { q in
            if bandFilter != "Alle", q.band != bandFilter { return nil }
            let refs = myRefs(for: q)
            return refs.isEmpty ? nil : (q, refs)
        }
    }

    private var refPins: [RefPin] {
        var seen: Set<String> = []
        var pins: [RefPin] = []
        for (_, refs) in qsosWithRefs {
            for ref in refs where seen.insert(ref).inserted {
                guard let r = wwff.ref(forReference: ref),
                      let lat = r.latitude, let lon = r.longitude else { continue }
                pins.append(RefPin(id: ref, ref: r,
                                   coord: CLLocationCoordinate2D(latitude: lat,
                                                                 longitude: lon)))
            }
        }
        return pins
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

    private var allMappedQSOs: [MappedQSO] {
        qsosWithRefs.compactMap { item in
            guard let coord = resolveCoord(for: item.qso) else { return nil }
            return MappedQSO(id: item.qso.id, qso: item.qso,
                             coord: coord, refs: item.refs)
        }
    }

    private var mappedQSOs: [MappedQSO] {
        allMappedQSOs.cappedByDate(max: MapRenderLimits.maxAnnotations,
                                   dateKey: { $0.qso.datetime })
    }

    private var qsosWithoutPositionCount: Int {
        qsosWithRefs.count - allMappedQSOs.count
    }

    private var isOverflow: Bool { allMappedQSOs.count > MapRenderLimits.maxAnnotations }
    private var linesAllowed: Bool { showQsoLines && mappedQSOs.count <= MapRenderLimits.maxLines }

    private var refCoordByRef: [String: CLLocationCoordinate2D] {
        Dictionary(uniqueKeysWithValues: refPins.map { ($0.id, $0.coord) })
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if refPins.isEmpty {
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
        .onAppear { centerOnFirstRef() }
        .onChange(of: refPins.map(\.id)) { centerOnFirstRef(force: false) }
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

            if !refPins.isEmpty {
                Text("\(refPins.count) \(refPins.count == 1 ? "Reference" : "References") · \(qsosWithRefs.count) QSOs")
                    .font(.caption.monospaced())
                    .foregroundStyle(theme.textSecondary)
                if qsosWithoutPositionCount > 0 {
                    Text("· \(qsosWithoutPositionCount) ohne Position")
                        .font(.caption.monospaced())
                        .foregroundStyle(theme.accentOrange)
                        .help("Diese QSOs haben weder Locator noch Callbook-Cache-Eintrag.")
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
            if linesAllowed {
                ForEach(mappedQSOs) { m in
                    ForEach(Array(m.refs.enumerated()), id: \.offset) { _, ref in
                        if let refCoord = refCoordByRef[ref] {
                            MapPolyline(coordinates: [refCoord, m.coord])
                                .stroke(theme.colorWWFF.opacity(0.55), lineWidth: 1)
                        }
                    }
                }
            }
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
            ForEach(refPins) { pin in
                Annotation(pin.id, coordinate: pin.coord, anchor: .bottom) {
                    refPinView(pin)
                }
            }
        }
        .appMapStyle(selectedMapStyle)
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 8) {
                if isOverflow {
                    MapOverflowBanner(totalMatched: allMappedQSOs.count,
                                      shown: mappedQSOs.count)
                }
                if let q = selectedQSO {
                    infoPopup(for: q)
                }
            }
            .padding(12)
        }
    }

    private func refPinView(_ pin: RefPin) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(Circle().fill(theme.colorWWFF))
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
            }
            Text(pin.id)
                .font(.caption2.monospaced().bold())
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(theme.colorWWFF)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .help(refHoverText(pin.ref))
    }

    private func refHoverText(_ r: WWFFReference) -> String {
        var parts: [String] = ["\(r.reference) — \(r.name)"]
        if let c = r.country, !c.isEmpty { parts.append(c) }
        if let cat = r.iucCategory, !cat.isEmpty { parts.append(cat) }
        return parts.joined(separator: " · ")
    }

    private func qsoHoverText(_ qso: QSO) -> String {
        var parts: [String] = [qso.call, qso.band, qso.mode]
        if let c = qso.country, !c.isEmpty { parts.append(c) }
        if let n = qso.name, !n.isEmpty    { parts.append(n) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Info-Popup

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
                    if let wwffRef = qso.theirWwffRef, !wwffRef.isEmpty {
                        Text("·").foregroundStyle(theme.textDim)
                        Text(wwffRef)
                            .font(.caption.monospaced())
                            .foregroundStyle(theme.colorWWFF)
                            .help("R2R — Gegen-Ref")
                    }
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

    // MARK: - Sidebar

    private var qsoSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader
            Divider()
            if qsosWithRefs.isEmpty {
                Spacer()
                Text("Keine QSOs im Filter").font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(qsosWithRefs.sorted { $0.qso.datetime > $1.qso.datetime },
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
            if let firstRef = refPins.first?.id,
               let r = wwff.ref(forReference: firstRef) {
                HStack(spacing: 4) {
                    Text(r.name)
                        .font(.caption2)
                        .foregroundStyle(theme.colorWWFF)
                        .lineLimit(1)
                    if let c = r.country, !c.isEmpty {
                        Text("· \(c)")
                            .font(.caption2)
                            .foregroundStyle(theme.textDim)
                    }
                }
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
                        if qso.theirWwffRef?.isEmpty == false {
                            Image(systemName: "leaf")
                                .font(.caption2)
                                .foregroundStyle(theme.colorWWFF)
                                .help("R2R")
                        }
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
            Image(systemName: "leaf.circle")
                .font(.system(size: 44))
                .foregroundStyle(theme.textDim)
            Text("Keine WWFF-Aktivierung im aktiven Log")
                .font(.callout)
                .foregroundStyle(theme.textSecondary)
            Text("Lege ein WWFF-Log an oder wechsle in eines, das myWwffRef enthält.")
                .font(.caption)
                .foregroundStyle(theme.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func centerOnFirstRef(force: Bool = true) {
        guard let first = refPins.first else {
            didCenterOnRef = false
            return
        }
        if !force, didCenterOnRef { return }
        cameraPosition = .region(MKCoordinateRegion(
            center: first.coord,
            span:   MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 60)
        ))
        didCenterOnRef = true
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
