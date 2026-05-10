import SwiftUI
import Charts

struct KabeldaempfungView: View {
    @State private var gewaehlteGruppe: String = "RG-Typen"
    @State private var gewaehlteKabelID: String = "rg213"
    @State private var frequenzText: String = "145"
    @State private var laengeText: String = "20"
    @State private var leistungText: String = "100"

    private var gewaehlteKabel: [Koaxkabel] {
        allKabel.filter { $0.gruppe == gewaehlteGruppe }
    }

    private var aktuellesKabel: Koaxkabel? {
        allKabel.first { $0.id == gewaehlteKabelID }
    }

    private var ergebnis: KabeldaempfungErgebnis? {
        guard let kabel = aktuellesKabel,
              let f = Double(frequenzText.replacingOccurrences(of: ",", with: ".")),
              let l = Double(laengeText.replacingOccurrences(of: ",", with: ".")),
              let p = Double(leistungText.replacingOccurrences(of: ",", with: ".")),
              f > 0, l > 0, p > 0 else { return nil }
        return berechneKabeldaempfung(kabel: kabel, frequenzMHz: f, laengeM: l, eingangsleistungW: p)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                kabelAuswahlBereich
                eingabeBereich
                if let r = ergebnis, let kabel = aktuellesKabel {
                    ergebnisBereich(r)
                    warnungsBereich(r)
                    chartBereich(kabel: kabel)
                }
                RechnerBeschreibung(resourceName: "kabeldaempfung")
            }
            .padding(24)
        }
        .navigationTitle("Kabeldämpfung")
        .onChange(of: gewaehlteGruppe) {
            if let erstes = gewaehlteKabel.first {
                gewaehlteKabelID = erstes.id
            }
        }
    }

    // MARK: - Kabelauswahl

    private var kabelAuswahlBereich: some View {
        SectionCard(title: "Kabelauswahl") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gruppe").font(.caption).foregroundStyle(.secondary)
                        Picker("Gruppe", selection: $gewaehlteGruppe) {
                            ForEach(kabelGruppen, id: \.self) { Text($0) }
                        }
                        .labelsHidden()
                        .frame(minWidth: 160)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kabeltyp").font(.caption).foregroundStyle(.secondary)
                        Picker("Kabel", selection: $gewaehlteKabelID) {
                            ForEach(gewaehlteKabel) { k in
                                Text(k.name).tag(k.id)
                            }
                        }
                        .labelsHidden()
                        .frame(minWidth: 200)
                    }
                }

                if let kabel = aktuellesKabel {
                    HStack(spacing: 16) {
                        Label(kabel.beschreibung, systemImage: "info.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Z₀ = \(Int(kabel.impedanz)) Ω")
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Parameter") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Frequenz").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("MHz", text: $frequenzText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                            Text("MHz").foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kabellänge").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("m", text: $laengeText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                            Text("m").foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Eingangsleistung").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("W", text: $leistungText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                            Text("W").foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Band-Schnellwahl").font(.caption).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(afuBaender) { band in
                                Button(band.name) {
                                    frequenzText = String(band.frequenzMHz)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(isAktivesBand(band) ? .accentColor : nil)
                            }
                        }
                    }
                }
            }
        }
    }

    private func isAktivesBand(_ band: AFUBand) -> Bool {
        guard let f = Double(frequenzText) else { return false }
        return abs(f - band.frequenzMHz) < 0.01
    }

    // MARK: - Ergebnisse

    private func ergebnisBereich(_ r: KabeldaempfungErgebnis) -> some View {
        SectionCard(title: "Ergebnisse") {
            VStack(spacing: 10) {
                ResultRow(label: "Dämpfung gesamt",    value: String(format: "%.2f", r.gesamtDaempfungDB),   unit: "dB",  highlight: true)
                ResultRow(label: "Ausgangsleistung",   value: String(format: "%.2f", r.ausgangsleistungW),   unit: "W")
                ResultRow(label: "Verlustleistung",    value: String(format: "%.2f", r.verlustleistungW),    unit: "W")

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Effizienz")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f %%", r.effizienzProzent))
                            .fontWeight(.bold)
                            .foregroundStyle(effizienzFarbe(r))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 12)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(effizienzFarbe(r))
                                .frame(width: geo.size.width * r.effizienzProzent / 100.0, height: 12)
                                .animation(.easeOut(duration: 0.3), value: r.effizienzProzent)
                        }
                    }
                    .frame(height: 12)
                }
            }
        }
    }

    private func effizienzFarbe(_ r: KabeldaempfungErgebnis) -> Color {
        switch r.bewertung {
        case .gut:     return .green
        case .mittel:  return .orange
        case .schlecht: return .red
        }
    }

    // MARK: - Warnung

    @ViewBuilder
    private func warnungsBereich(_ r: KabeldaempfungErgebnis) -> some View {
        if r.effizienzProzent < 50 {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text("Mehr als die Hälfte der Sendeleistung geht im Kabel verloren! Kürzeres Kabel oder besseren Kabeltyp wählen.")
                    .font(.callout)
            }
            .padding(12)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if r.gesamtDaempfungDB > 3 {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill").foregroundStyle(.orange)
                Text("Dämpfung über 3 dB – weniger als 50 % der Leistung erreicht die Antenne.")
                    .font(.callout)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Dämpfungskurve

    private func chartBereich(kabel: Koaxkabel) -> some View {
        SectionCard(title: "Dämpfungskurve (dB/100 m über Frequenz)") {
            let punkte = chartPunkte(kabel: kabel)
            let aktuelleFreq = Double(frequenzText.replacingOccurrences(of: ",", with: ".")) ?? 145

            Chart {
                ForEach(punkte, id: \.0) { freq, db in
                    LineMark(x: .value("MHz", freq), y: .value("dB/100m", db))
                        .foregroundStyle(Color.accentColor)
                        .interpolationMethod(.catmullRom)
                }
                AreaMark(x: .value("MHz", 0), y: .value("dB/100m", 0))

                // Marker für aktuelle Frequenz
                if aktuelleFreq > 0 {
                    let markerDB = kabel.daempfungPro100m(frequenzMHz: aktuelleFreq)
                    PointMark(x: .value("MHz", aktuelleFreq), y: .value("dB/100m", markerDB))
                        .foregroundStyle(.red)
                        .symbolSize(80)
                    RuleMark(x: .value("MHz", aktuelleFreq))
                        .foregroundStyle(.red.opacity(0.4))
                        .lineStyle(StrokeStyle(dash: [4]))
                }
            }
            .chartXAxis {
                AxisMarks(values: [10, 30, 100, 145, 300, 435, 1000, 1296]) { val in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let f = val.as(Double.self) {
                            Text(f >= 1000 ? "\(Int(f/1000))G" : "\(Int(f))")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXScale(domain: 1...1400)
            .chartXScale(type: .log)
            .chartYAxisLabel("dB / 100 m")
            .frame(height: 180)
        }
    }

    private func chartPunkte(kabel: Koaxkabel) -> [(Double, Double)] {
        let freqs: [Double] = [1, 5, 10, 20, 30, 50, 100, 145, 200, 300, 435, 600, 1000, 1296, 1400]
        return freqs.map { f in (f, kabel.daempfungPro100m(frequenzMHz: f)) }
    }
}
