# SWR-Simulator

## Beschreibung
Das **Stehwellenverhältnis (SWR)**, auch *Voltage Standing Wave Ratio*
(VSWR), beschreibt wie gut Sender, Kabel und Antenne aufeinander
abgestimmt sind. SWR = 1:1 ist perfekt (alle Leistung erreicht die
Antenne). Höhere SWR-Werte bedeuten Reflexion zurück zum Sender und
können die Endstufe beschädigen.

## Funktionsweise

**Reflexionsfaktor Γ** (Gamma):
`Γ = (SWR − 1) / (SWR + 1)`

Das gibt an, welcher Anteil der Sendeleistung zurückreflektiert wird:
**P_reflected = Γ² × P_forward**

**Rückflussdämpfung (Return Loss):**
`RL = −20 × log₁₀(Γ) [dB]`

**Mismatch-Verlust:**
`ML = −10 × log₁₀(1 − Γ²) [dB]`

**Lastimpedanz** bei reellem Mismatch:
`Z_Last = Z₀ × SWR` (oder Z₀ / SWR, je nach kapazitiv/induktiv)

## Bewertungsskala
| SWR | Bewertung | Verlust durch Mismatch |
|---|---|---|
| 1:1 – 1,5:1 | sehr gut | < 0,2 dB |
| 1,5:1 – 2,5:1 | akzeptabel | 0,2 – 0,8 dB |
| 2,5:1 – 4:1 | hoch — Tuner empfohlen | 0,8 – 1,9 dB |
| > 4:1 | kritisch — Endstufenschutz greift! | > 1,9 dB |

Moderne TX schalten bei SWR > 3 die Leistung schrittweise zurück
(*Foldback*), um die Endstufe zu schützen.

## Praxis-Tipps
- **Antennen-Trimming:** SWR über die Frequenz messen (Wobbel-Sweep) —
  Resonanz liegt am SWR-Minimum, nicht zwingend bei der Designfrequenz
- **Antennenanalysator** ist die einfachste Diagnose-Methode
- **Im Shack** sieht man oft nur die "transformierte" SWR — am Antennen-Speisepunkt
  kann es deutlich schlechter aussehen (Kabeldämpfung "schönt" das SWR!)
- **Dummy-Load** (50 Ω, 100 W+) zur PA-Kontrolle: SWR muss 1:1 sein
- **Sender-Schutz:** bei SWR > 3 Leistung deutlich reduzieren

## Häufige Ursachen für hohes SWR
- Antenne nicht resonant (Länge falsch, Höhe ändert sich, Material gealtert)
- Schlechter Stecker / Kontaktproblem
- Wasser im Kabel oder am Stecker
- Unterbrochener Mantelwellenfilter
- Antenne berührt Metall (Mast, Regenrinne)

## Quellen
- ARRL Handbook: Transmission Lines + SWR
- Walter Maxwell W2DU: "Reflections – Transmission Lines and Antennas"
