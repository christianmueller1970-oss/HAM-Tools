import SwiftUI
import AppKit

struct NewLogSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settings: LogbookSettings
    @Environment(\.dismiss) private var dismiss

    // Callback: Log + Ziel-Ordner (nil = Default verwenden)
    var onCreate: (Log, URL?) -> Void

    @State private var name: String = ""
    @State private var selectedType: LogType = .standard
    @State private var notes: String = ""
    @State private var customDirectory: URL? = nil

    private var theme: AppTheme { themeManager.theme }

    private var effectiveDirectory: URL {
        customDirectory ?? settings.logbookDirectory
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedType.isAvailable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Neues Log anlegen")
                .font(.title2.bold())
                .foregroundStyle(theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Log-Typ")
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 10) {
                    ForEach(LogType.allCases) { type in
                        LogTypeCard(type: type, selected: selectedType == type) {
                            if type.isAvailable { selectedType = type }
                        }
                    }
                }
            }

            if !selectedType.isAvailable {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(theme.accentOrange)
                    Text("\(selectedType.displayName) ist noch nicht verfügbar — kommt in einer späteren Phase.")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(8)
                .background(theme.bgCard2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.textSecondary)
                TextField("z.B. Lebens-Log, Field Day 2026, …", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // Speicherort-Auswahl
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Speicherort")
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    if customDirectory != nil {
                        Button("Standard verwenden") {
                            customDirectory = nil
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
                HStack(spacing: 8) {
                    Image(systemName: customDirectory == nil ? "folder" : "folder.badge.gearshape")
                        .foregroundStyle(theme.accentBlue)
                    Text(effectiveDirectory.path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Wählen …") {
                        pickFolder()
                    }
                }
                .padding(8)
                .background(theme.bgCard2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                if customDirectory == nil {
                    Text("Standardordner aus den Einstellungen. Klicke »Wählen« um diesem Log einen anderen Ordner zu geben (z.B. iCloud Drive oder externe Platte).")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                } else {
                    Text("Dieses Log wird im gewählten Ordner gespeichert und bleibt dort, auch wenn der Standardordner später geändert wird.")
                        .font(.caption2)
                        .foregroundStyle(theme.accentBlue)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notizen (optional)")
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.textSecondary)
                TextEditor(text: $notes)
                    .font(.body)
                    .frame(minHeight: 50, maxHeight: 80)
                    .padding(4)
                    .background(theme.bgCard2)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Anlegen") {
                    let log = Log(
                        name: name.trimmingCharacters(in: .whitespaces),
                        type: selectedType,
                        notes: notes.isEmpty ? nil : notes
                    )
                    onCreate(log, customDirectory)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 520)
        .background(theme.bgCard)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = effectiveDirectory
        panel.prompt = "Hier speichern"
        panel.message = "Ordner für dieses Logbuch wählen"
        if panel.runModal() == .OK, let url = panel.url {
            customDirectory = url
        }
    }
}

private struct LogTypeCard: View {
    let type: LogType
    let selected: Bool
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: type.systemImage)
                    .font(.title3)
                    .foregroundStyle(type.isAvailable ? theme.accentBlue : theme.textDim)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(type.isAvailable ? theme.textPrimary : theme.textDim)
                    Text(type.shortDescription)
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(10)
            .background(selected ? theme.bgHover : theme.bgCard2)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? theme.accentBlue : theme.separator,
                            lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(type.isAvailable ? 1.0 : 0.55)
        }
        .buttonStyle(.plain)
    }
}
