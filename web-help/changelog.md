# Changelog

Vollständiger Versionsverlauf von HAM-Tools.

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
