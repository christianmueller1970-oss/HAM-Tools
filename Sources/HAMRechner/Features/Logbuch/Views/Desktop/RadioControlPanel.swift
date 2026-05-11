import SwiftUI

// Platzhalter für CAT/Radio-Steuerung (Phase 5: Hamlib-Subprocess).
// Visuell schon im Look — Funktion folgt.
struct RadioControlPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var radio: RadioState

    @State private var freqText: String = ""
    @FocusState private var freqFocused: Bool

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        VStack(spacing: 8) {
            header

            trxSelector

            frequencyDisplay

            controlGrid

            sMeter

            statusBadges

            Spacer(minLength: 0)

            footer
        }
        .padding(10)
        .background(theme.bgCard)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear { freqText = formatFreq(radio.frequencyMHz) }
        .onChange(of: radio.frequencyMHz) { _, new in
            // Externe Updates (z.B. künftig CAT) → Anzeige aktualisieren,
            // außer der User tippt gerade rein.
            if !freqFocused { freqText = formatFreq(new) }
        }
    }

    private func formatFreq(_ mhz: Double) -> String {
        String(format: "%.3f", mhz)
    }
    private func commitFreqText() {
        let s = freqText.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(s), v > 0 else {
            freqText = formatFreq(radio.frequencyMHz)
            return
        }
        radio.frequencyMHz = v
        radio.source = radio.catConnected ? .cat : .manual
        freqText = formatFreq(v)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.caption)
                .foregroundStyle(theme.accentBlue)
            Text("Radio / CAT")
                .font(.caption.bold())
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text("Phase 5")
                .font(.caption2)
                .foregroundStyle(theme.accentOrange)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(theme.accentOrange.opacity(0.15))
                .clipShape(Capsule())
        }
    }

    // MARK: TRX-Picker

    private var trxSelector: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.dashed")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            Text("Kein Radio aktiv")
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(theme.bgCard2)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(0.6)
    }

    // MARK: Frequenz-Anzeige

    private var frequencyDisplay: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                TextField("14.200", text: $freqText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .focused($freqFocused)
                    .onSubmit { commitFreqText() }
                    .onChange(of: freqFocused) { _, focused in
                        if !focused { commitFreqText() }
                    }
                Text("MHz")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.bgLog)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            // Band + Quelle als kleine Pills darunter
            HStack(spacing: 4) {
                Text(radio.band.isEmpty ? "—" : radio.band)
                    .font(.caption2.bold())
                    .foregroundStyle(theme.accentBlue)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(theme.accentBlue.opacity(0.15))
                    .clipShape(Capsule())
                Spacer()
                Text(radio.catConnected ? "CAT" : "manuell")
                    .font(.caption2)
                    .foregroundStyle(radio.catConnected ? theme.accentGreen : theme.textDim)
            }
        }
    }

    // MARK: VFO / Mode / Split / Keyer

    private var controlGrid: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                pillButton("VFO A")
                pillButton("VFO B")
            }
            HStack(spacing: 4) {
                pillButton("USB", wide: true)
            }
            HStack(spacing: 4) {
                pillButton("Split", iconBefore: "arrow.left.arrow.right")
                pillButton("Keyer", iconBefore: "keyboard")
            }
        }
    }

    private func pillButton(_ label: String,
                            iconBefore: String? = nil,
                            wide: Bool = false) -> some View {
        HStack(spacing: 3) {
            if let iconBefore {
                Image(systemName: iconBefore)
                    .font(.caption2)
            }
            Text(label)
                .font(.caption)
        }
        .foregroundStyle(theme.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(theme.bgCard2)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(theme.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(0.55)
    }

    // MARK: S-Meter

    private var sMeter: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("S-Meter")
                    .font(.caption2.bold())
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text("S0")
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.textDim)
            }
            HStack(spacing: 1) {
                ForEach(0..<14) { i in
                    Rectangle()
                        .fill(theme.bgSubPanel)
                        .frame(height: 6)
                        .overlay(
                            i == 8
                                ? AnyView(Rectangle().fill(theme.separator).frame(width: 1))
                                : AnyView(EmptyView())
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    // MARK: RX / TX / PWR

    private var statusBadges: some View {
        HStack(spacing: 4) {
            statusBadge("RX", on: false, color: theme.accentGreen)
            statusBadge("TX", on: false, color: theme.accentRed)
            statusBadge("PWR", on: false, color: theme.accentYellow)
        }
    }

    private func statusBadge(_ label: String, on: Bool, color: Color) -> some View {
        Text(label)
            .font(.caption2.bold())
            .foregroundStyle(on ? color : theme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .background(on ? color.opacity(0.2) : theme.bgCard2)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .opacity(on ? 1.0 : 0.6)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(theme.textDim)
                .frame(width: 6, height: 6)
            Text("Idle — nicht verbunden")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            Spacer()
        }
    }
}
