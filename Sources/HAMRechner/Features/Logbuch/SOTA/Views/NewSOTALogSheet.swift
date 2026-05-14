import SwiftUI

// Wizard zum Anlegen einer neuen SOTA-Session. Summit-Autocomplete aus
// summits.sqlite (SotaSummitService). Bei Activator: My-Summit-Pflicht.
struct NewSOTALogSheet: View {
    @EnvironmentObject var sota: SotaSummitService
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var dataRoot: AppDataRoot

    @Environment(\.dismiss) private var dismiss

    enum Mode: String, CaseIterable, Identifiable {
        case open = "Bestehende öffnen"
        case new  = "Neue anlegen"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .new
    @State private var role: SOTARole = .activator
    @State private var mySummitQuery: String = ""
    @State private var mySummitSelected: Summit?
    @State private var hoppingInput: String = ""    // Komma-Liste weiterer Summits
    @State private var sessionName: String = ""
    @State private var suggestions: [Summit] = []
    @State private var creating: Bool = false
    @State private var errorText: String?
    @State private var usedCallsign: String = ""
    @AppStorage("callsign") private var defaultCallsign = ""

    private var hoppingRefs: [String] {
        hoppingInput.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }

    private var allSummitRefs: [String] {
        var seen: Set<String> = []
        var out: [String] = []
        if let primary = mySummitSelected?.reference.uppercased() {
            if seen.insert(primary).inserted { out.append(primary) }
        }
        for r in hoppingRefs where seen.insert(r).inserted {
            out.append(r)
        }
        return out
    }

    private var existingSOTALogs: [Log] {
        manager.logs
            .filter { $0.type == .sota }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(mode == .open ? "SOTA-Session öffnen" : "Neue SOTA-Session anlegen")
                .font(.title3.bold())

            if !existingSOTALogs.isEmpty {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)
            }

            if mode == .open {
                openExistingSection
            } else {
                newSessionSection
            }
        }
        .padding(20)
        .frame(width: 480, height: existingSOTALogs.isEmpty ? 460 : 540)
        .onAppear {
            mode = existingSOTALogs.isEmpty ? .new : .open
            regenerateName()
            if usedCallsign.isEmpty { usedCallsign = defaultCallsign }
        }
    }

    // MARK: - Bestehende öffnen

    private var openExistingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Klick auf eine Session, um sie weiter zu führen:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(existingSOTALogs) { log in
                        Button {
                            manager.openLog(log)
                            dismiss()
                        } label: {
                            existingLogRow(log)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                Button("Neue Session") { mode = .new }
            }
        }
    }

    private func existingLogRow(_ log: Log) -> some View {
        let count = manager.qsoCount(for: log)
        let df = DateFormatter()
        df.dateStyle = .medium
        return HStack(spacing: 10) {
            Image(systemName: "mountain.2.fill")
                .foregroundStyle(.brown)
            VStack(alignment: .leading, spacing: 2) {
                Text(log.name).font(.callout.bold())
                HStack(spacing: 8) {
                    if let role = log.role {
                        Text(role).font(.caption).foregroundStyle(.blue)
                    }
                    if let summit = log.sotaSummitRef {
                        Text(summit).font(.caption.monospaced())
                    }
                    Text("\(count) QSO\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(df.string(from: log.startDate))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: - Neue anlegen

    private var newSessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Rolle", selection: $role) {
                ForEach(SOTARole.allCases) { r in
                    Text(r.displayName).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: role) { _, _ in regenerateName() }

            if role == .activator {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mein Summit")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TextField("z.B. HB/BE-001 oder Summit-Name", text: $mySummitQuery)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: mySummitQuery) { _, q in
                            suggestions = q.count >= 2 ? sota.search(q) : []
                            if let exact = suggestions.first(where: {
                                $0.reference.caseInsensitiveCompare(q) == .orderedSame
                            }) {
                                mySummitSelected = exact
                                regenerateName()
                            } else {
                                mySummitSelected = nil
                            }
                        }
                    if !suggestions.isEmpty && mySummitSelected == nil {
                        suggestionsList
                    }
                    if let s = mySummitSelected {
                        selectedSummitRow(s)
                    }
                    if !sota.isLoaded {
                        Text("⚠ Summit-DB noch nicht geladen — Einstellungen → Daten → SOTA-DB laden.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if mySummitSelected != nil {
                    hoppingSummitsSection
                }
            } else {
                Text("Im Chaser-Modus brauchst du keinen eigenen Summit. Du loggst Kontakte zu Activators — Their Summit trägst du beim QSO ein.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Session-Name")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                TextField("Name", text: $sessionName)
                    .textFieldStyle(.roundedBorder)
            }

            MyCallField(call: $usedCallsign)

            if let err = errorText {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer(minLength: 0)

            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button("Anlegen") { createSession() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreate || creating)
            }
        }
    }

    private var hoppingSummitsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Weitere Summits (Hopping)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("optional, Komma-getrennt")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            TextField("z.B. HB/BE-002, HB/VS-001", text: $hoppingInput)
                .textFieldStyle(.roundedBorder)
                .onChange(of: hoppingInput) { _, n in
                    let up = n.uppercased()
                    if up != n { hoppingInput = up }
                }
            if !hoppingRefs.isEmpty {
                HStack(spacing: 6) {
                    ForEach(hoppingRefs, id: \.self) { ref in
                        hoppingRefBadge(ref)
                    }
                }
            }
        }
    }

    private func hoppingRefBadge(_ ref: String) -> some View {
        let known = sota.summit(forReference: ref) != nil
        return HStack(spacing: 3) {
            Image(systemName: known ? "checkmark.circle.fill" : "questionmark.circle")
                .font(.caption2)
                .foregroundStyle(known ? .green : .orange)
            Text(ref)
                .font(.caption.monospaced())
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background((known ? Color.green : Color.orange).opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .help(known
              ? (sota.summit(forReference: ref)?.name ?? ref)
              : "Summit nicht in der DB gefunden — wird trotzdem gespeichert")
    }

    private var canCreate: Bool {
        if role == .activator && mySummitSelected == nil { return false }
        return !sessionName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var suggestionsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(suggestions) { s in
                    Button {
                        mySummitSelected = s
                        mySummitQuery = s.reference
                        suggestions = []
                        regenerateName()
                    } label: {
                        HStack {
                            Text(s.reference).font(.caption.monospaced()).frame(width: 95, alignment: .leading)
                            Text(s.name).font(.caption).lineLimit(1)
                            Spacer()
                            HStack(spacing: 4) {
                                if let alt = s.altitudeM {
                                    Text("\(alt)m").font(.caption2.monospaced()).foregroundStyle(.secondary)
                                }
                                Text("\(s.points)p")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 130)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func selectedSummitRow(_ s: Summit) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            VStack(alignment: .leading) {
                Text("\(s.reference) — \(s.name)").font(.caption.bold())
                HStack(spacing: 6) {
                    if !s.association.isEmpty {
                        Text(s.association).font(.caption2).foregroundStyle(.secondary)
                    }
                    if let alt = s.altitudeM {
                        Text("\(alt) m").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("\(s.points) p")
                        .font(.caption2.bold())
                        .foregroundStyle(.blue)
                    if s.bonusPoints > 0 {
                        Text("+\(s.bonusPoints) Bonus")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
            Button("Ändern") {
                mySummitSelected = nil
                mySummitQuery = ""
            }
            .controlSize(.small)
        }
        .padding(6)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func regenerateName() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let date = df.string(from: Date())
        switch role {
        case .activator:
            if let s = mySummitSelected {
                sessionName = "SOTA \(s.reference) \(date)"
            } else {
                sessionName = "SOTA Activator \(date)"
            }
        case .chaser:
            sessionName = "SOTA Chaser \(date)"
        }
    }

    private func createSession() {
        creating = true
        defer { creating = false }
        errorText = nil

        var log = Log(
            id: UUID(),
            name: sessionName.trimmingCharacters(in: .whitespaces),
            type: .sota,
            startDate: Date(),
            createdAt: Date()
        )
        log.role = role.rawValue
        let trimmedCall = usedCallsign.trimmingCharacters(in: .whitespaces)
        log.usedCallsign = trimmedCall.isEmpty ? nil : trimmedCall.uppercased()
        log.sotaSummitRef = role == .activator ? mySummitSelected?.reference : nil
        if role == .activator, allSummitRefs.count > 1 {
            log.sotaSummitRefs = allSummitRefs.joined(separator: ",")
        }

        manager.createLog(log)
        if manager.currentLogID == log.id {
            dismiss()
        } else {
            errorText = "Konnte Log nicht anlegen."
        }
    }
}
