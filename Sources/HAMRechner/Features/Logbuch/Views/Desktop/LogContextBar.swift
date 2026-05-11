import SwiftUI

// Tab-Context-Bar für den »Log«-Tab. Filter über Call, Band, Mode, Country
// + Status-Zeile mit Anzahl/Pfad.
struct LogContextBar: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var manager: LogbookManager

    @Binding var filterCall: String
    @Binding var filterBand: String
    @Binding var filterMode: String
    @Binding var filterCountry: String

    let totalCount: Int
    let filteredCount: Int

    private var theme: AppTheme { themeManager.theme }

    private var hasFilter: Bool {
        !filterCall.isEmpty || !filterBand.isEmpty
            || !filterMode.isEmpty || !filterCountry.isEmpty
    }

    private var currentLog: Log? {
        guard let id = manager.currentLogID else { return nil }
        return manager.logs.first(where: { $0.id == id })
    }

    private var statusText: String {
        let fileName = currentLog.flatMap { manager.fileURL(for: $0)?.lastPathComponent } ?? ""
        if hasFilter && filteredCount != totalCount {
            return "\(fileName) · \(filteredCount) / \(totalCount) QSOs"
        }
        return "\(fileName) · \(totalCount) QSO\(totalCount == 1 ? "" : "s")"
    }

    var body: some View {
        TabContextBarShell {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                    .foregroundStyle(theme.textDim)
                filterField("Call", text: $filterCall, width: 110, monospaced: true)
                filterField("Band", text: $filterBand, width: 70)
                filterField("Mode", text: $filterMode, width: 70)
                filterField("Country", text: $filterCountry, width: 110)
                if hasFilter {
                    Button {
                        filterCall = ""; filterBand = ""
                        filterMode = ""; filterCountry = ""
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Filter zurücksetzen")
                        }
                        .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.accentBlue)
                }
            }
        }
    }

    private func filterField(_ placeholder: String,
                             text: Binding<String>,
                             width: CGFloat,
                             monospaced: Bool = false) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(monospaced
                  ? .system(.caption, design: .monospaced)
                  : .caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(width: width)
            .background(theme.bgCard2)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(theme.separator.opacity(0.5), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// Gemeinsame Hülle für alle Tab-Context-Bars (konsistente Höhe, Padding,
// Background, Separator-Linie).
struct TabContextBarShell<Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ViewBuilder var content: () -> Content

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .background(theme.bgPanel)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(theme.separator)
                    .frame(height: 1)
            }
    }
}
