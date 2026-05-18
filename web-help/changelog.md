# Changelog

Vollständiger Versionsverlauf von HAM-Tools.

## 1.8.10 — 2026-05-18

**POTA-Upload-Fix · Mode-Picker ohne CAT nutzbar mit FT8/FT4**

### POTA-ADIF-Upload jetzt verlässlich

`pota.app` lehnte Uploads mit *»Only a single STATION_CALLSIGN value
is supported per log file«* ab, wenn das POTA-Log über den
WSJT-X-Spot-Stream gefüttert wurde und in WSJT-X mid-session zwischen
Home- und Portable-Call gewechselt worden war (z.B. `HB9HJI` ↔
`IT/HB9HJI/P`). Behoben an zwei Stellen:

- **Wurzelfix**: Bei POTA/SOTA/WWFF/BOTA-Logs übernimmt der
  WSJT-X-Importer jetzt **immer** den im Log-Wizard gewählten
  Aktivierungs-Call (Feld »Verwendetes Rufzeichen«) — egal was WSJT-X
  als `my_call` mitschickt.
- **Export-Schutz**: Beim ADIF-Export eines POTA-Logs werden
  `OPERATOR` + `STATION_CALLSIGN` über alle QSOs vereinheitlicht.
  Damit lassen sich auch ältere Logs mit gemischten Calls problemlos
  hochladen — einfach erneut exportieren.

### Mode-Picker ohne CAT-Verbindung nutzbar 🆕

Im Radio/CAT-Panel war das Mode-Menü grau und nicht klickbar, solange
kein Funkgerät verbunden war. Loggen ganz ohne CAT (oder bei
Remote-/Reise-Setup ohne TRX in Reichweite) war damit auf den
zuletzt aktiven Mode festgenagelt.

- Mode-Menü ist jetzt **immer klickbar**. Ohne CAT wird die Auswahl
  direkt in den Radio-State geschrieben (USB→SSB, LSB→SSB, CW→CW,
  PKTUSB→DATA etc.).
- Zusätzliche Digi-Modes erscheinen nur ohne CAT: **FT8, FT4, JT65,
  JT9, PSK31, JS8, Q65, MSK144**. Bei aktiver CAT-Verbindung bleibt
  die Liste auf Hamlib-Modes (USB/LSB/CW/PKTUSB/…), weil das Radio
  FT8 & Co. nicht direkt kennt — die laufen am TRX über PKTUSB.

## 1.8.9 — 2026-05-17

**ATNO-Markierung im DX-Cluster · Bandplan-Awareness in QSO-Forms · Club Log live · DX-Log ohne Dupe-Warnung**

### ATNO-Live-Markierung im DX-Cluster 🆕

Pro Spot im DX-Cluster zeigt jetzt eine farbige Pille direkt links
vom Rufzeichen, ob das Land/Band/Mode für dich noch interessant ist:

- **rot »ATNO«** — All Time New One, dieses DXCC-Country hast du
  noch nie gearbeitet
- **orange »NEW BAND«** — Country schon gearbeitet, aber nicht auf
  diesem Band
- **gelb »NEW MODE«** — Country+Band schon, aber nicht in dem Mode
- schon gearbeitet → keine Pille (Liste bleibt ruhig)

Wird live aktualisiert bei jedem geloggten QSO. Im Contest-Log gilt
die Dupe/Mult-Färbung weiter (rot dupe, grün mult), in Outdoor-
Programmen zeigt der jeweilige Spot-Tab seine eigene Ref-Match-Logik.

### Bandplan-Live-Awareness in allen QSO-Forms 🆕

Beim Loggen jedes QSOs zeigt eine Pille in der Status-Bar sofort an,
ob Frequenz + Mode IARU-R1-konform sind:

- **grün** — im Band, Mode passt zum Subsegment
- **orange** — im Band, aber falsches Subsegment (z.B. SSB im
  CW-Bereich)
- **rot** — außerhalb aller Amateurfunkbänder

Reagiert live auf CAT-Frequenzwechsel. Aktiv in allen sechs
QSO-Formen: DX, Contest, POTA, SOTA, WWFF, BOTA.

### Club Log scharfgeschaltet

Der App-API-Key (zugeteilt von Club Log auf Antrag der HAM-Tools-App)
ist jetzt enthalten — du brauchst nichts mehr selbst zu beantragen.
In *Einstellungen → Lookup & Upload → Club Log* einfach Email +
**Application-Password** eintragen (von clublog.org → Settings →
Application Passwords, **nicht** dein Login-Passwort) — Auto-Upload
läuft direkt.

Außerdem ein Form-Encoding-Fix: bestimmte Sonderzeichen (z.B. `@`)
im HTTP-Body wurden nicht korrekt kodiert, Club Logs nginx-WAF blockte
das mit »403 Forbidden«. Jetzt RFC-3986-strikt — der 403-Bug ist weg.

### Standard-DX-Log: keine Dupe-Warnung mehr

Im normalen DX-Log (Lebens-Log, Tages-Log, Stammrunde) ist es legitim,
denselben Call mehrfach zu loggen — die »Schon gearbeitet«-Warnung
war dort nur lästig. Programm-Logs (POTA/SOTA/WWFF/BOTA) und Contest
behalten ihre eigenen Dupe-Regeln in den jeweiligen Eingabemasken.

## 1.8.8 — 2026-05-17

**Outdoor-Programme: Upload jetzt plattform-konform · POTA-Self-Spot · WWBOTA-Live-Anbindung · viele Polishs**

### ADIF-Export jetzt direkt hochladbar

- **POTA-ADIF** entspricht jetzt 1:1 der pota.app-Vorgabe
  (`MY_SIG=POTA` + `MY_SIG_INFO`, kein nicht-dokumentiertes
  `MY_POTA_REF` mehr). Wird beim Upload nicht mehr von pota.app
  abgelehnt.
- **WWBOTA-ADIF** mit `MY_SIG=WWBOTA` und Komma-Liste in
  `MY_SIG_INFO` für Multi-Bunker — laut offiziellem
  WWBOTA-ADIF-Guide.
- Bei **Multi-Park-Hopping** (POTA) wird beim Export automatisch
  pro Park ein eigenes File geschrieben — pota.app erlaubt
  keine Komma-Listen und verlangt File-pro-Park.

### POTA Self-Spot 🆕

Aus dem POTA-Log heraus direkt auf den POTA-Cluster spotten:

- Im **Activator-Modus** mit gesetztem Park + Frequenz erscheint
  in der Status-Bar ein **„Spot senden"**-Button.
- Sheet zeigt Vorschau (Call/Park/Frequenz/Mode) + optionales
  Comment-Feld. Nach „Senden" ist der Spot sofort auf pota.app
  sichtbar — inklusive Re-Spot-Button für Hunter.

### SOTA-CSV für sotadata.org.uk 🆕

Neuer Toolbar-Button in SOTA-Logs: **„Für sotadata.org.uk
exportieren (CSV)"**. Schreibt das offizielle V2-CSV-Format
inkl. Summit-Gruppierung, S2S-Spalte und Band-Mapping (40m →
7.0MHz). Damit kannst du deine Aktivierungen direkt bei
sotadata hochladen.

### WWBOTA-Anbindung statt Stub

- Bunker-Datenbank lädt jetzt von **api.wwbota.org** (~26.7k
  Bunker weltweit). Beim ersten Start kommt ein Snapshot direkt
  aus der App, danach jederzeit aktualisierbar über
  *Einstellungen → BOTA-Reference-Datenbank → „Aktualisieren"*.
- Refs durchgängig im offiziellen `B/XX-NNNN`-Format. Spots aus
  dem DX-Cluster werden mit + ohne `B/`-Präfix erkannt.

### Logbuch-Polish

- **QRZ-Auto-Fill** in Outdoor-Logs (POTA/SOTA/WWFF/BOTA)
  übernimmt jetzt nicht nur den Namen, sondern auch QTH,
  Locator, Country, Continent, CQ-/ITU-Zone. Das ADIF-Export-
  Ergebnis ist damit deutlich vollständiger und DXCC-tracking-
  tauglich.
- Beim **Anlegen eines POTA/SOTA/WWFF/BOTA-Logs** zeigt das
  Hopping-Feld pro Eintrag den vollständigen Namen + Details
  des jeweiligen Parks/Summits/Bunkers (vorher nur Häkchen ohne
  Kontext).
- **Bandplan** ist jetzt ein eigenes Fenster (Menü *Fenster →
  Bandplan-Fenster*, ⌘⇧P) statt eines beengten Sub-Tabs.
- **Export-Bestätigung** zeigt bei Multi-File-Exports alle
  geschriebenen Dateinamen und einen „Im Finder zeigen"-Button.

## 1.8.7 — 2026-05-16

**Club-Log-Upload · SOTA-Punkte komplett · Update-System gehärtet**

### Club Log Upload (Phase 6 Schritt 3)

- **Einstellungen → Lookup & Upload → Club Log**: nur Email + Application-Password
  eintragen (nicht das Login-Passwort — kommt aus Club Log → *Settings →
  Application Passwords*). Den API-Key, den Club Log seit 2026 zusätzlich
  verlangt, bringt HAM-Tools intern mit — kein extra Onboarding nötig.
- **Auto-Upload-Toggle** schickt jedes neu geloggte DX-QSO im Hintergrund an
  Club Log. Greift nur in Standard-Logs — Outdoor-Programme (POTA/SOTA/WWFF/
  BOTA) bleiben außen vor.
- **Bulk-Upload** für historische QSOs: mehrere Zeilen markieren → Rechtsklick
  → „N QSOs an Club Log hochladen" (ein zusammengefasster ADIF-Batch).
- ⚠️ Club Log sperrt die IP nach mehreren fehlgeschlagenen Uploads. Bei
  Auth-Fehlern wird der Auto-Upload automatisch pausiert, damit du eine
  Chance hast, die Credentials zu fixen, bevor Club Log den Zugriff blockt.
- Erfolgreich hochgeladene QSOs werden mit „QSL via Club Log gesendet"
  markiert und tauchen im QSL-Tab sowie in der Tabellen-Übersicht auf.

### SOTA — Phase 4d komplett

- **Activator-Punkte-Card** im Awards-Tab → SOTA: zeigt die Summe aller
  gültigen Aktivierungen (≥ 4 QSOs auf demselben Summit / UTC-Tag), inklusive
  saisonalem **Winterbonus** (Nord 1. Dez – 15. März, Süd 1. Juni – 15. Sept).
- **Multi-Summit-Hopping** korrekt: jeder Summit in der Komma-Liste zählt
  eigene 4-QSO-Schwelle.
- Damit ist die SOTA-Funktionalität bis auf den Upload zu sotadata.org.uk
  (kommt in Phase 6) komplett.

### Update-System gehärtet

- **macOS-Mindestversion** wird vor dem Anbieten geprüft — numerisch korrekt
  (vorher hätte ein String-Vergleich z. B. „10.15" als kleiner als „10.9"
  eingestuft).
- Inkompatible Updates: der „Download öffnen"-Button im Update-Dialog wird
  **deaktiviert**, mit klarer Erklärung warum. Der Dialog erscheint trotzdem,
  damit du weißt dass es eine neue Version gibt.

## 1.8.6 — 2026-05-16

**QRZ-Logbook-Anbindung · QSL-Tab · Stats-Dashboard · Distance/Bearing · viele Polishs**

### QRZ Logbook (Phase 6 Schritt 1+2)

#### Live-Upload jedes QSO an QRZ.com
- Im *Einstellungen → Lookup & Upload → QRZ.com → Logbook* den 32-stelligen
  API-Key eintragen (kommt von qrz.com → »My Account → Settings → Logbook API«).
- Toggle **"Jedes geloggte QSO automatisch hochladen"** schickt jedes neu
  geloggte DX-QSO im Hintergrund an QRZ. Greift nur in Standard-Logs —
  Outdoor-Programme (POTA/SOTA/WWFF/BOTA) bleiben ausgenommen, weil die
  eigene Upload-Pfade haben.
- **Bulk-Upload** für historische QSOs: mehrere Zeilen markieren →
  Rechtsklick → "N QSOs an QRZ Logbook hochladen". Läuft parallel (6 Requests
  gleichzeitig), duplicate-tolerant (war-schon-drin = OK).
- Status pro QSO in der neuen Spalte **"QRZ-LB"** (default ausgeblendet,
  via Spalten-Menü einblenden): grüner Haken = neu hochgeladen, grauer
  Haken = war bereits in QRZ, rotes ⚠ = fehlgeschlagen (klick = retry),
  grauer Pfeil = noch nicht versucht (klick = jetzt hochladen).

#### Bestätigungen abrufen
- Im QSL-Tab oben: Button **"↓ QRZ-Bestätigungen abrufen"**.
- Holt paginiert das komplette QRZ-Logbook und merged fehlende
  LoTW-/eQSL-/Direkt-Bestätigungen *additiv* in die lokalen QSOs —
  manuell gesetzte lokale Bestätigungen bleiben unberührt.

### Neue Tabs im Logbuch

#### QSL-Tab (Briefumschlag-Icon)
Übersicht offener Konfirmationen, sortierbar nach Alter, mit:
- Filter Offen / Bestätigt / Alle
- Service-Filter (Alle / LoTW / eQSL / Club Log / Direkt-QSL)
- Status-Badges pro Channel (✓ grün bestätigt, → gelb wartend, — leer)
- Stift-Icon öffnet das QSO-Edit-Sheet zum manuellen Flag-Setzen

#### Stats-Dashboard (Balken-Icon)
Live-Auswertungen über das aktive Log:
- 4 Kennzahl-Karten: QSOs · Best DX (km) · DXCC · aktive Jahre
- 2×2 Charts: QSOs pro Jahr · Band · Mode · Kontinent
- 2 Listen: Top-10 DXCC-Länder · Top-5 längste DX-Strecken

### Distance & Bearing pro QSO (Phase-3-Rest)

- Automatische Berechnung beim Anlegen oder Bearbeiten — Großkreis-Distanz
  und Initial-Bearing aus eigenem QTH-Locator (aus Settings) und dem
  QSO-Locator.
- Neue Spalten *Distanz (km)* und *Peil (°)* in der QSO-Tabelle
  (default-hidden).
- ADIF-Export schreibt DISTANCE + ANT_AZ.
- **Bulk-Backfill für ältere QSOs:** Spalten-Menü → "Wartung → Distanz/
  Peilung für alle QSOs nachrechnen…".

### Workflow-Verbesserungen

- **Bulk-Vervollständigen via Rechtsklick:** mehrere QSOs markieren →
  "N QSOs aus QRZ/HamQTH vervollständigen". Lookups laufen parallel,
  greifen auf den 30-Tage-Cache zu, befüllen nur leere Felder
  (vorhandene Daten werden nie überschrieben).
- **QRZ-Profilbild-Cache:** Profilbilder aus QRZ-Lookup landen jetzt
  persistent im Disk-Cache (30 Tage). Beim zweiten Öffnen erscheint
  das Bild sofort statt mit Lade-Spinner.
- **ADIF-Import läuft async:** Bei großen Dateien (z. B. der vollständige
  QRZ-Logbook-Export, 7 MB / 7000 QSOs) blockiert die UI nicht mehr —
  Button zeigt "Importiere…"-Spinner, klarer Alert bei 0 erkannten QSOs.

### Web/Download

- Der FAQ-Hinweis "Updates rückgängig machen?" verwies auf
  `/app/dmg/`, das lieferte aber 403. Jetzt steht dort das
  Verzeichnis-Listing aller DMG-Versionen.
- Top-Nav-Download zeigt jetzt auf eine versionslose `latest.dmg` —
  bei jedem Release wird der Symlink automatisch mitgezogen.

---

## 1.8.5 — 2026-05-15

**Bandmaps in eigenen Fenstern · Grayline-Fenster · UI-Polish**

### Neues "Fenster"-Menü in der macOS-Menubar

Mehrmonitor-Freundliche Pop-up-Fenster — beide Fenster persistieren
Position + Größe und kommen nach App-Neustart automatisch zurück.

### Bandmaps als eigene Fenster
- Pro Klick auf **"Fenster → Neue Bandmap → {Band}"** öffnet sich ein
  schmales 320×800-Fenster mit spalten-basierter Bandmap im
  N1MM/Skookum-Stil
- Vertikale Frequenz-Skala links (CH-Format "14'060"), Spots als
  farbige Striche rechts mit Call-Text
- Mode-Codierung: SSB gold, CW orange, FT8 grün, FT4 blau, RTTY pink,
  FM lila, DIGI magenta
- **Single-Instance pro Band** — zweiter Klick auf dasselbe Band
  bringt das existierende Fenster nach vorn
- Wählbare Auflösung: 1/2/4/8/16 px/kHz — bei hohem Zoom scrollt das
  Fenster vertikal, jeder Spot bekommt seine eigene Zeile
- Zeit-Filter 5min/15min/30min/60min/2h/6h/Alle
- Mode-Filter (Default **SSB**): Alle/SSB/CW/FT8/FT4/RTTY/FM/AM/DIGI
- Klick auf einen Spot lädt ihn ins Logbuch (analog DX-Cluster-Klick:
  QSY + Mode an TRX, Auto-QRZ-Lookup, ohne Sub-Tab-Wechsel)

### Grayline-Fenster (⌘⇧G)
- Welt-Karte mit Tag/Nacht-Linie für DX-Propagations-Planning
- Echte **Terminator-Linie** als oranger Großkreis (alle Punkte mit
  Sonnen-Altitude = 0°)
- Dämmerungs-Zonen in vier Stufen (bürgerlich/nautisch/astronomisch/
  Nacht) als feines Grid-Sampling (5°×5°)
- **QTH-Marker** (cyan) auf deinem Locator aus den Settings
- **Sonnen-Marker** (☀️) am Subsolar-Punkt — dort steht die Sonne
  gerade im Zenit
- **DatePicker** + **"Jetzt"-Button** + **LIVE-Badge** im Live-Modus
- Im Live-Modus tickt die Linie automatisch jede Minute weiter
- Default-View beim ersten Öffnen: ganze Welt

### UI-Polish
- ⚙️-Zahnrad-Button aus der Logbuch-Top-Bar entfernt — Standard-
  macOS-Konvention: Einstellungen sind im App-Menü "HAM-Tools →
  Einstellungen…" (⌘,) sowie im Transceiver-Menü erreichbar

---

## 1.8.4 — 2026-05-15

**Transceiver-Quick-Switch · Spot-Klick steuert TRX · Auto-QRZ-Lookup · 13"-Polish**

### Neues Transceiver-Menü (macOS-Menubar)
- Schneller Wechsel zwischen gespeicherten CAT-Configs ohne Settings-Klick
- **Reset CAT** (⌘⇧R) — Reconnect rigctld zur aktiven Config
- **CAT ein/aus** (⌘⇧T) — globaler CAT-Toggle
- **TRX-Setup laden ▸** — Untermenü aller Configs mit Häkchen vor der aktiven
- **TRX-Setup speichern…** — Dialog für neuen Namen, dupliziert aktive Config
- **Einstellungen…** (⌘,) — öffnet das Settings-Fenster

### Spot-Klick steuert den TRX
- Klick auf einen DX/POTA/SOTA/BOTA/WWFF-Spot sendet jetzt **Frequenz + Mode**
  an den TRX (vorher nur Frequenz bei POTA/SOTA, gar nichts bei DX-Cluster)
- "SSB" wird automatisch zu LSB (<10 MHz) bzw. USB (≥10 MHz) — über alle
  Bänder von 160m bis 70cm
- CW direkt, FT8/FT4/PSK/JS8/Digital-Modes als PKTUSB bzw. PKTLSB
- Cluster-Tabellen zeigen entsprechend „LSB" oder „USB" statt generischem
  „SSB"

### Auto-QRZ-Lookup nach Spot-Klick
- Name, QTH, Locator, Country, CQ-/ITU-Zonen, DXCC-Entity werden direkt
  vom Callbook (QRZ/HamQTH) in die QSO-Form gezogen
- Respektiert dein bestehendes „Auto-Lookup bei TAB"-Setting in den
  Callbook-Einstellungen

### Kein Tab-Wechsel mehr beim Spot-Klick
- Du bleibst im **DXClusters-Sub-Tab** und beobachtest weiter Spots
- Der Draft fließt im Hintergrund ins QSO-Form; beim manuellen Wechsel
  in den Log-Tab sind alle Felder vorbefüllt

### DX-Spot-Senden mit Auto-Fill
- Der „DX-Spot senden"-Block in der rechten Sidebar übernimmt automatisch
  den aktuellen Their-Call aus der QSO-Form und die Radio-Frequenz
- Spotten geht in einem Schritt — kein doppeltes Tippen mehr

### 13"-MacBook-Air-Polish
- Window-Default 1280×760 → **1180×720pt**, Mindestgröße 900×580 → 860×560
- Rechte Sidebar 40pt schmaler (idealWidth 300 → 260)
- Propagation-Gauges kompakter (Canvas 110×72 → 95×56, Schrift 28pt → 22pt)
- Solar-Daten zweispaltig (3×2 statt 6×1)
- HeatCell-Höhe 16 → 14pt, kompaktere Section-Paddings
- → rechte Sidebar passt auf einem 13"-MBA ohne Scrollen

### Fixes
- **CAT-Verbindung trennte sich beim QSY** — Race-Condition zwischen
  Poll-Loop und Write-Operationen (setFrequencyMHz/setMode/setVFO/setSplit)
  auf demselben TCP-Socket. Neuer Client-Lock serialisiert alle Operationen
- **Einstellungen-Button im Transceiver-Menü reagierte nicht** — alter
  `NSApp.sendAction(showSettingsWindow:)`-Selector durch offizielle SwiftUI-
  API `@Environment(\.openSettings)` ersetzt

---

## 1.8.3 — 2026-05-15

**UI-Polish im DX-Log · Spalten-Toolbar · Spot-Tabellen mit Reorder**

### Neue Spalten-Verwaltung im DX-Log
- Neuer „Spalten"-Button in der QSO-Toolbar — alle verfügbaren Spalten
  per Toggle ein-/ausblendbar, plus „Standard-Spalten wiederherstellen"
- 10 zusätzliche Spalten (alle default-aus): QTH, ITU-Zone, Distanz (km),
  Peilung (°), Station-Call, QSL Via, My POTA, My SOTA, My WWFF, My BOTA
- Reihenfolge per Drag im Spaltenkopf verschiebbar
- Sichtbarkeit + Reihenfolge persistieren **pro Log-Typ**
  (Standard / POTA / Contest haben jeweils eigene Konfiguration)

### Spot-Tabellen mit Reorder + Hide/Show
- **DX-Cluster, POTA-, SOTA-, BOTA- und WWFF-Spots** wurden von der
  bisherigen Card-Darstellung auf eine spalten-basierte Tabelle
  umgestellt — mit Drag-Reorder, Hide/Show pro Spalte und Klick-
  Sortierung auf jedem Spaltenkopf
- Copy ins Log bleibt via Doppelklick oder Context-Menü erreichbar
- Sichtbarkeit + Reihenfolge persistieren pro Spots-Quelle

### Fixes
- DX-Standard-Log: Die POTA-Spalten „State" und „Their Park" werden
  jetzt nur noch in echten POTA-Logs angezeigt (vorher fälschlich
  auch im Standard-Log)
- DX-Standard-Log: BOTA-Map Sub-Tab erscheint nur noch in
  BOTA-Programm-Logs
- Contest-Wizard: „Neuer Contest"-Sheet ist größer und scrollbar —
  die Buttons „Abbrechen / Anlegen" im Kategorien-Schritt sind nicht
  mehr abgeschnitten
- Spalten-Menü: Toggle-Häkchen entsprechen jetzt der tatsächlich
  angezeigten Sichtbarkeit (vorher zeigte das Menü Pseudo-Haken
  für default-ausgeblendete Spalten)

---

## 1.8.2 — 2026-05-14

**Multi-Call-Lizenz · Pro-Log-Callsign · Multi-Op-Contest · Generator als App-Bundle**

### Multi-Call-Lizenz + Portabel-Validation
- Lizenz-Schema akzeptiert mehrere Calls (z.B. Privatcall + Club-Call)
- Substring-Match an `/`-Grenzen: `HB9HJI`, `DL/HB9HJI`, `HB9HJI/P`,
  `F/HB9HJI/MM` sind ✓ — `HB0HJI` bleibt ✗ (kein Buchstaben-Drift)

### Pro-Log-Callsign (Schema v7 → v8)
- Jedes Log hält einen eigenen Station-Call (Portabel-/Ausland-/Club-Call)
- MyCallField im Wizard mit Live-Lizenz-Validation (grünes Häkchen oder
  orange Warnung)
- Bei Multi-Call-Lizenz erscheint ein Quick-Picker über dem Feld
- Pro-Log-Callsign landet in jedem QSO als `stationCall` + `operatorCall`
- Leerlassen → Fallback auf Settings-Default

### Multi-Op-Contest (Schema v8 → v9)
- NewContestLogSheet bekommt ein Feld „Operatoren" (Komma-Liste)
- ContestEntryForm zeigt einen OP-Switcher rechts in der Header-Bar
- Awards-Tab im Contest-Modus mit neuem Sub-Tab „OPs" und
  Pro-Operator-Aufschlüsselung (QSOs + Anteil pro OP, sortiert)

### Lizenz-Generator als App-Bundle
- `tools/HAMToolsLicenseGen/build.sh` erzeugt signiertes `.app`-Bundle
- Drag&Drop nach `/Applications` — kein `swift run` mehr nötig
- Privater Key bleibt extern (Sicherheits-Pattern)

### Fixes
- Awards-Tab im Contest-Modus war komplett ausgeblendet — jetzt sichtbar,
  damit der neue OPs-Sub-Tab erreichbar ist
- Help-Site dokumentiert macOS-14-Voraussetzung prominent (nach
  Beta-Tester-Feedback mit macOS 12.7.6)

---

## 1.8.1 — 2026-05-14

**WWFF + BOTA komplett · Outdoor-Tab-Refactor · Testlauf-Fixes**

### Phase 4e — WWFF (Worldwide Flora & Fauna)
- Lokale Reference-Datenbank mit Doppelpfad: URL-Download von wwff-cc.org
  oder manueller CSV-Import via Datei-Picker (fail-safe wenn die Haupt-URL
  nicht erreichbar)
- NewWWFFLogSheet mit Activator/Hunter + Multi-Reference-Hopping
- WWFFEntryForm mit **44-QSO-Aktivierungs-Counter** (strikter als POTA/SOTA)
- WWFF-Spots-Tab als gefilterter DX-Cluster-Stream
- WWFF-Map-Tab mit R2R-Indikator
- Awards-Sub-Tab mit Activator/Hunter/R2R/Programme-Counter
- ADIF mit `MY_SIG=WWFF`, `MY_WWFF_REF`, `WWFF_REF`
- Schema-Migration v5 → v6

### Phase 4f — BOTA (Bunkers On The Air)
- CSV-Import-primärer Pfad (kein zentrales öffentliches API verfügbar)
- NewBOTALogSheet, BOTAEntryForm ohne QSO-Counter (1 QSO reicht)
- BOTA-Spots gefiltert aus DX-Cluster mit DB-Lookup (vermeidet
  Pattern-Konflikte mit POTA/WWFF)
- BOTA-Map mit Shield-Pins + B2B-Indikator
- Awards-Sub-Tab mit Activator/Hunter/B2B/Programme
- Proprietäre `APP_HAMTOOLS_MY_BOTA_REF` ADIF-Felder
- Schema-Migration v6 → v7
- `bota_demo.csv` im Repo mit 15 echten EU-Bunkern für Sofort-Test

### Outdoor-Sammel-Tab
- QSO-Panel: DX/Contest/**Outdoor** als drei Haupt-Tabs
- Outdoor-Sub-Bar mit POTA/SOTA/WWFF/BOTA-Sub-Tabs
- Skaliert sauber auf weitere zukünftige Award-Programme

### Testlauf-Fixes
- **QSO-Tabellen-Spalten** programm-abhängig: SOTA → Region + Their Summit,
  WWFF → Country + Their Reference, BOTA → Their Bunker
- **Bottom-Tab-Bar** zeigt im Programm-Modus nur die relevanten Tabs
- **DXClusters-Tab-Label** dynamisch: „POTA-Spots" / „SOTA-Spots" / …
- **WWFF-DNS-Fehler-UX**: CSV-Import-Button bei Server-Ausfall hervorgehoben
- **Awards-Tab** im Programm-Modus auf das jeweilige Programm fokussiert
- **Enter** speichert QSO direkt in allen Logging-Forms (statt Cmd+Enter)
- **Update-Check** zeigt Alert auch bei „up to date" und „Fehler"
- **Helvetia-Contest**: myCanton-Picker in den Station-Settings
- **ContestStatsPanel** Alignment .top (war zentriert)

## 1.8.0 — 2026-05-14

**SOTA-Modul komplett (Phase 4d)**

Strukturparallel zum POTA-Modul, sieben Sub-Phasen an einem Tag durchgezogen.

### Summit-Datenbank
- Lokale SQLite (`summits.sqlite`) mit ~181 000 Summits aus
  [sotadata.org.uk/summitslist.csv](https://www.sotadata.org.uk/summitslist.csv)
- Refresh-Hinweis nach 30 Tagen
- Bulk-Replace mit Index-Drop für schnelle Imports (~3-5 Sek auf Mac)

### Session-Wizard
- Activator / Chaser-Modus, Multi-Summit-Hopping als Komma-Liste
- Summit-Auto-Complete mit Höhe + Punkte pro Vorschlag
- Auto-generierter Session-Name (`SOTA HB/BE-001 2026-05-14`)

### SOTA-QSO-Form
- 4-QSO-Aktivierungs-Counter (rot/grün mit „Aktivierung gültig"-Badge)
- Winterbonus-Anzeige: Status-Bar zeigt `10+3p` während des Winter-
  Fensters (NH: 1. Dez – 15. März, SH: 1. Juni – 15. Sep)
- Their-Summit-Feld mit Auto-Complete und automatischem Punkte-Lookup
- Dupe-Markierung (Call+Band+Mode im aktiven Log)

### SOTA-Spots-Tab
- 60-Sek-Polling aus `api2.sota.org.uk/api/spots/50/all`
- Filter: Band, Mode, Assoc-Prefix, „Nur manuell" (RBNHole ausblenden)
- Sort nach Zeit oder Frequenz
- Copy-Button mit optionalem CAT-QSY

### SOTA-Map-Tab
- Summit-Pins (Mountain-Icon, SOTA-Orange) mit Elevation/Punkte-Tooltip
- DX-Pins mit Mode-Farbe, S2S-Indikator pro QSO
- Linien Summit → DX optional
- Band-Filter persistent

### Awards-Sub-Tab SOTA
- Activator-Summits, Chaser-Summits, S2S, Chaser-Punkte aggregiert
- Auto-Switch in den SOTA-Sub-Tab beim Log-Wechsel

### ADIF-Export
- `MY_SIG=SOTA`, `MY_SOTA_REF`, `SIG/SIG_INFO`, `SOTA_REF`
- `MY_GRIDSQUARE` aus App-Settings
- Proprietäres `APP_HAMTOOLS_THEIR_SOTA_POINTS` für Re-Import

### Schema-Migration
- Logbook-DB-Schema v4 → v5 mit zwei neuen Spalten (`log_meta.sotaSummitRefs`,
  `qsos.mySotaRefs`) für Multi-Summit-Hopping
- ALTER-TABLE-Migration läuft automatisch beim Öffnen alter `.htlog`-Dateien

## 1.7.1 — 2026-05-13

**Contest-Polish + Notarisierung**

- Cluster-Click füllt jetzt korrekt das Contest/POTA-Form (Race-Condition behoben)
- Mode-Picker im Contest auf Cabrillo-Mode-Kategorie eingegrenzt
- CAT-Config "Speichern unter…"-Button mit klarerem Workflow + Serial-Port wird mitkopiert
- ICOM CI-V-Adresse als eigenes Feld pro Modell (mit Default und Override)
- In-App **Bug melden…** (Cmd+Shift+B) — strukturierte Mails an `bugs@funkwelt.net`
- DMG ist **Apple-notarisiert** — kein Gatekeeper-Workaround mehr nötig

## 1.7.0 — 2026-05-13

**Großer Wurf: Contest + Lizenz + Update-System**

### Contest-Modus
- Vollständiger Wizard mit 14 Templates (HB-Helvetia, USKA-FD, USKA-50MHz, CQ-WW, CQ-WPX, IARU, DARC-WAG, ARRL-DX, WAE)
- Dynamische Exchange-Felder pro Template (Helvetia mit HB/DX-Switch)
- Live-Score, Rate-Meter, Score-Matrix
- Dupe-Markierung (Call+Band+Mode)
- DX-Cluster im Contest gefiltert + Color-Markierung (Dupe rot, Multiplier grün)
- Contest-Map (QTH-zentriert)
- Cabrillo V3-Export mit Header aus Wizard

### Lizenzsystem
- Ed25519 offline-signiert (kein Server)
- 50-QSO-Demo, danach Read-Only (kein Datenverlust)
- Lifetime + 12 Monate Updates-Modell
- Settings → Lizenz-Tab mit Status + mailto-Anfrage
- Separates Generator-Tool für Lizenz- + Manifest-Signing

### Update-System
- Auto-Check 1× / 24h beim Start
- Manueller Check via Cmd+Opt+U
- Signiertes Manifest auf `toolbox.funkwelt.net/app/updates.json`
- Lizenz-bewusst (zeigt "Update-Verlängerung nötig" wenn Build nach `updates_until`)
- Critical-Flag blockiert Skip

### Sonstiges
- Sidebar-Refactor: 3 Top-Punkte (Logbuch / DX-Cluster / Rechner-Akkordeon)
- Bandplan als Logbuch-Sub-Tab
- DX-Cluster verbindet global beim App-Start
- CAT-Profile erweitert auf 24 Modelle (Yaesu, Icom, Kenwood, Elecraft)

## 1.6.1 — 2026-05-12

POTA: Multi-Park-Hopping, Dupe-Markierung, POTA-Anlege-Route, POTA-Stats aus pota.app, Awards-Auto-Switch, QRZ-Retry.

## 1.5.x — 2026-05-11

Cabrillo V3-Export, Multi-Log-Architektur, CAT via Hamlib-Subprocess.

## Ältere Versionen

Siehe Git-History.
