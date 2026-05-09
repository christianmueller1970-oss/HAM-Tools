import SwiftUI
import Charts

struct SWRSimulatorView: View {
    @State private var swr: Double = 1.5
    @State private var leistungText: String = "100"
    @State private var z0: Double = 50
    @State private var swrMax: Double = 5.0

    private var leistung: Double { Double(leistungText.replacingOccurrences(of: ",", with: ".")) ?? 100 }

    private var ergebnis: SWRErgebnis {
        SWRErgebnis(swr: swr, eingangsleistungW: max(leistung, 0.001), z0: z0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                swrAnzeigeBereich
                balkenBereich
                kenngroessenBereich
                warnBereich
                kurvenBereich
            }
            .padding(24)
        }
        .navigationTitle("SWR-Simulator")
    }

    // MARK: - Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Parameter") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sendeleistung").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("W", text: $leistungText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                            Text("W").foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Systemimpedanz Z₀").font(.caption).foregroundStyle(.secondary)
                        Picker("Z₀", selection: $z0) {
                            Text("50 Ω").tag(50.0)
                            Text("75 Ω").tag(75.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Slider-Maximum").font(.caption).foregroundStyle(.secondary)
                        Picker("Max", selection: $swrMax) {
                            Text("SWR 5").tag(5.0)
                            Text("SWR 10").tag(10.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                        .onChange(of: swrMax) {
                            if swr > swrMax { swr = swrMax }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("SWR")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("1 : \(swr, specifier: "%.2f")")
                            .font(.system(.callout, design: .monospaced).bold())
                            .foregroundStyle(ergebnis.farbe)
                            .animation(.easeOut(duration: 0.15), value: swr)
                    }
                    Slider(value: $swr, in: 1.0...swrMax, step: 0.05)
                        .tint(ergebnis.farbe)
                        .animation(.easeOut(duration: 0.15), value: swr)

                    HStack {
                        Text("1:1").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        ForEach([1.5, 2.0, 3.0, 4.0], id: \.self) { mark in
                            if mark <= swrMax {
                                Button("1:\(mark, specifier: "%.1f")") { swr = mark }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                    .tint(abs(swr - mark) < 0.03 ? .accentColor : nil)
                                Spacer()
                            }
                        }
                        Text("1:\(swrMax, specifier: "%.0f")").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Grosse SWR-Anzeige

    private var swrAnzeigeBereich: some View {
        let r = ergebnis
        return ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(r.farbe.opacity(0.4), lineWidth: 2)

            VStack(spacing: 4) {
                Text("Aktuelles SWR")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("1 : \(swr, specifier: "%.2f")")
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundStyle(r.farbe)
                    .animation(.easeOut(duration: 0.15), value: swr)
                HStack(spacing: 6) {
                    Image(systemName: r.bewertung.icon)
                    Text(r.bewertung.label)
                        .fontWeight(.semibold)
                }
                .font(.callout)
                .foregroundStyle(r.farbe)
                .animation(.none, value: swr)

                Rectangle()
                    .fill(r.farbe)
                    .frame(height: 4)
                    .clipShape(Capsule())
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                    .animation(.easeOut(duration: 0.2), value: r.farbe.description)
            }
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Balkendiagramm

    private var balkenBereich: some View {
        let r = ergebnis
        return SectionCard(title: "Leistungsverteilung") {
            VStack(spacing: 10) {
                BalkenZeile(
                    label: "Vorlauf",
                    wert: String(format: "%.1f W", leistung),
                    prozent: 1.0,
                    farbe: .blue
                )
                BalkenZeile(
                    label: "Rücklauf",
                    wert: String(format: "%.2f W", r.ruecklaufW),
                    prozent: r.gamma2,
                    farbe: .red
                )
                BalkenZeile(
                    label: "Verlust",
                    wert: String(format: "%.1f %%", r.verlustProzent),
                    prozent: r.gamma2,
                    farbe: .orange
                )
            }
        }
    }

    // MARK: - Kenngrößen

    private var kenngroessenBereich: some View {
        let r = ergebnis
        return SectionCard(title: "Kenngrößen") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                KenngroesseKachel(
                    wert: String(format: "%.2f W", r.ausgangsleistungW),
                    label: "An der Antenne",
                    hervorheben: true,
                    farbe: r.farbe
                )
                KenngroesseKachel(
                    wert: String(format: "%.4f", r.gamma),
                    label: "Reflexionsfaktor Γ"
                )
                KenngroesseKachel(
                    wert: r.rueckflussdaempfungDB.isFinite
                        ? String(format: "%.1f dB", r.rueckflussdaempfungDB)
                        : "∞",
                    label: "Rückflussdämpfung"
                )
                KenngroesseKachel(
                    wert: String(format: "%.2f dB", r.mismatchVerlustDB),
                    label: "Mismatch-Verlust"
                )
                KenngroesseKachel(
                    wert: String(format: "%.0f Ω", r.zLast),
                    label: "Z-Last (\(Int(z0)) Ω System)"
                )
                KenngroesseKachel(
                    wert: String(format: "%.1f %%", 100 - r.verlustProzent),
                    label: "Effizienz"
                )
            }
        }
    }

    // MARK: - Warnung

    @ViewBuilder
    private var warnBereich: some View {
        let r = ergebnis
        if r.bewertung != .gut {
            HStack(spacing: 12) {
                Image(systemName: r.bewertung.icon)
                    .foregroundStyle(r.farbe)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(warnTitel(r.bewertung)).fontWeight(.semibold)
                    Text(warnText(r.bewertung)).font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(r.bewertung.hintergrund)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func warnTitel(_ b: SWRBewertung) -> String {
        switch b {
        case .mittel: return "Leichte Fehlanpassung"
        case .hoch:   return "Hoher SWR – Tuner empfohlen"
        case .gefahr: return "Gefahr für die Endstufe!"
        case .gut:    return ""
        }
    }

    private func warnText(_ b: SWRBewertung) -> String {
        switch b {
        case .mittel: return "Für die meisten Betriebsarten noch akzeptabel. Ein Tuner verbessert die Effizienz."
        case .hoch:   return "Die Fehlanpassung verursacht messbare Leistungsverluste und belastet den PA."
        case .gefahr: return "Viele Transceiver schalten bei SWR > 4 die Leistung automatisch zurück. Sofortige Anpassung erforderlich."
        case .gut:    return ""
        }
    }

    // MARK: - SWR-Kurve

    private var kurvenBereich: some View {
        SectionCard(title: "Effizienz vs. SWR") {
            let kurve = (0...100).map { i -> (Double, Double) in
                let s = 1.0 + Double(i) / 100.0 * (swrMax - 1.0)
                let g = (s - 1) / (s + 1)
                return (s, (1 - g * g) * 100)
            }

            Chart {
                ForEach(kurve, id: \.0) { s, eff in
                    AreaMark(
                        x: .value("SWR", s),
                        y: .value("Effizienz %", eff)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green.opacity(0.3), .red.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(x: .value("SWR", s), y: .value("Effizienz %", eff))
                        .foregroundStyle(Color.accentColor)
                }

                // Marker für aktuelles SWR
                let aktEff = (1 - ergebnis.gamma2) * 100
                RuleMark(x: .value("SWR", swr))
                    .foregroundStyle(ergebnis.farbe.opacity(0.6))
                    .lineStyle(StrokeStyle(dash: [4]))
                PointMark(x: .value("SWR", swr), y: .value("Effizienz %", aktEff))
                    .foregroundStyle(ergebnis.farbe)
                    .symbolSize(100)
            }
            .chartXAxisLabel("SWR")
            .chartYAxisLabel("%")
            .chartYScale(domain: 0...100)
            .chartXScale(domain: 1...swrMax)
            .frame(height: 160)
        }
    }
}

// MARK: - Hilfs-Views

struct BalkenZeile: View {
    let label: String
    let wert: String
    let prozent: Double
    let farbe: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(farbe.opacity(0.8))
                        .frame(width: geo.size.width * min(prozent, 1.0))
                        .animation(.easeOut(duration: 0.25), value: prozent)
                }
            }
            .frame(height: 22)
            Text(wert)
                .font(.system(.callout, design: .monospaced).bold())
                .frame(width: 90, alignment: .trailing)
        }
    }
}

struct KenngroesseKachel: View {
    let wert: String
    let label: String
    var hervorheben: Bool = false
    var farbe: Color = .accentColor

    var body: some View {
        VStack(spacing: 5) {
            Text(wert)
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(hervorheben ? farbe : .primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(hervorheben ? farbe.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
    }
}
