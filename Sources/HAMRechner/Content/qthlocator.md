# QTH-Locator

## Beschreibung
Das **Maidenhead-Locator-System** (auch: IARU-Locator oder QTH-Locator)
ist ein weltweit verwendetes Geocoding-Schema für Amateurfunk-Standorte.
Es teilt die Erde in immer feinere Felder ein und liefert kompakte,
gut auszusprechende Codes — ideal für QSO-Logs, Diplom-Anträge, Contests
und VHF/UHF-Verbindungen, wo der Locator das Ziel ist.

## Aufbau des Locators

| Stelle | Format | Beispiel | Größe |
|---|---|---|---|
| 1–2 | Großbuchstabe | **JN** | Feld (20° × 10°) |
| 3–4 | Ziffer | **47** | Quadrat (2° × 1°) |
| 5–6 | Kleinbuchstabe | **PN** | Subquadrat (5' × 2,5', ca. 2,5 km) |
| 7–8 | Ziffer (optional) | **45** | erweiterte Genauigkeit (~250 m) |

Beispiel: **JN47PN** = 6-stellig = ±2,5 km Genauigkeit
(meine QTH-Region in der Schweiz)

## Funktionsweise (Berechnung)
**Locator → Koordinaten:**
- A–R repräsentiert 20° (Längengrad) bzw. 10° (Breitengrad)
- 0–9 unterteilt in 2° / 1°
- a–x (Kleinbuchstaben) unterteilt weiter in 5' / 2,5'

**Koordinaten → Locator:**
Umkehrung obiger Schritte: durch Division mit Rest die Buchstaben/Ziffern
ableiten, beginnend mit dem groben Feld.

## Praxis-Tipps
- **6-stellig genügt** für die meisten Anwendungen (~2,5 km Genauigkeit)
- **8-stellig** für VHF/UHF-Tropo-Tests, Mikrowellen-Verbindungen, EME
- **Häufige Fehler:**
  - Verwechslung von Buchstaben/Ziffern (O ↔ 0, I ↔ 1)
  - Großbuchstaben in Position 5–6 sollten Kleinbuchstaben sein
  - West-Länge wird negativ → Locator beginnt mit niedrigen Buchstaben (A–G)
- **Distanz zwischen 2 Locatoren:** über Kugel-Geometrie, nicht euklidisch
- **Online-Tools:** dxcc.club, qrz.com Map, F4ENO

## Bekannte Locatoren in Mitteleuropa
| QTH | Locator |
|---|---|
| Berlin | JO62QM |
| München | JN58SD |
| Wien | JN88EE |
| Zürich | JN47BG |
| Bern | JN36WW |
| London | IO91WM |

## Quellen
- John Morris G4ANB (1980): "Locator System"
- IARU Region 1: VHF-Manager's Handbook
- ARRL: Maidenhead Grid Locator System
