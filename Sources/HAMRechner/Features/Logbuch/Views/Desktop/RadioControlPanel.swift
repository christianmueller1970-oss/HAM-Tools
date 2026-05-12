import SwiftUI

// Platzhalter für CAT/Radio-Steuerung (Phase 5: Hamlib-Subprocess).
// Visuell schon im Look — Funktion folgt.
struct RadioControlPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var radio: RadioState
    @EnvironmentObject var catSettings: CATSettings
    @EnvironmentObject var cat: CATController

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
            // Externe Updates (CAT-Poll oder andere). Bei aktivem CAT
            // IMMER aktualisieren — der CAT-Poll ist die Wahrheit, nicht
            // der TextField. Nur bei manuellem Modus respektieren wir den
            // Focus, damit der User in Ruhe tippen kann.
            if radio.catConnected || !freqFocused {
                freqText = formatFreq(new)
            }
        }
        .onChange(of: radio.catConnected) { _, isOn in
            // Wenn CAT aktiv wird und der TextField den Focus hat,
            // Focus rausnehmen, damit auch Tastatur-Eingaben nicht in
            // einen schreibgeschützten Eingabebereich gehen.
            if isOn { freqFocused = false }
        }
    }

    // Ham-Style Frequenz-Format: MHz.kHz.10Hz mit Punkt-Separatoren.
    // Beispiel: 7.164.390 Hz → "7.164.39"
    private func formatFreq(_ mhz: Double) -> String {
        let totalHz = Int64((mhz * 1_000_000).rounded())
        let mhzPart = totalHz / 1_000_000
        let khzPart = (totalHz % 1_000_000) / 1_000
        let tenHz   = (totalHz % 1_000) / 10
        return String(format: "%d.%03d.%02d", mhzPart, khzPart, tenHz)
    }
    private func commitFreqText() {
        guard let v = parseFreqText(freqText), v > 0 else {
            freqText = formatFreq(radio.frequencyMHz)
            return
        }
        radio.frequencyMHz = v
        radio.source = radio.catConnected ? .cat : .manual
        freqText = formatFreq(v)
    }

    // Akzeptiert sowohl klassische Eingabe ("7.164", "7,164", "7.16439")
    // als auch das Ham-Style-Format mit doppeltem Punkt ("7.164.39").
    private func parseFreqText(_ raw: String) -> Double? {
        let cleaned = raw.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        let parts = cleaned.split(separator: ".")
        switch parts.count {
        case 1, 2:
            return Double(cleaned)
        case 3:
            guard let mhz = Int(parts[0]),
                  let khz = Int(parts[1]),
                  let tenHz = Int(parts[2]) else { return nil }
            return Double(mhz) + Double(khz) / 1_000.0 + Double(tenHz) / 100_000.0
        default:
            return nil
        }
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
        let isOn = radio.catConnected
        let cfgName = catSettings.activeConfig?.name ?? ""
        let modelName = TRXProfileLoader.shared
            .profile(forID: catSettings.activeConfig?.profileID ?? "")?
            .displayName ?? ""
        let displayText: String = {
            if isOn {
                if !cfgName.isEmpty && cfgName != modelName {
                    return "\(cfgName) · \(modelName)"
                }
                return modelName.isEmpty ? "CAT aktiv" : modelName
            }
            return "Kein Radio aktiv"
        }()
        return HStack(spacing: 6) {
            Image(systemName: isOn ? "antenna.radiowaves.left.and.right" : "circle.dashed")
                .font(.caption2)
                .foregroundStyle(isOn ? Color.green : theme.textDim)
            Text(displayText)
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
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
                TextField("14.200.00", text: $freqText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .focused($freqFocused)
                    .onSubmit { commitFreqText() }
                    .onChange(of: freqFocused) { _, focused in
                        if !focused { commitFreqText() }
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                Text("MHz")
                    .font(.caption2)
                    .foregroundStyle(theme.textDim)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
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
