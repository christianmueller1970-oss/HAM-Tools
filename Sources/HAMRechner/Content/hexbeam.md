# Hexbeam

## Beschreibung
Der **G3TXQ Hexbeam** (entwickelt von Steve Hunt G3TXQ) ist eine
2-Element-Multibandantenne mit sechs Glasfaser-Spreizern in
60°-Anordnung. Pro Band laufen zwei Drähte (Treiber + Reflektor)
um den Antennenkörper – nur in Strahlungsrichtung bleibt eine
Lücke. Mit ~5 dBd Gewinn pro Band auf nur ca. 6 m Spreizer
(20 m-Band) ist der Hexbeam einer der kompaktesten KW-Beams.

## Funktionsweise
- **Treiber (solid):** V-Form vorne, Speisepunkt in der Mitte
- **Reflektor (gestrichelt):** 5-seitiger Polygonzug um den Rücken
- **Tip Spacer:** kleine Isolatoren an den Spreizer-Enden
- **Speisung:** ≈ 50 Ω direktgekoppelt, kein Anpass-Netzwerk

Formeln:
- **Treiber** = 0,440 × λ
- **Reflektor** = 0,495 × λ (etwas länger)
- **Arm-Länge** (elektr.) = 0,260 × λ
- **Spreizer-Länge** (phys.) = Arm + 20 cm Reserve

Da alle Bänder denselben Antennenkörper teilen, ist die
Bauweise platzeffizient – der größte Arm bestimmt die Gesamtgröße.

## Spreizer-Material (Glasfaserstäbe)
Pro Hexbeam werden **6 Glasfaserstäbe** in der Länge des längsten
aktiven Arms benötigt. Die physische Länge entspricht der
elektrischen Arm-Länge plus ca. 20 cm Reserve für den Tip Spacer
und die Knotensicherung am Ende.

**Standard-Material:** 5,4 m konische Glasfaser-Spreizer (z.B. vom
Spiderbeam-Lieferanten) — passen für 5-Band-Hexbeam 20–10 m. Für
30 m: 7,8 m oder verlängerte Versionen. Für 40 m: 7,8 m als
Linear-Loaded-Variante.

## Einspeisung & Multiband-Verschaltung
Die professionelle Bauart (z.B. VHQ Hexbeam, SP7IDX) nutzt einen
**vertikalen Center Post** aus Aluminium-Vierkantprofil mit
gestapelten Band-Anschlüssen:

- Pro Band ein horizontaler Anschluss aus **zwei Schraubposten**
  (180° gegenüberliegend am Post angeordnet)
- Reihenfolge typisch von oben nach unten: längstes Band (z.B. 20m)
  oben, kürzestes (z.B. 6m) unten
- Die beiden Treiber-Schenkel jedes Bands werden direkt an diese
  Schrauben angeschraubt — kein zentraler Knoten am Hub
- **Koax läuft seitlich am Post hoch** mit Standoffs (zur Vermeidung
  kapazitiver Kopplung zum Mast und zwischen den Bändern)
- Innen am Post sind alle Band-Anschlüsse **parallel** an den
  Koax-Innenleiter bzw. -Mantel geführt

**Funktioniert weil:** Im Resonanzfall ist nur das aktive Band
niederohmig (~50 Ω) und absorbiert die HF-Energie. Andere Bänder
sind off-resonance hochohmig (kapazitiv/induktiv reaktiv) und
ziehen kaum Energie. Da die Bänder oktav-weit gespreizt sind
(14/18/21/24/28 MHz), ist die Kreuzkopplung minimal.

**Funktioniert weil:** Im Resonanzfall ist nur das aktive Band
niederohmig (~50 Ω) und absorbiert die HF-Energie. Andere Bänder
sind off-resonance hochohmig (kapazitiv/induktiv reaktiv) und
ziehen kaum Energie. Da die Bänder oktav-weit gespreizt sind
(14/18/21/24/28 MHz), ist die Kreuzkopplung minimal.

**Mantelwellensperre PFLICHT:** Direkt am Speisepunkt einen
1:1 Strombalun (Choke-Balun, z.B. 8–12 Wdg. Koax auf FT240-43)
einsetzen. Sonst läuft HF auf dem Koax-Mantel zurück und das
Vor-Rück-Verhältnis bricht ein.

**Reflektoren:** Komplett isolierte 5-seitige Polygone — KEINE
Verkabelung, keine Verbindung zum Speisepunkt. Werden nur durch
parasitäre Kopplung erregt.

## Praxis-Tipps
- **Glasfaser-Spreizer:** Spiderbeam-Set (sehr robust) oder Angelruten
- **Drahtmaterial:** CuLi 1,5 mm² – knickfrei verlegen
- **Tip Spacer:** kleine UV-feste Kunststoff-T-Stücke
- **Aufhängung:** mind. 6–8 m Mast, Rotor empfohlen
- **F/B-Verhältnis:** 15–20 dB
- **WARC-Bänder:** lieber Standard-Bänder einzeln aufbauen, WARC mischen ist
  schwieriger zu trimmen
- **Wind:** kompakter als Yagi, deutlich weniger Windlast
- **Kurze Verbindungen am Hub:** parasitäre Kapazität minimieren

## Quellen
- Steve Hunt G3TXQ: Original-Designs + Maße
- DK7ZB: Bauanleitungen für 5-Band-Hexbeam
- VHQ Hexbeam Assembly Manual & SP7IDX Hexbeam: Center-Post-Konstruktion
- Frage von HB9EIZ (Mai 2026): Spreizer-Länge, Einspeisung, Multiband-Verschaltung
