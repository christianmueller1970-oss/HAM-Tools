import SwiftUI

// Logbuch-Vollbild im Desktop-Logger-Stil:
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
    @EnvironmentObject var radioState: RadioState

    // Hilfs-Property: true wenn das aktuelle Log eine POTA-Session ist.
    // Steuert das Routing des DX-Cluster-Tabs auf den POTA-Spots-Feed.
    private var currentLogIsPOTA: Bool {
        guard let id = manager.currentLogID,
              let log = manager.logs.first(where: { $0.id == id }) else { return false }
        return log.type == .pota
    }

    // Hilfs-Property: true wenn das aktuelle Log ein Contest ist. Etappe 1
    // braucht das noch nicht (Contest nutzt regulären DX-Cluster wie Standard-Logs),
    // ab Etappe 2 schaltet damit der Stats-Panel + Run/S&P-Toggle frei.
    private var currentLogIsContest: Bool {
        guard let id = manager.currentLogID,
              let log = manager.logs.first(where: { $0.id == id }) else { return false }
        return log.type == .contest
    }

    // Hilfs-Property: true wenn das aktuelle Log eine SOTA-Session ist.
    // Schaltet den DX-Cluster-Tab auf den SOTA-Spots-Feed.
    private var currentLogIsSOTA: Bool {
        guard let id = manager.currentLogID,
              let log = manager.logs.first(where: { $0.id == id }) else { return false }
        return log.type == .sota
    }

    // Hilfs-Property: true wenn das aktuelle Log eine WWFF-Session ist.
    // Schaltet den DX-Cluster-Tab auf den (gefilterten) WWFF-Spots-View.
    private var currentLogIsWWFF: Bool {
        guard let id = manager.currentLogID,
              let log = manager.logs.first(where: { $0.id == id }) else { return false }
        return log.type == .wwff
    }

    // Hilfs-Property: true wenn das aktuelle Log eine BOTA-Session ist.
    private var currentLogIsBOTA: Bool {
        guard let id = manager.currentLogID,
              let log = manager.logs.first(where: { $0.id == id }) else { return false }
        return log.type == .bota
    }

    // Typ des aktiven Logs (oder nil wenn kein Log offen ist).
    // Wird vom QSO-Spalten-Store genutzt, um pro Log-Typ eine eigene
    // Spalten-Konfiguration zu laden.
    private var currentLogType: LogType? {
        guard let id = manager.currentLogID,
              let log = manager.logs.first(where: { $0.id == id }) else { return nil }
        return log.type
    }

    let onBackToHome: () -> Void

    @State private var showNewLogSheet: Bool = false
    @State private var showNewPOTASheet: Bool = false
    @State private var showNewContestSheet: Bool = false
    @State private var showNewSOTASheet: Bool = false
    @State private var showNewWWFFSheet: Bool = false
    @State private var showNewBOTASheet: Bool = false
    @State private var showLogsPopover: Bool = false

    // Alle Tab-State-Werte sind persistent über AppStorage — Wunsch des
    // Users: »Alle Einstellungen die man irgendwo im LOG macht sollten
    // persistent sein nach dem nächsten laden.«
    @AppStorage("logbook.bottomTab")      private var bottomTab: LogbookBottomTab = .dxClusters
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

    // Zentraler Store für die QSO-Tabellen-Spalten — wird von QSOTableView
    // (Tabelle selbst) und LogContextBar (Spalten-Menü) gemeinsam genutzt.
    @StateObject private var qsoColumnStore = QSOColumnVisibilityStore()

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

                // Rechte Seite: Contest-Modus zeigt das Live-Stats-Panel,
                // sonst das gewohnte Propagation/Solar/Band-Activity-Panel.
                if currentLogIsContest {
                    ContestStatsPanel()
                        .frame(minWidth: 230, idealWidth: 260, maxWidth: 340, maxHeight: .infinity)
                } else {
                    PropagationPanelView(
                        propagation: clusterVM.propagation,
                        bandMatrix:  clusterVM.bandMatrix(minutes: heatmapMinutes),
                        theme:       theme,
                        callsign:    clusterVM.myCallsign,
                        connected:   clusterVM.clusterStatus == .connected,
                        spots:       clusterVM.spots,
                        onSend:      { freq, call, comment in
                            clusterVM.sendSpot(freq: freq, call: call, comment: comment)
                        },
                        prefillCall:    logBridge.draftCallLive,
                        prefillFreqMHz: radioState.frequencyMHz
                    )
                    .frame(minWidth: 220, idealWidth: 260, maxWidth: 340, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.bgApp)
        .navigationTitle("Logbuch")
        .onAppear {
            if manager.currentLogID == nil, let first = manager.logs.first {
                manager.openLog(first)
            }
            qsoColumnStore.loadCustomization(for: currentLogType)
        }
        .onChange(of: manager.currentLogID) { _, _ in
            // Beim Log-Wechsel die für den Log-Typ passende Spalten-
            // Konfiguration laden (Standard/POTA/Contest haben eigene Keys).
            qsoColumnStore.loadCustomization(for: currentLogType)
        }
        .onChange(of: qsoColumnStore.customization) { _, _ in
            qsoColumnStore.saveCustomization()
        }
        // Hinweis: Tab-Wechsel beim Spot-Klick wurde absichtlich entfernt —
        // der User möchte im DXClusters-Sub-Tab bleiben und weiter Spots
        // beobachten, während der Draft sich im Hintergrund ins QSO-Form
        // füllt. Wechsel zum Log-Tab macht der User manuell, wenn er bereit
        // ist zu loggen. Der Draft selbst wird über navigationRequest →
        // QSOEntryPanel.consumeBridge() weiterhin sauber übertragen.
        .onChange(of: currentLogIsPOTA) { _, isPOTA in
            // Awards-Sub-Tab folgt automatisch dem Log-Typ beim Wechsel.
            // User-manuelle Auswahl bleibt erhalten solange im selben Log;
            // erst ein Typ-Wechsel setzt die Default-Sub-Tab.
            if isPOTA { awardsSubTab = .pota }
            else if !currentLogIsSOTA && !currentLogIsWWFF { awardsSubTab = .dxcc }
        }
        .onChange(of: currentLogIsSOTA) { _, isSOTA in
            if isSOTA { awardsSubTab = .sota }
            else if !currentLogIsPOTA && !currentLogIsWWFF { awardsSubTab = .dxcc }
        }
        .onChange(of: currentLogIsWWFF) { _, isWWFF in
            if isWWFF { awardsSubTab = .wwff }
            else if !currentLogIsPOTA && !currentLogIsSOTA && !currentLogIsBOTA { awardsSubTab = .dxcc }
        }
        .onChange(of: currentLogIsBOTA) { _, isBOTA in
            if isBOTA { awardsSubTab = .bota }
            else if !currentLogIsPOTA && !currentLogIsSOTA && !currentLogIsWWFF { awardsSubTab = .dxcc }
        }
        .sheet(isPresented: $showNewLogSheet) {
            NewLogSheet(onCreate: { newLog in
                manager.createLog(newLog)
            }, onSelectPOTA: {
                // POTA-Wizard kommt nach dismiss des generischen Sheets.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showNewPOTASheet = true
                }
            }, onSelectContest: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showNewContestSheet = true
                }
            }, onSelectSOTA: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showNewSOTASheet = true
                }
            }, onSelectWWFF: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showNewWWFFSheet = true
                }
            }, onSelectBOTA: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showNewBOTASheet = true
                }
            })
            .environmentObject(themeManager)
            .environmentObject(settings)
        }
        .sheet(isPresented: $showNewPOTASheet) {
            NewPOTALogSheet()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showNewContestSheet) {
            NewContestLogSheet()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showNewSOTASheet) {
            NewSOTALogSheet()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showNewWWFFSheet) {
            NewWWFFLogSheet()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showNewBOTASheet) {
            NewBOTALogSheet()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showNewMemorySheet) {
            NewMemorySheet(existing: nil)
                .environmentObject(themeManager)
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
                filteredCount: filteredLogCount,
                columnStore: qsoColumnStore,
                currentLogType: currentLogType
            )
        case .dxClusters:
            if currentLogIsPOTA {
                TabContextBarShell {
                    Text("POTA-Spots — Live von pota.app, kein DX-Cluster")
                        .font(.caption)
                        .foregroundStyle(theme.textDim)
                }
            } else if currentLogIsSOTA {
                TabContextBarShell {
                    Text("SOTA-Spots — Live von sotadata.org.uk, kein DX-Cluster")
                        .font(.caption)
                        .foregroundStyle(theme.textDim)
                }
            } else if currentLogIsWWFF {
                TabContextBarShell {
                    Text("WWFF-Spots — gefiltert aus dem DX-Cluster (Refs im Kommentar)")
                        .font(.caption)
                        .foregroundStyle(theme.textDim)
                }
            } else if currentLogIsBOTA {
                TabContextBarShell {
                    Text("BOTA-Spots — gefiltert aus dem DX-Cluster, gegen lokale Bunker-DB gematcht")
                        .font(.caption)
                        .foregroundStyle(theme.textDim)
                }
            } else {
                ClusterContextBar()
            }
        case .awards:
            awardsContextBar
        case .map, .bands:
            mapBandsContextBar
        case .history:
            historyContextBar
        case .memories:
            memoriesContextBar
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

    // Memories-Tab
    @State private var memoriesSearch: String = ""
    @State private var memoriesUpcomingOnly: Bool = false
    @State private var showNewMemorySheet: Bool = false

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

    private var memoriesContextBar: some View {
        TabContextBarShell {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(theme.accentYellow)
                Text("Schnellzugriff")
                    .font(.caption)
                    .foregroundStyle(theme.textPrimary)
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                    TextField("Suche", text: $memoriesSearch)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .frame(width: 140)
                        .background(theme.bgCard2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(theme.separator.opacity(0.5), lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Toggle(isOn: $memoriesUpcomingOnly) {
                    Text("Nur anstehende Skeds")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)
                .controlSize(.mini)
                Spacer()
                Button {
                    showNewMemorySheet = true
                } label: {
                    Label("Neue Memory", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(theme.accentGreen)
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
                    Text(clusterVM.poolStatusLabel)
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
    @AppStorage("qthLocator") private var qthLocator = ""

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

    // Awards-Sub-Tabs im Programm-Modus: User-Wunsch ist "auf POTA-Awards
    // zugeschnitten" — also bei aktivem POTA-Log nur den POTA-Sub-Tab
    // zeigen, analog für SOTA + WWFF. Im Standard-Log und Contest bleiben
    // alle Sub-Tabs (DXCC/WAZ/WAS/POTA/SOTA/WWFF) sichtbar.
    private var visibleAwardsSubTabs: [AwardsTab.AwardsSubTab] {
        if currentLogIsPOTA { return [.pota] }
        if currentLogIsSOTA { return [.sota] }
        if currentLogIsWWFF { return [.wwff] }
        if currentLogIsBOTA { return [.bota] }
        // Standard-Log: alle Awards außer Multi-Op-Stats.
        // Contest: zusätzlich .ops für die Pro-Operator-Aufschlüsselung.
        return AwardsTab.AwardsSubTab.allCases.filter { sub in
            if sub == .ops { return currentLogIsContest }
            return true
        }
    }

    private var awardsContextBar: some View {
        let a = manager.awards
        return TabContextBarShell {
            HStack(spacing: 8) {
                // Sub-Tab-Switcher — im Programm-Modus auf das jeweilige
                // Programm zugeschnitten.
                ForEach(visibleAwardsSubTabs) { sub in
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
        case .pota: return manager.awards.potaActivatorParks + manager.awards.potaHunterParks
        case .sota: return manager.awards.sotaActivatorSummits + manager.awards.sotaChaserSummits
        case .wwff: return manager.awards.wwffActivatorRefs + manager.awards.wwffHunterRefs
        case .bota: return manager.awards.botaActivatorRefs + manager.awards.botaHunterRefs
        case .ops:  return uniqueOpsInCurrentLog
        }
    }

    // Anzahl unique Operator-Calls im aktiven Log (incl. "kein OP"-Bucket).
    // Nur für die OP-Pill in der Awards-Bar.
    private var uniqueOpsInCurrentLog: Int {
        var seen: Set<String> = []
        for q in manager.currentQSOs {
            let key = (q.operatorCall?.trimmingCharacters(in: .whitespaces).uppercased())
                .flatMap { $0.isEmpty ? nil : $0 }
                ?? "—"
            seen.insert(key)
        }
        return seen.count
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
        case .pota:
            return "\(a.potaActivatorParks) Activator-Parks · \(a.potaHunterParks) Hunter-Parks · \(a.potaP2P) P2P"
        case .sota:
            return "\(a.sotaActivatorSummits) Activator-Summits · \(a.sotaChaserSummits) Chaser-Summits · \(a.sotaS2S) S2S"
        case .wwff:
            return "\(a.wwffActivatorRefs) Activator-Refs · \(a.wwffHunterRefs) Hunter-Refs · \(a.wwffR2R) R2R · \(a.wwffPrograms) Programme"
        case .bota:
            return "\(a.botaActivatorRefs) Activator-Bunker · \(a.botaHunterRefs) Hunter-Bunker · \(a.botaB2B) B2B · \(a.botaPrograms) Programme"
        case .ops:
            return "\(uniqueOpsInCurrentLog) Operatoren · \(manager.currentQSOs.count) QSOs gesamt"
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
            QSOTableView(columnStore: qsoColumnStore,
                         filterCall: $filterCall,
                         filterBand: $filterBand,
                         filterMode: $filterMode,
                         filterCountry: $filterCountry,
                         selectedQSOs: $selectedQSOs)
        case .dxClusters:
            if currentLogIsPOTA {
                PotaSpotsView { spot in
                    logBridge.pendingPotaSpot = spot
                }
            } else if currentLogIsSOTA {
                SotaSpotsView { spot in
                    logBridge.pendingSotaSpot = spot
                }
            } else if currentLogIsWWFF {
                WWFFSpotsView { spot in
                    logBridge.pendingWwffSpot = spot
                }
            } else if currentLogIsBOTA {
                BOTASpotsView { spot in
                    logBridge.pendingBotaSpot = spot
                }
            } else {
                LogbookClusterTab()
            }
        case .awards:
            AwardsTab(subTab: $awardsSubTab,
                      onlyUnconfirmed: $awardsOnlyUnconfirmed)
        case .map:
            WeltkarteView(spots: spotsForMapOrBands, theme: theme)
        case .bands:
            BandmapView(spots: spotsForMapOrBands, theme: theme)
        case .history:
            HistoryTab()
        case .memories:
            MemoriesTab(searchText: $memoriesSearch,
                        showOnlyUpcomingSkeds: $memoriesUpcomingOnly)
        case .qsl:
            QSLTab()
        case .stats:
            StatsDashboard()
        case .potaMap:
            POTAMapTab()
        case .sotaMap:
            SOTAMapTab()
        case .wwffMap:
            WWFFMapTab()
        case .botaMap:
            BOTAMapTab()
        case .contestMap:
            ContestMapTab()
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
