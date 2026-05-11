import Foundation

// Allgemeines Lookup-Resultat für Callbook-Services. Felder sind alle
// optional weil jeder Service unterschiedliche Daten liefert (z.B. ein
// EU-Server kennt vielleicht keine US-State, oder eine Freie-Tier-API
// liefert weniger als das Bezahl-Abo).
struct CallbookResult: Codable, Equatable {
    var firstName: String?
    var lastName: String?
    var qth: String?         // City
    var street: String?
    var state: String?
    var country: String?
    var continent: String?
    var locator: String?     // Maidenhead Grid
    var cqZone: Int?
    var ituZone: Int?
    var email: String?
    var lat: Double?
    var lon: Double?

    /// Wendet das Resultat auf ein QSO an. Existierende Felder werden
    /// NICHT überschrieben — Auto-Fill ergänzt nur Leerstellen.
    func applyFillingEmpty(to qso: inout QSO) {
        let combinedName = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces).nilIfEmpty }
            .joined(separator: " ")
        if (qso.name ?? "").isEmpty,    !combinedName.isEmpty   { qso.name = combinedName }
        if (qso.qth ?? "").isEmpty,     let v = qth?.nilIfEmpty { qso.qth = v }
        if (qso.country ?? "").isEmpty, let v = country?.nilIfEmpty { qso.country = v }
        if (qso.continent ?? "").isEmpty, let v = continent?.nilIfEmpty { qso.continent = v }
        if (qso.locator ?? "").isEmpty, let v = locator?.nilIfEmpty { qso.locator = v.uppercased() }
        if qso.cqZone == nil,           let v = cqZone  { qso.cqZone = v }
        if qso.ituZone == nil,          let v = ituZone { qso.ituZone = v }
    }

    var isEmpty: Bool {
        firstName == nil && lastName == nil && qth == nil && country == nil
            && locator == nil && cqZone == nil && ituZone == nil
    }
}

// Wurzel-Protokoll für alle Callbook-Services. Async damit der
// Network-Call den Main-Thread nicht blockiert.
protocol CallbookService: AnyObject {
    var name: String { get }
    var isConfigured: Bool { get }
    func lookup(call: String) async -> CallbookResult?
}

extension String {
    fileprivate var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }
}
