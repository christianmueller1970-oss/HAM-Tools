# Changelog

Alle nennenswerten Änderungen am Projekt werden hier dokumentiert.  
Format angelehnt an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

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
