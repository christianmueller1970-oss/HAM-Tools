import Foundation

// Lizenz-Payload — wird beim Helper-Tool signiert und in der App verifiziert.
//
// Format des Lizenz-Strings, der per E-Mail verteilt wird:
//
//     ham1.<base64URL(payload-JSON)>.<base64URL(signature)>
//
// Beispiel (gekürzt):
//     ham1.eyJjYWxscyI6WyJIQjlISkkiXSwidiI6MX0.MFQCIGSGV...
//
// Versions-Prefix "ham1" reserviert einen Migrationspfad. Wenn wir das
// Schema später ändern, wird das Prefix hochgezählt — alte Lizenzen bleiben
// validierbar, neue können zusätzliche Felder enthalten.
struct LicensePayload: Codable, Hashable {
    /// Schema-Version (aktuell 1)
    var v: Int = 1

    /// Auf welche Rufzeichen ist die Lizenz ausgestellt? 1–3 Calls erlaubt.
    /// Die App prüft den User-Settings-Call gegen diese Liste (Case-insensitive).
    var calls: [String]

    /// Vom Lizenznehmer für den Support hinterlegt — nicht für die Validierung.
    var email: String

    /// Klartext-Name (auch nur Anzeige).
    var name: String

    /// ISO-Datum (yyyy-MM-dd) — wann wurde die Lizenz ausgestellt.
    var issued: String

    /// ISO-Datum (yyyy-MM-dd). App-Versionen, die vor diesem Datum gebaut
    /// wurden, sind freigeschaltet. App-Versionen danach laufen im Demo-Modus
    /// — User braucht eine Update-Verlängerung. Die alten App-Versionen
    /// bleiben mit der ursprünglichen Lizenz lebenslang funktionsfähig.
    var updatesUntil: String

    /// Free-form Notiz beim Aussteller (optional, nur Helper, nicht in der App genutzt).
    var notes: String?
}

// Ergebnis-Status der Lizenz-Verifikation — fließt in den Banner + die
// Settings-Anzeige + die QSO-Logging-Logik ein.
enum LicenseStatus: Equatable {
    /// Lizenz gültig, Call passt, App-Version inkludiert → Vollmodus.
    case valid(payload: LicensePayload)

    /// Lizenz gültig, aber diese App-Version wurde nach `updatesUntil` released.
    /// Demo-Modus, freundliche Renewal-Aufforderung.
    case needsRenewal(payload: LicensePayload, appBuildDate: String)

    /// Lizenz gültig, aber das eingestellte Callsign ist nicht in `calls` enthalten.
    case wrongCall(payload: LicensePayload, configuredCall: String)

    /// Signatur ungültig / Format kaputt / Lizenz fehlt → Demo-Modus.
    case missingOrInvalid(reason: String)

    /// In allen "nicht voll"-Fällen läuft die App in Demo-Modus (50 QSOs).
    var allowsFullMode: Bool {
        if case .valid = self { return true }
        return false
    }

    /// Auf welche Base-Calls die Lizenz ausgestellt ist (für UI-Validation
    /// im Wizard etc.). Leer, wenn keine gültige Lizenz hinterlegt ist.
    var licensedCalls: [String] {
        switch self {
        case .valid(let p), .needsRenewal(let p, _), .wrongCall(let p, _):
            return p.calls
        case .missingOrInvalid:
            return []
        }
    }
}
