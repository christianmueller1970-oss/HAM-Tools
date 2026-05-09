# HAM-Tools

**Amateurfunk-Rechner für macOS** — eine native SwiftUI-App mit Berechnungswerkzeugen für Antennen, Leitungen, Spulen und Signale.

Entwickelt von **Christian Mueller HB9HJI**

---

## Funktionen (V1.0)

### Drahtantennen
| Rechner | Beschreibung |
|---|---|
| Dipol | Halbwellen-Dipol, Längenberechnung nach Band |
| Groundplane / Vertikal | λ/4-Vertikal mit Radials |
| J-Pole / Slim Jim | J-Pole und Slim-Jim Berechnungen |
| Sperrtopf | Koaxialer Sperrtopf (Mantelwellensperre) |
| Windom (OCFD) | Off-Center-Fed Dipol mit Speisepunkt |
| EFHW-Verkürzung | Endfed-Halbwellen mit Verkürzungsspule |
| Loop-Antenne | Geschlossene Schleifantennen |

### Richtstrahler
| Rechner | Beschreibung |
|---|---|
| Moxon Rectangle | Kompakter 2-Element-Beam |
| HB9CV Beam | 2-Element mit Phasenleitung |
| Hexbeam | G3TXQ-Hexbeam, mehrbandig (10/15/20/40m), mit Draufsicht und Seitenansicht |
| Yagi-Rechner | 2–6-Element Yagi nach Rothammel |
| Spiderbeam Einzelband | Leichter Fiberglas-Monoband-Beam |
| Spiderbeam Multi-Band | Mehrband-Spiderbeam |

### Spezialantennen
| Rechner | Beschreibung |
|---|---|
| Magnetic Loop | Abstimmbare Magnetschleife (Kapazität, Güte, Bandbreite) |
| Antennen-Designer | Freier Antennen-Entwurf |

### Spulen & Transformatoren
| Rechner | Beschreibung |
|---|---|
| Balun / Unun | Balun- und Unun-Wicklungsrechner (1:1, 4:1, 9:1…) |
| Strahler-Verlängerung | Verlängerungsspule für verkürzte Strahler |
| Spulen-Wickler | Luftspulen-Rechner (Windungen, Induktivität) |

### Anpassung & Leitungen
| Rechner | Beschreibung |
|---|---|
| Anpassnetzwerk (L-Netz) | L-Netz Impedanzanpassung |
| Koax-Stub | λ/4- und λ/2-Stub-Längen mit Schema |
| Kabeldämpfung | Dämpfung verschiedener Koaxtypen |

### Signale & Tools
| Rechner | Beschreibung |
|---|---|
| Pegel-Umrechner | dBm / dBW / V / µV / W |
| SWR-Simulator | SWR-Kurve und Rückflussdämpfung |
| Linkbudget / Reichweite | Friis-Formel, Freiraumdämpfung, Link-Margin |
| QTH-Locator | Maidenhead-Locator ↔ Koordinaten, Distanz & Richtung |

---

## Voraussetzungen

- **macOS 14** (Sonoma) oder neuer
- **Swift 5.9** oder neuer (Xcode 15+)

## Build & Start

```bash
git clone https://github.com/christianmueller1970-oss/HAM-Tools.git
cd HAM-Tools
swift run HAMRechner
```

Oder in Xcode öffnen: `File › Open › Package.swift`

---

## Projektstruktur

```
Sources/HAMRechner/
├── App/                    ContentView, Router, AppEntry
├── Shared/Components/      SectionCard, ResultRow, gemeinsame UI-Bausteine
└── Features/               Ein Ordner pro Rechner
    ├── Hexbeam/
    ├── YagiRechner/
    ├── QTHLocator/
    └── …
```

---

## Lizenz

MIT License — freie Nutzung, Weitergabe und Modifikation mit Nennung des Autors.

---

## Autor

**Christian Mueller — HB9HJI**  
Amateurfunker, Schweiz  
GitHub: [christianmuller1970-oss](https://github.com/christianmuller1970-oss)

> *73 de HB9HJI*
