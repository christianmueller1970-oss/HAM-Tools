# Yagi-Rechner

## Beschreibung
Die **Yagi-Uda-Antenne** (kurz "Yagi", entwickelt 1926 von Hidetsugu
Yagi und Shintaro Uda) ist die wahrscheinlich bekannteste
Richtantenne. Sie besteht aus einem **Reflektor** (hinten),
einem **Treiber** (Strahler, gespeist) und mehreren **Direktoren**
(vorne) auf einem gemeinsamen Boom. Mehr Elemente bedeuten mehr
Gewinn und schmalere Hauptkeule.

## Funktionsweise
Nur der Treiber wird aktiv gespeist. Reflektor und Direktoren sind
**parasitäre Elemente** – ihre Phasenlagen werden über die
Element-Längen und Boom-Abstände eingestellt:

- **Reflektor:** etwas länger als λ/2 → induktive Kopplung, reflektiert nach vorn
- **Treiber:** ca. 0,47 × λ (mit VF), Speisepunkt
- **Direktoren:** etwas kürzer als λ/2 → kapazitive Kopplung, fokussieren nach vorn

Typische Performance:
- **2 Element:** ~6 dBi Gewinn, F/B ~10 dB
- **3 Element:** ~7,5 dBi, F/B ~20 dB
- **4 Element:** ~8,5 dBi, F/B ~22 dB
- **5 Element (OWA):** ~9,8 dBi, F/B ~25 dB

## Praxis-Tipps
- **Element-Durchmesser:** dicker = breitbandiger, kürzer (höherer VF)
- **Boom-Material:** Aluminiumrohr (KW) oder Vierkantprofil
- **Element-Halterungen:** isolierend (Kunststoff) oder durch Boom-Bohrung mit Isolator
- **Speisung:** 1:1 Strombalun gegen Mantelwellen
- **OWA-Designs (Optimized Wideband Yagi):** breitbandiger als klassische Yagi
- **Aufhängehöhe:** mind. λ/2 über Hindernissen, drehbar mit Rotor

## Drahtversion (Spiderbeam-Style)
- Glasfiber-Spreizer ersetzen das Alurohr
- Sehr leicht (~5 kg statt 15 kg) und kleiner Windlast
- CuLi 1,5–2,5 mm² Draht statt Rohr
- Aufbau auf Glasfaser-Boom, Elemente per Spreizern aufgespannt

## Quellen
- ARRL Antenna Book: Yagi-Uda Antennas
- Carl Reinhardt DJ7VY: "DJ7VY OWA-Yagi-Designs"
- DK7ZB: Yagi-Designs für 6m, 2m, 70cm
