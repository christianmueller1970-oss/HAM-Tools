import SwiftUI
import AppKit

// CommandMenu-Inhalt für das macOS-Menubar-"Transceiver"-Menü.
//
// Inspiration: RUMlog "Transceiver"-Menü — Quick-Switch zwischen gespeicherten
// CAT-Configs ohne Settings-Klick. Wir halten an EINEM aktiven TRX fest
// (kein paralleles TRX #1 + #2), also keine "TRX #1 → TRX #2"-Kopier-Aktion.
//
// Struktur:
//   Reset CAT (= Reconnect zur aktiven Config)
//   ──
//   CAT ein-/ausschalten
//   ──
//   TRX-Setup laden ▸  (Untermenü mit allen gespeicherten Configs)
//   TRX-Setup speichern…
struct TransceiverCommands: View {
    @ObservedObject var settings:   CATSettings
    @ObservedObject var controller: CATController
    @Environment(\.openSettings) private var openSettings

    private var isConnected: Bool {
        if case .connected = controller.status { return true }
        return false
    }

    var body: some View {
        Button("Reset CAT") {
            Task { await controller.restart() }
        }
        .keyboardShortcut("r", modifiers: [.command, .shift])
        .disabled(settings.activeConfigID == nil)

        Divider()

        Button(settings.enabled ? "CAT ausschalten" : "CAT einschalten") {
            settings.enabled.toggle()
            Task { await controller.toggle() }
        }
        .keyboardShortcut("t", modifiers: [.command, .shift])
        .disabled(settings.activeConfigID == nil)

        Divider()

        Menu("TRX-Setup laden") {
            ForEach(settings.configs) { config in
                Button {
                    activate(config)
                } label: {
                    if config.id == settings.activeConfigID {
                        Label(config.name, systemImage: "checkmark")
                    } else {
                        Text(config.name)
                    }
                }
            }
        }
        .disabled(settings.configs.isEmpty)

        Button("TRX-Setup speichern…") {
            promptAndDuplicateActive()
        }
        .disabled(settings.activeConfigID == nil)

        Divider()

        Button("Einstellungen…") {
            openSettings()
        }
        .keyboardShortcut(",", modifiers: [.command])
    }

    /// Aktiviert eine andere gespeicherte Config. Wenn CAT gerade läuft,
    /// reconnecten wir, damit rigctld die neue Config aufnimmt — sonst
    /// bleibt der ungeänderte Port + Profile aktiv und die UI lügt.
    private func activate(_ config: CATConfig) {
        guard config.id != settings.activeConfigID else { return }
        settings.activeConfigID = config.id
        if isConnected || settings.enabled {
            Task { await controller.restart() }
        }
    }

    /// NSAlert mit Textfeld für den neuen Config-Namen, dann
    /// `CATSettings.duplicateActive(withName:)`. Eine reine SwiftUI-Sheet-
    /// Lösung wäre sauberer, würde aber State-Hoisting bis ins Scene-Root
    /// erzwingen — pragmatischer Weg für den ersten Wurf.
    private func promptAndDuplicateActive() {
        guard let current = settings.activeConfig else { return }

        let alert = NSAlert()
        alert.messageText     = "TRX-Setup speichern"
        alert.informativeText = "Name für die neue Config:"
        alert.alertStyle      = .informational
        alert.addButton(withTitle: "Speichern")
        alert.addButton(withTitle: "Abbrechen")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = "Kopie von \(current.name)"
        input.selectText(nil)
        alert.accessoryView = input

        // Damit der Text bei Sheet-Öffnung sofort Fokus hat (für ⏎-Speichern).
        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            let name = input.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            settings.duplicateActive(withName: name)
        }
    }
}
