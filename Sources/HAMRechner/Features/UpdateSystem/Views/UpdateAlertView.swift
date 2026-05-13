import SwiftUI
import AppKit

// Sheet das angezeigt wird wenn ein Update verfügbar ist. Drei Modi:
//
//  1) Normales Update — User darf laden oder skippen.
//  2) Critical Update — Skip-Button deaktiviert.
//  3) Update jenseits der Lizenz-Update-Frist — kein Download-Button,
//     stattdessen Hinweis auf Update-Verlängerung + mailto.
//
// Wird vom Auto-Check (täglich) und vom manuellen Cmd+Opt+U-Eintrag geöffnet.
struct UpdateAlertView: View {
    @EnvironmentObject var update:  UpdateChecker
    @EnvironmentObject var license: LicenseService
    @Environment(\.dismiss) private var dismiss

    let payload: UpdateManifestPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            metaRow
            if let warning = macOSWarning() {
                warningRow(warning)
            }
            renderModeBlock
            Divider()
            ScrollView {
                Text(payload.releaseNotes)
                    .font(.system(.body, design: .default))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            .frame(maxHeight: 220)
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            Divider()
            footer
        }
        .padding(20)
        .frame(width: 520, height: 540)
    }

    // MARK: - Components

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: payload.critical ? "exclamationmark.triangle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(payload.critical ? .orange : .blue)
            VStack(alignment: .leading, spacing: 1) {
                Text(payload.critical ? "Wichtiges Update verfügbar" : "Neue Version verfügbar")
                    .font(.title3.bold())
                Text("Version \(payload.version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var metaRow: some View {
        HStack(spacing: 16) {
            metaItem("Aktuell", "v\(BuildInfo.appVersion)  ·  \(BuildInfo.appBuildDate)")
            metaItem("Neu",     "v\(payload.version)  ·  \(payload.buildDate)")
        }
    }

    private func metaItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.body, design: .monospaced))
        }
    }

    private func warningRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .padding(8)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // Block je nach Lizenz-Lage anders
    @ViewBuilder
    private var renderModeBlock: some View {
        if isUpdateBeyondLicense {
            renewalBlock
        } else {
            licenseOkBlock
        }
    }

    private var licenseOkBlock: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            Text("Dieses Update ist in deiner Lizenz inkludiert.")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    private var renewalBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "key.slash.fill").foregroundStyle(.orange)
                Text("Update-Verlängerung erforderlich")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
            }
            Text("Deine Lizenz deckt Updates bis \(licenseUpdatesUntil ?? "—"). Dieser Build ist vom \(payload.buildDate). Die installierte Version kannst du weiterhin uneingeschränkt nutzen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var footer: some View {
        HStack {
            if !payload.critical {
                Button("Diese Version überspringen") {
                    update.skipVersion(payload)
                    dismiss()
                }
            }
            Spacer()
            Button("Später") { dismiss() }
                .keyboardShortcut(.cancelAction)
            if isUpdateBeyondLicense {
                Button("Update anfragen") { sendRenewalMail() }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Download öffnen") { openDownload() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - Helpers

    private var isUpdateBeyondLicense: Bool {
        guard let until = licenseUpdatesUntil else { return true }
        return payload.buildDate > until
    }

    private var licenseUpdatesUntil: String? {
        switch license.status {
        case .valid(let p):           return p.updatesUntil
        case .needsRenewal(let p, _): return p.updatesUntil
        case .wrongCall(let p, _):    return p.updatesUntil
        case .missingOrInvalid:       return nil
        }
    }

    private func openDownload() {
        guard let u = URL(string: payload.dmgURL) else { return }
        NSWorkspace.shared.open(u)
        dismiss()
    }

    private func sendRenewalMail() {
        let subject = "HAM-Tools Update-Verlängerung"
        let body = "Hallo Christian,\n\nich möchte meine HAM-Tools-Lizenz für ein weiteres Jahr Updates verlängern.\n\nAktuelle Lizenz gültig bis: \(licenseUpdatesUntil ?? "—")\nNeue Version: \(payload.version) (\(payload.buildDate))\n\n73 de"
        let encS = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encB = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let u = URL(string: "mailto:\(BuildInfo.licenseRequestEmail)?subject=\(encS)&body=\(encB)") {
            NSWorkspace.shared.open(u)
        }
        dismiss()
    }

    private func macOSWarning() -> String? {
        guard let min = payload.minMacOSVersion, !min.isEmpty else { return nil }
        let current = ProcessInfo.processInfo.operatingSystemVersion
        let currentStr = "\(current.majorVersion).\(current.minorVersion)"
        if currentStr < min {
            return "Diese Version benötigt mindestens macOS \(min). Dein System: \(currentStr)."
        }
        return nil
    }
}
