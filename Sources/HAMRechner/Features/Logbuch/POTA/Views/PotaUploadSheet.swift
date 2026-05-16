import SwiftUI

// Sheet zum Hochladen der QSOs eines POTA-Logs an pota.app. Schritt 3 —
// echte API-Anbindung (CognitoAuthService → PotaUploadService → POST /adif
// → PotaJobsService poll). Auth-Daten kommen aus UploadServicesSettings
// (Username UserDefaults, Passwort Keychain).
//
// Polling-Strategie: nach dem POST haben wir nur die JobId. POTA verarbeitet
// asynchron im Backend; wir pollen `GET /user/jobs` alle 2 Sekunden bis zu
// 30s lang, dann zeigen wir den letzten bekannten Status. Verfehlt das
// 30s-Fenster den Wechsel auf `status==2`, ist das nicht tragisch — der
// Job ist trotzdem eingereicht, der User kann später auf pota.app
// nachschauen.
struct PotaUploadSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var parkService: PotaParkService
    @EnvironmentObject var uploadSettings: UploadServicesSettings
    @Environment(\.dismiss) private var dismiss

    // CognitoAuthService hält den ID-Token-Cache. Wir halten ihn als
    // @StateObject im Sheet — Token überlebt mehrere Klicks auf "Jetzt
    // hochladen" innerhalb derselben Sheet-Session.
    @StateObject private var auth = CognitoAuthService()

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
        case uploading(phase: String)
        case succeeded(at: Date, jobId: Int, counts: String?)
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

    private var hasCredentials: Bool {
        !uploadSettings.potaUsername.trimmingCharacters(in: .whitespaces).isEmpty &&
        !uploadSettings.potaPassword.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isUploading: Bool {
        if case .uploading = uploadState { return true }
        return false
    }

    private var canUpload: Bool {
        !qsos.isEmpty && hasCredentials && !isUploading && !parkRefs.isEmpty
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
            if !hasCredentials {
                statusBanner(systemName: "key",
                             tint: .orange,
                             title: "POTA-Login fehlt",
                             detail: "Einstellungen → Lookup & Upload → POTA: Username + Passwort eintragen")
            } else if parkRefs.isEmpty {
                statusBanner(systemName: "exclamationmark.triangle",
                             tint: .orange,
                             title: "Log enthält keinen Park-Ref",
                             detail: "Ohne MY_SIG_INFO kann POTA die Aktivierung nicht zuordnen.")
            } else {
                EmptyView()
            }
        case .uploading(let phase):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(phase)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        case .succeeded(let at, let jobId, let counts):
            statusBanner(systemName: "checkmark.seal.fill",
                         tint: .green,
                         title: "Hochgeladen \(at.formatted(date: .omitted, time: .shortened)) · Job #\(jobId)",
                         detail: counts ?? "POTA hat den Job in seine Warteschlange aufgenommen — verarbeitet im Hintergrund.")
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

    /// Echter Upload-Flow (Schritt 3):
    ///   1. Cognito-Login (cached) → ID-Token
    ///   2. ADIF-Multipart-POST an api.pota.app/adif → JobId
    ///   3. Job-Polling (alle 2s, max 30s) bis Status==2 (processed)
    ///   4. Verarbeitete QSO-Counts an die Sheet-UI durchreichen
    private func triggerUpload() {
        let username = uploadSettings.potaUsername
        let password = uploadSettings.potaPassword
        let logName  = log.name
        let snapshotQSOs = qsos
        // Filename folgt POTAs eigener Konvention (siehe userComment-Feld
        // in den Bestands-Jobs): "POTA@<REF>.adi". Bei Multi-Park nehmen
        // wir die primäre Ref — POTA liest die echten Refs eh aus dem
        // ADIF (MY_SIG_INFO).
        let primaryRef = parkRefs.first ?? "UNKNOWN"
        let filename = "POTA@\(primaryRef).adi"

        uploadState = .uploading(phase: "Bei pota.app anmelden…")

        Task {
            let uploadService = PotaUploadService(auth: auth)
            let jobsService   = PotaJobsService(auth: auth)

            do {
                await MainActor.run {
                    uploadState = .uploading(phase: "ADIF wird hochgeladen…")
                }
                let result = try await uploadService.upload(
                    qsos: snapshotQSOs,
                    logName: logName,
                    filename: filename,
                    username: username,
                    password: password)

                // Polling — POTA arbeitet asynchron. Wir geben dem
                // Backend ein paar Sekunden, dann zeigen wir das, was
                // wir bekommen haben (status 7 = noch in Queue oder
                // status 2 = fertig mit Counts).
                let pollResult = await pollJob(id: result.jobId,
                                                username: username,
                                                password: password,
                                                via: jobsService)
                await MainActor.run {
                    let countText = pollResult.flatMap { job -> String? in
                        guard job.isProcessed else { return nil }
                        let m = [
                            "\(job.total) gesamt",
                            "\(job.inserted) übernommen",
                            job.cw    > 0 ? "\(job.cw) CW"        : nil,
                            job.phone > 0 ? "\(job.phone) Phone"  : nil,
                            job.data  > 0 ? "\(job.data) Digital" : nil,
                        ].compactMap { $0 }
                        return m.joined(separator: " · ")
                    }
                    uploadState = .succeeded(at: Date(),
                                              jobId: result.jobId,
                                              counts: countText)
                }
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription
                          ?? error.localizedDescription
                await MainActor.run {
                    uploadState = .failed(msg)
                }
            }
        }
    }

    /// Pollt die Job-Liste alle 2 Sekunden bis zu 15× (= 30s). Liefert den
    /// gefundenen Job sobald `isProcessed`. Falls Timeout zuschlägt, kommt
    /// trotzdem der letzte Job-Snapshot zurück (oder nil bei Fehler — dann
    /// zeigen wir die generische "in Warteschlange"-Meldung).
    private func pollJob(id: Int,
                         username: String,
                         password: String,
                         via service: PotaJobsService) async -> PotaJobsService.Job? {
        var last: PotaJobsService.Job?
        for attempt in 0..<15 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    uploadState = .uploading(phase: "POTA verarbeitet… (Polling \(attempt)/15)")
                }
            } else {
                await MainActor.run {
                    uploadState = .uploading(phase: "POTA verarbeitet…")
                }
            }
            do {
                if let job = try await service.findJob(id: id,
                                                       username: username,
                                                       password: password) {
                    last = job
                    if job.isProcessed { return job }
                }
            } catch {
                // Polling-Fehler verschlucken — die initiale Upload-
                // Quittung war ja schon erfolgreich (Job liegt im
                // Server). Bei harten Fehlern brechen wir nicht ab,
                // wir geben nur den letzten Stand zurück.
                continue
            }
        }
        return last
    }

    private func formatUTC(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
