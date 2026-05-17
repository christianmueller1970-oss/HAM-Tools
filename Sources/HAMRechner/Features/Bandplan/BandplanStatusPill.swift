import SwiftUI

// Kleine Pille die live anzeigt, ob die aktuelle Frequenz+Mode-Kombi im
// IARU-R1-Bandplan zulässig ist. Wird in den QSO-Forms unter dem
// Frequenz-Pill bzw. in der Status-Bar eingeblendet.
//
// Drei Zustände:
// - Grün ✓   — Frequenz im Band UND Mode passt zum Sub-Segment
// - Orange ⚠ — Frequenz im Band, aber falsches Mode-Subsegment
// - Rot ❌   — Frequenz außerhalb aller Amateurfunkbänder
//
// Bei Frequenz ≤ 0 (TRX/Settings noch nicht initialisiert) wird gar
// nichts angezeigt — wir wollen nicht permanent eine rote Warnung
// blinken lassen, solange noch keine echte Frequenz im RadioState steht.
struct BandplanStatusPill: View {
    let frequencyMHz: Double
    let mode: String

    var body: some View {
        guard frequencyMHz > 0 else { return AnyView(EmptyView()) }
        let result = BandplanChecker.check(frequencyMHz: frequencyMHz, mode: mode)
        return AnyView(pill(for: result))
    }

    @ViewBuilder
    private func pill(for result: BandplanChecker.Result) -> some View {
        switch result {
        case .ok(let band, let sub):
            badge(icon: "checkmark.circle.fill",
                  iconColor: .green,
                  text: band,
                  detail: sub,
                  background: Color.green.opacity(0.12))
        case .wrongCategory(let band, let expected, let sub):
            badge(icon: "exclamationmark.triangle.fill",
                  iconColor: .orange,
                  text: "\(band) · falsches Subsegment",
                  detail: "Erwartet: \(expected) · \(sub)",
                  background: Color.orange.opacity(0.15))
        case .outOfBand:
            badge(icon: "xmark.octagon.fill",
                  iconColor: .red,
                  text: "Außerhalb Amateurfunkband",
                  detail: nil,
                  background: Color.red.opacity(0.15))
        }
    }

    private func badge(icon: String,
                       iconColor: Color,
                       text: String,
                       detail: String?,
                       background: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 0) {
                Text(text)
                    .font(.caption.weight(.medium))
                if let d = detail {
                    Text(d)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .help(detail ?? text)
    }
}
