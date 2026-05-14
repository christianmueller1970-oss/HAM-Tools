# HAM-Tools

**Native macOS-App für Funkamateure** — Logbuch mit vier Award-Programmen
(POTA, SOTA, WWFF, BOTA), Contest-Logger mit Cabrillo V3, CAT-Steuerung
via Hamlib für Yaesu/Icom/Kenwood/Elecraft, DX-Cluster-Integration und
über 25 Berechnungswerkzeuge für Antennen, Leitungen, Spulen und Signale.

Entwickelt von **Christian Mueller HB9HJI**

---

## Funktionen (V1.8.1)

### Logbuch

Vollständiges Logger-Modul im Desktop-Logger-Stil mit Multi-Log-Architektur,
Online-Lookups und Cross-Modul-Integration. Vier voll umgesetzte Award-
Programme (POTA, SOTA, WWFF, BOTA) mit gemeinsamem Outdoor-Sub-Picker.

| Feature | Beschreibung |
|---|---|
| Multi-Log-Architektur | Eine SQLite-Datei pro Logbuch (.htlog), Standard / Contest / POTA / SOTA / WWFF / BOTA |
| **POTA-Modus** | ~91k Parks aus pota.app, Activator/Hunter, 10-QSO-Counter, Multi-Park-Hopping, Live-Spots, Map, Awards (Phase 4c) |
| **SOTA-Modus** | ~181k Summits aus sotadata.org.uk, Activator/Chaser, 4-QSO-Counter + Winterbonus, S2S, Live-Spots, Map, Awards (Phase 4d) |
| **WWFF-Modus** | Doppelpfad-DB (URL + CSV-Import), Activator/Hunter, 44-QSO-Counter, R2R, DX-Cluster-gefilterte Spots, Map, Awards (Phase 4e) |
| **BOTA-Modus** | CSV-Import-DB, Activator/Hunter (1 QSO), B2B, DX-Cluster-gefilterte Spots mit DB-Match, Map, Awards (Phase 4f) |
| **Outdoor-Sub-Picker** | DX/Contest/Outdoor als 3 Haupt-Tabs, sub-bar POTA/SOTA/WWFF/BOTA — skaliert auf weitere Programme |
| Konfigurierbarer Datenordner | Default `~/Documents/HAM-Tools/`, alle Daten zentral (Logs/Cache/Exports/Backups/Audio) |
| QSO-Eingabe-Panel | Drei-Spalten-Form im Desktop-Logger-Look mit Auto-Band, RST-Mode-Defaults, Time-On-Live |
| Frequenz aus Radio-Panel | Zentrale Quelle (manuell oder ab Phase 5 via CAT/Hamlib) |
| Spot-Bridge | DX-Cluster-Spot doppelklicken → QSO-Form vorausgefüllt, POTA/SOTA-Refs aus Comment extrahiert |
| Callbook-Lookup | QRZ.com + HamQTH.com mit Primary/Fallback-Logik, Cache 30 Tage, Profilbild |
| Auto-Fill bei TAB | Sobald der Call eingegeben wird, füllen Name/QTH/Locator/CQ/ITU/DXCC automatisch |
| Bulk-Lookup | QSOs in der Tabelle markieren → »QRZ für N Auswahl« ergänzt fehlende Daten |
| Previous-Button | Frühere QSOs mit demselben Call über ALLE Logs als Popover |
| Duplicate-Warnung | Exact-Match (Call+Band+Mode) + Recent-Match (selber Call in 30 min) |
| ADIF Import/Export/Merge | Phase 2: ADIF 3.x mit Duplikat-Erkennung, drei Strategien |
| Cabrillo V3 Export | Phase 4b: Contest-Log-Einreichungsformat mit allen Header-Tags |
| Auto-Backup | Vor Log-Löschung und ADIF-Import wird ein ADIF-Backup in `Backups/` geschrieben |
| Sortierbare/anpassbare Tabelle | Klick-Sort, Drag-Reorder, Hide/Show pro Spalte, 5 zusätzliche optionale Spalten |
| Tab-Bar mit Context-Filter-Zeile | Log · Map · Bands · DXClusters · Awards · Memories · History · QSL · Schedules |
| Awards-Live-Counter | DXCC/WAZ/WAS/Total über alle Logs, Worked + Confirmed (LoTW/eQSL), Detail-Tab |
| History-Map | Eigene QSOs als Linien Home→DX, Mode-Farben, Filter Band/Mode/Zeitraum |
| Memories | Schnellzugriffs-Karten für häufige Calls + Sked-Termine mit Countdown |
| Send-Spot-Button | DX-Spot direkt aus dem QSO-Form ans Cluster |
| Propagation-Panel | Rechte Seitenleiste mit Solar/Magnetic Gauges, SFI, Band-Activity (wiederverwendet aus DX-Cluster) |
| Vollbild-Layout | Logbuch übernimmt das ganze Fenster, eigene Sidebar/Toolbar |

**Pfade:** Datenordner zentral konfigurierbar in Einstellungen → Daten. Auto-Migration vom Legacy-Pfad beim ersten Start.  
**Persistenz:** SQLite per Log (`.htlog`), Spot/Callbook/Memories als JSON in `Cache/`, App-Settings in UserDefaults.

---

### Live-Tools

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
│   ├── AppDataRoot.swift       zentrale Datenordner-Verwaltung
│   ├── Components/             SectionCard, ResultRow, gemeinsame UI-Bausteine
│   └── Theme/                  AppTheme, ThemeManager (3 Themes)
└── Features/
    ├── Logbuch/                Logger-Modul (Phase 1 + 2 + 3 + 4b)
    │   ├── Models/             Log, QSO, HamBand, LogType, LogbookManager,
    │   │                       LogbookSettings, MemoryStore, RadioState, LogEntryBridge
    │   ├── Callbook/           CallbookService-Protokoll, QRZService, HamQTHService,
    │   │                       CallbookManager, CallbookSettings
    │   ├── Persistence/        SQLite, LogbookDatabase, ADIFCodec, CabrilloExporter
    │   └── Views/              LogbuchView, NewLogSheet, QSOFormSheet, LogsPopover,
    │                           Desktop/{LogbookTopBar, RadioControlPanel, QSOEntryPanel,
    │                                    LogActionBar, LogbookTabBar, QSOTableView,
    │                                    LogContextBar, ClusterContextBar,
    │                                    LogbookClusterTab, AwardsTab, HistoryTab,
    │                                    MemoriesTab, NewMemorySheet, ADIFImportSheet,
    │                                    CabrilloExportSheet, PreviousQSOsPopover}
    ├── DXCluster/              Live DX-Cluster Workstation
    │   ├── Models/             DXSpot, BandData, DXCCData, Persistenz, WatchList
    │   ├── Network/            ClusterClient (TCP), PropagationFetcher, APIFetcher
    │   ├── ViewModels/         DXClusterViewModel (@MainActor)
    │   └── Views/              SpotList, Bandmap, Weltkarte, Statistik, Log, Panel
    ├── Settings/               EinstellungenView (Station, Cluster, Daten, Callbook, …)
    ├── Hexbeam/
    ├── YagiRechner/
    ├── QTHLocator/
    └── …                       25 weitere Rechner-Features
```

### Datenordner

Alle App-Daten leben unter einem konfigurierbaren Root (Default `~/Documents/HAM-Tools/`):

```
HAM-Tools/
├── Logs/        — .htlog SQLite-Dateien pro Logbuch
├── Cache/       — spots.json, callbook-cache.json, memories.json
├── Exports/     — ADIF (.adi) + Cabrillo (.cbr) Exports
├── Backups/     — Auto-Backups vor riskanten Aktionen
└── Audio/       — Voice-Keyer/Recordings (Phase 11)
```

Pfad wechselbar in Einstellungen → Daten. UserDefaults bleiben im macOS-Standard-Pfad
(`~/Library/Preferences/com.hb9hji.hamrechner.plist`).

---

## Lizenz

MIT License — freie Nutzung, Weitergabe und Modifikation mit Nennung des Autors.

---

## Autor

**Christian Mueller — HB9HJI**  
Amateurfunker, Schweiz  
GitHub: [christianmuller1970-oss](https://github.com/christianmuller1970-oss)

> *73 de HB9HJI*
