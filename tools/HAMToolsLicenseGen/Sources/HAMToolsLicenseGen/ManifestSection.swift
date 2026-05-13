import SwiftUI
import AppKit

// Tab im License-Generator zum Erzeugen + Signieren des Update-Manifests.
// Output landet als JSON-Envelope-String, der direkt nach
// /var/www/toolbox/app/updates.json hochgeladen werden kann.
struct ManifestSection: View {
    @Binding var pair: KeyStore.Pair?

    @State private var version: String = "1.7.0"
    @State private var buildDate: String = today()
    @State private var minMacOS: String = "14.0"
    @State private var dmgURL: String = "https://toolbox.funkwelt.net/app/dmg/HAM-Tools-1.7.0.dmg"
    @State private var releaseNotes: String = "• Neue Features …\n• Bugfixes …"
    @State private var critical: Bool = false
    @State private var output: String = ""
    @State private var status: String = ""

    private static func today() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            formSection
            Divider()
            outputBlock
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Version").frame(width: 130, alignment: .leading)
                TextField("1.7.0", text: $version)
                    .font(.system(.body, design: .monospaced))
            }
            HStack {
                Text("Build-Datum").frame(width: 130, alignment: .leading)
                TextField("yyyy-MM-dd", text: $buildDate)
                    .font(.system(.body, design: .monospaced))
            }
            HStack {
                Text("Min macOS").frame(width: 130, alignment: .leading)
                TextField("14.0 (leer = keine Vorgabe)", text: $minMacOS)
                    .font(.system(.body, design: .monospaced))
            }
            HStack {
                Text("DMG-URL").frame(width: 130, alignment: .leading)
                TextField("https://toolbox.funkwelt.net/app/dmg/…", text: $dmgURL)
                    .font(.system(.caption, design: .monospaced))
            }
            HStack(alignment: .top) {
                Text("Release-Notes").frame(width: 130, alignment: .leading)
                TextEditor(text: $releaseNotes)
                    .font(.system(.body, design: .default))
                    .frame(minHeight: 100, maxHeight: 140)
            }
            Toggle("Critical Update (User kann nicht skippen)", isOn: $critical)
                .padding(.leading, 130)

            HStack {
                Spacer()
                Button("updates.json erzeugen") { generate() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(pair == nil || version.isEmpty || buildDate.isEmpty || dmgURL.isEmpty)
            }
        }
    }

    private var outputBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("updates.json").font(.headline)
                Spacer()
                if !status.isEmpty {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            }
            TextEditor(text: $output)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 160)
                .textSelection(.enabled)
            HStack {
                Spacer()
                Button("In Datei sichern…") { saveToFile() }
                    .disabled(output.isEmpty)
                Button("In Zwischenablage kopieren") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                    status = "In der Zwischenablage."
                }
                .disabled(output.isEmpty)
            }
            Text("Datei nach /var/www/toolbox/app/updates.json hochladen (s. tools/README-server.md).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func generate() {
        guard let p = pair else { return }
        do {
            let key = try KeyStore.signingKey(from: p)
            let payload = UpdateManifestPayloadOut(
                version: version,
                buildDate: buildDate,
                minMacOSVersion: minMacOS.isEmpty ? nil : minMacOS,
                dmgURL: dmgURL,
                releaseNotes: releaseNotes,
                critical: critical
            )
            output = try ManifestSigner.sign(payload: payload, with: key)
            status = "Manifest signiert — \(output.count) Zeichen."
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }

    private func saveToFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "updates.json"
        panel.allowedContentTypes  = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? output.write(to: url, atomically: true, encoding: .utf8)
            status = "Gespeichert: \(url.lastPathComponent)"
        }
    }
}
