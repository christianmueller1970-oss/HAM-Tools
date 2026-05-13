import Foundation
import SwiftUI

// Lädt die mitgelieferten Contest-Templates (Content/contests.json) zur App-Startzeit.
// Stellt Lookups, Serial-Counter-Berechnung und Auto-Fill-Resolver bereit.
// In Etappe 3 kommt ein Overlay-Folder dazu (~/Library/Application Support/HAM-Tools/contests/).
final class ContestService: ObservableObject {
    @Published private(set) var templates: [ContestTemplate] = []
    @Published private(set) var loadError: String?

    init() { load() }

    func load() {
        guard let url = Bundle.module.url(forResource: "contests", withExtension: "json") else {
            loadError = "contests.json nicht im Bundle gefunden"
            templates = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            templates = try JSONDecoder().decode([ContestTemplate].self, from: data)
            loadError = nil
        } catch {
            loadError = "Fehler beim Lesen von contests.json: \(error.localizedDescription)"
            templates = []
        }
    }

    func template(forID id: String) -> ContestTemplate? {
        templates.first { $0.id == id }
    }

    /// Bestimmt den effektiven Serial-Scope für einen Contest-Log.
    /// Reihenfolge: explizit gespeicherter Override am Log > Template-Override
    /// durch Cabrillo-Operator-Kategorie > Template-Default.
    func effectiveScope(template: ContestTemplate, log: Log) -> SerialScope {
        if let raw = log.contestSerialScope,
           let scope = SerialScope(rawValue: raw) {
            return scope
        }
        if let op = log.contestCategory,
           let mapped = template.serialScopeByOperator?[op] {
            return mapped
        }
        return template.defaultSerialScope
    }

    /// Liefert die nächste zu vergebende Serial-Nummer auf Basis bereits gespeicherter QSOs.
    /// Verwendet `max(contestSerial)+1` statt eines monotonen Zählers — so wird
    /// nach Undo / Löschen einer QSO die Nummer automatisch wiederverwendet.
    func nextSerial(qsos: [QSO], scope: SerialScope, currentBand: String?) -> Int {
        switch scope {
        case .log:
            let max = qsos.compactMap { $0.contestSerial }.max() ?? 0
            return max + 1
        case .band:
            guard let band = currentBand, !band.isEmpty else { return 1 }
            let max = qsos.filter { $0.band == band }
                .compactMap { $0.contestSerial }.max() ?? 0
            return max + 1
        }
    }

    /// Default-RST je nach Mode. 599 für CW/RTTY/Digital, 59 für SSB/FM/AM.
    static func defaultRST(forMode mode: String) -> String {
        let m = mode.uppercased()
        let digital = ["CW", "RTTY", "PSK", "PSK31", "PSK63", "FT8", "FT4", "JT65", "JT9",
                       "MFSK", "OLIVIA", "JS8", "Q65", "FSK441", "ROS", "DOMINO", "THOR"]
        if digital.contains(where: { m.contains($0) }) {
            return "599"
        }
        return "59"
    }

    /// Versucht ein 4-stelliges Maidenhead-Grid auf 4 Stellen zu beschneiden.
    /// Wenn der gespeicherte Locator 6-stellig ist (z.B. JN47PN), liefert das
    /// Helvetia-50 MHz-Feld trotzdem den vollen 6er-String.
    static func formattedGrid(_ raw: String, sixDigits: Bool) -> String {
        let upper = raw.uppercased()
        if sixDigits { return upper }
        return String(upper.prefix(4))
    }
}
