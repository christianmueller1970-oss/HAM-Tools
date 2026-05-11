import SwiftUI

struct BandplanView: View {
    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.theme }

    @State private var data: BandplanData = BandplanLoader.load()
    @State private var filterType: String = "alle"
    @State private var filterContest: Bool = false
    @State private var filterWarc: Bool = false
    @State private var filterDigi: Bool = false
    @State private var lookupFreq: String = ""
    @State private var expandedBandID: String? = nil

    private let typeFilters: [(id: String, label: String)] = [
        ("alle", "Alle Bänder"),
        ("lf",   "LF / MF"),
        ("hf",   "KW (HF)"),
        ("vhf",  "UKW (VHF)"),
        ("uhf",  "UHF"),
        ("shf",  "SHF (Mikro)")
    ]

    private var filteredBands: [Band] {
        data.bands.filter { b in
            if filterType != "alle" {
                if filterType == "lf" {
                    if b.type != "lf" && b.type != "mf" { return false }
                } else if b.type != filterType { return false }
            }
            if filterContest && !b.contest { return false }
            if filterWarc {
                let isWarc = b.iaru.contains("WARC") || b.iaru.contains("WRC")
                if !isWarc { return false }
            }
            if filterDigi && !b.digi { return false }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            filterBar
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(filteredBands) { band in
                        bandCard(band)
                    }
                    legendBar
                        .padding(.top, 12)
                    Text("Quelle: funkwelt-bandguide · IARU R1 Band Plans + BAKOM/NaFV (Schweiz). Visualisierung schematisch — verbindlich ist immer der offizielle Bandplan.")
                        .font(.caption2)
                        .foregroundStyle(theme.textDim)
                        .padding(.top, 8)
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgApp)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("IARU R1 Bandplan")
                    .font(.title2.bold())
                    .foregroundStyle(theme.textPrimary)
                Text("Amateurfunk-Frequenzzuteilungen Region 1 · Schweiz")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textSecondary)
                TextField("Frequenz in kHz (z.B. 14074)", text: $lookupFreq)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .onSubmit { lookup() }
                Button("Lookup") { lookup() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.bgPanel)
    }

    // MARK: Filter

    private var filterBar: some View {
        HStack(spacing: 10) {
            ForEach(typeFilters, id: \.id) { f in
                filterChip(label: f.label, active: filterType == f.id, color: theme.accentBlue) {
                    filterType = f.id
                }
            }
            Divider().frame(height: 18)
            filterChip(label: "Contest", active: filterContest, color: theme.accentOrange) { filterContest.toggle() }
            filterChip(label: "WARC",    active: filterWarc,    color: theme.accentGreen)  { filterWarc.toggle() }
            filterChip(label: "Digi",    active: filterDigi,    color: Color(hex: "#A855F7")) { filterDigi.toggle() }
            Spacer()
            Text("\(filteredBands.count) Bänder")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.bgPanel)
    }

    private func filterChip(label: String, active: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(active ? color.opacity(0.85) : theme.bgSubPanel)
                .foregroundStyle(active ? .white : theme.textSecondary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: Band Card

    private func bandCard(_ band: Band) -> some View {
        let isOpen = expandedBandID == band.id
        return VStack(alignment: .leading, spacing: 0) {
            // Kompakter Bar-Header (immer sichtbar)
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    expandedBandID = isOpen ? nil : band.id
                }
            } label: {
                HStack(spacing: 12) {
                    Text(band.name)
                        .font(.headline.bold())
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 60, alignment: .leading)
                    barView(band)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(band.freq)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(theme.textSecondary)
                        Text(band.leistung)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.textDim)
                    }
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textDim)
                }
                .padding(12)
                .background(theme.bgPanel)
            }
            .buttonStyle(.plain)

            if isOpen {
                Divider()
                detailView(band)
                    .padding(12)
                    .background(theme.bgSubPanel)
            }
        }
        .background(theme.bgPanel)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isOpen ? theme.accentBlue.opacity(0.6) : Color.clear, lineWidth: 1)
        )
    }

    private func barView(_ band: Band) -> some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(Array(band.segments.enumerated()), id: \.offset) { idx, seg in
                    Rectangle()
                        .fill(seg.swiftColor)
                        .overlay(
                            Text(seg.label)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 4)
                        )
                        .frame(width: max(2, geo.size.width * seg.pct / 100))
                }
            }
            .frame(height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 24)
    }

    private func detailView(_ band: Band) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header-Zeile mit Status, Mode-Chips
            HStack(spacing: 10) {
                Text("\(band.name) Band")
                    .font(.headline.bold())
                    .foregroundStyle(theme.textPrimary)
                Text(band.freq)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                badge(band.zuweisung,
                      bg: band.zuweisung.contains("Sekundär") ? theme.accentYellow.opacity(0.25) : theme.accentBlue.opacity(0.25),
                      fg: band.zuweisung.contains("Sekundär") ? theme.accentYellow : theme.accentBlue)
                badge("Max. \(band.leistung)",
                      bg: theme.bgPanel, fg: theme.textSecondary)
                Spacer()
            }
            FlowLayout(spacing: 6) {
                ForEach(band.modes, id: \.self) { mode in
                    badge(mode, bg: theme.accentBlue.opacity(0.15), fg: theme.accentBlue)
                }
                if band.contest {
                    badge("Contest ✓", bg: theme.accentOrange.opacity(0.2), fg: theme.accentOrange)
                }
            }

            // Beschreibung
            Text("Typische Nutzung:").font(.caption.bold()).foregroundStyle(theme.textSecondary)
            Text(band.typUse).font(.callout).foregroundStyle(theme.textPrimary)
            Text(band.info).font(.callout).foregroundStyle(theme.textSecondary)
            Text("Quelle: \(band.iaru)").font(.caption2).foregroundStyle(theme.textDim)

            // Subsegment-Tabelle
            VStack(spacing: 0) {
                tableHeader
                ForEach(Array(band.subsegments.enumerated()), id: \.offset) { idx, sub in
                    tableRow(sub, even: idx % 2 == 0)
                }
            }
            .background(theme.bgPanel)
            .cornerRadius(6)
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("VON – BIS").frame(width: 130, alignment: .leading)
            Text("BANDBREITE").frame(width: 100, alignment: .leading)
            Text("MODUS").frame(width: 200, alignment: .leading)
            Text("HINWEIS").frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(theme.bgSubPanel)
    }

    private func tableRow(_ sub: BandSubsegment, even: Bool) -> some View {
        let cat = data.categories[sub.cat]
        return HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(formatFreq(sub.von)).font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(cat?.swiftColor ?? theme.textPrimary)
                Text("– \(formatFreq(sub.bis))").font(.system(size: 10))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(width: 130, alignment: .leading)
            Text(sub.bandwidthDisplay).font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 100, alignment: .leading)
            Text(sub.mode).font(.system(size: 11))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 200, alignment: .leading)
            Text(sub.info).font(.system(size: 11))
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(even ? theme.bgPanel : theme.bgSubPanel.opacity(0.4))
    }

    private func badge(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(bg)
            .foregroundStyle(fg)
            .cornerRadius(4)
    }

    // MARK: Legende

    private var legendBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Legende").font(.caption.bold()).foregroundStyle(theme.textSecondary)
            FlowLayout(spacing: 8) {
                ForEach(Array(data.categories.keys.sorted()), id: \.self) { key in
                    let cat = data.categories[key]!
                    HStack(spacing: 4) {
                        Rectangle().fill(cat.swiftColor).frame(width: 14, height: 14).cornerRadius(2)
                        Text(cat.label).font(.caption).foregroundStyle(theme.textPrimary)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(theme.bgPanel)
                    .cornerRadius(4)
                }
            }
        }
    }

    // MARK: Lookup

    private func lookup() {
        let raw = lookupFreq.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let f = Double(raw) else { return }
        if let hit = BandplanLoader.lookup(frequencyKHz: f, in: data) {
            withAnimation { expandedBandID = hit.band.id }
        }
    }

    // MARK: Helpers

    private func formatFreq(_ kHz: Double) -> String {
        if kHz >= 1_000_000 {
            return String(format: "%.3f GHz", kHz / 1_000_000)
        }
        if kHz >= 1000 {
            return String(format: "%.3f MHz", kHz / 1000)
        }
        return kHz.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f kHz", kHz)
            : String(format: "%.1f kHz", kHz)
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x + sz.width > maxWidth {
                x = 0; y += lineH + spacing; lineH = 0
            }
            x += sz.width + spacing
            lineH = max(lineH, sz.height)
        }
        return CGSize(width: maxWidth, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX {
                x = bounds.minX; y += lineH + spacing; lineH = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            lineH = max(lineH, sz.height)
        }
    }
}
