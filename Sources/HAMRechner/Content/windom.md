# Windom (OCFD)

## Beschreibung
Die Windom-Antenne (englisch *Off-Center Fed Dipole*, OCFD) ist eine
horizontale Multiband-Drahtantenne. Im Gegensatz zum klassischen Dipol
liegt ihr Speisepunkt **nicht in der Mitte**, sondern bei etwa 36 % der
Gesamtlänge. Dadurch erschließt sich eine reproduzierbare
Mehrband-Resonanz auf mehreren Amateurfunkbändern ohne Antennentuner.

## Funktionsweise
Die Verschiebung des Speisepunkts auf 36/64 % bewirkt, dass auf der
Grundwelle (λ/2) und mehreren geradzahligen Harmonischen (1, 2, 4, 6 …)
eine vergleichbare Speisepunkt-Impedanz von rund **200–300 Ω** entsteht.
Das ermöglicht den Multiband-Betrieb mit nur einem festen Anpasselement.

Der hohe Speisepunktwiderstand wird mit einem **4:1 oder 6:1 Strombalun**
auf 50 Ω heruntertransformiert. Dieser Balun (typischerweise auf
FT240-43 Ringkern) sitzt direkt am Speisepunkt.

## Praxis-Tipps
- **Berechnung:** Gesamtlänge = 150 / f<sub>Grundwelle</sub> × VF (in m)
- **Lange Seite (64 %):** strahlt vorwiegend, längere Antennenseite
- **Kurze Seite (36 %):** Speisung erfolgt hier am Übergang
- **Balun:** **4:1 Current/Strom-Balun** (Guanella-Bauweise) auf FT240-43
- **Koax direkt unter Balun:** weiteren Mantelwellensperre einbauen für saubere Symmetrierung
- **Frequenz-Wahl:** Grundwelle bestimmt die Gesamtlänge, alle Harmonischen nutzbar

## Resonanzbänder (Beispiel: 40 m Grundwelle = 7,1 MHz)
- 40 m, 20 m, 17 m, 15 m, 12 m, 10 m – alle ohne Tuner

## Praxis-Tipps zum Aufbau
- **Aufhängehöhe** wie beim Dipol: mindestens λ/4 der niedrigsten Frequenz
- **Endisolatoren** wie beim Dipol verwenden
- **Drahtmaterial:** CuLi (Kupfer-Litze) gegen Bruch, ggf. mit Stahlseele

## Quellen
- Loren G. Windom W8GZ (1929) – Original-Patent
- Rothammels Antennenbuch: Off-Center Fed Antennas
