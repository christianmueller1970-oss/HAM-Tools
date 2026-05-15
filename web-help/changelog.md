# Changelog

Vollständiger Versionsverlauf von HAM-Tools.

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
