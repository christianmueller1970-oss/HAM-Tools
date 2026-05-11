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
    @State private var bottomTab: LogbookBottomTab = .log
    @State private var heatmapMinutes: Int = 60

    // Filter-State für den Log-Tab (lebt hier oben damit die ContextBar
    // ihn zwischen Tab-Bar und Tabelle bedienen kann).
    @State private var filterCall: String = ""
    @State private var filterBand: String = ""
    @State private var filterMode: String = ""
    @State private var filterCountry: String = ""

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
            NewLogSheet { newLog, customDir in
                manager.createLog(newLog, in: customDir)
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
        .frame(height: 380)
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
                totalCount: manager.currentQSOs.count,
                filteredCount: filteredLogCount
            )
        case .dxClusters:
            ClusterContextBar()
        default:
            TabContextBarShell {
                Text("Keine Filter für »\(bottomTab.rawValue)«")
                    .font(.caption)
                    .foregroundStyle(theme.textDim)
            }
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
                         filterCountry: $filterCountry)
        case .dxClusters:
            LogbookClusterTab()
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
