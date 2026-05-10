# Kabeldämpfung

## Beschreibung
Jedes Koaxialkabel verliert Sendeleistung in Form von Wärme — die
**Dämpfung** wächst mit Frequenz und Kabellänge. Bei UKW/UHF-Stationen
kann die Hälfte der Sendeleistung im Kabel verloren gehen, bevor sie
die Antenne erreicht. Die Wahl des richtigen Kabels ist daher
entscheidend für die effektive Strahlungsleistung.

## Funktionsweise
Die Dämpfung steigt **mit der Wurzel der Frequenz** (Skin-Effekt) und
**linear mit der Länge**:

`Dämpfung_total [dB] = (Dämpfung_pro_100m [dB/100m] / 100) × Länge [m]`

Die Datenblattwerte werden in dB pro 100 m bei verschiedenen
Frequenzen angegeben (typ. 10/30/100/145/300/435/1000/1296 MHz).
Zwischenwerte interpoliert der Rechner linear.

Aus der Gesamtdämpfung folgt die **Ausgangsleistung**:
`P_out = P_in × 10^(−Dämpfung/10)`

## Effizienz-Bewertung
| Wirkungsgrad | Bewertung |
|---|---|
| ≥ 80 % | gut — kein Handlungsbedarf |
| 50–80 % | mittel — bessere Kabel-Wahl überlegen |
| < 50 % | schlecht — > Hälfte der Leistung verloren! |

## Typische Kabel-Verluste (dB pro 100 m bei 145 MHz)
| Kabel | Dämpfung |
|---|---|
| RG-58 | 19,0 |
| RG-213 | 8,5 |
| Aircell 7 | 8,9 |
| LMR-400 | 5,4 |
| Ecoflex 10 | 4,9 |
| Ecoflex 15 | 3,3 |
| LMR-600 | 3,5 |
| LMR-900 | 2,3 |

## Praxis-Tipps
- **Kürzeste Kabellänge wählen:** jeder Meter weniger spart Dämpfung
- **Dickeres Kabel nehmen** auf VHF/UHF — der Mehraufwand zahlt sich aus
- **N-Stecker statt PL-259** auf UHF — bessere HF-Eigenschaften
- **Kabelqualität** prüfen: alte/feuchte Kabel haben deutlich höhere Dämpfung
- **Wasser im Kabel** ruiniert sofort die Dämpfung — wetterfeste Stecker
- **Auf KW** ist die Kabelwahl unkritisch (RG-58 reicht für 100 W)

## Faustregel
**3 dB Verlust = halbe Leistung.** Ein 30 m RG-213 auf 145 MHz hat
~2,5 dB → 56 % der Leistung kommt an. Auf 432 MHz schon ~5 dB → 32 %.

## Quellen
- Herstellerdatenblätter: Times Microwave, Belden, Andrew, Cinkit
- ARRL Handbook: Transmission Lines
