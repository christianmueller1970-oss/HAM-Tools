# Hexbeam

## Beschreibung
Der **G3TXQ Broadband Hexbeam** (entwickelt von Steve Hunt G3TXQ) ist eine
2-Element-Multibandantenne mit sechs Glasfaser-Spreizern in 60°-Anordnung.
Pro Band laufen zwei Drähte (Driver + Reflektor) entlang den Spreizern.
Mit ~3,5–3,8 dBd Gewinn pro Band und nur 3,46 m horizontalem Spreader-Radius
(20 m-Band) ist der Hexbeam einer der kompaktesten KW-Beams.

Die Werte und Geometrie dieses Rechners sind G3TXQ-konform und referenzieren
die offiziell lizenzierte **WiMo EAntenna HEX6B** Bauanleitung.

## Funktionsweise
- **Driver (solid):** V-Form vorne, Apex am Center-Post (Koax-Einspeisung),
  Endpunkte an den zwei Front-Spreader-Tips
- **Reflektor (gestrichelt):** 3-Sehnen-Bogen hinten durch die 4 hinteren
  Spreader-Tips (90° → 150° → 210° → 270°), vorne offen
- **Tip Spacer:** PVC-Isolator am Front-Spreader-Tip zwischen Driver-Ende
  und Reflektor-Anfang. Mechanisch verbunden, elektrisch isoliert.
- **Speisung:** ≈ 50 Ω direktgekoppelt, kein Anpass-Netzwerk

## Maße (G3TXQ-Faktoren, abgeleitet aus 20m-Referenz)

| Maß | 20m-Wert | Faktor × λ |
|---|---|---|
| ½ Driver (Drahtlänge, 3D) | 214″ = 5,44 m | 0,2570 |
| Reflektor (Drahtlänge, 3D) | 404″ = 10,26 m | 0,4849 |
| Tip Spacer (PVC) | 24″ = 0,61 m | 0,0288 |
| Spreader-Radius (horiz.) | 11′4″ ≈ 3,46 m | 0,1635 |

Andere Bänder werden linear mit λ skaliert. Die Drahtlängen sind 3D entlang
dem gebogenen Spreader-Pole (Schüsselform), die Top-View-Skizze zeigt die
horizontale Projektion.

## Schüsselform und Pole-Länge
Die 6 Spreader-Poles biegen sich nach oben/außen zu einer Schüssel
(siehe WiMo HEX6B Bauanleitung, Side View Seite 4/13). Der **Pole-Länge
entlang dem Bogen** ist ca. π/2 × Horizontal-Radius (Halbkreis-Schüssel),
also bei einer 20m-Hexbeam: ~5,4 m Pole-Bogenlänge bei ~3,5 m
Horizontal-Radius. Niedere Frequenzen sitzen oben am Schüsselrand
(großer Radius), höhere Frequenzen tiefer im Inneren (kleiner Radius).

## Spreader-Material (Glasfaserstäbe)
Pro Hexbeam werden **6 Glasfaserstäbe** in einer Länge entsprechend der
Pole-Bogenlänge des längsten aktiven Bandes benötigt.

**Standard-Material:** 5,4 m konische Glasfaser-Spreizer (z. B. vom
Spiderbeam-Lieferanten) — passend für eine 6-Band-Hexbeam 20–6 m
(WiMo HEX6B / G3TXQ-Standard). Für 30 m oder 40 m: längere
Spezialausführungen erforderlich, ist aber praktisch ungewöhnlich.

## Eyelet-Anordnung (WiMo HEX6B)
Pro Pole sind die 6 Wire-Eyelets entlang des Spreaders verteilt — Reihenfolge
von Spreader-Tip (außen) nach Center (innen):

1. 12E (am 12 mm-Element, äußerste Eyelet) — **20m**
2. 12E (am 12 mm-Element) — **17m**
3. 16E (am 16 mm-Element) — **15m**
4. 16E — **12m**
5. 16E — **10m**
6. 20E (am 20 mm-Element, nächste am Center) — **6m**

Niedrigste Frequenz = größter Radius (am Spreader-Tip), höchste Frequenz =
kleinster Radius (innen). Die Bracket-Bezeichnungen (12, 16, 20) bezeichnen
den Durchmesser des Pole-Segments, NICHT das Band.

## Einspeisung & Multiband-Verschaltung
Der **vertikale Center Post** aus Aluminium-Vierkantprofil hat
6 horizontale Anschluss-Reihen (eine pro Band):

- Pro Band ein horizontaler Anschluss aus **zwei Schraubposten**
  (180° gegenüberliegend)
- Reihenfolge typisch oben nach unten: **20m** oben, **6m** unten
  (siehe HEX6B Anleitung Seite 5)
- Die beiden Driver-Halbschenkel jedes Bands werden direkt an diese
  Schrauben angeschraubt — kein zentraler Knoten am Hub
- **Koax läuft seitlich am Post hoch** mit Standoffs (zur Vermeidung
  kapazitiver Kopplung zum Mast und zwischen den Bändern)
- Innen am Post sind alle Band-Anschlüsse **parallel** an den
  Koax-Innenleiter bzw. -Mantel geführt
- **1:1 Balun** ist bereits vormontiert im Center-Post (WiMo HEX6B)

**Funktioniert weil:** Im Resonanzfall ist nur das aktive Band
niederohmig (~50 Ω) und absorbiert die HF-Energie. Andere Bänder
sind off-resonance hochohmig (kapazitiv/induktiv reaktiv) und
ziehen kaum Energie. Da die Bänder oktav-weit gespreizt sind
(14/18/21/24/28 MHz), ist die Kreuzkopplung minimal.

## Specs WiMo HEX6B (G3TXQ-Standard)
- **Peak Gain:** 20m 3,8 dBd · 17m 3,2 dBd · 15m 3,5 dBd · 12m 3,0 dBd · 10m 3,6 dBd · 6m 3,7 dBd
- **F/B:** 13–22 dB
- **SWR 2:1 B/W:** 20m 350 kHz · 17m 100 kHz · 15m 450 kHz · 12m 100 kHz · 10m 1400 kHz · 6m 500 kHz
- **Gewicht:** 8,1 kg
- **Max. Leistung:** 5 kW

## Praxis-Tipps
- **Drahtmaterial:** CuLi 1,5 mm² – knickfrei verlegen
- **Tip Spacer:** UV-feste PVC-T-Stücke (Standard-WiMo-Bauteil)
- **Aufhängung:** mind. 6–8 m Mast, Rotor empfohlen
- **WARC-Bänder:** 17m und 12m sind im G3TXQ-Standard-Set enthalten
- **Wind:** kompakter als Yagi, deutlich weniger Windlast
- **Schüssel-Tiefe:** ca. 20 % des Horizontal-Radius (für 20m: ~70 cm Sag)

## Quellen
- Steve Hunt G3TXQ: Original-Design + Maße
- WiMo EAntenna HEX6B (Art.-Nr. 17820.HEX6B): G3TXQ-lizenzierte
  Bauanleitung, Rev. V2.1 (05JUL2022) — Single Source of Truth
  für die Maße in diesem Rechner
- Feedback Markus HB9EIZ (Mai 2026): Hinweis auf G3TXQ-konforme Maße
  und Bereitstellung der HEX6B-Bauanleitung
