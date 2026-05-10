# Pegel-Umrechner

## Beschreibung
Im Funkbetrieb werden Leistungen und Spannungen in vielen Einheiten
angegeben — Watt, dBm, dBW, Volt. Dieser Umrechner zeigt **alle
Größen gleichzeitig** und vergleicht zusätzlich mit den
Referenz-Sendeleistungen QRP/100 W/1 kW.

## Umrechnungsformeln

**Leistung ↔ Leistung:**
- `mW = W × 1000`
- `dBm = 10 × log₁₀(P_W × 1000)`
- `dBW = 10 × log₁₀(P_W)`
- `dBm = dBW + 30`

**Leistung ↔ Spannung** (an Z₀, typ. 50 Ω):
- `U = √(P × Z₀)`
- `P = U² / Z₀`

## Wichtige Bezugswerte im Amateurfunk
| Pegel | Leistung |
|---|---|
| 0 dBm | 1 mW |
| 17 dBm | 50 mW |
| 30 dBm | 1 W |
| 33 dBm | 2 W |
| 37 dBm | 5 W (QRP-Grenze) |
| 40 dBm | 10 W |
| 50 dBm | 100 W |
| 60 dBm | 1 kW |

## Praxis-Tipps
- **dBm-Differenz** zeigt direkt das Leistungsverhältnis:
  - +3 dB = doppelt
  - +10 dB = 10×
  - +20 dB = 100×
  - +30 dB = 1000×
- **S-Stufen**: 1 S-Stufe = 6 dB (≈ 4× Leistung), aber Empfänger-spezifisch
- **dB-Verhältnisse addieren statt multiplizieren** (logarithmisch!)
- **3 dB Faustregel:** halbe oder doppelte Leistung
- **−10 dBm Empfangspegel** = 100 µW = sehr starkes Signal
- **−120 dBm** = typ. Empfindlichkeit eines guten KW-Empfängers (SSB)

## Spannung an verschiedenen Impedanzen
- **50 Ω:** 100 W → 70,7 V_eff
- **75 Ω:** 100 W → 86,6 V_eff
- **600 Ω:** 100 W → 245 V_eff (Hühnerleiter!)

Hochspannung an symmetrischen Speiseleitungen ist ein Sicherheitsthema —
Endisolatoren verwenden, Berührung während Betrieb vermeiden.

## Quellen
- ARRL Handbook: Decibel Tables
- Wikipedia: Decibel Watt
