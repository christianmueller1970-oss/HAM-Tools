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

    let onBackToHome: () -> Void

    @State private var showNewLogSheet: Bool = false
    @State private var showLogsPopover: Bool = false
    @State private var bottomTab: LogbookBottomTab = .log

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

            entrySection
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 4)
                .background(theme.bgApp)

            LogbookTabBar(selected: $bottomTab)

            Divider().background(theme.separator)

            bottomContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.bgApp)
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
        .frame(height: 310)
    }

    // MARK: - Bottom-Content (je nach gewähltem Tab)

    @ViewBuilder
    private var bottomContent: some View {
        switch bottomTab {
        case .log:
            QSOTableView()
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
