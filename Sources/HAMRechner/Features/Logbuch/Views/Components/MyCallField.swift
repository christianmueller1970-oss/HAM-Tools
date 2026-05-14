import SwiftUI

// "Mein Call (für dieses Log)" — Eingabefeld für Portabel-/Ausland-/Club-Call.
// Default ist der globale Settings-Call. Live-Validation gegen die Lizenz
// (Substring-Match via CallValidator). Bei nicht-licensed Input erscheint
// eine gelbe Warnung — die UI blockt das Anlegen aber nicht: der User kann
// auch im Demo-Modus loggen, und manche Test-Calls sind explizit nicht
// licensed.
struct MyCallField: View {
    @Binding var call: String

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var license: LicenseService

    private var theme: AppTheme { themeManager.theme }

    /// Trimmed + uppercased Repräsentation für die Validation.
    private var normalized: String {
        call.uppercased().trimmingCharacters(in: .whitespaces)
    }

    /// Lizenz-Liste; leer wenn keine gültige Lizenz hinterlegt.
    private var licensedCalls: [String] {
        license.status.licensedCalls
    }

    /// nil = keine Lizenz aktiv (Demo) → kein Validation-Icon zeigen
    /// true = Input ist von Lizenz gedeckt
    /// false = nicht gedeckt → Warnung
    private var validationState: Bool? {
        guard !licensedCalls.isEmpty, !normalized.isEmpty else { return nil }
        return CallValidator.isLicensed(call: normalized, licensedCalls: licensedCalls)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mein Call (für dieses Log)")
                .font(.subheadline.bold())
                .foregroundStyle(theme.textSecondary)

            // Quick-Picker bei Multi-Call-Lizenz (Club-Call etc.): ein Tap
            // füllt das Eingabefeld vor. User kann anschließend Portabel-
            // Suffixe (/P, /MM) anhängen, ohne den Base-Call neu zu tippen.
            if licensedCalls.count > 1 {
                HStack(spacing: 6) {
                    ForEach(licensedCalls, id: \.self) { c in
                        Button {
                            call = c
                        } label: {
                            Text(c)
                                .font(.caption.monospaced())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    normalized == c
                                        ? theme.accentBlue.opacity(0.25)
                                        : theme.bgCard2
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("z.B. HB9HJI, HB9HJI/P, DL/HB9HJI", text: $call)
                    .textFieldStyle(.roundedBorder)
                    .textCase(.uppercase)
                    .autocorrectionDisabled()
                    .disableAutocorrection(true)

                switch validationState {
                case .some(true):
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(theme.accentGreen)
                        .help("Call ist durch die Lizenz gedeckt.")
                case .some(false):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.accentOrange)
                        .help("Call ist nicht durch die Lizenz gedeckt — Loggen weiterhin möglich, aber Demo-Mode.")
                case .none:
                    EmptyView()
                }
            }

            Group {
                if validationState == false {
                    Text("\(normalized) ist nicht durch deine Lizenz gedeckt (\(licensedCalls.joined(separator: ", "))). Im Demo-Modus loggst du trotzdem — für Vollmodus muss ein lizenzierter Base-Call als `/`-getrenntes Segment vorkommen.")
                        .font(.caption2)
                        .foregroundStyle(theme.accentOrange)
                } else {
                    Text("Wird in jedem QSO als Station-Call gespeichert. Leerlassen → Settings-Default (`\(UserDefaults.standard.string(forKey: "callsign") ?? "")`).")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                }
            }
        }
    }
}
