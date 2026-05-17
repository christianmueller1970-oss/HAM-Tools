import SwiftUI

// DX-Cluster-Tab innerhalb des Logbuch-Moduls.
//
// Wenn das aktive Log ein Contest ist, wird die Spot-Liste zusätzlich auf
// die Cabrillo-Mode-Kategorie + die Contest-relevanten Bänder eingeschränkt
// (z.B. nur SSB-Spots auf 160/80/40/20/15/10m bei einem SSB-HF-Contest).
// Bei Standard- und POTA-Logs zeigt sie alle VM-gefilterten Spots.
struct LogbookClusterTab: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var clusterVM:    DXClusterViewModel
    @EnvironmentObject var watchList:    WatchListStore
    @EnvironmentObject var manager:      LogbookManager
    @EnvironmentObject var contests:     ContestService

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        // ATNO-Pille nur im Standard-DX-Log. Contest hat eigene Färbung
        // (dupe/mult), Outdoor-Programme haben programm-eigene Match-
        // Kriterien (POTA/SOTA/WWFF/BOTA-Ref-Match in den Spot-Tabs).
        let showATNO = (activeLog?.type ?? .standard) == .standard
        SpotListView(spots: contextFilteredSpots,
                     theme: theme,
                     watchList: watchList,
                     rowAccent: contestRowAccent,
                     showATNO: showATNO)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.bgApp)
    }

    /// Bei Contest-Log liefert die Closure pro Spot eine Farbe:
    /// dupe → rot, multiplier → grün, normal → nil (Standard-Bandfarbe).
    /// Außerhalb Contest → nil (keine Färbung).
    private var contestRowAccent: ((DXSpot) -> Color?)? {
        guard activeLog?.type == .contest else { return nil }
        let qsos = manager.currentQSOs
        let tpl  = contestTemplate
        return { spot in
            switch ContestSpotEvaluator.status(for: spot, in: qsos, template: tpl) {
            case .dupe:       return .red
            case .multiplier: return .green
            case .normal:     return nil
            }
        }
    }

    private var activeLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    private var contestTemplate: ContestTemplate? {
        guard let id = activeLog?.contestID else { return nil }
        return contests.template(forID: id)
    }

    /// Spots gefiltert nach Contest-Kontext (wenn aktiv) — sonst die
    /// volle VM-Liste.
    /// Quelle der Mode-Wahl: vom Wizard explizit gewählter `contestModeCategory`
    /// am Log; nur als Fallback der Template-Default. Sonst sieht der User im
    /// SSB-Contest weiterhin CW/Digi-Spots, weil das Template "Mixed" defaultet.
    private var contextFilteredSpots: [DXSpot] {
        guard let log = activeLog, log.type == .contest, let tpl = contestTemplate else {
            return clusterVM.filteredSpots
        }
        let modeCat = (log.contestModeCategory
                       ?? tpl.defaultCategories?.mode
                       ?? "MIXED").uppercased()
        let bandCat = (tpl.defaultCategories?.band ?? "ALL").uppercased()

        return clusterVM.filteredSpots.filter { spot in
            matchesMode(spotMode: spot.mode, contestMode: modeCat)
                && matchesBand(spotBand: spot.band, contestBand: bandCat)
        }
    }

    private func matchesMode(spotMode: String, contestMode: String) -> Bool {
        let m = spotMode.uppercased()
        switch contestMode {
        case "CW":     return m == "CW"
        case "PH":     return ["SSB", "USB", "LSB", "AM", "FM"].contains(m)
        case "RY":     return m == "RTTY"
        case "DG":     return ["FT8", "FT4", "PSK31", "PSK", "JS8"].contains(m)
        case "FM":     return m == "FM"
        case "MIXED":  return true
        default:       return true
        }
    }

    private func matchesBand(spotBand: String, contestBand: String) -> Bool {
        let b = spotBand.uppercased()
        switch contestBand {
        case "ALL":
            // Standard-HF-Contestbänder. WARC (12/17/30m) ist contestfrei.
            return ["160M", "80M", "40M", "20M", "15M", "10M"].contains(b)
        case "MIXED":
            return true
        default:
            return b == contestBand
        }
    }
}
