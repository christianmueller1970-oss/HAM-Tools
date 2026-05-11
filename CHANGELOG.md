# Changelog

Alle nennenswerten Änderungen am Projekt werden hier dokumentiert.  
Format angelehnt an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

---

## [1.5.0] — 2026-05-11

### Neu: Logbuch-Modul (Phase 1 + 2 + 3 + 4b)

Komplettes Logger-Modul im MacLoggerDX-Stil, von Multi-Log-Architektur über Online-Lookups bis Cabrillo-Export. Über 30 Commits an einem Tag.

#### Datenarchitektur
- **Multi-Log statt Mega-Log**: pro Logbuch eine eigene SQLite-Datei (`.htlog`), Typ-Auswahl beim Anlegen (Standard / Contest / POTA / SOTA, letztere drei vorbereitet für spätere Phasen)
- **AppDataRoot** als zentraler konfigurierbarer Datenordner. Default `~/Documents/HAM-Tools/`. Unter-Struktur: `Logs/ · Cache/ · Exports/ · Backups/ · Audio/`. Auto-Migration vom Legacy-Pfad.
- **SQLite direkt via C-API** — Command-Line-Toolchain hat keine SwiftDataMacros, also schlanker eigener Wrapper. Schema: `log_meta` + `qsos` + `schema_info` mit Indizes auf datetime/call/band.
- **Persistenz aller UI-States** via `@AppStorage`: Tab, Filter, Awards-Sub-Tab, Heatmap-Minutes, Spots-Mode/Radius, Cluster-Source-Toggles, etc.

#### Desktop-Layout (MacLoggerDX-inspiriert)
- **Vollbild-Logbuch**: wenn aktiv, übernimmt das Modul das ganze Fenster mit eigener Sidebar/Toolbar
- **Top-Bar**: Zurück-Button · Aktives-Log-Selector · Live-UTC-Uhr · Callsign · Settings-Zahnrad
- **Entry-Sektion** (HSplitView): RadioControlPanel (195 px) · QSOEntryPanel · Propagation-Panel (240-360 px)
- **QSOEntryPanel**: vier Spalten — Adresse · Funk-Daten · Award-Refs · QRZ-Profil-Bild (250 × 200)
- **LogActionBar**: LookUp · Previous · Time On · Time Off · **Log QSO** (⌘↩) · Send Spot · Beam · Reset · Stacking — Phase-tagged disabled
- **Tab-Bar mit Context-Filter-Zeile** unter den Tabs — pro Tab eigene Filter/Aktionen, konsistente Höhe
- **QSO-Tabelle**: sortierbar per Klick, drag-reorder, hide/show 15 Spalten via Header-Rechtsklick, Customization persistiert
- **Color-Coding**: rot=unbestätigt, gelb=upload pending, grün=LoTW/eQSL confirmed

#### Datenfluss & Bridges
- **LogEntryBridge** (Singleton, analog AntennaSimBridge): DX-Cluster-Spot oder Memory → QSO-Form vorausgefüllt
- **POTA/SOTA/WWFF-Ref-Extraktion** aus Spot-Kommentaren via Regex
- **RadioState** als zentrale Frequenz-Quelle (manuell jetzt, ab Phase 5 via CAT/Hamlib)
- **Time-On läuft sekündlich mit** — Timer-publish, beim Loggen wird aktuelle Zeit übernommen

#### Online-Schnittstellen (Phase 3)
- **QRZService**: XML-API mit Session-Login + Re-Login bei Timeout, parsed alle Standard-Felder + `<ccode>` + `<image>` + `<url>`
- **HamQTHService**: XML-API kostenlos, parsed nick/adr_name + adr_city + adif + picture etc.
- **CallbookService**-Protokoll als Plug-In-Architektur — weitere Services trivial dazuzustellen
- **CallbookManager**: Primary/Fallback-Logik mit persistentem Cache (30 Tage TTL)
- **Auto-Fill** beim TAB im Call-Feld via `@FocusState` — leere Felder werden gefüllt, keine Überschreibung
- **Bulk-Lookup**: Tabellen-Selection markieren → »QRZ für N Auswahl« mit Live-Progress

#### Cross-Log-Suche
- **Previous-Button**: Popover mit allen früheren QSOs des aktuellen Calls über ALLE Logs (in-memory für aktives, lazy SQLite für andere)
- **Duplicate-Warnung beim Loggen**: Exact-Match (Call+Band+Mode in aktivem Log) + Recent-Match (selber Call irgendwo in letzten 30 min) → Alert mit Details

#### Import / Export (Phase 2)
- **ADIF 3.x Codec**: Encoder + Parser (UTF-8-Byte-genau), Field-Mapping aller QSO-Felder inkl. POTA/SOTA via SIG/MY_SIG, LoTW/eQSL-Flags, Solar
- **ADIF-Import-Sheet** mit drei Strategien: nur-neue / alle / neues-Log. Duplikat-Erkennung Call+Band+Mode+±5min
- **Auto-Backup** vor riskanten Operationen (Log-Löschen + ADIF-Import): ADIF nach `Backups/{Logname}-{Stamp}-{tag}.adi`
- **Cabrillo V3 Export** (Phase 4b): Sheet mit allen Header-Tags (Contest-ID, Category-Operator/Band/Mode/Power/Station/Time, Claimed-Score, Sent-Exchange, Soapbox), Mode-Mapping CW/PH/RY/DG, Datei nach `Exports/`

#### Tabs (Bottom-Sektion)
- **Log**: QSO-Tabelle mit Filter-Bar (Call/Band/Mode/Country) + Status-Zeile mit Dateinamen
- **Map**: Weltkarte mit DX-Cluster-Spots (zentriert auf eigenen QTH, Mode-Farben, Radius/Mode-Filter)
- **Bands**: Frequenz/Zeit-Diagramm pro Band (wiederverwendet aus DX-Cluster)
- **DXClusters**: Spot-Liste inline mit Status-Bar, Doppelklick öffnet Spot im Log-Form
- **Awards**: DXCC-Tabelle / WAZ-Grid (40 Zonen) / WAS-Tabelle mit Worked/Confirmed-Status
- **Memories**: Schnellzugriffs-Karten mit Pin · Call · Band/Mode · Frequenz · Sked-Termin (Live-Countdown) · Notes
- **History**: Karte eigener QSOs als Linien Home→DX, Mode-Farben, Filter Band/Mode/Zeitraum

#### Persistenz
- **Letztes aktives Log**: UUID in UserDefaults, beim Neustart wieder geöffnet
- **Spalten-Anpassung** der QSO-Tabelle (TableColumnCustomization als Codable JSON)
- **Callbook-Cache** als JSON in `Cache/callbook-cache.json`
- **Memories** als JSON in `Cache/memories.json`
- **Cluster-Filter** (Source-Toggles, Band/Mode/Continent/Search/Radius) in UserDefaults

### Sonstiges in 1.5
- Map-Initial-Camera auf QTH (statt fest 47°/8°), engerer Span (80×160°)
- Cluster-Default-Toggles: nur DX an, SOTA/POTA/WWFF aus
- HB9HJI/JN47PN-Vorbelegungen neutralisiert — Placeholder zeigen jetzt »Call«, »Locator«, »Rufzeichen« etc.
- Settings-Button in der Logbook-Top-Bar
- SpotListView Spotter+Quelle in einer Zeile statt übereinander → flacher

### Code-Statistik (Schätzung)
- ~4500 Zeilen neuer Swift-Code im Logbuch-Modul
- 35 neue Source-Dateien
- Über 30 Commits in einer Session
- Build clean unter Swift 5.9 / macOS 14+

---

## [1.3.0] — 2026-05-09

### Neu: QTH-Locator Erweiterungen

Umfassender Ausbau des QTH-Locator-Werkzeugs zu einer vollständigen Standort- und Ausbreitungsanalyse-Station.

#### Interaktive Karte & Locator
- MapKit-Karte direkt in den „Karte & Locator"-Tab integriert (NSViewRepresentable-Workaround für macOS-Gestenkonflikte)
- Klickbarer Pins für Quelle und Ziel direkt auf der Karte setzbar (Fadenkreuz-Cursor)
- Koordinaten-Panel oben im Tab: Locator, Lat/Lon, Distanz, Richtung für Quelle und Ziel
- 8-stelliger Maidenhead Extended Square (~500 m Auflösung, Raster 2/240° × 1/240°)
- Prominente Quelle→Ziel-Linie auf der Karte (weisser 6 px Halo + orangefarbener 3 px Kern)

#### SOTA / POTA Suche auf Karte
- SOTA-Gipfel und POTA-Parks in einstellbarem Radius um Quelle anzeigen
- Vergrösserte, gut lesbare Marker mit dunklem Hintergrund-Label auf der Karte
- VSplitView: Karte oben, Ergebnisliste unten (kollabierbar)
- Konverter-Funktionalität (Koordinaten ↔ Locator) direkt in Karte & Locator integriert (eigener Tab entfernt)

#### Höhenprofil & Sichtlinie
- Sichtverbindungs-Linie (LOS) von Quelle zu Ziel mit Erdkrümmungs-Korrektur (k = 4/3, Standardatmosphäre)
- Erdkrümmungsformel: `bulge(d) = d × (D−d) / (2 × Re × k)` über dem linearen Interpolationspfad
- Fresnel-Zonen-Visualisierung für 70 cm, 2 m, 4 m, 6 m (einzeln ein-/ausblendbar)
- Fresnel-Radius-Formel: `r = sqrt(λ × d1 × d2 / D)`
- Darstellung als LineMark-Paare (obere + untere Grenze) je Band — kein AreaMark-Artefakt
- Statistik-Kacheln (2×2 LazyVGrid): Min. Höhe, Max. Höhe, Differenz, Distanz

---

## [1.1.0] — 2026-05-09

### Neu: DX-Cluster Live-Workstation

Vollständige DX-Cluster-Integration als neue Live-Tools-Kategorie in der Seitenleiste.

#### Verbindung & Daten
- TCP-Client für DXSpider-Protokoll (Port 7300) mit Auto-Reconnect (NWConnection)
- Multi-Cluster-Verwaltung: beliebig viele Knoten konfigurierbar, Einzel-Aktivierung
- Login-Sequenz: connect → warte auf "login:" → sende Rufzeichen → `sh/dx 50`
- REST-API-Fetcher: SOTAwatch3, POTA, WWFF mit konfigurierbarem Poll-Intervall
- Propagation-Fetcher: NOAA SFI, Kp-Index, A-Index alle 15 Minuten
- Spot-Parser: `DX de SPOTTER: FREQ DXCALL COMMENT HHMM` inkl. DXCC-Lookup

#### Spot-Liste (Tab 0)
- SwiftUI Table mit 10 Spalten: Zeit, Freq, Band, Mode, DX-Rufzeichen, Land, Kontinent, Kommentar, Spotter
- Band-Farbkodierung (14 Bänder), sortierbar nach allen Spalten
- ★-Spalte und goldene Textfarbe für Spots auf der Watch List

#### Bandmap (Tab 1)
- Canvas-basiertes Frequenzdiagramm pro Band
- Farbkodierung nach Mode (FT8 grün, CW orange, SSB gelb, …)
- Zeitfenster-Filter (15 / 30 / 60 / 120 min)

#### Weltkarte (Tab 2)
- MapKit-Karte (macOS 14 SwiftUI API) mit Spot-Markern als farbige Punkte
- Spotter-Linien (MapPolyline) ein-/ausblendbar
- Auswahl-Ring mit Spot-Detailleiste
- Zeitfenster-Filter (15 / 30 / 60 min / Alle)

#### Statistik (Tab 3)
- 2×2-Grid mit SwiftUI Charts
- Spots/Band (horizontale Balken mit Band-Farben)
- Spots/Mode (Balken)
- Top-15 DX-Calls (grüne Balken)
- 24h-Verlauf (Area-Chart + Linie)

#### Filter & Suche
- Band, Mode, Kontinent (Picker-Menüs)
- Quelle: DX / SOTA / POTA / WWFF (Checkboxen)
- Freitext-Suche über DX-Call, Kommentar, Spotter
- Spotter-Radius-Filter (0 / 500 / 1000 / 2500 / 5000 km vom eigenen QTH, Haversine)
- Reset-Button für alle Filter
- Leeren-Button: löscht Spot-Liste und Persistenz

#### DX-Spot senden
- Sheet-Dialog mit Frequenz, DX-Rufzeichen, Kommentar
- Sendet `DX freq call comment` via TCP an aktiven Cluster
- Button deaktiviert wenn nicht verbunden

#### Watch List / Alerts
- WatchListStore: Prefix- oder Exakt-Match (Gross-/Kleinschreibung ignoriert)
- Einstellungen → Alerts-Tab: Watch-Liste verwalten, Benachrichtigungs-Toggle
- macOS-Benachrichtigungen (UNUserNotificationCenter) bei neuem Watch-Spot
- Deduplizierung innerhalb einer Session (gleicher Call + Frequenz)
- Alarm-Badge (🔔 N) in der Verbindungsleiste, tippbar zum Zurücksetzen

#### Persistenz & Settings
- Spot-Persistenz: JSON in `~/Library/Application Support/HAMRechner/spots.json`
  - Max. 500 Spots, 24h-Retention, atomarer Schreibvorgang
  - Geladen beim Start, gespeichert alle 25 neuen Spots
- Einstellungen (Cmd+,):
  - **Station**: Rufzeichen + QTH-Locator (AppStorage)
  - **Cluster**: Tabelle mit +/−/Bearbeiten, Aktiv-Auswahl, autoConnect-Markierung
  - **Darstellung**: 3 Themes mit Mini-Swatch-Vorschau
  - **Alerts**: Watch-Liste + Benachrichtigungs-Toggle

#### 3-Theme-System
- **HAM Style** (Standard): helles Design, weiße Tabelle, schwarzes Terminal
- **Dark**: dunkles blau-graues Design
- **Ham Classic**: bernsteinfarbenes Terminal-Design
- ThemeManager mit AppStorage-Persistenz, wechselbar im laufenden Betrieb

#### Propagation-Panel (Rechte Spalte)
- SFI-Gauge (Halbkreis, 0–300)
- Kp-Gauge (Halbkreis, 0–9)
- Band-Activity-Heatmap: Bänder × Kontinente, zeitgefiltert (15/30/60 min)

---

## [1.0.0] — 2026-05-09

### Erstveröffentlichung

Vollständige SwiftUI macOS-App mit 25 Amateurfunk-Rechnern in 6 Kategorien.

#### Drahtantennen
- Dipol-Rechner (Halbwellen, alle Bänder)
- Groundplane / Vertikal (λ/4 mit Radials)
- J-Pole / Slim Jim
- Sperrtopf (koaxiale Mantelwellensperre)
- Windom / OCFD
- EFHW-Verkürzungsspule
- Loop-Antenne

#### Richtstrahler
- Moxon Rectangle
- HB9CV Beam
- **Hexbeam** (G3TXQ, mehrbandig 10/15/20/40m)
  - Parametrische Draufsicht: Treiber (V), Reflektor (gestrichelt), Schnüre (grau), Tip Spacer
  - Seitenansicht: Halbkreis-Schüssel, horizontale Drähte, Träger, Höhenmass
- Yagi-Rechner (2–6 Elemente nach Rothammel)
- Spiderbeam Einzelband
- Spiderbeam Multi-Band

#### Spezialantennen
- Magnetic Loop (Kapazität, Güte, Bandbreite)
- Antennen-Designer

#### Spulen & Transformatoren
- Balun / Unun (Wicklungsrechner, verschiedene Übersetzungen)
- Strahler-Verlängerung
- Spulen-Wickler (Luftspule, Induktivität)

#### Anpassung & Leitungen
- Anpassnetzwerk (L-Netz)
- Koax-Stub (λ/4, λ/2, offen/kurzgeschlossen, Schema-Canvas)
- Kabeldämpfung

#### Signale & Tools
- Pegel-Umrechner (dBm / dBW / V / µV / W)
- SWR-Simulator
- Linkbudget / Reichweite (Friis-Formel)
- QTH-Locator (Maidenhead ↔ Koordinaten, Distanz, Bearing)

#### UI
- NavigationSplitView mit kategorisierter Seitenleiste (Mindestbreite 220 px)
- Konsistentes `SectionCard` + `ResultRow` Design-System
- Dark Mode nativ unterstützt
