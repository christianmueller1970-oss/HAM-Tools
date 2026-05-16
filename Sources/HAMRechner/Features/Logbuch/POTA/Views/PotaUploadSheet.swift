import SwiftUI

// Schritt 1 (UI-Gerüst, kein echter API-Call):
// Sheet zum Hochladen der QSOs eines POTA-Logs an pota.app. Layout-Vorlage
// ist das mit dem User abgestimmte Mockup (Header → Stats-Card → Vorschau
// → Optionen → Status-Banner → Aktion-Footer). Der „Jetzt hochladen"-Button
// triggert hier nur eine simulierte 1.5-Sekunden-Operation, damit die
// Status-Übergänge sichtbar werden. Der echte Multipart-Request kommt in
// Schritt 3 via `PotaUploadService`, sobald die API-Form per Browser-DevTools
// verifiziert ist.
struct PotaUploadSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var parkService: PotaParkService
    @EnvironmentObject var uploadSettings: UploadServicesSettings
    @Environment(\.dismiss) private var dismiss

    // Vom Aufrufer mitgegeben — wir wollen nicht implizit vom „aktuellen Log"
    // abhängen, sonst würde ein Log-Wechsel im Hintergrund den Sheet-Kontext
    // wegziehen.
    let log: Log
    let qsos: [QSO]

    @State private var isActivator: Bool = true
    @State private var includeHunterQsos: Bool = false
    @State private var uploadState: UploadState = .idle

    enum UploadState: Equatable {
        case idle
        case uploading
        case succeeded(at: Date, accepted: Int)
        case failed(String)
    }

    private var theme: AppTheme { themeManager.theme }

    // MARK: - Abgeleitete Daten

    private var parkRefs: [String] {
        if let refs = log.potaParkRefs, !refs.isEmpty {
            return refs.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        if let ref = log.potaParkRef, !ref.isEmpty { return [ref] }
        return []
    }

    private var primaryHeaderLine: String {
        guard let first = parkRefs.first else { return "Kein Park-Ref im Log" }
        if let name = parkService.park(forReference: first)?.name {
            return "\(first) — \(name)"
        }
        return first
    }

    private var additionalRefs: [String] { Array(parkRefs.dropFirst()) }

    // Bänder nach Häufigkeit absteigend, dann alphabetisch — bleibt stabil.
    private var uniqueBands: [String] {
        let counts = Dictionary(grouping: qsos, by: { $0.band })
            .mapValues { $0.count }
        return counts.keys
            .filter { !$0.isEmpty }
            .sorted { a, b in
                let ca = counts[a] ?? 0, cb = counts[b] ?? 0
                if ca != cb { return ca > cb }
                return a < b
            }
    }

    private var preview: [QSO] {
        Array(qsos.sorted { $0.datetime < $1.datetime }.prefix(5))
    }

    private var hasToken: Bool {
        !uploadSettings.potaApiToken.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var canUpload: Bool {
        !qsos.isEmpty && hasToken && uploadState != .uploading && !parkRefs.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider().background(theme.separator)
            statsCard
            previewSection
            optionsSection
            statusSection
            Spacer(minLength: 0)
            footerButtons
        }
        .padding(20)
        .frame(width: 520, height: 600)
        .background(theme.bgApp)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("An pota.app hochladen")
                    .font(.title3.bold())
                    .foregroundStyle(theme.textPrimary)
                Text(primaryHeaderLine)
                    .font(.callout)
                    .foregroundStyle(theme.textPrimary)
                if !additionalRefs.isEmpty {
                    Text("+ \(additionalRefs.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                    Text("Activator-Session · \(log.startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(theme.textDim)
                }
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(theme.textDim)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "number")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                    Text("\(qsos.count) QSO\(qsos.count == 1 ? "" : "s")")
                        .font(.callout.bold())
                        .foregroundStyle(theme.textPrimary)
                }
                if !uniqueBands.isEmpty {
                    Text("Bänder: \(uniqueBands.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                // Schritt 4: hier kommt der echte Wert aus persistiertem
                // `potaUploadStatus`. Für jetzt Platzhalter.
                Text("Letzter Upload: noch nie")
                    .font(.caption)
                    .foregroundStyle(theme.textDim)
            }
            Spacer()
        }
        .padding(12)
        .background(theme.bgCard2)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Vorschau (erste \(preview.count)):")
                .font(.caption.bold())
                .foregroundStyle(theme.textSecondary)
            ForEach(preview, id: \.id) { q in
                HStack(spacing: 10) {
                    Text(formatUTC(q.datetime))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textDim)
                        .frame(width: 56, alignment: .leading)
                    Text(q.call)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 100, alignment: .leading)
                    Text(q.band)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 50, alignment: .leading)
                    Text(q.mode)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }
            }
            if qsos.count > preview.count {
                Text("… und \(qsos.count - preview.count) weitere")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Optionen

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $isActivator) {
                Text("Als Activator hochladen (mind. 10 QSOs zählt als Aktivierung)")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)

            Toggle(isOn: $includeHunterQsos) {
                Text("Hunter-QSOs (Park-to-Park) mit einschließen")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusSection: some View {
        switch uploadState {
        case .idle:
            if !hasToken {
                statusBanner(systemName: "key",
                             tint: .orange,
                             title: "Kein POTA-API-Token gesetzt",
                             detail: "Einstellungen → Lookup & Upload → POTA")
            } else if parkRefs.isEmpty {
                statusBanner(systemName: "exclamationmark.triangle",
                             tint: .orange,
                             title: "Log enthält keinen Park-Ref",
                             detail: "Ohne MY_SIG_INFO kann POTA die Aktivierung nicht zuordnen.")
            } else {
                EmptyView()
            }
        case .uploading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Hochladen läuft…")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        case .succeeded(let at, let accepted):
            statusBanner(systemName: "checkmark.seal.fill",
                         tint: .green,
                         title: "Hochgeladen \(at.formatted(date: .omitted, time: .shortened))",
                         detail: "\(accepted) QSOs angenommen")
        case .failed(let msg):
            statusBanner(systemName: "exclamationmark.triangle.fill",
                         tint: .red,
                         title: "Upload fehlgeschlagen",
                         detail: msg)
        }
    }

    private func statusBanner(systemName: String,
                              tint: Color,
                              title: String,
                              detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemName)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(theme.textPrimary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .padding(8)
        .background(tint.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(tint.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack {
            Button("Schließen") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                triggerUpload()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Jetzt hochladen").bold()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canUpload)
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Action

    // Schritt 1: simulierte Operation, damit die Status-Übergänge in der UI
    // sichtbar werden. Schritt 3 ersetzt das durch einen echten Service-Call.
    private func triggerUpload() {
        uploadState = .uploading
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                uploadState = .succeeded(at: Date(), accepted: qsos.count)
            }
        }
    }

    private func formatUTC(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
