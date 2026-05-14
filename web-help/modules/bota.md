# BOTA — Bunkers On The Air

::: tip Neu in 1.8.1 (Mai 2026)
BOTA-Modul komplett. Aktivierung von historischen Bunkern, Festungen und
militärischen Anlagen. Strukturparallel zu POTA/SOTA/WWFF — Activator/Hunter,
Bunker-DB via CSV-Import, Live-Spots aus dem DX-Cluster, Karte, Awards.
:::

## Kurz-Überblick

- **Activator / Hunter**-Modi mit Multi-Bunker-Hopping
- **Bunker-Auto-Complete** aus lokaler SQLite-Datenbank
- **Kein QSO-Counter** — bei BOTA-Programmen reicht meist 1 QSO pro Aktivierung
- **B2B-Erkennung** (Bunker-to-Bunker)
- **BOTA-Spots-Feed**: gefiltert aus dem DX-Cluster, gegen lokale Bunker-DB
  gematcht (Pattern allein wäre zu generisch und würde POTA/WWFF-Refs mitfangen)
- **BOTA-Map** mit Shield-Pins + DX-Pins + Linien
- **BOTA-Awards** mit Activator/Hunter-Counter, B2B + Programme

## Datenquelle: warum manueller CSV-Import?

Im Gegensatz zu POTA/SOTA gibt es **kein zentrales öffentliches API** für BOTA:

- `bunkersontheair.com` ist nur eine Platzhalter-Site
- GMA (`cqgma.org`) hat kein BOTA-Endpoint
- Verschiedene nationale Programme (deutsches BOTA, polnisches BPL,
  russisches RBA, tschechisches BUR …) sind nicht zentralisiert

**Lösung:** Manueller CSV-Import ist der primäre Pfad. Die App liefert
eine `bota_demo.csv` im Repo-Root mit ~15 echten europäischen Bunker-Refs
als Start-Datenset.

### CSV-Format

```csv
reference,name,country,type,status,latitude,longitude
DE-0001,Bunker Höxter,Germany,WWII,active,51.7770,9.3815
HB-0001,Festung Furigen,Switzerland,Kalter Krieg,active,46.9530,8.4250
F-0011,Maginot-Linie Schoenenbourg,France,WWII,active,48.9667,7.9333
```

Spalten-Erkennung ist tolerant gegen Synonyme:
- `reference` / `bota_ref` / `ref` / `bunker_ref`
- `name` / `bunker_name`
- `country` / `land`
- `type` / `bunker_type` / `category`
- `status` / `state`
- `lat` / `latitude`, `lon` / `long` / `longitude`

## Anlegen einer BOTA-Session

1. **Einstellungen → Daten → BOTA-Reference-Datenbank → „CSV importieren …"**
   (einmalig, mit `bota_demo.csv` oder eigener Country-Liste)
2. Top-Bar → **Neues Log** → **BOTA-Session** → Wizard
3. **Activator / Hunter** wählen
4. **Eigener Bunker** (Activator) mit Auto-Complete inkl. Country + Type
5. Optional: **Hopping-Bunker** als Komma-Liste

## QSO loggen

- **Status-Bar** mit Bunker-Ref + Country
- **Their Bunker**-Feld mit DB-Lookup für B2B
- **Enter** speichert direkt
- Dupe-Markierung wie bei den anderen Programmen

## BOTA-Spots-Tab

Der „BOTA-Spots"-Tab filtert den DX-Cluster-Stream:

- Pattern-Erkennung `[A-Z]{1,4}-\d{3,5}` im Spot-Comment
- **Zusätzlich** wird jeder Match gegen die lokale Bunker-DB geprüft —
  nur tatsächlich eingetragene Refs zählen. Damit fallen POTA-Refs
  (`K-1234`) oder WWFF-Refs (`DLFF-0001`) nicht ins BOTA-Filter
- Filter wie bei POTA/SOTA: Band, Mode, Programm-Prefix
- Copy-Button + CAT-QSY analog

## BOTA-Map

- Bunker-Pins (Shield-Icon, dezent grau-blau)
- DX-Pins mit Mode-Farbe
- B2B-Indikator im Sidebar-Row und Info-Popup

## Awards-Tab

Sub-Tab **BOTA** mit Stats:
- Activator-Bunker (+ QSOs)
- Hunter-Bunker (+ QSOs)
- Bunker-to-Bunker (B2B)
- Programme (eindeutige Land-Prefixe wie DE, HB, F, PL, …)

## ADIF-Export

BOTA hat **kein ADIF-Standard-Tag**. Die App schreibt proprietäre
APP-Felder, damit der Wert beim Re-Import erhalten bleibt:

```
<APP_HAMTOOLS_MY_BOTA_REF:7>DE-0001
<APP_HAMTOOLS_BOTA_REF:7>HB-0007
```

Beim Export für externe Logger gehen diese Felder verloren — andere
Software erkennt BOTA nicht über ADIF. Für die App selbst ist der
Re-Import-Roundtrip sauber.

## Bekannte Einschränkungen

- **Kein offenes Spots-API** — wir filtern aus dem DX-Cluster
- **Kein zentrales Referenz-Verzeichnis** — User muss CSV besorgen
- **ADIF-Felder sind proprietär** — keine externe Logger-Kompatibilität
- **Demo-CSV** im Repo deckt nur ~15 EU-Bunker ab; für ernsthaften
  Einsatz: Country-Coordinator kontaktieren

## Vergleich der vier Award-Programme

| Aspekt | POTA | SOTA | WWFF | BOTA |
|---|---|---|---|---|
| Aktivierung ab | 10 QSOs | 4 QSOs | 44 QSOs | 1 QSO |
| Refs | `K-1234` | `HB/BE-001` | `DLFF-0001` | `DE-1234` |
| Punkte | ✗ | 1–10 + Winterbonus | ✗ | ✗ |
| Datenquelle | API offen | API offen | URL + File | nur File |
| Spots | dediziert | dediziert | DX-Cluster-Filter | DX-Cluster + DB-Match |
| ADIF | Standard | Standard | Standard | proprietär |
