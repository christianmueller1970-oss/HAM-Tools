import SwiftUI
import AppKit

// Einstellungen → Lizenz-Tab.
// Bewusst schlicht gehalten (VStack + Text + TextEditor) — komplexere
// Form/Section/grouped-Layouts machen in dieser Settings-Scene auf manchen
// macOS-Versionen Probleme.
struct LicenseSettingsView: View {
    @EnvironmentObject var license: LicenseService
    @AppStorage("callsign") private var callsign = ""

    @State private var envelopeDraft: String = ""
    @State private var lastApplyMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Lizenz")
                    .font(.title2.bold())

                statusBlock
                Divider()
                inputBlock
                Divider()
                requestBlock
                Divider()
                buildInfoBlock
            }
            .padding(20)
        }
        .onAppear { envelopeDraft = license.currentEnvelope }
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Status").font(.headline)
            Text(statusText)
                .font(.body)
                .foregroundStyle(statusColor)
            if let p = currentPayload {
                payloadDetail(p)
            }
            if !license.status.allowsFullMode {
                Text("Demo verbleibend: \(license.demoRemaining) von \(LicenseService.demoLimit) QSO")
                    .font(.caption)
                    .foregroundStyle(license.demoRemaining > 0 ? Color.secondary : Color.red)
            }
        }
    }

    private var statusText: String {
        switch license.status {
        case .valid:                            return "Vollversion aktiv"
        case .needsRenewal(_, let buildDate):   return "Update-Verlängerung nötig (App-Build \(buildDate))"
        case .wrongCall(_, let cfg):            return "Lizenz vorhanden, aber Call »\(cfg)« passt nicht"
        case .missingOrInvalid(let reason):     return "Demo-Modus — \(reason)"
        }
    }

    private var statusColor: Color {
        switch license.status {
        case .valid:             return .green
        case .needsRenewal:      return .orange
        case .wrongCall:         return .orange
        case .missingOrInvalid:  return .blue
        }
    }

    private var currentPayload: LicensePayload? {
        switch license.status {
        case .valid(let p):              return p
        case .needsRenewal(let p, _):    return p
        case .wrongCall(let p, _):       return p
        case .missingOrInvalid:          return nil
        }
    }

    private func payloadDetail(_ p: LicensePayload) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Lizenznehmer: \(p.name)").font(.caption)
            Text("E-Mail: \(p.email)").font(.caption)
            Text("Rufzeichen: \(p.calls.joined(separator: ", "))").font(.caption)
            Text("Ausgestellt: \(p.issued)").font(.caption)
            Text("Updates inkl. bis: \(p.updatesUntil)").font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private var inputBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lizenz-String").font(.headline)
            TextEditor(text: $envelopeDraft)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 80, maxHeight: 140)
                .border(Color.secondary.opacity(0.3))
            HStack {
                Button("Aus Zwischenablage einfügen") {
                    if let s = NSPasteboard.general.string(forType: .string) {
                        envelopeDraft = s
                    }
                }
                Spacer()
                Button("Lizenz übernehmen") {
                    let result = license.apply(envelope: envelopeDraft)
                    lastApplyMessage = message(for: result)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(envelopeDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let msg = lastApplyMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(license.status.allowsFullMode ? .green : .orange)
            }
        }
    }

    private func message(for status: LicenseStatus) -> String {
        switch status {
        case .valid:                    return "Lizenz akzeptiert — Vollmodus aktiv."
        case .needsRenewal:             return "Lizenz gültig, aber für eine ältere App-Version. Update-Verlängerung anfragen."
        case .wrongCall:                return "Lizenz gültig, aber dein Callsign passt nicht."
        case .missingOrInvalid(let r):  return "Nicht akzeptiert: \(r)"
        }
    }

    private var requestBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lizenz anfragen").font(.headline)
            Text("Bitte sende eine kurze Mail mit Rufzeichen + Name. Du erhältst per Antwort einen Lizenz-String.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text(BuildInfo.licenseRequestEmail)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Button("Mail öffnen") { openMailto() }
            }
        }
    }

    private func openMailto() {
        let subject = "HAM-Tools Lizenz-Anfrage"
        let body = "Hallo Christian,\n\nich möchte eine HAM-Tools-Lizenz anfragen.\n\nName: \(NSFullUserName())\nRufzeichen: \(callsign)\n\n73 de"
        let encS = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encB = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let u = URL(string: "mailto:\(BuildInfo.licenseRequestEmail)?subject=\(encS)&body=\(encB)") {
            NSWorkspace.shared.open(u)
        }
    }

    private var buildInfoBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("App-Info").font(.headline)
            Text("Build-Datum: \(BuildInfo.appBuildDate)")
                .font(.caption)
            Text("Dein Lizenzeintrag »Updates inkl. bis« muss ≥ diesem Datum sein, damit die App im Vollmodus läuft.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
