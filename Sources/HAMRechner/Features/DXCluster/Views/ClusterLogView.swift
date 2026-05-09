import SwiftUI

struct ClusterLogView: View {
    let messages: [String]
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "terminal")
                    .font(.caption)
                    .foregroundStyle(theme.logText)
                Text("Cluster-Log")
                    .font(.caption.bold())
                    .foregroundStyle(theme.logText)
                Spacer()
                Text("← Stash-Griff ziehen zum Anpassen")
                    .font(.caption2)
                    .foregroundStyle(theme.logText.opacity(0.5))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.bgLog)

            Divider().background(theme.logText.opacity(0.2))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { i, msg in
                            Text(msg)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(theme.logText)
                                .textSelection(.enabled)
                                .id(i)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .onChange(of: messages.count) {
                    if let last = messages.indices.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
            .background(theme.bgLog)
        }
        .frame(minHeight: 100)
    }
}
