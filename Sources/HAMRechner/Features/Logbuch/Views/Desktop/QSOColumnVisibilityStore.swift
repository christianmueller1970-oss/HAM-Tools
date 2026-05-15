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
    // `defaultVisible` spiegelt die `.defaultVisibility(.hidden)` Markierungen
    // in QSOTableView wider, damit das Toggle-Binding den korrekten Ausgangs-
    // zustand zeigt, wenn der User noch nichts manuell umgeschaltet hat.
    struct ColumnInfo: Identifiable {
        let id: String           // customizationID
        let label: String        // Deutscher Anzeigename
        let canHide: Bool        // false = immer sichtbar (z.B. Aktionen)
        let defaultVisible: Bool // initialer Sichtbarkeits-Zustand
    }

    static let columns: [ColumnInfo] = [
        ColumnInfo(id: "rowNumber",       label: "#",                  canHide: true,  defaultVisible: true),
        ColumnInfo(id: "timeOn",          label: "Time On (UTC)",      canHide: true,  defaultVisible: true),
        ColumnInfo(id: "call",            label: "Call Sign",          canHide: true,  defaultVisible: true),
        ColumnInfo(id: "name",            label: "Name",               canHide: true,  defaultVisible: false),
        ColumnInfo(id: "countryLocator",  label: "Country / Locator",  canHide: true,  defaultVisible: false),
        ColumnInfo(id: "freqBand",        label: "Freq / Band",        canHide: true,  defaultVisible: true),
        ColumnInfo(id: "mode",            label: "Mode",               canHide: true,  defaultVisible: true),
        ColumnInfo(id: "power",           label: "Power",              canHide: true,  defaultVisible: true),
        ColumnInfo(id: "rst",             label: "RST S/R",            canHide: true,  defaultVisible: true),
        ColumnInfo(id: "qslStatus",       label: "QSL-Status",         canHide: true,  defaultVisible: false),
        ColumnInfo(id: "state",           label: "State",              canHide: true,  defaultVisible: false),
        ColumnInfo(id: "theirPark",       label: "Their Park",         canHide: true,  defaultVisible: false),
        ColumnInfo(id: "continent",       label: "Kontinent",          canHide: true,  defaultVisible: false),
        ColumnInfo(id: "cqZone",          label: "CQ-Zone",            canHide: true,  defaultVisible: false),
        ColumnInfo(id: "antenna",         label: "Antenne",            canHide: true,  defaultVisible: false),
        ColumnInfo(id: "operator",        label: "Operator",           canHide: true,  defaultVisible: false),
        ColumnInfo(id: "comment",         label: "Bemerkung",          canHide: true,  defaultVisible: false),
        ColumnInfo(id: "contestSerial",   label: "S-Nr",               canHide: true,  defaultVisible: false),
        ColumnInfo(id: "contestExchSent", label: "Sent Exch",          canHide: true,  defaultVisible: false),
        ColumnInfo(id: "contestExchRecv", label: "Recv Exch",          canHide: true,  defaultVisible: false),
        ColumnInfo(id: "qth",             label: "QTH",                canHide: true,  defaultVisible: false),
        ColumnInfo(id: "ituZone",         label: "ITU-Zone",           canHide: true,  defaultVisible: false),
        ColumnInfo(id: "distance",        label: "Distanz (km)",       canHide: true,  defaultVisible: false),
        ColumnInfo(id: "bearing",         label: "Peilung (°)",        canHide: true,  defaultVisible: false),
        ColumnInfo(id: "stationCall",     label: "Station-Call",       canHide: true,  defaultVisible: false),
        ColumnInfo(id: "qslVia",          label: "QSL Via",            canHide: true,  defaultVisible: false),
        ColumnInfo(id: "myPota",          label: "My POTA",            canHide: true,  defaultVisible: false),
        ColumnInfo(id: "mySota",          label: "My SOTA",            canHide: true,  defaultVisible: false),
        ColumnInfo(id: "myWwff",          label: "My WWFF",            canHide: true,  defaultVisible: false),
        ColumnInfo(id: "myBota",          label: "My BOTA",            canHide: true,  defaultVisible: false),
        ColumnInfo(id: "qrzStatus",       label: "QRZ",                canHide: true,  defaultVisible: true),
        ColumnInfo(id: "actions",         label: "Aktionen",           canHide: false, defaultVisible: true),
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
    /// als Toggle-Source verwendet. Bei fehlendem Customization-Eintrag wird
    /// der `defaultVisible`-Wert aus ColumnInfo verwendet, damit das Menü die
    /// real angezeigte Sichtbarkeit korrekt widerspiegelt.
    func visibilityBinding(for id: String) -> Binding<Bool> {
        let columnDefault = Self.columns.first(where: { $0.id == id })?.defaultVisible ?? true
        return Binding(
            get: { [weak self] in
                guard let self else { return columnDefault }
                switch self.customization[visibility: id] {
                case .visible: return true
                case .hidden:  return false
                default:       return columnDefault
                }
            },
            set: { [weak self] newValue in
                guard let self else { return }
                self.customization[visibility: id] = newValue ? .visible : .hidden
            }
        )
    }
}
