import SwiftUI
import AppKit

extension Notification.Name {
    /// Vom Menü "Hilfe → Bug melden…" gepostet; ContentView abonniert und
    /// öffnet das BugReportSheet.
    static let showBugReport = Notification.Name("HAMTools.showBugReport")
}

// "Bug melden…"-Sheet — schickt einen vorausgefüllten mailto an
// BuildInfo.bugReportEmail. Tester muss nur Beschreibung tippen, App-Kontext
// (Version, macOS, aktives Modul) kommt automatisch dazu.
//
// Eindeutige Bug-ID im Subject: yyyyMMdd-HHmm-XX (HH:MM aus Submit-Zeit +
// zwei zufällige Zeichen). Format ist mail-grep-bar — Christian kann später
// per Mail antworten und der Tester findet seinen Report wieder.
struct BugReportSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("callsign") private var callsign = ""
    @Environment(\.dismiss) private var dismiss

    enum Module: String, CaseIterable, Identifiable {
        case logbuch     = "Logbuch (Standard)"
        case contest     = "Logbuch — Contest"
        case pota        = "Logbuch — POTA"
        case dxCluster   = "DX-Cluster"
        case cat         = "CAT / Radio-Steuerung"
        case rechner     = "Rechner"
        case bandplan    = "Bandplan"
        case update      = "Update-System"
        case lizenz      = "Lizenz / Demo"
        case einstellung = "Einstellungen / Darstellung"
        case other       = "Sonstiges / Mehrere Module"
        var id: String { rawValue }
    }

    @State private var module: Module = .logbuch
    @State private var summary: String = ""
    @State private var details: String = ""
    @State private var includeDiagnostics: Bool = true

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            form
            Divider()
            footer
        }
        .padding(20)
        .frame(width: 560, height: 540)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "ant.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Bug melden")
                    .font(.title3.bold())
                Text("Wird per E-Mail an \(BuildInfo.bugReportEmail) gesendet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Modul").frame(width: 110, alignment: .leading)
                Picker("", selection: $module) {
                    ForEach(Module.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Kurz-Titel").frame(width: 110, alignment: .leading)
                TextField("z.B. POTA-Spot wird nicht ins Form übernommen", text: $summary)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Beschreibung — was hast du getan, was sollte passieren, was passiert tatsächlich?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $details)
                    .font(.body)
                    .frame(minHeight: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                    )
            }
            Toggle("Diagnose-Infos anhängen (App-Version, macOS, Callsign — keine Logs)",
                   isOn: $includeDiagnostics)
                .font(.caption)
        }
    }

    private var footer: some View {
        HStack {
            Text("ID wird beim Versenden generiert")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Abbrechen") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Mail öffnen") {
                openMail()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(summary.trimmingCharacters(in: .whitespaces).isEmpty
                      && details.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Mail-Generation

    private func openMail() {
        let bugID = generateBugID()
        let subject = "[\(bugID)] [\(module.rawValue)] \(summary.isEmpty ? "(ohne Titel)" : summary)"

        var body = details + "\n\n"
        if includeDiagnostics {
            body += diagnosticsBlock()
        }
        body += "\n— gesendet aus HAM-Tools v\(BuildInfo.appVersion)"

        let encS = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encB = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let u = URL(string: "mailto:\(BuildInfo.bugReportEmail)?subject=\(encS)&body=\(encB)") {
            NSWorkspace.shared.open(u)
        }
    }

    /// Bug-ID: yyyyMMdd-HHmm-XX (XX = 2 alphanumerische Zeichen). Kurz genug
    /// für Mail-Subjects, eindeutig genug für Cross-Reference.
    private func generateBugID() -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd-HHmm"
        let stamp = f.string(from: Date())
        let pool = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   // ohne I/O/1/0 — verwechslungsfrei
        let tail = String((0..<2).map { _ in pool.randomElement()! })
        return "BUG-\(stamp)-\(tail)"
    }

    private func diagnosticsBlock() -> String {
        let osv = ProcessInfo.processInfo.operatingSystemVersion
        let osStr = "\(osv.majorVersion).\(osv.minorVersion).\(osv.patchVersion)"
        let hw = Self.hwModel()
        return """
        ---
        Diagnose:
          App-Version:  \(BuildInfo.appVersion)
          App-Build:    \(BuildInfo.appBuildDate)
          macOS:        \(osStr)
          Hardware:     \(hw)
          Callsign:     \(callsign.isEmpty ? "(nicht gesetzt)" : callsign)
        ---
        """
    }

    /// "Mac14,12" o.ä. — knapp, anonymisiert, hilfreich beim Bug-Triage.
    private static func hwModel() -> String {
        var size: size_t = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
}
