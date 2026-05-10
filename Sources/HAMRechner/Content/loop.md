# Loop-Antenne

## Beschreibung
Die Vollwellen-Loop ist eine geschlossene Drahtschleife mit einem Umfang
von einer **vollen Wellenlänge** (λ). Sie ist robust gegen Umwelteinflüsse,
bietet einen kleinen Gewinn (≈ 2 dB) gegenüber dem Dipol und hat ein
geringes Rauschniveau – ideal für DX und für ländliche Standorte mit
Platz zum Aufspannen.

## Funktionsweise
Bei voller Wellenlänge im Umfang ergibt sich eine stehende Welle entlang
des Drahts mit zwei Strommaxima. Die Strahlungscharakteristik hängt von
der Geometrie ab:

- **Delta-Loop, Spitze unten:** Speisepunkt am Apex, vorwiegend
  vertikale Polarisation, gut für DX
- **Delta-Loop, Spitze oben:** Speisepunkt an der Basis, horizontale
  Polarisation, Steilstrahlung
- **Quad (quadratisch):** ebenfalls horizontal polarisiert, etwas mehr Gewinn

Die Speisepunkt-Impedanz hängt stark vom Aufbau ab:

- **Gleichseitige Delta-Loop:** ≈ 110 Ω → λ/4-Trafoleitung aus 75 Ω Koax
- **Delta-Loop 40/30/30 (flach):** ≈ 50 Ω → direkt 50 Ω-Speisung
- **Delta-Loop 18/41/41 (Apex):** ≈ 50 Ω → direkt 50 Ω-Speisung
- **Quadratische Loop:** ≈ 110 Ω → λ/4-Trafoleitung

## λ/4-Anpassleitung berechnen
Bei 110 Ω Loops kommt eine **λ/4-Transformationsleitung aus 75 Ω Koax**
zum Einsatz. Sie transformiert 110 Ω auf ca. 50 Ω. Länge:

`L = (300 / f / 4) × VF_Koax`

VF des Koax: 0,66 für PVC-Schaum, 0,67 typisch, 0,70 für Luft-Dielektrikum.

## Praxis-Tipps
- **Aufhängung:** drei Punkte für Delta, vier Eckpunkte für Quad
- **Drahtmaterial:** CuLi 1,5–2,5 mm² für Stabilität bei großen Spannweiten
- **Aufhängehöhe:** Bottom-Wire mind. 3 m über Grund, je höher desto besser
- **Polarisation wählen:** je nach Bestandsverbindungen entscheiden
- **Endisolatoren** an allen Eckpunkten verwenden
- **Multiband:** Loop nur auf Designfrequenz resonant, mit Tuner +
  Hühnerleiter-Speisung breitbandig nutzbar

## Quellen
- ARRL Antenna Book: Loop Antennas
- DJ7HS: "Praktische Loop-Antennen"
