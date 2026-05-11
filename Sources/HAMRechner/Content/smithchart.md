# Smith-Chart

## Beschreibung
Das **Smith-Diagramm** (Phillip H. Smith, 1939) ist das wichtigste
grafische Werkzeug der HF-Technik. Es bildet die komplexe
Impedanz-Ebene auf einen Einheitskreis ab, indem die Impedanz Z
in den Reflexionsfaktor Γ umgerechnet wird:

```
Γ = (Z − Z₀) / (Z + Z₀)
```

Ein Punkt auf der Karte beschreibt vollständig:
- Komplexe Impedanz Z = R + jX
- Komplexe Admittanz Y = G + jB
- Reflexionsfaktor Γ (Magnitude + Phase)
- VSWR und Return Loss

## Funktionsweise
Die Smith-Karte ist normalisiert auf eine **System-Impedanz Z₀**
(meist 50 Ω im Amateurfunk). Eine Last z = Z/Z₀ wird auf der Karte
als Punkt eingezeichnet:

- **Mitte** = perfekter Match (z = 1, also Z = Z₀, VSWR 1:1)
- **Rechter Rand (1, 0)** = Open (Leerlauf, ∞ Ω)
- **Linker Rand (−1, 0)** = Short (Kurzschluss, 0 Ω)
- **Obere Halbebene** = induktive Last (X > 0)
- **Untere Halbebene** = kapazitive Last (X < 0)
- **Außerer Einheitskreis** = |Γ| = 1 (Total-Reflexion)

**Konstante-R-Kreise** (blau) bilden alle Impedanzen mit gleichem
Realteil ab. **Konstante-X-Bögen** (lila) entsprechen gleichem
Imaginärteil. Der Kreis durch die Last mit Mittelpunkt im Z₀-Match
ist der **VSWR-Kreis** — alle Punkte darauf haben dasselbe VSWR.

## Praxis-Tipps
- **Antenne im Resonanzpunkt:** X≈0 → Punkt liegt auf der waagerechten Mittellinie
- **VSWR ablesen:** Schnittpunkt des VSWR-Kreises mit der R-Achse rechts vom Zentrum gibt direkt den VSWR-Wert (in normalisierter Form als R)
- **Tuner-Anpassung visualisieren:** Series-L bewegt im Uhrzeigersinn auf einem R-Kreis nach oben, Shunt-C im Uhrzeigersinn auf einem G-Kreis (gespiegelt)
- **Quarter-Wave-Transformation:** dreht den Punkt um 180° um den Mittelpunkt
- **Antennen-Analyzer-Output:** RigExpert/AA-Geräte liefern direkt R + jX → Punkt einzeichnen, sofort sehen ob Kürzen oder Verlängern hilft

## Häufige Werte (50 Ω System)
| Last | Punkt | VSWR | RL |
|---|---|---|---|
| 50 + j0  Ω | Mittelpunkt   | 1.0  | ∞ dB |
| 100 + j0 Ω | (0.33, 0)     | 2.0  | 9.5 dB |
| 25 + j0  Ω | (−0.33, 0)    | 2.0  | 9.5 dB |
| 75 + j25 Ω | (0.25, 0.13)  | ~1.7 | 12.5 dB |
| 0 (Short)  | (−1, 0)       | ∞    | 0 dB |
| ∞ (Open)   | (1, 0)        | ∞    | 0 dB |

## Quellen
- Phillip H. Smith: "Transmission Line Calculator" (Electronics, Jan 1939)
- ARRL Antenna Book: Kapitel "Transmission Lines & Smith Chart"
- HB9MTN Smith-Chart Tutorial (USKA)
