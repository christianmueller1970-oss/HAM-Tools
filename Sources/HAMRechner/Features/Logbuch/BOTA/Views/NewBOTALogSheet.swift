import SwiftUI

// Wizard zum Anlegen einer neuen BOTA-Session. Reference-Autocomplete aus
// bota_refs.sqlite (BOTARefService). Bei Activator: My-Ref-Pflicht.
// Strukturparallel zu NewWWFFLogSheet, ohne 44-QSO-Hinweis (BOTA hat keine
// strikten Aktivierungs-Regeln).
struct NewBOTALogSheet: View {
    @EnvironmentObject var bota: BOTARefService
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var dataRoot: AppDataRoot

    @Environment(\.dismiss) private var dismiss

    enum Mode: String, CaseIterable, Identifiable {
        case open = "Bestehende öffnen"
        case new  = "Neue anlegen"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .new
    @State private var role: BOTARole = .activator
    @State private var myRefQuery: String = ""
    @State private var myRefSelected: BOTAReference?
    @State private var hoppingInput: String = ""
    @State private var sessionName: String = ""
    @State private var suggestions: [BOTAReference] = []
    @State private var creating: Bool = false
    @State private var errorText: String?

    private var hoppingRefs: [String] {
        hoppingInput.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }

    private var allRefs: [String] {
        var seen: Set<String> = []
        var out: [String] = []
        if let primary = myRefSelected?.reference.uppercased() {
            if seen.insert(primary).inserted { out.append(primary) }
        }
        for r in hoppingRefs where seen.insert(r).inserted {
            out.append(r)
        }
        return out
    }

    private var existingBOTALogs: [Log] {
        manager.logs
            .filter { $0.type == .bota }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(mode == .open ? "BOTA-Session öffnen" : "Neue BOTA-Session anlegen")
                .font(.title3.bold())

            if !existingBOTALogs.isEmpty {
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
        .frame(width: 480, height: existingBOTALogs.isEmpty ? 440 : 540)
        .onAppear {
            mode = existingBOTALogs.isEmpty ? .new : .open
            regenerateName()
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
                    ForEach(existingBOTALogs) { log in
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
            Image(systemName: "shield.fill")
                .foregroundStyle(.gray)
            VStack(alignment: .leading, spacing: 2) {
                Text(log.name).font(.callout.bold())
                HStack(spacing: 8) {
                    if let role = log.role {
                        Text(role).font(.caption).foregroundStyle(.blue)
                    }
                    if let ref = log.botaRef {
                        Text(ref).font(.caption.monospaced())
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
                ForEach(BOTARole.allCases) { r in
                    Text(r.displayName).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: role) { _, _ in regenerateName() }

            if role == .activator {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mein Bunker")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TextField("z.B. DE-1234 oder Bunker-Name", text: $myRefQuery)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: myRefQuery) { _, q in
                            suggestions = q.count >= 2 ? bota.search(q) : []
                            if let exact = suggestions.first(where: {
                                $0.reference.caseInsensitiveCompare(q) == .orderedSame
                            }) {
                                myRefSelected = exact
                                regenerateName()
                            } else {
                                myRefSelected = nil
                            }
                        }
                    if !suggestions.isEmpty && myRefSelected == nil {
                        suggestionsList
                    }
                    if let r = myRefSelected {
                        selectedRefRow(r)
                    }
                    if !bota.isLoaded {
                        Text("⚠ BOTA-DB noch nicht geladen — Einstellungen → Daten → CSV importieren.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if myRefSelected != nil {
                    hoppingRefsSection
                }
            } else {
                Text("Im Hunter-Modus brauchst du keinen eigenen Bunker. Du loggst Kontakte zu Activators — Their Reference trägst du beim QSO ein.")
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

    private var hoppingRefsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Weitere Bunker (Hopping)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("optional, Komma-getrennt")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            TextField("z.B. DE-0002, F-0011", text: $hoppingInput)
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
        let known = bota.ref(forReference: ref) != nil
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
              ? (bota.ref(forReference: ref)?.name ?? ref)
              : "Bunker nicht in der DB gefunden — wird trotzdem gespeichert")
    }

    private var canCreate: Bool {
        if role == .activator && myRefSelected == nil { return false }
        return !sessionName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var suggestionsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(suggestions) { r in
                    Button {
                        myRefSelected = r
                        myRefQuery = r.reference
                        suggestions = []
                        regenerateName()
                    } label: {
                        HStack {
                            Text(r.reference).font(.caption.monospaced()).frame(width: 90, alignment: .leading)
                            Text(r.name).font(.caption).lineLimit(1)
                            Spacer()
                            if let c = r.country, !c.isEmpty {
                                Text(c).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
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

    private func selectedRefRow(_ r: BOTAReference) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            VStack(alignment: .leading) {
                Text("\(r.reference) — \(r.name)").font(.caption.bold())
                HStack(spacing: 6) {
                    if let c = r.country, !c.isEmpty {
                        Text(c).font(.caption2).foregroundStyle(.secondary)
                    }
                    if let t = r.bunkerType, !t.isEmpty {
                        Text("·").foregroundStyle(.secondary)
                        Text(t).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button("Ändern") {
                myRefSelected = nil
                myRefQuery = ""
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
            if let r = myRefSelected {
                sessionName = "BOTA \(r.reference) \(date)"
            } else {
                sessionName = "BOTA Activator \(date)"
            }
        case .hunter:
            sessionName = "BOTA Hunter \(date)"
        }
    }

    private func createSession() {
        creating = true
        defer { creating = false }
        errorText = nil

        var log = Log(
            id: UUID(),
            name: sessionName.trimmingCharacters(in: .whitespaces),
            type: .bota,
            startDate: Date(),
            createdAt: Date()
        )
        log.role = role.rawValue
        log.botaRef = role == .activator ? myRefSelected?.reference : nil
        if role == .activator, allRefs.count > 1 {
            log.botaRefs = allRefs.joined(separator: ",")
        }

        manager.createLog(log)
        if manager.currentLogID == log.id {
            dismiss()
        } else {
            errorText = "Konnte Log nicht anlegen."
        }
    }
}
