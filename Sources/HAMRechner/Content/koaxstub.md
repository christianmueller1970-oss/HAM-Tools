# Koax-Stub

## Beschreibung
Ein **Koax-Stub** ist ein Stück Koaxialkabel definierter Länge, das parallel
in eine Übertragungsleitung eingeschleift wird, um auf einer bestimmten
Frequenz **Bandsperren** (Notch) oder **Bandpässe** zu erzeugen.
Stub-Filter sind günstig (Kabelreste!), präzise und kommen ohne aktive
Bauteile aus.

## Funktionsweise
Ein Stub ist eine Leitung, die an einem Ende **offen** oder
**kurzgeschlossen** abgeschlossen ist. Je nach Länge und Abschluss
transformiert der Stub die Eingangsimpedanz:

| Stub-Typ | Wirkung am Speisepunkt | Anwendung |
|---|---|---|
| **λ/4 offen** | wirkt wie Kurzschluss | Bandsperre (Notch) |
| **λ/4 kurz** | wirkt wie Leerlauf | transparent |
| **λ/2 offen** | wirkt wie Leerlauf | transparent |
| **λ/2 kurz** | wirkt wie Kurzschluss | Bandsperre |

Die physikalische Länge berücksichtigt den **Verkürzungsfaktor (VF)** des
Koax — typ. 0,66 (PVC), 0,82 (Schaum), 0,85 (PE):

`L = (300 / f / 4) × VF` (für λ/4)

## Praxis-Anwendungen
- **Oberwellen-Filter** vor TX-Ausgang (z.B. λ/4 offener Stub auf 2× Sendefrequenz)
- **Empfänger-Schutz** vor lokalen Störquellen (Mobilfunk-Notch)
- **Mehrere Sender auf eine Antenne** über Stub-Diplexer
- **Mantelwellensperre** mit λ/4-Stub kurzgeschlossen

## Praxis-Tipps
- **Toleranzen:** Stub-Länge auf ±2 % genau zuschneiden, dann mit Antennenanalysator nachtrimmen
- **VF testen:** 1 m Probestück, Resonanzfrequenz messen, dann VF rückrechnen
- **Hochwertiger Koax** für hohe Q (RG-213 besser als RG-58)
- **PL-T-Stück** zum Einschleifen, kurze Stub-Anschlussleitung
- **Bandbreite einer λ/4-Sperre:** typ. ±5 % bei -20 dB Dämpfung
- **Kaskadierung** möglich: zwei Stubs auf gleicher Frequenz für tiefere Sperre

## Quellen
- ARRL Antenna Book: Transmission Lines + Stubs
- DK7ZB: Stub-Filter für Contest-Stationen
