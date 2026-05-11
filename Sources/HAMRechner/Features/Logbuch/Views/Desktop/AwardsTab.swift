import SwiftUI

// Awards-Tab im Logbuch. Zeigt aufgeschlüsselt was in den Counter-Pills
// oben in der Tab-Bar summiert ist — DXCC-Liste, WAZ-Grid (40 Zonen),
// WAS-Grid (50 US-States). Sub-Tab-Switcher oben links.
struct AwardsTab: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager
    @Binding var subTab: AwardsSubTab
    @Binding var onlyUnconfirmed: Bool

    enum AwardsSubTab: String, CaseIterable, Identifiable {
        case dxcc = "DXCC"
        case waz  = "WAZ"
        case was  = "WAS"
        var id: String { rawValue }
    }

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        Group {
            switch subTab {
            case .dxcc: dxccView
            case .waz:  wazView
            case .was:  wasView
            }
        }
        .background(theme.bgApp)
    }

    // MARK: - DXCC

    private var dxccView: some View {
        let entries = onlyUnconfirmed
            ? manager.dxccBreakdown.filter { !$0.confirmed }
            : manager.dxccBreakdown
        return Group {
            if entries.isEmpty {
                emptyState(
                    icon: "globe",
                    title: onlyUnconfirmed
                        ? "Keine unbestätigten Länder"
                        : "Noch keine Länder gearbeitet",
                    subtitle: "Sobald QSOs mit Country-Feld eingetragen sind, erscheinen sie hier."
                )
            } else {
                dxccTable(entries)
            }
        }
    }

    private func dxccTable(_ entries: [DXCCAwardEntry]) -> some View {
        Table(entries) {
            TableColumn("Status") { e in
                statusBadge(confirmed: e.confirmed)
            }
            .width(min: 70, ideal: 80)

            TableColumn("Country") { e in
                Text(e.country)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
            }
            .width(min: 140, ideal: 180)

            TableColumn("QSOs") { e in
                Text("\(e.qsoCount)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
            }
            .width(min: 50, ideal: 60)

            TableColumn("Bands") { e in
                Text(e.bands.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .width(min: 120, ideal: 160)

            TableColumn("Modes") { e in
                Text(e.modes.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .width(min: 100, ideal: 130)

            TableColumn("Erster QSO") { e in
                Text(formatDate(e.firstQSO))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.textDim)
            }
            .width(min: 90, ideal: 100)

            TableColumn("Letzter QSO") { e in
                Text(formatDate(e.lastQSO))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.textDim)
            }
            .width(min: 90, ideal: 100)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - WAZ (40 Zonen-Grid)

    private var wazView: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)
        let allZones = Array(1...40)
        return ScrollView {
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(allZones, id: \.self) { z in
                    zoneCell(z)
                }
            }
            .padding(14)
        }
    }

    private func zoneCell(_ zone: Int) -> some View {
        let entry = manager.wazBreakdown.first { $0.zone == zone }
        let worked = entry != nil
        let confirmed = entry?.confirmed == true
        let count = entry?.qsoCount ?? 0

        return VStack(spacing: 2) {
            Text(String(format: "%02d", zone))
                .font(.system(.body, design: .monospaced).weight(.bold))
                .foregroundStyle(
                    confirmed ? theme.accentGreen
                    : worked   ? theme.textPrimary
                               : theme.textDim
                )
            if worked {
                Text("\(count) QSO\(count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            worked ? theme.bgCard : theme.bgCard2
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(confirmed ? theme.accentGreen
                        : worked ? theme.separator
                                 : theme.separator.opacity(0.4),
                        lineWidth: confirmed ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .opacity(worked ? 1.0 : 0.55)
    }

    // MARK: - WAS (US-States)

    private var wasView: some View {
        let entries = manager.wasBreakdown
        return Group {
            if entries.isEmpty {
                emptyState(
                    icon: "map",
                    title: "Keine US-States gearbeitet",
                    subtitle: "WAS zählt US-States. Sobald QSOs mit »United States« als Country + State im QTH-Feld eingetragen sind, erscheinen sie hier."
                )
            } else {
                Table(entries) {
                    TableColumn("Status") { e in
                        statusBadge(confirmed: e.confirmed)
                    }
                    .width(min: 70, ideal: 80)

                    TableColumn("State") { e in
                        Text(e.state)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("QSOs") { e in
                        Text("\(e.qsoCount)")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 60, ideal: 80)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Helpers

    private func statusBadge(confirmed: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: confirmed ? "checkmark.circle.fill" : "circle.dashed")
                .font(.caption2)
            Text(confirmed ? "✓ bestät." : "gearbeit.")
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(confirmed ? theme.accentGreen : theme.accentYellow)
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 38))
                .foregroundStyle(theme.textDim)
            Text(title)
                .font(.callout.bold())
                .foregroundStyle(theme.textSecondary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(theme.textDim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}
