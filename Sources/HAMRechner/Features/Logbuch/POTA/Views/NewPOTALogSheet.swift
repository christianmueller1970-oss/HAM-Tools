import SwiftUI

// Wizard zum Anlegen einer neuen POTA-Session. Park-Autocomplete aus
// parks.sqlite (PotaParkService). Bei Activator: My-Park-Pflicht.
struct NewPOTALogSheet: View {
    @EnvironmentObject var pota: PotaParkService
    @EnvironmentObject var manager: LogbookManager
    @EnvironmentObject var dataRoot: AppDataRoot

    @Environment(\.dismiss) private var dismiss

    enum Mode: String, CaseIterable, Identifiable {
        case open = "Bestehende öffnen"
        case new  = "Neue anlegen"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .new
    @State private var role: POTARole = .activator
    @State private var myParkQuery: String = ""
    @State private var myParkSelected: Park?
    @State private var hoppingInput: String = ""    // Komma-Liste weiterer Parks
    @State private var sessionName: String = ""
    @State private var suggestions: [Park] = []
    @State private var creating: Bool = false
    @State private var errorText: String?

    // Parst die Hopping-Eingabe in eine Liste eindeutiger Park-Refs.
    // Validierung gegen die Park-DB ist optional (Hinweis im UI).
    private var hoppingRefs: [String] {
        hoppingInput.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }

    // Alle Parks dieses Logs in Reihenfolge: primärer Park zuerst, danach
    // Hopping-Parks. Duplikate werden entfernt.
    private var allParkRefs: [String] {
        var seen: Set<String> = []
        var out: [String] = []
        if let primary = myParkSelected?.reference.uppercased() {
            if seen.insert(primary).inserted { out.append(primary) }
        }
        for r in hoppingRefs where seen.insert(r).inserted {
            out.append(r)
        }
        return out
    }

    private var existingPOTALogs: [Log] {
        manager.logs
            .filter { $0.type == .pota }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(mode == .open ? "POTA-Session öffnen" : "Neue POTA-Session anlegen")
                .font(.title3.bold())

            if !existingPOTALogs.isEmpty {
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
        .frame(width: 480, height: existingPOTALogs.isEmpty ? 460 : 540)
        .onAppear {
            // Wenn es bestehende POTA-Logs gibt: Default = "Öffnen" anzeigen.
            mode = existingPOTALogs.isEmpty ? .new : .open
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
                    ForEach(existingPOTALogs) { log in
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
            Image(systemName: "tree.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(log.name).font(.callout.bold())
                HStack(spacing: 8) {
                    if let role = log.role {
                        Text(role).font(.caption).foregroundStyle(.blue)
                    }
                    if let park = log.potaParkRef {
                        Text(park).font(.caption.monospaced())
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
                ForEach(POTARole.allCases) { r in
                    Text(r.displayName).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: role) { _, _ in regenerateName() }

            if role == .activator {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mein Park")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TextField("z.B. K-1234 oder Park-Name", text: $myParkQuery)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: myParkQuery) { _, q in
                            suggestions = q.count >= 2 ? pota.search(q) : []
                            if let exact = suggestions.first(where: {
                                $0.reference.caseInsensitiveCompare(q) == .orderedSame
                            }) {
                                myParkSelected = exact
                                regenerateName()
                            } else {
                                myParkSelected = nil
                            }
                        }
                    if !suggestions.isEmpty && myParkSelected == nil {
                        suggestionsList
                    }
                    if let p = myParkSelected {
                        selectedParkRow(p)
                    }
                    if !pota.isLoaded {
                        Text("⚠ Park-DB noch nicht geladen — Einstellungen → Daten → Park-DB laden.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if myParkSelected != nil {
                    hoppingParksSection
                }
            } else {
                Text("Im Hunter-Modus brauchst du keinen eigenen Park. Du loggst Kontakte zu Activatoren — Their Park trägst du beim QSO ein.")
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

    // Hopping-Parks: Komma-getrennte Liste. Keine Autocomplete, weil der User
    // bei Hopping die Refs in der Regel schon kennt — Validierung gegen die
    // Park-DB nur als grüner Haken / oranges Warn-Icon.
    private var hoppingParksSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Weitere Parks (Hopping)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("optional, Komma-getrennt")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            TextField("z.B. K-5678, HB-0042", text: $hoppingInput)
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
        let known = pota.park(forReference: ref) != nil
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
              ? (pota.park(forReference: ref)?.name ?? ref)
              : "Park nicht in der DB gefunden — wird trotzdem gespeichert")
    }

    private var canCreate: Bool {
        if role == .activator && myParkSelected == nil { return false }
        return !sessionName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var suggestionsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(suggestions) { p in
                    Button {
                        myParkSelected = p
                        myParkQuery = p.reference
                        suggestions = []
                        regenerateName()
                    } label: {
                        HStack {
                            Text(p.reference).font(.caption.monospaced()).frame(width: 90, alignment: .leading)
                            Text(p.name).font(.caption).lineLimit(1)
                            Spacer()
                            if let loc = p.locationDesc {
                                Text(loc).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
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
        .frame(maxHeight: 110)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func selectedParkRow(_ p: Park) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            VStack(alignment: .leading) {
                Text("\(p.reference) — \(p.name)").font(.caption.bold())
                if let loc = p.locationDesc { Text(loc).font(.caption2).foregroundStyle(.secondary) }
            }
            Spacer()
            Button("Ändern") {
                myParkSelected = nil
                myParkQuery = ""
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
            if let p = myParkSelected {
                sessionName = "POTA \(p.reference) \(date)"
            } else {
                sessionName = "POTA Activator \(date)"
            }
        case .hunter:
            sessionName = "POTA Hunter \(date)"
        }
    }

    private func createSession() {
        creating = true
        defer { creating = false }
        errorText = nil

        var log = Log(
            id: UUID(),
            name: sessionName.trimmingCharacters(in: .whitespaces),
            type: .pota,
            startDate: Date(),
            createdAt: Date()
        )
        log.role = role.rawValue
        log.potaParkRef = role == .activator ? myParkSelected?.reference : nil
        // Multi-Park-Hopping nur setzen, wenn echt > 1 Park gewählt wurde.
        // Single-Park-Aktivierungen lassen potaParkRefs = nil, damit
        // bestehende Lesepfade (Sidebar, ADIF) unverändert weiterlaufen.
        if role == .activator, allParkRefs.count > 1 {
            log.potaParkRefs = allParkRefs.joined(separator: ",")
        }

        manager.createLog(log)
        if manager.currentLogID == log.id {
            dismiss()
        } else {
            errorText = "Konnte Log nicht anlegen."
        }
    }
}
