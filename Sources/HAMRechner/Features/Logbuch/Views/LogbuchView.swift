import SwiftUI

// Logbuch-Vollbild im MacLoggerDX-Stil:
//
//  ┌────────── Top-Bar: Zurück | Active Log ▾ | UTC | Callsign ─────────┐
//  ├─Radio────┬──────────QSO-Eingabe-Panel (3 Spalten)──────────────────┤
//  │ CAT      │  Call/Time/Freq/Mode/RST/Locator/Award-Refs/…           │
//  │ VFO/Mode │                                                         │
//  │ Keyer    ├──── Action-Bar: LookUp · TimeOn · Log QSO · …  ─────────┤
//  ├──────────┴──── Tab-Bar: Log · Map · Bands · …          DXCC 0/0 ───┤
//  │ Filter: Call · Band · Mode · Country                               │
//  │ ─────────────────── QSO-Tabelle ────────────────────                │
//  │ Time On │ Call │ Name │ Country │ Freq │ Band │ Mode │ RST │ QSL S │
//  └────────────────────────────────────────────────────────────────────┘
struct LogbuchView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var settings: LogbookSettings
    @EnvironmentObject var logBridge: LogEntryBridge
    @EnvironmentObject var clusterVM: DXClusterViewModel

    let onBackToHome: () -> Void

    @State private var showNewLogSheet: Bool = false
    @State private var showLogsPopover: Bool = false

    // Alle Tab-State-Werte sind persistent über AppStorage — Wunsch des
    // Users: »Alle Einstellungen die man irgendwo im LOG macht sollten
    // persistent sein nach dem nächsten laden.«
    @AppStorage("logbook.bottomTab")      private var bottomTab: LogbookBottomTab = .log
    @AppStorage("logbook.heatmapMinutes") private var heatmapMinutes: Int         = 60

    // Filter-State für den Log-Tab (persistent)
    @AppStorage("logbook.filter.call")    private var filterCall: String    = ""
    @AppStorage("logbook.filter.band")    private var filterBand: String    = ""
    @AppStorage("logbook.filter.mode")    private var filterMode: String    = ""
    @AppStorage("logbook.filter.country") private var filterCountry: String = ""

    // Awards-Tab Sub-State (persistent)
    @AppStorage("logbook.awards.subTab")           private var awardsSubTab: AwardsTab.AwardsSubTab = .dxcc
    @AppStorage("logbook.awards.onlyUnconfirmed") private var awardsOnlyUnconfirmed: Bool          = false

    // Map/Bands Filter (persistent)
    @AppStorage("logbook.spotsModeFilter")  private var spotsModeFilter: String = "Alle"
    @AppStorage("logbook.spotsRadiusKm")    private var spotsRadiusKm:   Int    = 0

    // Auswahl in der QSO-Tabelle (für Bulk-QRZ-Lookup) — bleibt während
    // der Session bestehen, persistiert aber nicht (Selektionen sind
    // typischerweise transient).
    @State private var selectedQSOs: Set<UUID> = []

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        VStack(spacing: 0) {
            LogbookTopBar(
                onBackToHome: onBackToHome,
                onShowLogs: { showLogsPopover.toggle() }
            )
            .popover(isPresented: $showLogsPopover, arrowEdge: .bottom) {
                LogsPopover(showNewLogSheet: $showNewLogSheet,
                            onClose: { showLogsPopover = false })
                    .environmentObject(themeManager)
                    .environmentObject(manager)
                    .environmentObject(settings)
            }

            Divider().background(theme.separator)

            HSplitView {
                // Hauptbereich: Entry-Sektion oben + Tabs/Tabelle unten
                VStack(spacing: 0) {
                    entrySection
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                        .background(theme.bgApp)

                    LogbookTabBar(selected: $bottomTab)
                    tabContextBar

                    bottomContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(theme.bgApp)
                }
                .frame(minWidth: 600, maxWidth: .infinity, maxHeight: .infinity)

                // Rechte Seite: Propagation/Solar/Band Activity Panel
                // (Wiederverwendet aus dem DX-Cluster-Modul, identische Daten.)
                PropagationPanelView(
                    propagation: clusterVM.propagation,
                    bandMatrix:  clusterVM.bandMatrix(minutes: heatmapMinutes),
                    theme:       theme,
                    callsign:    clusterVM.myCallsign,
                    connected:   clusterVM.clusterStatus == .connected,
                    spots:       clusterVM.spots,
                    onSend:      { freq, call, comment in
                        clusterVM.sendSpot(freq: freq, call: call, comment: comment)
                    }
                )
                .frame(minWidth: 240, idealWidth: 300, maxWidth: 360, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.bgApp)
        .navigationTitle("Logbuch")
        .onAppear {
            if manager.currentLogID == nil, let first = manager.logs.first {
                manager.openLog(first)
            }
        }
        .onChange(of: logBridge.navigationRequest) {
            // Spot wurde im DXClusters-Tab geklickt während wir schon im
            // Logbuch sind → zurück zum Log-Tab damit der Draft sichtbar
            // ist und »Log QSO« einen Klick weg ist.
            if logBridge.navigationRequest != nil {
                bottomTab = .log
            }
        }
        .sheet(isPresented: $showNewLogSheet) {
            NewLogSheet { newLog in
                manager.createLog(newLog)
            }
            .environmentObject(themeManager)
            .environmentObject(settings)
        }
    }

    // MARK: - Entry-Sektion (Radio links, QSO-Eingabe rechts)

    private var entrySection: some View {
        HStack(alignment: .top, spacing: 8) {
            RadioControlPanel()
                .frame(width: 195)
            QSOEntryPanel()
                .frame(maxWidth: .infinity)
        }
        .frame(height: 440)
    }

    // MARK: - Bottom-Content (je nach gewähltem Tab)

    // Tab-Context-Bar: zeigt je nach aktivem Tab andere Filter/Aktionen,
    // mit konsistenter Höhe und Styling (TabContextBarShell).
    @ViewBuilder
    private var tabContextBar: some View {
        switch bottomTab {
        case .log:
            LogContextBar(
                filterCall: $filterCall,
                filterBand: $filterBand,
                filterMode: $filterMode,
                filterCountry: $filterCountry,
                selectedQSOs: $selectedQSOs,
                totalCount: manager.currentQSOs.count,
                filteredCount: filteredLogCount
            )
        case .dxClusters:
            ClusterContextBar()
        case .awards:
            awardsContextBar
        case .map, .bands:
            mapBandsContextBar
        case .history:
            historyContextBar
        default:
            TabContextBarShell {
                Text("Keine Filter für »\(bottomTab.rawValue)«")
                    .font(.caption)
                    .foregroundStyle(theme.textDim)
            }
        }
    }

    // History-Tab: Filter über Mode/Band/Zeitraum + Linien-Toggle
    @AppStorage("logbook.history.lines") private var historyShowLines: Bool = true
    @AppStorage("logbook.history.mode")  private var historyModeFilter   = "Alle"
    @AppStorage("logbook.history.band")  private var historyBandFilter   = "Alle"
    @AppStorage("logbook.history.days")  private var historyDaysFilter   = 365

    private var historyContextBar: some View {
        TabContextBarShell {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(theme.accentBlue)

                Toggle(isOn: $historyShowLines) {
                    Text("Linien zeigen").font(.caption)
                }
                .toggleStyle(.checkbox)
                .controlSize(.mini)

                Divider().frame(height: 16).background(theme.separator)

                HStack(spacing: 3) {
                    Text("Mode").font(.caption2).foregroundStyle(theme.textDim)
                    Picker("", selection: $historyModeFilter) {
                        ForEach(historyModeOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .controlSize(.mini)
                    .frame(width: 90)
                }
                HStack(spacing: 3) {
                    Text("Band").font(.caption2).foregroundStyle(theme.textDim)
                    Picker("", selection: $historyBandFilter) {
                        ForEach(historyBandOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .controlSize(.mini)
                    .frame(width: 80)
                }
                HStack(spacing: 3) {
                    Text("Zeitraum").font(.caption2).foregroundStyle(theme.textDim)
                    Picker("", selection: $historyDaysFilter) {
                        Text("30 Tage").tag(30)
                        Text("3 Monate").tag(90)
                        Text("1 Jahr").tag(365)
                        Text("Alle").tag(0)
                    }
                    .labelsHidden()
                    .controlSize(.mini)
                    .frame(width: 90)
                }

                if historyModeFilter != "Alle" || historyBandFilter != "Alle"
                    || historyDaysFilter != 365 {
                    Button {
                        historyModeFilter = "Alle"
                        historyBandFilter = "Alle"
                        historyDaysFilter = 365
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Zurücksetzen")
                        }
                        .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.accentBlue)
                }

                Spacer()

                Text(historyStatusText)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var historyModeOptions: [String] {
        ["Alle"] + Array(Set(manager.currentQSOs.map(\.mode))).filter { !$0.isEmpty }.sorted()
    }
    private var historyBandOptions: [String] {
        ["Alle"] + Array(Set(manager.currentQSOs.map(\.band))).filter { !$0.isEmpty }.sorted()
    }
    private var historyStatusText: String {
        let total = manager.currentQSOs.count
        let withLocator = manager.currentQSOs.filter { ($0.locator ?? "").count >= 4 }.count
        return withLocator < total
            ? "\(withLocator) / \(total) QSOs mit Locator"
            : "\(total) QSOs"
    }

    private var mapBandsContextBar: some View {
        TabContextBarShell {
            HStack(spacing: 10) {
                Image(systemName: bottomTab == .map ? "globe.europe.africa" : "chart.bar.xaxis")
                    .font(.caption)
                    .foregroundStyle(theme.accentBlue)

                // Mode-Filter (gilt für Map UND Bands)
                HStack(spacing: 3) {
                    Text("Mode")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                    Picker("Mode", selection: $spotsModeFilter) {
                        ForEach(spotsModeOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .controlSize(.mini)
                    .frame(width: 90)
                }

                // Radius vom QTH (0 = unbegrenzt)
                HStack(spacing: 3) {
                    Text("Radius QTH")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                    Picker("Radius", selection: $spotsRadiusKm) {
                        Text("unbegrenzt").tag(0)
                        Text("500 km").tag(500)
                        Text("1000 km").tag(1000)
                        Text("2000 km").tag(2000)
                        Text("5000 km").tag(5000)
                        Text("10000 km").tag(10000)
                    }
                    .labelsHidden()
                    .controlSize(.mini)
                    .frame(width: 100)
                }

                if spotsModeFilter != "Alle" || spotsRadiusKm > 0 {
                    Button {
                        spotsModeFilter = "Alle"
                        spotsRadiusKm = 0
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Zurücksetzen")
                        }
                        .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.accentBlue)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(clusterVM.clusterStatus == .connected
                              ? theme.accentGreen : theme.textDim)
                        .frame(width: 7, height: 7)
                    Text(clusterVM.clusterStatus.rawValue)
                        .font(.caption2.bold())
                        .foregroundStyle(theme.textSecondary)
                    Text("·")
                        .foregroundStyle(theme.textDim)
                    Text("\(spotsForMapOrBands.count) / \(clusterVM.filteredSpots.count) Spots")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
    }

    // Mode-Optionen für den Spot-Filter — aus den aktuellen Spots
    private var spotsModeOptions: [String] {
        ["Alle"] + Array(Set(clusterVM.filteredSpots.compactMap {
            $0.mode.isEmpty ? nil : $0.mode
        })).sorted()
    }

    // Spots gefiltert auf Mode + Radius vom eigenen QTH
    @AppStorage("qthLocator") private var qthLocator = "JN47PN"

    private var spotsForMapOrBands: [DXSpot] {
        let base = clusterVM.filteredSpots
        let modeFiltered = spotsModeFilter == "Alle"
            ? base
            : base.filter { $0.mode == spotsModeFilter }

        guard spotsRadiusKm > 0,
              let qth = locatorToLatLon(qthLocator) else {
            return modeFiltered
        }
        return modeFiltered.filter { spot in
            // Wenn Spot keine Geo-Daten hat, lieber drin lassen statt aussortieren
            guard spot.lat != 0 || spot.lon != 0 else { return true }
            let d = haversineKm(lat1: qth.lat, lon1: qth.lon,
                                lat2: spot.lat, lon2: spot.lon)
            return d <= Double(spotsRadiusKm)
        }
    }

    private var awardsContextBar: some View {
        let a = manager.awards
        return TabContextBarShell {
            HStack(spacing: 8) {
                // Sub-Tab-Switcher
                ForEach(AwardsTab.AwardsSubTab.allCases) { sub in
                    Button {
                        awardsSubTab = sub
                    } label: {
                        Text("\(sub.rawValue) (\(count(for: sub)))")
                            .font(.caption.weight(awardsSubTab == sub ? .bold : .regular))
                            .foregroundStyle(awardsSubTab == sub ? .white : theme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(awardsSubTab == sub ? theme.accentBlue : theme.bgCard2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(awardsSubTab == sub ? theme.accentBlue : theme.separator,
                                            lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }

                Divider().frame(height: 16).background(theme.separator)

                if awardsSubTab == .dxcc {
                    Toggle(isOn: $awardsOnlyUnconfirmed) {
                        Text("Nur unbestätigte")
                            .font(.caption)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.mini)
                }

                Spacer()

                Text(summaryText(for: awardsSubTab, awards: a))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func count(for sub: AwardsTab.AwardsSubTab) -> Int {
        switch sub {
        case .dxcc: return manager.awards.dxccWorked
        case .waz:  return manager.awards.wazWorked
        case .was:  return manager.awards.wasWorked
        }
    }

    private func summaryText(for sub: AwardsTab.AwardsSubTab,
                             awards a: AwardCounts) -> String {
        switch sub {
        case .dxcc:
            return "\(a.dxccWorked) Länder gearbeitet · \(a.dxccConfirmed) bestätigt"
        case .waz:
            return "\(a.wazWorked) / 40 Zonen gearbeitet · \(a.wazConfirmed) bestätigt"
        case .was:
            return "\(a.wasWorked) / 50 States gearbeitet · \(a.wasConfirmed) bestätigt"
        }
    }

    private var filteredLogCount: Int {
        manager.currentQSOs.filter { qso in
            (filterCall.isEmpty    || qso.call.localizedCaseInsensitiveContains(filterCall)) &&
            (filterBand.isEmpty    || qso.band.localizedCaseInsensitiveContains(filterBand)) &&
            (filterMode.isEmpty    || qso.mode.localizedCaseInsensitiveContains(filterMode)) &&
            (filterCountry.isEmpty || (qso.country ?? "").localizedCaseInsensitiveContains(filterCountry))
        }.count
    }

    @ViewBuilder
    private var bottomContent: some View {
        switch bottomTab {
        case .log:
            QSOTableView(filterCall: $filterCall,
                         filterBand: $filterBand,
                         filterMode: $filterMode,
                         filterCountry: $filterCountry,
                         selectedQSOs: $selectedQSOs)
        case .dxClusters:
            LogbookClusterTab()
        case .awards:
            AwardsTab(subTab: $awardsSubTab,
                      onlyUnconfirmed: $awardsOnlyUnconfirmed)
        case .map:
            WeltkarteView(spots: spotsForMapOrBands, theme: theme)
        case .bands:
            BandmapView(spots: spotsForMapOrBands, theme: theme)
        case .history:
            HistoryTab()
        default:
            comingSoon(bottomTab)
        }
    }

    private func comingSoon(_ tab: LogbookBottomTab) -> some View {
        VStack(spacing: 10) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 44))
                .foregroundStyle(theme.textDim)
            Text("\(tab.rawValue) — kommt in einer späteren Phase")
                .font(.callout)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
