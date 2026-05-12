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

    private static let availableModes = [
        "USB", "LSB", "CW", "CWR", "AM", "FM", "RTTY", "RTTYR", "PKTUSB", "PKTLSB"
    ]

    private var controlGrid: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                actionPillButton("VFO A",
                                 active: isVfoA,
                                 isEnabled: radio.catConnected) {
                    Task { await cat.setVFO("VFOA") }
                }
                actionPillButton("VFO B",
                                 active: isVfoB,
                                 isEnabled: radio.catConnected) {
                    Task { await cat.setVFO("VFOB") }
                }
            }
            modeMenu
            HStack(spacing: 4) {
                actionPillButton("Split",
                                 iconBefore: "arrow.left.arrow.right",
                                 active: radio.splitOn,
                                 isEnabled: radio.catConnected) {
                    Task { await cat.setSplit(on: !radio.splitOn,
                                              txVfo: radio.splitTxVfo) }
                }
                pillButton("Keyer", iconBefore: "keyboard")  // Phase-tagged Placeholder
            }
        }
    }

    private var isVfoA: Bool { radio.activeVFO.uppercased().contains("A") || radio.activeVFO.uppercased().contains("MAIN") }
    private var isVfoB: Bool { radio.activeVFO.uppercased().contains("B") || radio.activeVFO.uppercased().contains("SUB") }

    private var modeMenu: some View {
        let current = radio.hamlibMode.isEmpty ? "—" : radio.hamlibMode
        return Menu {
            ForEach(Self.availableModes, id: \.self) { m in
                Button(m) { Task { await cat.setHamlibMode(m) } }
            }
        } label: {
            HStack(spacing: 3) {
                Text(current)
                    .font(.caption)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.bgCard2)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.separator, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .opacity(radio.catConnected ? 1.0 : 0.55)
        }
        .menuStyle(.borderlessButton)
        .disabled(!radio.catConnected)
    }

    // Klickbarer Button mit Active-State (Akzentfarbe wenn aktiv).
    private func actionPillButton(_ label: String,
                                  iconBefore: String? = nil,
                                  active: Bool = false,
                                  isEnabled: Bool = true,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let iconBefore {
                    Image(systemName: iconBefore)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption)
            }
            .foregroundStyle(active ? theme.accentBlue : theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(active ? theme.accentBlue.opacity(0.15) : theme.bgCard2)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(active ? theme.accentBlue : theme.separator, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .opacity(isEnabled ? 1.0 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    // Read-only Pill (für Keyer-Placeholder etc).
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
        let rel = radio.signalStrengthRelDB
        let units = Self.sUnits(fromRelDB: rel)
        let label = Self.sLabel(fromRelDB: rel)
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("S-Meter")
                    .font(.caption2.bold())
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text(label)
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.textDim)
            }
            HStack(spacing: 1) {
                ForEach(0..<14) { i in
                    Rectangle()
                        .fill(Self.sSegmentColor(index: i,
                                                 litCount: units,
                                                 dim: theme.bgSubPanel))
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

    // S-Meter-Mathe — Hamlib liefert dB relativ zu S9 (S9 = 0, S0 ≈ −54,
    // S9+x = +x). Skala: 6 dB pro S-Stufe unterhalb S9, 10 dB pro Schritt
    // oberhalb. 14 Segmente: S0…S8 (9 grüne), S9 (gelb), S9+10/20/30/40/50 (rot).
    private static func sUnits(fromRelDB rel: Int) -> Int {
        if rel >= 0 {
            return max(0, min(14, 9 + rel / 10))
        }
        // rel negativ → unter S9. /6 ist negativ → addiert zu 9 ergibt 0..9.
        return max(0, min(14, 9 + rel / 6))
    }
    private static func sLabel(fromRelDB rel: Int) -> String {
        if rel >= 0 {
            let rounded = (rel / 10) * 10
            return rounded > 0 ? "S9+\(rounded)" : "S9"
        }
        let s = max(0, min(9, 9 + rel / 6))
        return "S\(s)"
    }
    private static func sSegmentColor(index: Int, litCount: Int, dim: Color) -> Color {
        guard index < litCount else { return dim }
        if index < 9 { return .green }
        if index < 10 { return .yellow }
        return .red
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
