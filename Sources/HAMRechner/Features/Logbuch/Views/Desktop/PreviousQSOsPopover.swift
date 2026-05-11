import SwiftUI

// Popover-Inhalt für den Previous-Button: zeigt alle früheren QSOs zum
// aktuellen Call über ALLE bekannten Logbücher.
struct PreviousQSOsPopover: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager

    let call: String

    private var theme: AppTheme { themeManager.theme }

    private var matches: [QSOMatch] {
        manager.findQSOs(forCall: call)
    }

    private var distinctLogs: Int {
        Set(matches.map(\.logID)).count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(theme.separator)
            content
        }
        .frame(width: 420, height: 360)
        .background(theme.bgCard)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(theme.accentBlue)
            Text("Frühere QSOs mit")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
            Text(call.uppercased())
                .font(.subheadline.monospaced().weight(.bold))
                .foregroundStyle(theme.accentBlue)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if matches.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 30))
                    .foregroundStyle(theme.textDim)
                Text("Keine früheren QSOs")
                    .font(.callout)
                    .foregroundStyle(theme.textSecondary)
                Text("Dieser Call kommt in keinem deiner Logs vor.")
                    .font(.caption)
                    .foregroundStyle(theme.textDim)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                summary
                Divider().background(theme.separator)
                matchList
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 6) {
            Text("\(matches.count) Eintrag\(matches.count == 1 ? "" : "e")")
                .foregroundStyle(theme.textPrimary)
            Text("·")
                .foregroundStyle(theme.textDim)
            Text("\(distinctLogs) Log\(distinctLogs == 1 ? "" : "s")")
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(theme.bgPanel)
    }

    private var matchList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(matches) { match in
                    matchRow(match)
                    Divider()
                        .background(theme.separator.opacity(0.4))
                        .padding(.horizontal, 6)
                }
            }
        }
    }

    private func matchRow(_ m: QSOMatch) -> some View {
        let q = m.qso
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(formatUTC(q.datetime))
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(theme.textPrimary)
                Text(q.band)
                    .font(.caption.bold())
                    .foregroundStyle(theme.accentBlue)
                Text(q.mode)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Text(String(format: "%.3f MHz", q.frequencyMHz))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(theme.textDim)
                Spacer()
                Text("\(q.rstSent) / \(q.rstReceived)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
            }
            HStack(spacing: 6) {
                Image(systemName: "book.closed")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
                Text(m.logName)
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
                if let name = q.name, !name.isEmpty {
                    Text("· \(name)")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                }
                if let qth = q.qth, !qth.isEmpty {
                    Text("· \(qth)")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                }
                Spacer()
                statusBadge(q)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func statusBadge(_ q: QSO) -> some View {
        if q.lotwConfirmed || q.eqslConfirmed {
            Text("bestätigt")
                .font(.caption2.bold())
                .foregroundStyle(theme.accentGreen)
        } else if q.lotwSent || q.eqslSent || q.clublogSent {
            Text("gesendet")
                .font(.caption2)
                .foregroundStyle(theme.accentYellow)
        }
    }

    private func formatUTC(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}
