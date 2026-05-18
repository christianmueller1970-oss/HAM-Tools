import SwiftUI
import MapKit

// SOTA-Map-Tab: Grafische Live-Ansicht des AKTIVEN SOTA-Logs.
//
//   - Summit-Pin(s): die Summit-Reference(n) aus mySotaRef / mySotaRefs der
//     QSOs im aktiven Log (meist genau einer; bei Hopping mehrere).
//   - DX-Pins: jede in diesem Log erreichte Station mit Locator/Callbook-
//     Auflösung.
//   - Linien Summit → DX: zeigen welche Stationen aus welchem Summit
//     gearbeitet wurden.
//
// Strukturell parallel zu POTAMapTab. Unterschiede: Mountain-Icon, SOTA-
// Color (orange), Pin-Label mit Elevation+Punkten.
struct SOTAMapTab: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager:      LogbookManager
    @EnvironmentObject var sota:         SotaSummitService
    @EnvironmentObject var callbook:     CallbookManager

    @AppStorage("logbook.sotaMap.qsoLines") private var showQsoLines: Bool = false
    @AppStorage("logbook.sotaMap.band")     private var bandFilter         = "Alle"
    @AppStorage("map.style")                private var selectedMapStyle: MapStyleChoice = .standard

    @State private var selectedQSO: QSO? = nil
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47, longitude: 8),
            span:   MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 60)
        )
    )
    @State private var didCenterOnSummit: Bool = false

    private var theme: AppTheme { themeManager.theme }

    // MARK: - Datenaufbereitung

    private struct SummitPin: Identifiable {
        let id: String   // Summit-Reference
        let summit: Summit
        let coord: CLLocationCoordinate2D
    }

    private struct MappedQSO: Identifiable {
        let id: UUID
        let qso: QSO
        let coord: CLLocationCoordinate2D
        let summitRefs: [String]   // an welche Summits dieses QSO geht (Linien)
    }

    private func mySummits(for qso: QSO) -> [String] {
        var refs: [String] = []
        var seen: Set<String> = []
        if let r = qso.mySotaRef?.trimmingCharacters(in: .whitespaces), !r.isEmpty {
            let u = r.uppercased()
            if seen.insert(u).inserted { refs.append(u) }
        }
        if let list = qso.mySotaRefs {
            for r in list.split(separator: ",") {
                let s = r.trimmingCharacters(in: .whitespaces).uppercased()
                if !s.isEmpty, seen.insert(s).inserted { refs.append(s) }
            }
        }
        return refs
    }

    private var qsosWithSummits: [(qso: QSO, summitRefs: [String])] {
        manager.currentQSOs.compactMap { q in
            if bandFilter != "Alle", q.band != bandFilter { return nil }
            let refs = mySummits(for: q)
            return refs.isEmpty ? nil : (q, refs)
        }
    }

    private var summitPins: [SummitPin] {
        var seen: Set<String> = []
        var pins: [SummitPin] = []
        for (_, refs) in qsosWithSummits {
            for ref in refs where seen.insert(ref).inserted {
                guard let s = sota.summit(forReference: ref),
                      let lat = s.latitude, let lon = s.longitude else { continue }
                pins.append(SummitPin(id: ref, summit: s,
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
        qsosWithSummits.compactMap { item in
            guard let coord = resolveCoord(for: item.qso) else { return nil }
            return MappedQSO(id: item.qso.id, qso: item.qso,
                             coord: coord, summitRefs: item.summitRefs)
        }
    }

    private var mappedQSOs: [MappedQSO] {
        allMappedQSOs.cappedByDate(max: MapRenderLimits.maxAnnotations,
                                   dateKey: { $0.qso.datetime })
    }

    private var qsosWithoutPositionCount: Int {
        qsosWithSummits.count - allMappedQSOs.count
    }

    private var isOverflow: Bool { allMappedQSOs.count > MapRenderLimits.maxAnnotations }
    private var linesAllowed: Bool { showQsoLines && mappedQSOs.count <= MapRenderLimits.maxLines }

    private var summitCoordByRef: [String: CLLocationCoordinate2D] {
        Dictionary(uniqueKeysWithValues: summitPins.map { ($0.id, $0.coord) })
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if summitPins.isEmpty {
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
        .onAppear { centerOnFirstSummit() }
        .onChange(of: summitPins.map(\.id)) { centerOnFirstSummit(force: false) }
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

            if !summitPins.isEmpty {
                Text("\(summitPins.count) \(summitPins.count == 1 ? "Summit" : "Summits") · \(qsosWithSummits.count) QSOs")
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
            if linesAllowed {
                ForEach(mappedQSOs) { m in
                    ForEach(Array(m.summitRefs.enumerated()), id: \.offset) { _, ref in
                        if let summitCoord = summitCoordByRef[ref] {
                            MapPolyline(coordinates: [summitCoord, m.coord])
                                .stroke(theme.colorSOTA.opacity(0.55), lineWidth: 1)
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
            ForEach(summitPins) { pin in
                Annotation(pin.id, coordinate: pin.coord, anchor: .bottom) {
                    summitPinView(pin)
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

    private func summitPinView(_ pin: SummitPin) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(Circle().fill(theme.colorSOTA))
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
            }
            Text(pin.id)
                .font(.caption2.monospaced().bold())
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(theme.colorSOTA)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .help(summitHoverText(pin.summit))
    }

    private func summitHoverText(_ s: Summit) -> String {
        var parts: [String] = ["\(s.reference) — \(s.name)"]
        if let alt = s.altitudeM { parts.append("\(alt) m") }
        parts.append("\(s.points) p\(s.bonusPoints > 0 ? " (+\(s.bonusPoints) Bonus)" : "")")
        if !s.association.isEmpty { parts.append(s.association) }
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
                    if let sotaRef = qso.theirSotaRef, !sotaRef.isEmpty {
                        Text("·").foregroundStyle(theme.textDim)
                        Text(sotaRef)
                            .font(.caption.monospaced())
                            .foregroundStyle(theme.colorSOTA)
                            .help("S2S — Gegen-Summit")
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
            if qsosWithSummits.isEmpty {
                Spacer()
                Text("Keine QSOs im Filter").font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(qsosWithSummits.sorted { $0.qso.datetime > $1.qso.datetime },
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
            if let firstRef = summitPins.first?.id,
               let summit = sota.summit(forReference: firstRef) {
                HStack(spacing: 4) {
                    Text(summit.name)
                        .font(.caption2)
                        .foregroundStyle(theme.colorSOTA)
                        .lineLimit(1)
                    if let alt = summit.altitudeM {
                        Text("· \(alt) m")
                            .font(.caption2.monospaced())
                            .foregroundStyle(theme.textDim)
                    }
                    Text("· \(summit.points) p")
                        .font(.caption2.monospaced())
                        .foregroundStyle(theme.colorSOTA)
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
                        if qso.theirSotaRef?.isEmpty == false {
                            Image(systemName: "mountain.2")
                                .font(.caption2)
                                .foregroundStyle(theme.colorSOTA)
                                .help("S2S")
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
            Image(systemName: "mountain.2.circle")
                .font(.system(size: 44))
                .foregroundStyle(theme.textDim)
            Text("Keine SOTA-Aktivierung im aktiven Log")
                .font(.callout)
                .foregroundStyle(theme.textSecondary)
            Text("Lege ein SOTA-Log an oder wechsle in eines, das mySotaRef enthält.")
                .font(.caption)
                .foregroundStyle(theme.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func centerOnFirstSummit(force: Bool = true) {
        guard let first = summitPins.first else {
            didCenterOnSummit = false
            return
        }
        if !force, didCenterOnSummit { return }
        cameraPosition = .region(MKCoordinateRegion(
            center: first.coord,
            span:   MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 60)
        ))
        didCenterOnSummit = true
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
