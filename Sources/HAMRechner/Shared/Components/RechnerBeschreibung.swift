import SwiftUI

// MARK: - Markdown-Section Modell

private struct MDSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String

    /// Inline-Markdown (Bold, Italic, Code, Links) wird gerendert,
    /// Blockstrukturen (Listen, Absätze) bleiben über den Textfluss erhalten.
    var attributedBody: AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        return (try? AttributedString(markdown: body, options: options))
            ?? AttributedString(body)
    }
}

// MARK: - View

/// Lädt eine Markdown-Datei aus dem App-Bundle (`Content/<resourceName>.md`)
/// und rendert jede `## Section` als eigene SectionCard.
///
/// Single Source of Truth — die gleichen Markdown-Dateien werden auch
/// von der Web-Version gelesen (siehe `web-vue/src/components/RechnerBeschreibung.vue`).
struct RechnerBeschreibung: View {
    let resourceName: String

    private var sections: [MDSection] { Self.loadSections(named: resourceName) }

    var body: some View {
        if !sections.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(sections) { section in
                    SectionCard(title: section.title) {
                        Text(section.attributedBody)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: Loader

    private static func loadSections(named name: String) -> [MDSection] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return parseSections(content)
    }

    /// Splittet Markdown in Sections an `## ` Headern.
    /// Top-Level `# ` wird übersprungen (Page-Titel kommt aus navigationTitle).
    private static func parseSections(_ md: String) -> [MDSection] {
        var sections: [MDSection] = []
        var currentTitle: String? = nil
        var currentBody: [String] = []

        for rawLine in md.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix("## ") {
                if let title = currentTitle {
                    sections.append(.init(title: title, body: joinBody(currentBody)))
                }
                currentTitle = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentBody = []
            } else if line.hasPrefix("# ") {
                continue   // Page-Titel ignorieren
            } else {
                currentBody.append(line)
            }
        }
        if let title = currentTitle {
            sections.append(.init(title: title, body: joinBody(currentBody)))
        }
        return sections
    }

    private static func joinBody(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
