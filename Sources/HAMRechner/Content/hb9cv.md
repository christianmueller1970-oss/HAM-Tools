# HB9CV Beam

## Beschreibung
Die **HB9CV-Antenne** ist ein 2-Element-Yagi-ähnlicher Richtstrahler mit
einer charakteristischen **gekreuzten Phasenleitung** zwischen Reflektor
und Direktor. Entwickelt von **HB9CV** (Rudolf Baumgartner) in den
1950er-Jahren, kombiniert sie kompakte Bauweise mit gutem Gewinn
(≈ 5–6 dBd) und ordentlichem F/B-Verhältnis (~10–15 dB). Beliebt für
2 m und 70 cm – als Drahtversion auch auf KW.

## Funktionsweise
Beide Elemente werden aktiv gespeist – im Gegensatz zur klassischen Yagi,
wo Reflektor und Direktoren parasitär arbeiten. Eine **Phasenleitung
mit 180°-Phasenversatz** koppelt Reflektor und Direktor:

- **Reflektor (L1)** = 0,500 × λ × VF (etwas länger)
- **Direktor (L2)**  = 0,460 × λ × VF (etwas kürzer)
- **Boom-Abstand**   = 0,10–0,15 × λ (kompakt)
- **Speisung:** über Gamma-Match am Reflektor (typisch) oder direkt
  über 50 Ω-Anpassung

Die Phasenleitung sorgt dafür, dass beide Elemente gegenphasig
abstrahlen – das gibt eine ausgeprägte Vorwärtsrichtwirkung mit
gleichzeitig kompakter Bauweise.

## Praxis-Tipps
- **Phasenleitung-Impedanz:** ca. 240 Ω, entspricht zwei parallelen
  Drähten mit ~10–15 mm Abstand
- **Phasenleitung-Länge:** = Boom-Abstand (also der gleiche Wert wie der Boom)
- **Gamma-Match-Abgleich:**
  1. Innenleiter-Länge des Gamma-Stabs einstellen
  2. Anpass-Kondensator (10–60 pF, variabel) iterativ verstellen
  3. Auf SWR-Minimum optimieren
- **Element-Durchmesser:** geht in den VF ein – dickere Elemente werden etwas kürzer
- **Drahtversion (Spiderbeam-Style):** CuLi auf Glasfaser-Spreizern, sehr leicht und klein
- **Rohrversion:** Aluminiumrohr 4–8 mm Ø, mechanisch robust

## Vorteile / Nachteile
**Vorteile:**
- Kompakte Bauweise (Boom 10–15 % der λ)
- Gewinn ähnlich 3-Element-Yagi
- Tolerant gegen mechanische Toleranzen

**Nachteile:**
- F/B-Verhältnis schlechter als 3-Element-Yagi
- Aufwendiger Abgleich (Gamma-Match + Phasenleitung)
- Schmaler Anpass-Bereich

## Quellen
- HB9CV (Rudolf Baumgartner): Original-Beschreibung in der Schweizer Funkzeitschrift "old man" (1955)
- DK7ZB: HB9CV-Bauanleitungen für 2m/70cm
- Rothammels Antennenbuch
