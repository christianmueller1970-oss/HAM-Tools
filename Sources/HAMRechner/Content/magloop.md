# Magnetic Loop

## Beschreibung
Eine **Magnetic Loop** (Schmalband-Antenne) ist eine kreisförmige,
quadratische oder achteckige Drahtschleife mit einem Umfang von
typischerweise **< 1/10 λ**. Sie ist sehr klein im Vergleich zu
"normalen" Antennen, hat eine extrem schmale Bandbreite und
benötigt einen hochwertigen Drehkondensator zur Abstimmung.
Beliebt für Indoor- und Balkonbetrieb sowie Stealth-Aufbauten.

## Funktionsweise
Bei λ/10-Umfang wirkt die Loop hauptsächlich über das
**Magnetfeld** (statt elektrischem Feld wie ein Dipol) – daher der
Name. Die Schleife bildet zusammen mit einem Abstimmkondensator
einen LC-Schwingkreis mit sehr hohem Q (>200 typisch).

Wichtige Kenngrößen:
- **Induktivität L:** abhängig von Geometrie und Drahtdurchmesser
- **Resonanzkapazität C:** umgekehrt proportional zu L und f²
- **Spannung am Drehko:** kann **mehrere kV** erreichen!
- **Wirkungsgrad η:** je größer die Loop und je dicker das Rohr, desto besser

## Bauanleitung
- **Material:** Kupferrohr 15–25 mm Ø oder Kupferband – hauptsächlich Skin-Effekt-Verluste
- **Drehkondensator:** Vakuum-Kondensator (Standard) oder Spread-Plate mit großem Plattenabstand
- **Kopplungsschleife:** kleine Faraday-Schleife mit ⌀ ≈ 1/5 des Hauptloops, am
  unteren Ende montiert
- **Position der Kopplung:** experimentell – Abstand und Drehung beeinflussen
  die Anpassung auf 50 Ω
- **Frequenz-Abstimmung:** ausschließlich über Drehko-Kapazität

## Sicherheit – sehr wichtig
- **Lebensgefahr** durch Hochspannung am Drehko (1–5 kV typisch bei 100 W)
- **Niemals während Betrieb anfassen** – HF-Hautverbrennung möglich
- **Vakuum-Kondensator** oder weit-spaced Air-Drehko verwenden
- **Wetterschutz** für Drehko (Feuchtigkeit + HV = Sprühentladung)

## Praxis-Tipps
- **Wirkungsgrad:** auf 80 m typ. 5–15 %, auf 20 m 50–70 %, auf 10 m bis 95 %
- **Bandbreite:** sehr schmal (typ. 1–10 kHz bei 80 m, 10–30 kHz bei 20 m)
- **Aufbau-Höhe:** weniger kritisch als bei Dipolen – auch nahe Boden brauchbar
- **Polarisation:** Loop senkrecht = horizontal polarisiert,
  Loop horizontal = vertikal polarisiert (entgegen Intuition!)

## Quellen
- ARRL Antenna Book: Loop Antennas
- AA5TB (Steve Yates): umfangreiche Magloop-Theorie
