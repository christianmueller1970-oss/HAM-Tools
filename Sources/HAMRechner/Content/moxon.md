# Moxon Rectangle

## Beschreibung
Die **Moxon-Antenne** ist ein kompakter 2-Element-Beam (Treiber +
Reflektor) mit nach innen gefalteten Element-Enden. Sie hat einen
Footprint, der nur etwa **30 % kleiner** ist als ein vergleichbarer
Yagi, bietet aber sehr ähnliche elektrische Eigenschaften:
~5 dBd Gewinn und 20–30 dB Front/Back-Verhältnis. Speisepunkt-Impedanz
ist direkt 50 Ω – kein Anpassglied nötig.

## Funktionsweise
Der Treiber (Driven Element, vorne) und Reflektor (hinten) sind über
ihre nach innen gefalteten Enden gekoppelt. Die Lücke (Spalt) zwischen
den gefalteten Enden bestimmt zusammen mit der Boom-Tiefe die Resonanz
und das F/B-Verhältnis. Die Geometrie nach **G3TXQ-Koeffizienten**:

- **A** = 0,4750 × λ × VF – Horizontale Seite
- **B** = 0,0500 × λ × VF – Treiber-Rücklauf (je Seite)
- **C** = 0,0156 × λ × VF – Lücke (Spalt) zwischen Treiber und Reflektor
- **D** = 0,0624 × λ × VF – Reflektor-Rücklauf (je Seite)
- **E** = A – Reflektor-Horizontale (gleich Treiber-Horizontale)

Hauptstrahlrichtung ist senkrecht zum Treiber, Front zum geschlossenen
Ende, Back zum Reflektor.

## Praxis-Tipps
- **Drahtversion:** CuLi 1,5 mm², Spreizer aus Glasfiber oder PVC-Rohr
- **Rohrversion:** Aluminiumrohr 6–10 mm Ø für VHF/UHF
- **Lücke C exakt:** entscheidet über die Resonanz – bei Aufbau iterativ einstellen
- **Element-Durchmesser** geht in den VF ein: dickere Elemente = etwas kleiner
- **Speisepunkt:** in der Mitte des Treibers, mit 1:1 Strombalun
- **Freistrahlend:** mind. λ/2 über Grund und allen Hindernissen
- **Drehbar montieren:** Beam-Antenne braucht Rotor

## Vorteile gegenüber Yagi
- ~30 % geringerer Footprint
- 50 Ω direkt – kein Gamma-Match oder Hairpin
- Nur 2 Elemente – leichter, weniger Material
- Ähnlicher Gewinn und besseres F/B als 2-Element Yagi

## Quellen
- L. B. Cebik W4RNL: "The Moxon Rectangle Antenna"
- G3TXQ (Steve Hunt): Moxon-Geometrie-Untersuchungen, vereinfachte Formeln
