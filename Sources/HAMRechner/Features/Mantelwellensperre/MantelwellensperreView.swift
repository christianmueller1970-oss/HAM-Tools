import SwiftUI

// MARK: - Mantelwellensperre / Common-Mode-Choke Rechner
//
// Nutzt die zentrale Ringkern-DB aus BalunRechnerModel (alleKerne, kernGruppen)

struct MantelwellensperreView: View {
    @AppStorage("mws_kernID")    private var kernID: String  = "ft240_43"
    @AppStorage("mws_gruppe")    private var gruppe: String  = "Amidon Ferrit Mix 43"
    @AppStorage("mws_windungen") private var windungen: Int  = 12
    @AppStorage("mws_freqMHz")   private var freqMHz: String = "14.2"
    @AppStorage("mws_koaxDmm")   private var koaxDmm: String = "5.0"   // Aircell 5 / RG-58 ~5 mm

    private let bandList: [(name: String, fMHz: Double)] = [
        ("160m", 1.85), ("80m", 3.65), ("60m", 5.36),
        ("40m", 7.10),  ("30m", 10.12), ("20m", 14.20),
        ("17m", 18.10), ("15m", 21.20), ("12m", 24.94),
        ("10m", 28.50), ("6m",  50.10),
    ]

    private var gewaehlteKerne: [Ringkern] { alleKerne.filter { $0.gruppe == gruppe } }
    private var kern: Ringkern? { alleKerne.first { $0.id == kernID } }
    private var fVal: Double { Double(freqMHz.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var koaxD: Double { Double(koaxDmm.replacingOccurrences(of: ",", with: ".")) ?? 5.0 }

    // L [µH] = N² × A_L [nH/N²] / 1000
    private func lUH(N: Int, kern: Ringkern) -> Double {
        Double(N * N) * kern.al / 1000.0
    }
    private func zCM(N: Int, fMHz: Double, kern: Ringkern) -> Double {
        let L = lUH(N: N, kern: kern)
        return 2 * .pi * fMHz * L  // X_L in Ω (vereinfacht, konservative Schätzung)
    }

    private var isFerrite: Bool { gruppe.contains("Ferrit") || gruppe.contains("Fair-Rite") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if let k = kern {
                    if !isFerrite { warnungEisenpulver }
                    ergebnisBereich(kern: k)
                    multibandBereich(kern: k)
                    wickelBereich(kern: k)
                }
                hinweisBereich
                RechnerBeschreibung(resourceName: "mantelwellensperre")
            }
            .padding(24)
        }
        .navigationTitle("Mantelwellensperre")
    }

    // MARK: - Eingabe

    private var eingabeBereich: some View {
        SectionCard(title: "Ringkern + Wicklung") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Material / Mix").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $gruppe) {
                            ForEach(kernGruppen, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 240)
                        .onChange(of: gruppe) { _, _ in
                            if let first = gewaehlteKerne.first { kernID = first.id }
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Kern").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $kernID) {
                            ForEach(gewaehlteKerne) { k in Text(k.name).tag(k.id) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                    Spacer()
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Windungen N").font(.caption).foregroundStyle(.secondary)
                        Stepper("\(windungen)", value: $windungen, in: 1...30)
                            .frame(width: 130)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Test-Frequenz").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            TextField("", text: $freqMHz)
                                .textFieldStyle(.roundedBorder).frame(width: 100)
                            Text("MHz").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Koax-⌀ (für Wickel-Check)").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            TextField("", text: $koaxDmm)
                                .textFieldStyle(.roundedBorder).frame(width: 80)
                            Text("mm").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                Text("Eine Mantelwellensperre wird typisch durch Wickeln des **Koaxialkabels selbst** durch oder um einen Ringkern hergestellt — die Anzahl Windungen entspricht der Anzahl Durchführungen durch das Kernloch.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Warnung Eisenpulver

    private var warnungEisenpulver: some View {
        SectionCard(title: "⚠ Material-Warnung") {
            Text("**Eisenpulver-Kerne (Mix 2, Mix 6) sind für Mantelwellensperren UNGEEIGNET!** Sie haben hohes Q (geringe Verluste), wirken nur als reine Induktivität und sperren Common-Mode-Ströme nur über einen schmalen Frequenzbereich. Für Chokes immer **Ferrit-Mix verwenden** (Mix 43 für KW, Mix 31 für 1-10 MHz EFHW, Mix 61 für VHF/UHF, Mix 77 für NF).")
                .font(.callout)
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Ergebnis bei Test-Frequenz

    private func ergebnisBereich(kern: Ringkern) -> some View {
        let L_uH = lUH(N: windungen, kern: kern)
        let X_L  = zCM(N: windungen, fMHz: fVal, kern: kern)
        return SectionCard(title: "Sperrwirkung bei \(String(format: "%.3f", fVal)) MHz") {
            VStack(spacing: 4) {
                ResultRow(label: "Induktivität L",
                          value: String(format: "%.2f µH", L_uH))
                ResultRow(label: "Reaktanz X_L = 2πfL",
                          value: String(format: "%.0f Ω", X_L))
                ResultRow(label: "Common-Mode Z (konservativ)",
                          value: String(format: "%.0f Ω ≈ %.2f kΩ", X_L, X_L / 1000),
                          highlight: true)
                ResultRow(label: "Bewertung",
                          value: bewertung(X_L: X_L))
            }
        }
    }

    private func bewertung(X_L: Double) -> String {
        if X_L >= 5000 { return "✓ ausgezeichnet (≥ 5 kΩ)" }
        if X_L >= 1000 { return "✓ gut (≥ 1 kΩ)" }
        if X_L >= 500  { return "~ akzeptabel" }
        return "✗ ungenügend (< 500 Ω)"
    }

    // MARK: - Multiband-Tabelle

    private func multibandBereich(kern: Ringkern) -> some View {
        SectionCard(title: "Sperrwirkung über alle Bänder") {
            VStack(spacing: 0) {
                HStack {
                    Text("Band").font(.caption).bold().foregroundStyle(.secondary).frame(width: 50, alignment: .leading)
                    Text("Frequenz").font(.caption).bold().foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    Text("X_L").font(.caption).bold().foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                    Text("kΩ").font(.caption).bold().foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                    Text("Status").font(.caption).bold().foregroundStyle(.secondary).frame(width: 80, alignment: .center)
                }
                .padding(.vertical, 6)
                Divider()
                ForEach(bandList, id: \.name) { band in
                    let X = zCM(N: windungen, fMHz: band.fMHz, kern: kern)
                    HStack {
                        Text(band.name).font(.callout).bold().frame(width: 50, alignment: .leading)
                        Text(String(format: "%.2f MHz", band.fMHz))
                            .font(.callout).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.0f Ω", X)).font(.callout).frame(maxWidth: .infinity, alignment: .trailing)
                        Text(String(format: "%.2f", X / 1000)).font(.callout).bold().frame(maxWidth: .infinity, alignment: .trailing)
                        Text(statusIcon(X_L: X))
                            .font(.callout)
                            .frame(width: 80, alignment: .center)
                            .foregroundStyle(statusColor(X_L: X))
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
    }
    private func statusIcon(X_L: Double) -> String {
        if X_L >= 5000 { return "✓ top" }
        if X_L >= 1000 { return "✓ ok" }
        if X_L >= 500  { return "~" }
        return "✗"
    }
    private func statusColor(X_L: Double) -> Color {
        if X_L >= 5000 { return .green }
        if X_L >= 1000 { return Color(red: 0.5, green: 0.8, blue: 0.2) }
        if X_L >= 500  { return .yellow }
        return .red
    }

    // MARK: - Wickel-Check

    private func wickelBereich(kern: Ringkern) -> some View {
        let innenUmfang = .pi * kern.idMM
        let maxN = Int(innenUmfang / koaxD)
        let auslastung = Double(windungen) * koaxD / innenUmfang * 100
        return SectionCard(title: "Wickel-Check") {
            VStack(spacing: 4) {
                ResultRow(label: "Kern-Innenumfang", value: String(format: "%.1f mm", innenUmfang))
                ResultRow(label: "Maximal mögliche Windungen", value: "≈ \(maxN)")
                ResultRow(label: "Aktuelle Auslastung",
                          value: String(format: "%.0f %%  (%d von %d)", auslastung, windungen, maxN),
                          highlight: auslastung > 90)
                if windungen > maxN {
                    Text("⚠ Mehr Windungen geplant als auf den Kern passen!")
                        .font(.callout).foregroundStyle(.red)
                } else if auslastung > 90 {
                    Text("⚠ Wickelfenster fast voll — eng zu wickeln, ggf. größeren Kern wählen.")
                        .font(.callout).foregroundStyle(.orange)
                } else if auslastung > 60 {
                    Text("Wickelfenster gut belegt, sollte sauber zu wickeln sein.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("Viel Platz — alternativ größere Windungszahl möglich für mehr Sperrwirkung.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Hinweis

    private var hinweisBereich: some View {
        SectionCard(title: "Praxis-Empfehlung") {
            VStack(alignment: .leading, spacing: 6) {
                Text("• **Ziel: Z_CM ≥ 1 kΩ** auf den genutzten Bändern. **≥ 5 kΩ** ist optimal.")
                Text("• **Mix 31** ist typisch beste Wahl für KW-Choke (1–10 MHz top, brauchbar bis 30 MHz). **Mix 43** für 5–50 MHz universell. **Mix 61** für VHF/UHF. **Mix 77** für NF (<2 MHz).")
                Text("• **Konservative Berechnung:** Z_CM = X_L (rein induktiv). Bei Ferrit liegen die realen Werte im Verlust-Resonanz-Fenster oft 2–3× höher dank des Material-Imaginärteils μ\".")
                Text("• **Standard-Empfehlung 100 W KW-Station:** FT-240-43 mit 10–14 Windungen Aircell-5 / RG-58 — deckt 80–10m sauber ab.")
                Text("• **EFHW-Choke:** FT-240-31 mit 7–10 Windungen — speziell für die Common-Mode-Probleme an EFHW-Antennen.")
                Text("• **Wickel-Trick:** Windungen gleichmäßig um den Kern verteilen (nicht alle nebeneinander) — weniger Eigenkapazität, breiteres Sperrband.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}
