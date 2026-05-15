import SwiftUI

// Zentraler Store für die QSO-Tabellen-Spalten-Konfiguration (Sichtbarkeit
// + Reihenfolge + Breite). Hält pro Log-Typ eine eigene Persistierung,
// damit Contest, POTA und Standard-Logs unterschiedliche Default-Spalten
// haben können. Wird in LogbuchView als @StateObject erzeugt und an
// QSOTableView (für die Tabelle) und LogContextBar (für das Spalten-
// Auswahl-Menü) gereicht.
@MainActor
final class QSOColumnVisibilityStore: ObservableObject {

    // Reihenfolge entspricht dem Vorkommen in QSOTableView — und damit
    // der Standard-Reihenfolge im Spalten-Menü, bis der User reordnert.
    struct ColumnInfo: Identifiable {
        let id: String      // customizationID
        let label: String   // Deutscher Anzeigename
        let canHide: Bool   // false = immer sichtbar (z.B. Aktionen)
    }

    static let columns: [ColumnInfo] = [
        ColumnInfo(id: "rowNumber",       label: "#",                  canHide: true),
        ColumnInfo(id: "timeOn",          label: "Time On (UTC)",      canHide: true),
        ColumnInfo(id: "call",            label: "Call Sign",          canHide: true),
        ColumnInfo(id: "name",            label: "Name",               canHide: true),
        ColumnInfo(id: "countryLocator",  label: "Country / Locator",  canHide: true),
        ColumnInfo(id: "freqBand",        label: "Freq / Band",        canHide: true),
        ColumnInfo(id: "mode",            label: "Mode",               canHide: true),
        ColumnInfo(id: "power",           label: "Power",              canHide: true),
        ColumnInfo(id: "rst",             label: "RST S/R",            canHide: true),
        ColumnInfo(id: "qslStatus",       label: "QSL-Status",         canHide: true),
        ColumnInfo(id: "state",           label: "State",              canHide: true),
        ColumnInfo(id: "theirPark",       label: "Their Park",         canHide: true),
        ColumnInfo(id: "continent",       label: "Kontinent",          canHide: true),
        ColumnInfo(id: "cqZone",          label: "CQ-Zone",            canHide: true),
        ColumnInfo(id: "antenna",         label: "Antenne",            canHide: true),
        ColumnInfo(id: "operator",        label: "Operator",           canHide: true),
        ColumnInfo(id: "comment",         label: "Bemerkung",          canHide: true),
        ColumnInfo(id: "contestSerial",   label: "S-Nr",               canHide: true),
        ColumnInfo(id: "contestExchSent", label: "Sent Exch",          canHide: true),
        ColumnInfo(id: "contestExchRecv", label: "Recv Exch",          canHide: true),
        ColumnInfo(id: "qth",             label: "QTH",                canHide: true),
        ColumnInfo(id: "ituZone",         label: "ITU-Zone",           canHide: true),
        ColumnInfo(id: "distance",        label: "Distanz (km)",       canHide: true),
        ColumnInfo(id: "bearing",         label: "Peilung (°)",        canHide: true),
        ColumnInfo(id: "stationCall",     label: "Station-Call",       canHide: true),
        ColumnInfo(id: "qslVia",          label: "QSL Via",            canHide: true),
        ColumnInfo(id: "myPota",          label: "My POTA",            canHide: true),
        ColumnInfo(id: "mySota",          label: "My SOTA",            canHide: true),
        ColumnInfo(id: "myWwff",          label: "My WWFF",            canHide: true),
        ColumnInfo(id: "myBota",          label: "My BOTA",            canHide: true),
        ColumnInfo(id: "qrzStatus",       label: "QRZ",                canHide: true),
        ColumnInfo(id: "actions",         label: "Aktionen",           canHide: false),
    ]

    @Published var customization = TableColumnCustomization<QSO>()

    private var currentSuffix: String = ""

    private func storageKey(for logType: LogType?) -> String {
        let suffix: String
        switch logType {
        case .contest: suffix = ".contest"
        case .pota:    suffix = ".pota"
        default:       suffix = ""
        }
        return "logbook.qsoTable.columnCustomization\(suffix).v2"
    }

    /// Lädt die Customization für den gegebenen Log-Typ aus UserDefaults
    /// oder erzeugt sinnvolle Defaults (POTA-Spalten ausblenden im Standard,
    /// Contest-Felder einblenden im Contest, …).
    func loadCustomization(for logType: LogType?) {
        let key = storageKey(for: logType)
        currentSuffix = key
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(TableColumnCustomization<QSO>.self, from: data) {
            customization = decoded
            return
        }
        customization = defaults(for: logType)
    }

    func saveCustomization() {
        guard !currentSuffix.isEmpty,
              let data = try? JSONEncoder().encode(customization) else { return }
        UserDefaults.standard.set(data, forKey: currentSuffix)
    }

    func resetToDefaults(for logType: LogType?) {
        customization = defaults(for: logType)
    }

    /// Default-Konfiguration pro Log-Typ — was beim ersten Öffnen sichtbar
    /// ist, wenn der User noch keine Anpassung gespeichert hat.
    private func defaults(for logType: LogType?) -> TableColumnCustomization<QSO> {
        var c = TableColumnCustomization<QSO>()
        switch logType {
        case .contest:
            c[visibility: "theirPark"]       = .hidden
            c[visibility: "state"]           = .hidden
            c[visibility: "qrzStatus"]       = .hidden
            c[visibility: "contestSerial"]   = .visible
            c[visibility: "contestExchSent"] = .visible
            c[visibility: "contestExchRecv"] = .visible
        case .pota:
            c[visibility: "theirPark"]       = .visible
            c[visibility: "state"]           = .visible
        default:
            c[visibility: "theirPark"]       = .hidden
            c[visibility: "state"]           = .hidden
        }
        return c
    }

    /// Toggle-Binding für eine einzelne Spalten-ID — wird im Spalten-Menü
    /// als Toggle-Source verwendet.
    func visibilityBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { [weak self] in
                guard let self else { return true }
                return self.customization[visibility: id] != .hidden
            },
            set: { [weak self] newValue in
                guard let self else { return }
                self.customization[visibility: id] = newValue ? .visible : .hidden
            }
        )
    }
}
