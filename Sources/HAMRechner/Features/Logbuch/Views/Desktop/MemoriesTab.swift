import SwiftUI

// Memories-Tab: Schnellzugriffs-Karten für häufige Calls / Sked-Notizen.
// Klick auf eine Karte füllt das QSO-Form (springt zum Log-Tab).
struct MemoriesTab: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var memoryStore: MemoryStore
    @EnvironmentObject var logBridge: LogEntryBridge

    @Binding var searchText: String
    @Binding var showOnlyUpcomingSkeds: Bool

    @State private var editingMemory: Memory? = nil

    private var theme: AppTheme { themeManager.theme }

    private var filteredMemories: [Memory] {
        var result = memoryStore.memories
        if showOnlyUpcomingSkeds {
            let now = Date()
            result = result.filter {
                guard let d = $0.skedDate else { return false }
                return d.timeIntervalSince(now) > -3600 && d.timeIntervalSince(now) < 7 * 86400
            }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.label.localizedCaseInsensitiveContains(searchText)
                || $0.call.localizedCaseInsensitiveContains(searchText)
                || ($0.notes ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        Group {
            if filteredMemories.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .background(theme.bgApp)
        .sheet(item: $editingMemory) { mem in
            NewMemorySheet(existing: mem)
                .environmentObject(themeManager)
                .environmentObject(memoryStore)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "star.slash")
                .font(.system(size: 40))
                .foregroundStyle(theme.textDim)
            Text(memoryStore.memories.isEmpty
                 ? "Noch keine Memories"
                 : "Kein Treffer im Filter")
                .font(.callout.bold())
                .foregroundStyle(theme.textSecondary)
            Text(memoryStore.memories.isEmpty
                 ? "Lege Schnellzugriffs-Karten an für häufige Calls oder Sked-Termine — Klick auf eine Karte füllt das QSO-Form."
                 : "Filter oder Suche zurücksetzen.")
                .font(.caption)
                .foregroundStyle(theme.textDim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 280),
                                         spacing: 10)],
                      spacing: 10) {
                ForEach(filteredMemories) { mem in
                    MemoryCard(memory: mem,
                               onTap: { useMemory(mem) },
                               onEdit: { editingMemory = mem },
                               onPin: { memoryStore.togglePin(mem) },
                               onDelete: { memoryStore.delete(mem) })
                }
            }
            .padding(12)
        }
    }

    private func useMemory(_ m: Memory) {
        memoryStore.markUsed(m)
        logBridge.openInLog(from: m)
    }
}

// MARK: - Memory Card

private struct MemoryCard: View {
    let memory: Memory
    let onTap: () -> Void
    let onEdit: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.theme }

    private var skedStatus: (String, Color)? {
        guard let d = memory.skedDate else { return nil }
        let diff = d.timeIntervalSinceNow
        if diff > 0, diff < 3600 {
            return ("in \(Int(diff/60)) min", theme.accentGreen)
        }
        if diff > 0, diff < 86400 {
            return ("in \(Int(diff/3600)) h", theme.accentBlue)
        }
        if diff > 0, diff < 86400 * 7 {
            return ("in \(Int(diff/86400)) Tagen", theme.accentBlue)
        }
        if diff > -3600 {
            return ("jetzt", theme.accentGreen)
        }
        if diff > -86400 {
            return ("vorbei", theme.textDim)
        }
        return nil
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if memory.pinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(theme.accentYellow)
                            .font(.caption)
                    }
                    Text(memory.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if let (text, color) = skedStatus {
                        Text(text)
                            .font(.caption2.bold())
                            .foregroundStyle(color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }
                Text(memory.call)
                    .font(.title3.monospaced().bold())
                    .foregroundStyle(theme.accentBlue)

                HStack(spacing: 6) {
                    if let band = memory.band, !band.isEmpty {
                        badge(band, color: theme.accentBlue)
                    }
                    if let mode = memory.mode, !mode.isEmpty {
                        badge(mode, color: theme.accentGreen)
                    }
                    if let f = memory.frequencyMHz {
                        Text(String(format: "%.3f MHz", f))
                            .font(.caption.monospaced())
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                if let name = memory.name, !name.isEmpty {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                if let notes = memory.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(theme.textDim)
                        .lineLimit(2)
                }
                if let date = memory.skedDate {
                    Text("Sked: \(formatSked(date))")
                        .font(.caption2.monospaced())
                        .foregroundStyle(theme.textDim)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.bgCard)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(memory.pinned ? theme.accentYellow.opacity(0.6) : theme.separator,
                            lineWidth: memory.pinned ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onPin()
            } label: {
                Label(memory.pinned ? "Pin entfernen" : "Anpinnen",
                      systemImage: memory.pinned ? "pin.slash" : "pin")
            }
            Button {
                onEdit()
            } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func formatSked(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm 'UTC'"
        return f.string(from: d)
    }
}
