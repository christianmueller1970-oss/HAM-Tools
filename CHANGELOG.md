# Changelog

Alle nennenswerten Änderungen am Projekt werden hier dokumentiert.  
Format angelehnt an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

---

## [1.6.1] — 2026-05-12

### Neu: POTA-Modul (Phase 4c)

Komplette POTA-Integration vom Park-Lookup bis zum pota.app-konformen ADIF-Export. Live mit IC-705 getestet, P2P-QSOs erfolgreich geloggt und Export gegen valide Referenz (HAMRS DA-0005) verifiziert.

#### Park-Datenbank
- **PotaParkService** lädt `all_parks_ext.csv` (~91'000 Parks, ~9 MB) von pota.app und schreibt es in `~/Documents/HAM-Tools/Cache/parks.sqlite`
- Byte-basierter CSV-Parser mit korrekter Behandlung von CRLF-Zeilenenden + escaped quotes (`""`) — 2'256 escaped-quote-Stellen im echten Datensatz erfolgreich verarbeitet
- Settings → Daten → "POTA-Park-Datenbank" mit Status-Anzeige, "Jetzt laden" / "Aktualisieren"-Button, 14-Tage-Refresh-Empfehlung
- Lookup-API: `park(reference:)` für Detail, `search(prefix:)` für Autocomplete

#### POTA-Session-Anlegen
- **NewPOTALogSheet**: Wizard mit Segmented-Picker "Bestehende öffnen / Neue anlegen"
  - "Öffnen": Liste aller bisherigen POTA-Logs mit Name, Park-Ref, QSO-Count, Datum → Klick öffnet
  - "Anlegen": Activator/Hunter-Toggle, bei Activator Park-Autocomplete-Picker mit Live-Suche, Session-Name-Auto-Gen
- POTA-Tab im QSO-Form klickt das Sheet auf, wenn kein POTA-Log aktiv ist

#### POTA-Entry-Form
- **POTAEntryForm**: schlanke Logging-Maske analog Referenz-Bild aus dem POTA-Logger
- Top-Status-Bar: Live-UTC, Frequenz/Band (aus CAT), Mode, Power, Session-Name, eigener Park
- Felder: Their Call, RST/S, RST/R, Their Park (comma-separated für P2P-Hopping), Power, Comments, Notes
- **QRZ-Lookup** mit 600 ms Debounce: bei Eingabe wird Name aus Callbook geladen und grün unter dem Call-Feld angezeigt (nicht zwingend ins Log gespeichert, aber als "Hi John!"-Hilfe)
- **10-QSO-Counter** im Activator-Modus: rot < 10, grün ≥ 10 mit "Aktivierung gültig"-Badge
- Save speichert automatisch myPotaRef, theirPotaRef, OPERATOR + STATION_CALLSIGN aus Settings, Name aus QRZ

#### POTA-Spots Live-Feed
- **PotaSpotsService** pollt `api.pota.app/spot/activator` alle 60 Sek (read-only, kein Upload), tolerant gegen Server-Format-Drift
- **PotaSpotsView**: Card-Grid statt Liste, analog Referenz-Bild
  - Pro Card: Activator @ Park-Ref, Zeit-ago, Frequenz + Mode, locationDesc, Park-Name, Spotter, Comments, Source ("RBN" / "Manual" / etc.)
  - Filter-Bar: Time/Freq-Sort, Band, Mode, Ref-Prefix-Suche
  - "QSY bei Copy"-Toggle: bei aktivem CAT springt der TRX auf die Spot-Frequenz beim Klick auf Copy
- **Copy-Button** füllt Their Call + Their Park automatisch ins POTA-Form via LogEntryBridge
- Bei POTA-Logs ersetzt PotaSpotsView den klassischen DXCluster-Tab unten — bei Non-POTA-Logs bleibt der DX-Cluster wie gehabt (komplett unabhängige Services, keine Interferenz)

#### QSO-Tabelle
- Spalten **Name**, **Country/Locator**, **QSL-Status** default versteckt (per Rechtsklick im Header wieder einblendbar)
- Neue **State**-Spalte: liest aus POTA-Park-DB via `park.locationDesc` → "CH-AG" → "AG"
- Neue **Their Park**-Spalte: theirPotaRef
- Neue **QRZ-Status**-Spalte am Ende: grüner Haken wenn Callbook-Name vorhanden, oranges Fragezeichen sonst — Klick darauf forciert Re-Lookup und speichert den gefundenen Namen

#### ADIF-Export (POTA-konform)
- **QSO_DATE_OFF + TIME_OFF** immer geschrieben (= ON falls keine separate End-Zeit)
- **MY_GRIDSQUARE** aus App-Settings (`qthLocator`) wenn `MY_POTA_REF` gesetzt
- **OPERATOR + STATION_CALLSIGN** aus QSO-Feld oder Fallback auf App-Settings.callsign — pota.app verweigert Upload ohne diese Felder
- LOTW/EQSL-QSL-Status-Felder nur noch geschrieben wenn `Y` (war vorher immer `N` in jeder Zeile, unnötig)
- **Pre-Header-Text raus**: `<ADIF_VER>` jetzt erster Tag (strikt-konform für LoTW / Club Log / eQSL). Log-Name als `APP_HAMTOOLS_LOGNAME` im Header erhalten.
- Verifikation: 4 QSOs aus POTA-CH-0001-Session gegen valide HAMRS-Referenz (DA-0005, eigener Activator-Log vom Februar 2024) Feld-für-Feld geprüft

#### Frontend
- **POTA-Tab** neben DX/Contest im QSO-Entry-Panel
- POTA-Modus rendert POTAEntryForm statt DX-Grid und PotaSpotsView statt DXCluster
- LogEntryBridge ergänzt um `pendingPotaSpot` für POTA-spezifische Form-Prefills

#### Dokumentation
- **POTA_PLAN.md** dokumentiert Architektur, Phasen 4c-1 bis 4c-6, UI-Referenzen, Bundling-Strategie

#### Offen für 1.6.x-Polish (Folge-Patches)
- 4c-6 QSO-Map mit Park-Markern
- Multi-Park-Hopping vollständig durchziehen (`MY_POTA_REF` mit Komma-Liste, ADIF-Splitting)
- POTA-Upload-API direkt aus der App (Phase 6, zusammen mit LoTW/eQSL)
- POTA-Aktivierungs-Statistiken im Awards-Tab

---

## [1.6.0] — 2026-05-12

### Neu: CAT-Anbindung (Phase 5a)

Erstes funktionsfähiges Live-CAT-Modul für IC-7300 / IC-705 / IC-9700 (und 9 weitere Profile vorbereitet) via Hamlib-Subprocess. Frequenz und Mode kommen live vom Funkgerät in die App und werden in `RadioState` gespiegelt.

#### Hamlib-Build-Pipeline
- **`scripts/build-hamlib.sh`** — reproducible Build von Hamlib 4.7.1 als Universal2 (arm64 + x86_64), statisch, `--without-libusb`, Ad-Hoc codesigned mit Hardened Runtime
- Resultat: `vendor/hamlib/rigctld` 22 MB, **truly self-contained** (nur `libSystem` + `libedit` als macOS-Dylibs), keine Third-Party-Dependencies
- `build-dmg.sh` baut Hamlib automatisch falls fehlend und packt `rigctld` in `Contents/Helpers/` des App-Bundles
- Smoke-Test gegen Dummy-Rig grün

#### CAT-Architektur (Sources/HAMRechner/Features/CAT/)
- **`TRXProfile`** + `trx-profiles.json`: Brand/Model/Hamlib-Rig-Number + Werkseinstellungen (Baud, DataBits, StopBits, Parity, Handshake) für 13 Rigs:
  - **Hamlib** Dummy (Test ohne Hardware)
  - **Icom** IC-7300 / IC-705 / IC-9700
  - **Yaesu** FT-991 / FT-857 / FT-817
  - **Kenwood** TS-2000 / TS-590S / TS-480
  - **Elecraft** K3 / KX2 / KX3
- **`CATConfig`**: benannte User-Konfiguration mit allen Verbindungs-Parametern. Mehrere Configs speicherbar (z.B. "Home-IC7300", "Portable-IC705"), beliebig umschaltbar
- **`CATSettings`**: Multi-Config-Store, UserDefaults-persistiert, analog zu ClusterSettingsStore
- **`RigctldProcess`**: Lifecycle des `rigctld`-Subprocess. Bundle-Lookup mit Dev-Fallback auf `vendor/hamlib/rigctld`, ENV-Override, defensiv chmod+x (Google-Drive frisst Exec-Bits). Serial-Parameter via `-C "data_bits=..,stop_bits=..,serial_parity=..,serial_handshake=.."` an rigctld
- **`RigctldClient`**: TCP-Client zu localhost:4532 via URLSessionStreamTask, line-based Protocol für `f`/`m`-Commands. Phase 5b wird `F`/`M` ergänzen
- **`CATController`**: Orchestrator. Connect-Retry-Loop (30 × 150 ms = 4.5 s) für rigctld-Bind-Race, stopInternal-vor-start gegen Orphan-rigctld-Prozesse. Status `disconnected/starting/connected/errored`, Poll-Loop (default 500 ms) spiegelt Frequenz und Mode in `RadioState`. Mode-Mapping Hamlib → UI (USB/LSB → SSB, PKTUSB → DATA, …)

#### Settings-UI (Einstellungen → CAT)
- **Multi-Config-Manager** oben: Aktive Konfig-Picker + "Neu…" + "Löschen", Name-Edit
- **Zwei-Stufen-Radio-Picker**: Hersteller → Modell. Auto-Fill der Werkseinstellungen bei Modell-Wechsel, alle Felder weiterhin editierbar
- **Vollständiger Serial-Editor**: Port (USB-Serial-Discovery via `/dev/cu.*` + Refresh-Button), Baudrate, Datenbits 7/8, Stopbits 1/2, Parität None/Odd/Even, Flusskontrolle None/Hardware/XONXOFF
- **"Werkseinstellungen zurücksetzen"**-Button für Quick-Recovery aus verfiddelten Configs
- **Polling-Intervall** als Slider 200-2000 ms
- **Diagnose-Section** zeigt zuletzt empfangene Frequenz/Mode, bei Fehler auch rigctld-stderr (kopierbar)
- Settings-Fenster resize-fähig (ideal 640 × 860, min 580 × 480), damit alle Sections ohne Scrollen Platz haben

#### Frontend-Integration
- **Klickbarer `CATStatusBadge`** in der Sidebar unten — One-Click-Toggle für schnelles Reconnect nach Fehlern, ohne Settings öffnen zu müssen
- **`RadioControlPanel`** Updates:
  - TRX-Selector zeigt aktive Konfiguration + Radio-Modell bei aktivem CAT (grünes Antennen-Icon), "Kein Radio aktiv" bei Off
  - Frequenz-Anzeige im **Ham-Style MHz.kHz.10Hz** (z.B. `7.164.39 MHz`), Parser akzeptiert sowohl Klassik `7.16439` als auch Ham-Style
  - CAT-Updates spiegeln immer in Display, auch wenn TextField fokussiert ist (CAT ist Wahrheit); Focus wird beim Aktivwerden automatisch freigegeben
- `RadioState`-Instanz wird in `HAMRechnerApp` zentral erzeugt und mit `CATController` geteilt (single source of truth)

#### Dokumentation
- **`CAT_PLAN.md`** dokumentiert Architektur-Entscheidungen, Phasen-Plan (5a/5b/5c/5d), UI-Referenzen, Bundling-Strategie, Test-Strategie, Risiken
- **`hamlog-update-system-spec.md.gdoc`** als Google-Doc-Referenz im Repo

#### Bekannte Einschränkungen / nächste Schritte
- Phase 5b: Write-Pfad (Set-Frequenz/Mode aus App ans Radio, "Set Radio to Spot" aus DX-Cluster)
- Phase 5c: Reconnect-Watchdog, automatische USB-Yank-Erkennung
- Phase 5d: PTT-Control (für künftige Digi-Mode-Integration)
- Ad-Hoc-Codesigning für Dev; für öffentliche Verteilung kommt Developer-ID + Notarization
- `swift build` aus dem Drive-synced Projektordner kann hängen — Workaround: `--build-path /tmp/hamtools-build` (Empfehlung für `run.sh`/`build-dmg.sh` in Folge-Commit)

---

## [1.5.0] — 2026-05-11

### Neu: Logbuch-Modul (Phase 1 + 2 + 3 + 4b)

Komplettes Logger-Modul im Desktop-Logger-Stil, von Multi-Log-Architektur über Online-Lookups bis Cabrillo-Export. Über 30 Commits an einem Tag.

#### Datenarchitektur
- **Multi-Log statt Mega-Log**: pro Logbuch eine eigene SQLite-Datei (`.htlog`), Typ-Auswahl beim Anlegen (Standard / Contest / POTA / SOTA, letztere drei vorbereitet für spätere Phasen)
- **AppDataRoot** als zentraler konfigurierbarer Datenordner. Default `~/Documents/HAM-Tools/`. Unter-Struktur: `Logs/ · Cache/ · Exports/ · Backups/ · Audio/`. Auto-Migration vom Legacy-Pfad.
- **SQLite direkt via C-API** — Command-Line-Toolchain hat keine SwiftDataMacros, also schlanker eigener Wrapper. Schema: `log_meta` + `qsos` + `schema_info` mit Indizes auf datetime/call/band.
- **Persistenz aller UI-States** via `@AppStorage`: Tab, Filter, Awards-Sub-Tab, Heatmap-Minutes, Spots-Mode/Radius, Cluster-Source-Toggles, etc.

#### Desktop-Layout
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
