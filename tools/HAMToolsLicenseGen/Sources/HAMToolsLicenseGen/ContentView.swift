import SwiftUI
import AppKit

struct ContentView: View {
    @State private var pair: KeyStore.Pair?
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var callsRaw: String = ""    // Komma-getrennt
    @State private var issued: String = today()
    @State private var updatesUntil: String = inOneYear()
    @State private var notes: String = ""
    @State private var output: String = ""
    @State private var status: String = ""

    private static func today() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    private static func inOneYear() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let d = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        return f.string(from: d)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HAM-Tools — License Generator")
                .font(.title2.bold())

            keypairSection
            Divider()
            licenseFormSection
            Divider()
            outputSection
        }
        .padding(20)
        .frame(minWidth: 640, idealWidth: 720, minHeight: 620, idealHeight: 720)
        .onAppear { pair = KeyStore.load() }
    }

    // MARK: - Schlüsselpaar

    private var keypairSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "key.fill")
                Text("Schlüsselpaar")
                    .font(.headline)
                Spacer()
                if let p = pair {
                    Text("Public Key: \(p.publicKey.prefix(20))…")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Button(pair == nil ? "Schlüsselpaar erzeugen" : "Neu erzeugen (überschreibt!)") {
                    do {
                        let p = try KeyStore.generateNew()
                        pair = p
                        status = "Neues Pair generiert. Public Key in die App kopieren."
                    } catch {
                        status = "Fehler: \(error.localizedDescription)"
                    }
                }
            }
            if let p = pair {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Public Key (in App hartcodieren in LicenseCrypto.publicKeyBase64):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: .constant(p.publicKey))
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 44)
                        .textSelection(.enabled)
                    HStack {
                        Spacer()
                        Button("Public Key kopieren") {
                            copyToClipboard(p.publicKey)
                            status = "Public Key in der Zwischenablage."
                        }
                    }
                }
            } else {
                Text("Noch kein Pair vorhanden. Beim ersten Mal »Schlüsselpaar erzeugen« klicken — wird unter ~/Library/Application Support/HAM-Tools License Generator/ abgelegt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - License-Form

    private var licenseFormSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lizenz-Daten")
                .font(.headline)
            HStack {
                Text("Name").frame(width: 120, alignment: .leading)
                TextField("Christian Mueller", text: $name)
            }
            HStack {
                Text("E-Mail").frame(width: 120, alignment: .leading)
                TextField("hb9hji@example.ch", text: $email)
            }
            HStack {
                Text("Rufzeichen").frame(width: 120, alignment: .leading)
                TextField("HB9HJI, HB9XX (komma-getrennt, max. 3)", text: $callsRaw)
                    .font(.system(.body, design: .monospaced))
            }
            HStack {
                Text("Ausgestellt").frame(width: 120, alignment: .leading)
                TextField("yyyy-MM-dd", text: $issued)
                    .font(.system(.body, design: .monospaced))
            }
            HStack {
                Text("Updates inkl. bis").frame(width: 120, alignment: .leading)
                TextField("yyyy-MM-dd", text: $updatesUntil)
                    .font(.system(.body, design: .monospaced))
            }
            HStack(alignment: .top) {
                Text("Notiz (intern)").frame(width: 120, alignment: .leading)
                TextEditor(text: $notes)
                    .font(.caption)
                    .frame(height: 40)
            }
            HStack {
                Spacer()
                Button("Lizenz generieren") {
                    generate()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(pair == nil
                          || name.isEmpty
                          || email.isEmpty
                          || parsedCalls().isEmpty)
            }
        }
    }

    // MARK: - Output

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Lizenz-String")
                    .font(.headline)
                Spacer()
                if !status.isEmpty {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            }
            // TextEditor ohne .disabled — sonst wird die Auswahl blockiert und
            // Copy-Paste geht nicht. Output ist @State, User kann reinschreiben,
            // aber das nächste »Lizenz generieren« überschreibt es eh.
            TextEditor(text: $output)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 120)
                .textSelection(.enabled)
            HStack {
                Spacer()
                Button("Per Mail versenden") {
                    sendByMail()
                }
                .disabled(output.isEmpty || email.isEmpty)
                Button("In Zwischenablage kopieren") {
                    copyToClipboard(output)
                    status = "Lizenz-String in der Zwischenablage."
                }
                .disabled(output.isEmpty)
            }
        }
    }

    // MARK: - Logic

    private func parsedCalls() -> [String] {
        callsRaw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }

    private func generate() {
        guard let p = pair else { return }
        do {
            let key = try KeyStore.signingKey(from: p)
            let payload = LicensePayload(
                calls: parsedCalls(),
                email: email,
                name: name,
                issued: issued,
                updatesUntil: updatesUntil,
                notes: notes.isEmpty ? nil : notes
            )
            output = try LicenseSigner.sign(payload: payload, with: key)
            status = "Lizenz erzeugt — \(output.count) Zeichen."
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }

    private func copyToClipboard(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    private func sendByMail() {
        let subject = "HAM-Tools — Dein Lizenz-String"
        let body = """
        Hallo \(name),

        anbei dein HAM-Tools-Lizenz-String. Bitte in der App unter
        Einstellungen → Lizenz einfügen und »Lizenz übernehmen« klicken.

        ---
        \(output)
        ---

        Updates inkl. bis: \(updatesUntil)
        Rufzeichen:        \(parsedCalls().joined(separator: ", "))

        73 de HB9HJI
        Christian
        """
        let encS = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encB = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let u = URL(string: "mailto:\(email)?subject=\(encS)&body=\(encB)") {
            NSWorkspace.shared.open(u)
        }
    }
}
