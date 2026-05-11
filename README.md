# HAM-Tools

**Amateurfunk-Rechner für macOS** — eine native SwiftUI-App mit Berechnungswerkzeugen für Antennen, Leitungen, Spulen und Signale sowie Live-Tools für den aktiven Amateurfunk-Betrieb.

Entwickelt von **Christian Mueller HB9HJI**

---

## Funktionen (V1.3)

### Live-Tools (NEU in V1.1)

#### DX-Cluster
Vollständige DX-Cluster-Workstation mit TCP-Verbindung zu DXSpider-Knoten und REST-API-Integration für SOTA, POTA und WWFF.

| Feature | Beschreibung |
|---|---|
| Spot-Liste | Farbkodierte Tabelle mit Band/Mode/DX-Call/Land/Kontinent, sortierbar |
| Bandmap | Frequenz-Balkendiagramm pro Band, zeitgefiltert, farblich nach Mode |
| Weltkarte | MapKit-Karte mit Spot-Markern und Spotter-Linien |
| Statistik | Spots/Band, Spots/Mode, Top-15-DX-Calls, 24h-Verlauf (SwiftUI Charts) |
| Propagation-Panel | NOAA SFI/Kp-Gauges + Band-Activity-Heatmap |
| SOTA / POTA / WWFF | REST-API-Fetcher mit Live-Polling |
| DX-Spot senden | Spot-Dialog mit Frequenz, Rufzeichen und Kommentar |
| Cluster-Verwaltung | Mehrere DXSpider-Knoten konfigurierbar, Einzel-Aktivierung |
| Spotter-Radius-Filter | Spots nach Entfernung vom eigenen QTH (Haversine) |
| Watch List / Alerts | Prefix/Rufzeichen-Überwachung mit macOS-Benachrichtigungen und ★-Markierung |
| Spot-Persistenz | Bis zu 500 Spots, 24h-Retention, JSON in Application Support |
| 3-Theme-System | HAM Style, Dark, Ham Classic — wechselbar im laufenden Betrieb |

**Filter:** Band, Mode, Kontinent, Quelle (DX/SOTA/POTA/WWFF), Freitext, Spotter-Radius  
**Cluster-Knoten:** DXSpider Funkwelt, HB9W, DB0ERF, DX.OE5TXF, ON0ANT, VE7CC (konfigurierbar)

---

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
| QTH-Locator | Maidenhead (6/8-stellig) ↔ Koordinaten, Karte, SOTA/POTA, Höhenprofil, Fresnel-Zonen, LOS mit Erdkrümmung (NEU in V1.3) |

---

## Voraussetzungen

- **macOS 14** (Sonoma) oder neuer
- **Swift 5.9** oder neuer (Xcode 15+)

## Build & Start

```bash
git clone https://github.com/christianmuller1970-oss/HAM-Tools.git
cd HAM-Tools
swift run HAMRechner
```

Oder in Xcode öffnen: `File › Open › Package.swift`

---

## Projektstruktur

```
Sources/HAMRechner/
├── App/                        ContentView, Router, AppEntry
├── Shared/
│   ├── Components/             SectionCard, ResultRow, gemeinsame UI-Bausteine
│   └── Theme/                  AppTheme, ThemeManager (3 Themes)
└── Features/
    ├── DXCluster/              Live DX-Cluster Workstation
    │   ├── Models/             DXSpot, BandData, DXCCData, Persistenz, WatchList
    │   ├── Network/            ClusterClient (TCP), PropagationFetcher, APIFetcher
    │   ├── ViewModels/         DXClusterViewModel (@MainActor)
    │   └── Views/              SpotList, Bandmap, Weltkarte, Statistik, Log, Panel
    ├── Settings/               EinstellungenView (Station, Cluster, Darstellung, Alerts)
    ├── Hexbeam/
    ├── YagiRechner/
    ├── QTHLocator/
    └── …                       25 weitere Rechner-Features
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
