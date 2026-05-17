# HAM-Tools — BOTA-Modus (Phase 4f)

**Status:** ✅ ABGESCHLOSSEN + Polish 2026-05-17.

**Polish-Update 2026-05-17:**
- Datenquelle gewechselt auf **WWBOTA Master Reference List**
  (`https://api.wwbota.org/bunkers/?format=CSV`, ~26.7k Bunker weltweit).
  Initial-CSV-Snapshot ist im App-Bundle, wird beim ersten Start ingestet,
  Versionsstand via `bundle_snapshot_date`-Meta-Key getrackt. URL-Refresh +
  manueller CSV-Import bleiben als Fallback.
- Ref-Format auf WWBOTA-Standard `B/XX-NNNN` umgestellt (vorher
  `XX-NNNN`). `BOTAReference.programFromRef` strippt den `B/`-Präfix,
  `BOTARefService.ref(forReference:)` normalisiert User-Eingaben mit/ohne
  Präfix. Spot-Pattern auf `(?:B/)?([A-Z0-9]{1,4})-(\d{3,5})` erweitert,
  damit 9A/3A/etc. funktionieren.
- ADIF-Export jetzt **WWBOTA-konform** laut offiziellem Guide
  (`wwbota.net/adifguide`): `MY_SIG="WWBOTA"`, `MY_SIG_INFO=<refs>`
  (Komma-Liste explizit erlaubt), `SIG/SIG_INFO` für B2B. Proprietäre
  `APP_HAMTOOLS_*` bleiben für unseren Re-Import-Roundtrip.

**Ursprünglicher Status:** Konzept + Implementation 2026-05-14.
**Vorbedingung:** Logbuch Phase 1–4e ist live (POTA+SOTA+WWFF). Outdoor-Sub-
Picker hat BOTA bereits als disabled-Slot — muss nur aktiviert werden.
**Vorlage:** WWFF-Modul (`Sources/HAMRechner/Features/Logbuch/WWFF/`) strukturparallel.

---

## Entscheidungen (offen — wird beim Test geklärt)

| Frage | Annahme | Hintergrund |
|---|---|---|
| Datenquelle | **File-Import primär** (keine zentrale öffentliche API gefunden), URL-Slot als Platzhalter | bunkersontheair.com nur Stub (114B), GMA `cqgma.org/bota` → 404, GMA-Feed `which=bota` → 404 |
| Ref-Format | `[A-Z]{1,4}-\d{3,5}` (z.B. `DE-1234`, `BU-099`) — flexibel | Programm-spezifisch — deutsches BOTA, polnisches BPL, russisches RB-Award unterscheiden sich |
| Aktivierungs-Regel | **1 QSO** (kein 4/10/44-Minimum wie SOTA/POTA/WWFF) — bei den meisten BOTA-Programmen reicht 1 Kontakt pro Aktivierung | Falls falsch: in 4f-3 anpassen |
| Spots-Feed | **DX-Cluster-Filter** mit BOTA-Pattern (analog WWFF) | Kein offener API-Feed |
| ADIF | Kein Standard-Tag. Proprietäres `APP_HAMTOOLS_MY_BOTA_REF` + `APP_HAMTOOLS_BOTA_REF` | ADIF 3.x kennt keine BOTA-Felder; Re-Import erhält Daten innerhalb der App |
| Multi-Bunker-Hopping | Wie POTA/WWFF (Komma-Liste) | |

---

## Architektur (analog WWFF)

### Datenbank `bota_refs.sqlite`

```sql
CREATE TABLE bota_refs (
  reference     TEXT PRIMARY KEY,    -- "DE-1234", "BU-099"
  name          TEXT NOT NULL,       -- "Bunker Münster"
  program       TEXT NOT NULL,       -- "DE", "BU" — Land-/Programm-Präfix
  country       TEXT,
  bunker_type   TEXT,                -- "WWII", "Kalter Krieg", "ATM", …
  latitude      REAL,
  longitude     REAL,
  is_active     INTEGER NOT NULL
);
CREATE INDEX idx_bota_active  ON bota_refs(is_active);
CREATE INDEX idx_bota_program ON bota_refs(program);
```

### Komponenten

```
Sources/HAMRechner/Features/Logbuch/BOTA/
├── Models/
│   ├── BOTAReference.swift
│   ├── BOTAEnums.swift            (BOTARole — activator/hunter)
│   └── BOTASpot.swift             (analog WWFFSpot, aus DXSpot abgeleitet)
├── Services/
│   ├── BOTARefDatabase.swift
│   └── BOTARefService.swift       (Doppelpfad URL + File-Picker)
└── Views/
    ├── NewBOTALogSheet.swift
    ├── BOTAEntryForm.swift        (kein QSO-Counter — 1 QSO reicht)
    ├── BOTASpotsView.swift        (DX-Cluster-Filter)
    └── BOTAMapTab.swift
```

### Schema-Migration v6 → v7

5 neue Spalten:
- `log_meta.botaRef`, `log_meta.botaRefs`
- `qsos.myBotaRef`, `qsos.myBotaRefs`, `qsos.theirBotaRef`

Analoge Strategie zum v5/v6-Pattern: am Ende der SELECT/INSERT-Listen anhängen, keine Bind-Index-Verschiebung.

### LogType + Outdoor-Sub-Picker

- `LogType.bota` neu ergänzen, `isAvailable = true`
- `OutdoorMode.bota.isAvailable = true` (war `false`)
- Routing: `currentLogIsBOTA` analog, EntryForm-Routing, DXClusters-Tab-Routing zur BOTASpotsView

---

## Phasen-Aufteilung 4f

| # | Sub-Phase | Inhalt | Status |
|---|---|---|---|
| **4f-1** | DB-Foundation | BOTAReference, BOTAEnums, BOTARefDatabase, BOTARefService (Doppelpfad), App-DI, Settings-Daten-Tab | ✅ erledigt |
| **4f-2** | Session-Wizard + Schema v7 | NewBOTALogSheet, LogType.bota, Log+QSO-Felder, Migration, Wire-Up (NewLogSheet, LogbuchView, QSOEntryPanel, WsjtxQSOConverter) | ✅ erledigt |
| **4f-3** | EntryForm | BOTAEntryForm ohne QSO-Counter (1 QSO reicht), Status-Bar, Dupe-Markierung | ✅ erledigt |
| **4f-4** | Spots-Tab | BOTASpot-Modell, BOTASpotsView (DX-Cluster-Filter), pendingBotaSpot-Bridge | ✅ erledigt |
| **4f-5** | ADIF-Export | `MY_SIG="WWBOTA"` + `MY_SIG_INFO` (Standard-Tags, 2026-05-17 nachgezogen) + APP_HAMTOOLS-Felder für Re-Import-Roundtrip | ✅ erledigt |
| **4f-6** | Map-Tab | BOTAMapTab analog WWFFMapTab | ✅ erledigt |
| **4f-7** | Awards-Sub-Tab | AwardCounts + AwardsTab.bota mit Stats-Cards | ✅ erledigt |
| **4f-Polish** | WWBOTA-Anbindung | api.wwbota.org-Endpoint, Initial-Bundle-Snapshot mit Versions-Check, B/-Präfix-Normalisierung (2026-05-17) | ✅ erledigt |

**Gesamt:** ~4 Sessions. Schneller als WWFF, weil Pattern eingespielt + kein QSO-Counter.

---

## Demo-CSV für sofortigen Test

Nach 4f-1 lege ich eine `bota_demo.csv` mit ~10-15 echten BOTA-Refs an (DE, BU, …), damit du sofort eine Session anlegen kannst ohne externe Quelle.

---

## Out-of-Scope für 4f (Phase 6+)

- Upload zu bunkers-Programmen (manueller ADIF-Export funktioniert, Auto-
  Upload offen — kein offizielles API bei WWBOTA gefunden, nur Web-Upload)
- Self-Spotting
- Aktivierungs-Punkte (gibt's bei BOTA in der Form nicht)
