import SwiftUI

struct ResultRow: View {
    let label: String
    let value: String
    var unit: String = ""
    var highlight: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .fontWeight(highlight ? .bold : .regular)
                    .foregroundStyle(highlight ? Color.accentColor : Color.primary)
                if !unit.isEmpty {
                    Text(unit)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        GroupBox(title) {
            content
                .padding(.top, 4)
        }
    }
}
