# Anpassnetzwerk (L-Netz)

## Beschreibung
Das **L-Netz** (auch: L-Match) ist die einfachste reine Reaktanz-Anpassung
zwischen zwei reellen Impedanzen. Es besteht aus nur zwei Bauteilen
(Spule + Kondensator) und wird in zwei Konfigurationen genutzt:

- **Tiefpass-Konfiguration:** Spule in Serie + Kondensator parallel zur Last
- **Hochpass-Konfiguration:** Kondensator in Serie + Spule parallel zur Last

Anwendungen: Antennen-Anpassung, PA-Ausgangsstufen, Filter-Designs.

## Funktionsweise
Bei zwei reellen Impedanzen R_low (z.B. 50 Ω Koax) und R_high (z.B. 200 Ω
Antennenfußpunkt) berechnet sich die Güte zu:

`Q = √(R_high / R_low − 1)`

Daraus die Reaktanzen:
- **X_L = R_low × Q** (Spule in Serie zum niedrigen Widerstand)
- **X_C = R_high / Q** (Kondensator parallel zum hohen Widerstand)

Die Komponenten:
- `L_µH = X_L / (2π × f_MHz) × 10³`
- `C_pF = 10⁹ / (2π × f_MHz × X_C)`

## Wahl der Konfiguration
- **Tiefpass:** unterdrückt Oberwellen → für PA-Ausgangsstufen ideal
- **Hochpass:** lässt Harmonische durch → für Empfänger oder reine Antennen-Anpassung

## Praxis-Tipps
- **Spulenmaterial:** Luftspule für hohe Q und PA-Leistung
- **Kondensator-Spannungsfestigkeit:** bei 100 W an 50 Ω herrschen ca. 70 V_eff,
  bei Mismatch und Sättigung können Spitzen >300 V auftreten
- **NP0/C0G-Keramik** für QRP, **Glimmer** für höhere Spannungen, **Vakuum** für PA
- **Q sinnvoll wählen:** Q < 5 = breitbandig, Q > 10 = sehr schmal
- **Verlust pro L-Netz:** typ. 0,1–0,5 dB bei guten Bauteilen

## Bandbreite und Q
- **Q = 2:** ±20 % Bandbreite (sehr breit)
- **Q = 5:** ±10 % Bandbreite
- **Q = 10:** ±5 % Bandbreite (Schmalband-Filter)

Hohe Q bedeutet engere Anpassung, aber sensitiver gegen Bauteiltoleranzen.

## Quellen
- ARRL Handbook: Impedance Matching
- W. Hayward: "Solid State Design for the Radio Amateur"
