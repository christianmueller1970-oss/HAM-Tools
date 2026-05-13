import Foundation
import SwiftUI

// Hält den aktuellen Lizenz-Zustand, prüft beim App-Start + bei jedem
// String-Update die Signatur, das Build-Datum und den eingetragenen Call.
// Hält zudem den Demo-QSO-Counter (cumulativ über alle Logs).
//
// User-sichtbare Wirkung:
//  • LicenseStatus  → Banner-Anzeige + Settings-Status
//  • canLogMoreQSOs → wird vom LogbookManager beim Add-QSO geprüft
//
// User-Daten in AppStorage:
//  • license.string             — der eingegebene Envelope (oder leer)
//  • license.demoQSOCount       — gezählte Logs im Demo-Modus
final class LicenseService: ObservableObject {
    static let demoLimit = 50

    @Published private(set) var status: LicenseStatus = .missingOrInvalid(reason: "Noch nicht geladen")
    @Published private(set) var demoQSOCount: Int = 0

    private let licenseKey  = "license.string"
    private let demoCountKey = "license.demoQSOCount"

    init() {
        demoQSOCount = UserDefaults.standard.integer(forKey: demoCountKey)
        refresh()
    }

    // MARK: - Lizenz setzen / entfernen

    /// User trägt einen Envelope in den Settings ein. Bei Erfolg wird er
    /// persistiert; bei Fehler bleibt die alte Lizenz in den Settings stehen
    /// und der Status wird auf invalid gesetzt.
    @discardableResult
    func apply(envelope: String) -> LicenseStatus {
        let trimmed = envelope.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: licenseKey)
        refresh()
        return status
    }

    /// Aktuell eingetragenen Envelope für Settings-UI zurückgeben.
    var currentEnvelope: String {
        UserDefaults.standard.string(forKey: licenseKey) ?? ""
    }

    // MARK: - Status-Berechnung

    /// Lädt aus AppStorage, dekodiert, prüft Call + Build-Datum.
    /// Wird bei jedem App-Start aufgerufen und nach jeder Eingabe.
    func refresh() {
        let envelope = currentEnvelope
        guard !envelope.isEmpty else {
            status = .missingOrInvalid(reason: "Keine Lizenz hinterlegt")
            return
        }
        do {
            let payload = try LicenseCrypto.verifyAndDecode(envelope)
            status = evaluate(payload: payload)
        } catch let LicenseCrypto.CryptoError.publicKeyNotConfigured {
            status = .missingOrInvalid(reason: "App ohne Lizenz-Public-Key gebaut (Dev-Build)")
        } catch let LicenseCrypto.CryptoError.signatureInvalid {
            status = .missingOrInvalid(reason: "Signatur ungültig — Lizenz manipuliert oder verkürzt")
        } catch let LicenseCrypto.CryptoError.unknownVersionPrefix(v) {
            status = .missingOrInvalid(reason: "Unbekanntes Lizenz-Format »\(v)«")
        } catch {
            status = .missingOrInvalid(reason: "Lizenz-String konnte nicht gelesen werden")
        }
    }

    private func evaluate(payload: LicensePayload) -> LicenseStatus {
        // Build-Datum gegen updatesUntil prüfen
        if BuildInfo.appBuildDate > payload.updatesUntil {
            return .needsRenewal(payload: payload, appBuildDate: BuildInfo.appBuildDate)
        }
        // Call gegen eingestelltes Callsign prüfen
        let configured = (UserDefaults.standard.string(forKey: "callsign") ?? "")
            .uppercased()
            .trimmingCharacters(in: .whitespaces)
        guard !configured.isEmpty else {
            // Kein Call gesetzt → noch nicht verifizierbar. Lizenz technisch
            // OK, aber die App soll trotzdem Demo zeigen bis Call gesetzt ist.
            return .wrongCall(payload: payload, configuredCall: "(kein Call gesetzt)")
        }
        let licensed = payload.calls.map { $0.uppercased().trimmingCharacters(in: .whitespaces) }
        if licensed.contains(configured) {
            return .valid(payload: payload)
        }
        return .wrongCall(payload: payload, configuredCall: configured)
    }

    // MARK: - Demo-Counter

    /// Wird vom LogbookManager VOR dem persistieren eines neuen QSOs gefragt.
    /// Gibt true zurück wenn das QSO geloggt werden darf.
    var canLogMoreQSOs: Bool {
        if status.allowsFullMode { return true }
        return demoQSOCount < Self.demoLimit
    }

    /// Wird nach erfolgreichem QSO-Add aufgerufen — zählt im Demo-Modus hoch.
    /// Im Vollmodus ist das ein no-op.
    func registerLoggedQSO() {
        guard !status.allowsFullMode else { return }
        demoQSOCount += 1
        UserDefaults.standard.set(demoQSOCount, forKey: demoCountKey)
    }

    /// Restliche Demo-QSOs (für Banner-Anzeige).
    var demoRemaining: Int {
        max(0, Self.demoLimit - demoQSOCount)
    }
}
