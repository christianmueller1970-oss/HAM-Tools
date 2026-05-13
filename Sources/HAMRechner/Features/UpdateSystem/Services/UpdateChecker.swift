import Foundation
import SwiftUI
import CryptoKit

// Update-Check-Service.
//
// • Beim App-Start automatisch, aber max 1×/24h (Timestamp in AppStorage).
// • Manuell via Menü »Auf Updates prüfen…« (⌘⌥U).
// • Lädt Envelope von BuildInfo.updateManifestURL, verifiziert Ed25519-Signatur
//   gegen denselben Public Key wie das Lizenzsystem.
// • State-Maschine: idle → checking → entweder .upToDate / .updateAvailable / .error.
// • Übersprungene Versionen werden in AppStorage gemerkt — beim nächsten
//   Auto-Check nicht erneut angezeigt. Bei `critical: true` ignoriert.
@MainActor
final class UpdateChecker: ObservableObject {

    enum State: Equatable {
        case idle
        case checking
        case upToDate(latestBuildDate: String)
        case updateAvailable(UpdateManifestPayload)
        case error(String)
    }

    @Published private(set) var state: State = .idle

    @AppStorage("update.lastCheckTimestamp") private var lastCheckTimestamp: TimeInterval = 0
    @AppStorage("update.skippedVersion")    private var skippedVersion: String = ""

    /// Eintrittspunkt für Auto-Check beim App-Start. Macht nichts wenn
    /// der letzte Check < 24h her war.
    func autoCheckIfDue() {
        let now = Date().timeIntervalSince1970
        let dayInSec: Double = 24 * 3600
        guard now - lastCheckTimestamp >= dayInSec else { return }
        Task { await check(force: false) }
    }

    /// Manueller Check (Cmd+Opt+U). force=true ignoriert die Skip-Markierung.
    func checkNow() {
        Task { await check(force: true) }
    }

    /// Skip eine konkrete Version. Wird beim Klick auf »Später« im Alert gesetzt.
    func skipVersion(_ payload: UpdateManifestPayload) {
        skippedVersion = payload.version
    }

    /// Manuell den Skip-Status für eine Version löschen — wenn der User
    /// die Version doch laden möchte.
    func clearSkip() {
        skippedVersion = ""
    }

    // MARK: - Core

    private func check(force: Bool) async {
        await MainActor.run { state = .checking }
        guard let url = URL(string: BuildInfo.updateManifestURL) else {
            await fail("Update-URL ungültig")
            return
        }
        do {
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = 15
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                await fail("Server antwortete nicht (HTTP \(string(of: resp)))")
                return
            }
            let envelope = try JSONDecoder().decode(UpdateManifestEnvelope.self, from: data)
            let payload  = try verifyAndDecode(envelope: envelope)
            await MainActor.run {
                lastCheckTimestamp = Date().timeIntervalSince1970
                state = decideState(payload: payload, force: force)
            }
        } catch {
            await fail("Update-Check fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func decideState(payload: UpdateManifestPayload, force: Bool) -> State {
        // Wenn der Server eine Version ankündigt, die wir bereits haben oder
        // älter ist als unser eigener Build: keine Aktion.
        if !isNewerBuild(latest: payload.buildDate, than: BuildInfo.appBuildDate) {
            return .upToDate(latestBuildDate: payload.buildDate)
        }
        // Skip-Logik: User hat diese Version aktiv übersprungen → nicht erneut nerven,
        // außer er hat manuell gecheckt (force) oder das Update ist critical.
        if !force, !payload.critical, payload.version == skippedVersion {
            return .upToDate(latestBuildDate: payload.buildDate)
        }
        return .updateAvailable(payload)
    }

    private func verifyAndDecode(envelope: UpdateManifestEnvelope) throws -> UpdateManifestPayload {
        guard !LicenseCrypto.publicKeyBase64.isEmpty,
              let pubRaw = Data(base64Encoded: LicenseCrypto.publicKeyBase64),
              let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: pubRaw)
        else { throw UpdateError.publicKeyMissing }

        guard let sig = Data(base64URLEncoded: envelope.signature) else {
            throw UpdateError.signatureMalformed
        }
        guard let msg = envelope.manifest.data(using: .utf8) else {
            throw UpdateError.signatureMalformed
        }
        guard pub.isValidSignature(sig, for: msg) else {
            throw UpdateError.signatureInvalid
        }
        guard let payloadJSON = Data(base64URLEncoded: envelope.manifest) else {
            throw UpdateError.payloadMalformed
        }
        return try JSONDecoder().decode(UpdateManifestPayload.self, from: payloadJSON)
    }

    private func fail(_ msg: String) async {
        await MainActor.run { state = .error(msg) }
    }

    private func string(of resp: URLResponse?) -> String {
        guard let h = resp as? HTTPURLResponse else { return "?" }
        return String(h.statusCode)
    }
}

enum UpdateError: Error {
    case publicKeyMissing
    case signatureMalformed
    case signatureInvalid
    case payloadMalformed
}
