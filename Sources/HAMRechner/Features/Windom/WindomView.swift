import SwiftUI

// MARK: - Model

private struct WindomErgebnis {
    let f: Double
    let vf: Double
    let gesamt_m: Double
    let langSchenkel_m: Double   // 64%
    let kurzSchenkel_m: Double   // 36%
    let balun: String
    let baender: [String]

    static func berechne(f: Double, vf: Double) -> WindomErgebnis? {
        guard f > 0, vf > 0 else { return nil }
        let gesamt = 150.0 / f * vf
        let lang   = gesamt * 0.64
        let kurz   = gesamt * 0.36
        let baender = multiband(f: f)
        return WindomErgebnis(f: f, vf: vf, gesamt_m: gesamt,
                              langSchenkel_m: lang, kurzSchenkel_m: kurz,
                              balun: "4:1 Current Balun (empfohlen) oder 6:1",
                              baender: baender)
    }

    private static func multiband(f: Double) -> [String] {
        var bands: [String] = []
        // Windom arbeitet auf Grundfrequenz und Oberwellen (n=1,2,3,5,...)
        let harmonics: [(Int, String)] = [(1,"Grundwelle"), (2,"2. Harmonische"), (3,"3. Harmonische"),
                                           (5,"5. Harmonische"), (7,"7. Harmonische")]
        let allBands: [(String, Double, Double)] = [
            ("160m", 1.8, 2.0), ("80m", 3.5, 3.8), ("60m", 5.3, 5.4),
            ("40m", 7.0, 7.3), ("30m", 10.1, 10.15), ("20m", 14.0, 14.35),
            ("17m", 18.068, 18.168), ("15m", 21.0, 21.45),
            ("12m", 24.89, 24.99), ("10m", 28.0, 29.7)
        ]
        for (n, _) in harmonics {
            let fCheck = f * Double(n)
            for (band, low, high) in allBands {
                if fCheck >= low && fCheck <= high && !bands.contains(band) {
                    bands.append(band)
                }
            }
        }
        return bands.sorted { a, b in
            let order = ["160m","80m","60m","40m","30m","20m","17m","15m","12m","10m"]
            return (order.firstIndex(of: a) ?? 99) < (order.firstIndex(of: b) ?? 99)
        }
    }
}

// MARK: - View

struct WindomView: View {
    @State private var freqText = "7.1"
    @State private var vfText   = "0.95"

    private var f:  Double { Double(freqText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var vf: Double { Double(vfText.replacingOccurrences(of: ",", with: "."))   ?? 0.95 }
    private var ergebnis: WindomErgebnis? { WindomErgebnis.berechne(f: f, vf: vf) }

    private let bands: [(String, Double)] = [
        ("160m", 1.85), ("80m", 3.65), ("60m", 5.36), ("40m", 7.1), ("30m", 10.125)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eingabeBereich
                if let r = ergebnis { ergebnisBereich(r); skizzeBereich(r); mehrbandBereich(r); hinweisBereich }
                RechnerBeschreibung(resourceName: "windom")
            }
            .padding(24)
        }
        .navigationTitle("Windom (OCFD)")
    }

    private var eingabeBereich: some View {
        SectionCard(title: "Eingabe") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Niederste Betriebsfrequenz (Grundwelle)").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 4) {
                        ForEach(bands, id: \.0) { name, freq in
                            Button(name) { freqText = String(freq) }
                                .buttonStyle(.bordered).controlSize(.small)
                                .tint(abs(f - freq) < 0.5 ? .accentColor : nil)
                        }
                    }
                }
                Divider()
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Frequenz (Grundwelle)").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("MHz", text: $freqText).textFieldStyle(.roundedBorder)
                            Text("MHz").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Verkürzungsfaktor VF").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("0.95", text: $vfText).textFieldStyle(.roundedBorder).frame(width: 80)
                        }
                    }
                }
            }
        }
    }

    private func ergebnisBereich(_ r: WindomErgebnis) -> some View {
        SectionCard(title: "Maße") {
            VStack(spacing: 4) {
                ResultRow(label: "Gesamtlänge (λ/2)",          value: String(format: "%.3f m", r.gesamt_m), highlight: true)
                ResultRow(label: "Langer Schenkel (64%)",      value: String(format: "%.3f m", r.langSchenkel_m))
                ResultRow(label: "Kurzer Schenkel (36%)",      value: String(format: "%.3f m", r.kurzSchenkel_m))
                ResultRow(label: "Speisepunkt-Impedanz",       value: "≈ 200–300 Ω")
                ResultRow(label: "Balun",                      value: r.balun)
                ResultRow(label: "Frequenz (Grundwelle)",      value: String(format: "%.3f MHz", r.f))
            }
        }
    }

    private func skizzeBereich(_ r: WindomErgebnis) -> some View {
        SectionCard(title: "Skizze") {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let cy = H / 2
                let margin: CGFloat = 30
                let availW = W - 2 * margin
                let feedX = margin + availW * 0.36  // Speisepunkt bei 36%
                let leftX = margin
                let rightX = W - margin

                // Kurzer Schenkel (links, 36%)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: leftX, y: cy))
                    p.addLine(to: CGPoint(x: feedX, y: cy))
                }, with: .color(.blue), lineWidth: 4)

                // Langer Schenkel (rechts, 64%)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: feedX, y: cy))
                    p.addLine(to: CGPoint(x: rightX, y: cy))
                }, with: .color(.blue), lineWidth: 4)

                // Balun-Box
                let boxW: CGFloat = 34, boxH: CGFloat = 22
                ctx.stroke(Path { p in
                    p.addRoundedRect(in: CGRect(x: feedX - boxW/2, y: cy - boxH/2 - 18, width: boxW, height: boxH),
                                     cornerSize: CGSize(width: 4, height: 4))
                }, with: .color(.orange), lineWidth: 2)
                ctx.draw(Text("4:1").font(.system(size: 10)).bold().foregroundStyle(.orange),
                         at: CGPoint(x: feedX, y: cy - 18), anchor: .center)

                // Koax nach unten
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: feedX, y: cy + 5))
                    p.addLine(to: CGPoint(x: feedX, y: cy + 28))
                }, with: .color(.accentColor), lineWidth: 2.5)
                ctx.fill(Path(ellipseIn: CGRect(x: feedX-4, y: cy-4, width: 8, height: 8)), with: .color(.accentColor))
                ctx.draw(Text("50Ω").font(.system(size: 10)).bold().foregroundStyle(Color.accentColor),
                         at: CGPoint(x: feedX, y: cy + 40), anchor: .center)

                // Bemaßung
                ctx.draw(Text(String(format: "← %.3f m (36%%) →", r.kurzSchenkel_m)).font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: (leftX + feedX) / 2, y: cy - 38), anchor: .center)
                ctx.draw(Text(String(format: "← %.3f m (64%%) →", r.langSchenkel_m)).font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: (feedX + rightX) / 2, y: cy - 38), anchor: .center)
                ctx.draw(Text(String(format: "Gesamt: %.3f m", r.gesamt_m)).font(.system(size: 11)).foregroundStyle(.secondary),
                         at: CGPoint(x: W / 2, y: H - 8), anchor: .center)
            }
            .frame(height: 130)
        }
    }

    private func mehrbandBereich(_ r: WindomErgebnis) -> some View {
        SectionCard(title: "Einsetzbare Bänder") {
            if r.baender.isEmpty {
                Text("Keine zusätzlichen Bänder ermittelt.").font(.callout).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 6) {
                    ForEach(r.baender, id: \.self) { band in
                        Text(band)
                            .font(.caption).bold()
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    private var hinweisBereich: some View {
        SectionCard(title: "Hinweis") {
            Text("Windom (Off-Center Fed Dipole, OCFD): Speisepunkt liegt bei 36% / 64% der Gesamtlänge. Impedanz am Speisepunkt ≈ 200–300 Ω je nach Band. 4:1 Current Balun auf FT240-43 empfohlen. Arbeitet auf Grundfrequenz und mehreren Oberwellen ohne Antennentuner.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
