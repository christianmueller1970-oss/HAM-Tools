# Changelog

Vollständiger Versionsverlauf von HAM-Tools.

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
