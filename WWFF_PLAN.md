# HAM-Tools — WWFF-Modus (Phase 4e)

**Status (Stand 2026-05-19):** ✅ ABGESCHLOSSEN (2026-05-14). Outdoor-Tab-Refactor durch (DX/Contest/Outdoor mit Sub-Picker POTA/SOTA/WWFF/BOTA), Reference-DB mit URL- + CSV-Doppelpfad, 44-QSO-Counter, Map, Awards. Dieses Dokument ist die historische Plan-Skizze.
**Vorbedingung:** Logbuch Phase 1–4d ist live (v1.8). Phase 4e-0
(Outdoor-Tab-Refactor) MUSS vor 4e-1 abgeschlossen sein.
**Vorlage:** SOTA-Modul (`Sources/HAMRechner/Features/Logbuch/SOTA/`)
strukturidentisch übernehmen, mit den WWFF-Besonderheiten unten.

---

## Entscheidungen (offen — beim Session-Start klären)

| Frage | Vorschlag | Erinnerung |
|---|---|---|
| Datenquelle (vollständige Ref-Liste) | `wwff-cc.org/dir.php?do=list_directory` als CSV oder Pro-Country-CSVs konsolidieren | Endpoint live verifizieren wie bei sotadata.org.uk in 4d-1 |
| Aktivierungs-Regel | **44 QSOs** (WWFF-Standard) — strikter als POTA/SOTA | Counter im Form rot bis 44, grün ab 44 |
| Spots-Feed | GMA-Aggregator: `cqgma.org/gma_news/feed_view.php?which=ff` (read-only) | GMA aggregiert SOTA/WWFF/BOTA — könnte später für ein zentrales Spots-Modul interessant sein |
| Self-Spotting | Out-of-Scope für 4e (analog POTA self-spot bei Phase 6) | |
| Doppel-Refs POTA/WWFF | Optional als Bonus-Feature nach 4e-1 (Park-Wizard zeigt WWFF-Match an) | Nice-to-have, ~0.5 Session |
| Honor-Roll / Punkte | Activator-Refs + Hunter-Refs als eindeutige Liste; Punkte = Anzahl unique Refs | Keine separaten Bonuspunkte wie SOTA-Winter |

---

## Phase 4e-0 — Outdoor-Tab-Refactor (Voraussetzung)

**Warum vorher:** WWFF wäre der 5. Sub-Modus im QSO-Panel-Tab-Picker
(neben DX/Contest/POTA/SOTA). Bei BOTA als 6. Sub-Modus wird die Bar zu
voll. Sauberer Refactor jetzt erspart doppelte Arbeit.

**Was wird gemacht:**
- `EntryMode { dx, contest, outdoor }` statt aktuell vier Cases
- **Outdoor-Tab** mit Sub-Picker (POTA / SOTA / WWFF / BOTA):
  - Variante A: Zweistöckige Tab-Bar (Haupt-Tabs oben, Outdoor-Sub-Tabs darunter wenn aktiv)
  - Variante B: Drop-Down im Tab-Label („Outdoor: SOTA ▾"); UX bestimmt User
- Aktives Log bestimmt Default-Sub
- `currentLogIsOutdoor` Computed Property in LogbuchView (Aggregat aus POTA/SOTA/WWFF/BOTA)
- Anlegen-Button im Sub-Picker triggert den jeweiligen Wizard
- Bestehendes Routing (DXClusters-Tab → POTA-Spots / SOTA-Spots) bleibt
  log-typ-basiert wie heute; nur die UI-Quelle (Tab-Click) wandert in den Sub-Picker

**Aufwand:** ~1 Session.

---

## Architektur (analog SOTA)

### Datenbank `wwff_refs.sqlite`

```sql
CREATE TABLE wwff_refs (
  reference     TEXT PRIMARY KEY,    -- "DLFF-0001", "HBFF-0019", "KFF-1234"
  name          TEXT NOT NULL,       -- "Berchtesgaden National Park"
  program       TEXT NOT NULL,       -- "DLFF", "HBFF", "KFF" (Land-Präfix-Programm)
  country       TEXT,                -- "Germany", "Switzerland", "USA"
  iuc_category  TEXT,                -- Schutzgebietskategorie (Nationalpark, Natura-2000, …)
  latitude      REAL,
  longitude     REAL,
  is_active     INTEGER NOT NULL,
  pota_link     TEXT                 -- Optional: bekannte POTA-Ref wenn Doppel-Programm
);
CREATE INDEX idx_wwff_active  ON wwff_refs(is_active);
CREATE INDEX idx_wwff_program ON wwff_refs(program);

CREATE TABLE wwff_refs_meta (
  key   TEXT PRIMARY KEY,
  value TEXT
);
```

**Download-Quelle:** muss verifiziert werden (curl in 4e-1). Optionen:
- `wwff-cc.org/dir.php?do=list_directory` (offizielles Directory, Format prüfen)
- GitHub-Mirror (z.B. github.com/wwff/directory) falls vorhanden
- Pro-Country-CSVs ([DLFF.csv], [HBFF.csv] …) konsolidieren

Refresh-Empfehlung: alle 30 Tage analog SOTA.

### Datenmodelle

```swift
// Sources/HAMRechner/Features/Logbuch/WWFF/Models/WWFFReference.swift
struct WWFFReference: Identifiable, Codable, Hashable {
    var id: String { reference }
    let reference: String          // "DLFF-0001"
    let name: String
    let program: String            // "DLFF" (Land-Code aus Ref-Prefix abgeleitet)
    let country: String?
    let iucCategory: String?
    let latitude: Double?
    let longitude: Double?
    let isActive: Bool
    let potaLink: String?          // bekannte POTA-Doppel-Ref, falls vorhanden

    var displayLabel: String       // "DLFF-0001 — Berchtesgaden (Germany)"
}

// Sources/HAMRechner/Features/Logbuch/WWFF/Models/WWFFEnums.swift
enum WWFFRole: String, Codable, CaseIterable, Identifiable {
    case activator = "Activator"
    case hunter    = "Hunter"
    var id: String { rawValue }
    var displayName: String { ... }
}

// Sources/HAMRechner/Features/Logbuch/WWFF/Models/WWFFSpot.swift
struct WWFFSpot: Identifiable, Hashable, Codable {
    // GMA-Format prüfen — wahrscheinlich JSON oder RSS/XML
    let id: Int
    let timeStamp: Date
    let callsign: String
    let reference: String          // "DLFF-0001"
    let frequencyMHz: Double
    let mode: String
    let comments: String?
    let spotter: String?
}
```

### Komponenten

```
Sources/HAMRechner/Features/Logbuch/WWFF/
├── Models/
│   ├── WWFFReference.swift
│   ├── WWFFEnums.swift            (WWFFRole)
│   └── WWFFSpot.swift
├── Services/
│   ├── WWFFRefDatabase.swift      (SQLite-Wrapper)
│   ├── WWFFRefService.swift       (CSV-Parser, Lifecycle)
│   └── WWFFSpotsService.swift     (GMA-Polling)
└── Views/
    ├── NewWWFFLogSheet.swift
    ├── WWFFEntryForm.swift        (mit 44-QSO-Counter)
    ├── WWFFSpotsView.swift
    └── WWFFMapTab.swift
```

### WWFF-Spots-API

- Wahrscheinlich GMA-Endpoint: `https://www.cqgma.org/gma_news/feed_view.php?which=ff`
- Format prüfen (JSON, RSS, oder eigenes HTML?)
- Polling-Rate: 60 Sek analog SOTA
- Filter: nur `type=SPOT` (falls vorhanden), keine Test-Einträge

### Aktivierungs-Logik

**Activator:**
- Mindestens **44 QSOs** pro Aktivierung (das ist die fixe WWFF-Regel)
- 1 Aktivierung pro Tag pro Ref zählt — bei Hopping pro Ref separat 44 nötig
- Keine Punkte-Multiplier wie SOTA — jede gültige Aktivierung = 1 neue Ref im Honor-Roll

**Hunter:**
- 1 QSO mit aktiver Ref reicht für 1 Punkt zum Honor-Roll
- Gleiche Ref mehrfach an verschiedenen Tagen = 1 Hunter-Punkt (nicht aufaddieren)

**Park-to-Park („Reference-to-Reference"):**
- Beide Operatoren auf einer Ref → P2P zählt für beide
- Optional: WWFF zählt auch P2P-Bonus separat (analog POTA P2P)

### WWFF-Form

**Felder (analog POTA-Form):**
- `call` — Pflicht
- `theirWwffRef` — optional (P2P/R2R)
- `rstSent` / `rstReceived`
- `powerW`, `comments`
- `timeOn` — auto

**Status-Bar (read-only):**
```
UTC · Freq (Band) · Mode · Power · My Ref(s) · My Grid
```

**Counter (nur Activator):**
```
44-QSO-Aktivierung: 27/44 [orange/grün]
```

### Bestehende Logbook-Erweiterungen

- `LogType.wwff` muss in `LogType.swift` ergänzt werden (aktuell: standard,
  contest, pota, sota)
- `Log.wwffRef`, `Log.wwffRefs` (Komma-Liste analog `sotaSummitRefs`) als
  neue Felder
- `QSO.myWwffRef` existiert bereits (LogEntryBridge sammelt es schon aus
  DX-Spot-Kommentaren), aber `QSO.myWwffRefs` (Hopping) und
  `QSO.theirWwffRef` (P2P) sind noch zu ergänzen
- **Schema-Migration v5 → v6**: vier neue Spalten

### Routing (LogbuchView)

```swift
private var currentLogIsWWFF: Bool {
    guard let id = manager.currentLogID,
          let log = manager.logs.first(where: { $0.id == id }) else { return false }
    return log.type == .wwff
}
```

Steuert (analog SOTA):
1. QSO-Eingabe-Panel: WWFFEntryForm statt Standard
2. Awards-Sub-Tab: auto-switch auf `.wwff`
3. DX-Cluster-Tab: WWFFSpotsView
4. Map-Tab: WWFFMapTab

---

## Phasen-Aufteilung 4e

| # | Sub-Phase | Inhalt | Aufwand |
|---|---|---|---|
| **4e-0** | Outdoor-Tab-Refactor | EntryMode → 3 Tabs, Sub-Picker für POTA/SOTA. **Voraussetzung.** | 1 Session |
| **4e-1** | WWFF-DB-Foundation | WWFFReference, WWFFEnums, WWFFRefDatabase (SQLite), WWFFRefService (CSV-Parser, 30-Tage-Refresh). **Datenquelle live verifizieren!** | 1 Session |
| **4e-2** | Session-Anlage | NewWWFFLogSheet (Activator/Hunter + Ref-Picker + Hopping + Auto-Name). Logbuch-Schema-Migration v6 für `wwffRefs` + `QSO.myWwffRefs`/`theirWwffRef` | 1 Session |
| **4e-3** | Entry-Form + 44-QSO-Counter | WWFFEntryForm, Routing in LogbuchView, Status-Bar, Dupe-Markierung. Counter ist rot bis 43, grün ab 44 | 1 Session |
| **4e-4** | Spots-Tab | WWFFSpotsService (GMA-Polling), WWFFSpotsView (Filter, Copy, CAT-QSY). **GMA-Format verifizieren** | 1 Session |
| **4e-5** | ADIF-Export | ADIFCodec erweitern um MY_SIG=WWFF, MY_WWFF_REF, WWFF_REF | 0.5 Session |
| **4e-6** | Map-Tab | WWFFMapTab (Reference-Pins + DX-Pins + Linien, R2R-Indikator) | 0.5–1 Session |
| **4e-7** | Awards-Sub-Tab | Awards-Tab `.wwff`-Case: Activator-Refs, Hunter-Refs, R2R, einzigartige Programme. Auto-Switch wie POTA/SOTA | 0.5 Session |

**Gesamt:** 6–7 Sessions inkl. 4e-0.

---

## Bonus-Feature: Doppel-Refs POTA / WWFF

In Europa sind viele Parks gleichzeitig POTA und WWFF (z.B. Schweizer
Nationalpark = `HB-0001` POTA + `HBFF-0010` WWFF). Idee:

- Beim POTA-Wizard nach Park-Auswahl: in `wwff_refs.pota_link`-Spalte
  suchen und falls Match → blauer Hinweis „auch WWFFF-Ref `HBFF-...`
  vorhanden — auch aktivieren?"
- Optional als zweites WWFF-Log anlegen (User-Choice)
- Beim Loggen: QSO wird automatisch mit beiden Refs gespeichert

**Aufwand:** ~0.5 Session nach 4e-1 (Reference-Service steht dann).
Macht den EU-User-Workflow deutlich smoother. **Optional** — kann
auch ans Ende von 4e geschoben werden.

---

## Reihenfolge-Empfehlung

1. **4e-0** ZUERST — Refactor ist Pflicht, sonst muss WWFF in die alte
   Tab-Struktur und dann später nochmal umgebaut werden.
2. **4e-1** zweiter — Foundation steht, datenquellenseitig verifizieren.
3. **4e-2 + 4e-3** als Block — Session + Form müssen zusammen testbar sein.
4. **4e-5** (ADIF) gleich nach 4e-3 — sichert die Logging-Phase.
5. **4e-4** (Spots) + **4e-6** (Map) parallel als Polish-Block.
6. **4e-7** (Awards) zum Schluss.
7. **Bonus Doppel-Refs** nach 4e-1, falls Zeit + Energie.

---

## Risiken / Offene Punkte

- **CSV-Format wwff-cc.org:** noch nicht live verifiziert (Endpoint hängt
  zeitweise). Beim 4e-1-Start curl-Test wie bei sotadata.org.uk in 4d-1.
  Fallback: GitHub-Mirror oder Pro-Country-CSVs.
- **GMA-Spots-Format:** muss live geprüft werden — JSON oder RSS/XML?
  Falls XML, eigener Parser nötig (POTA/SOTA waren beide JSON).
- **44-QSO-Hürde:** das ist eine HOHE Latte. UX-Frage: wenn User nur
  10 QSOs gemacht hat, ist Activator-Aktivierung ungültig. Counter klar
  kommunizieren („14 weitere QSOs für Aktivierung nötig").
- **Doppel-Refs-Daten:** der `wwff_refs.pota_link`-Mapping muss erst
  einmal aufgebaut werden. Quelle? Manuell pflegen? Es gibt
  cross-reference-Sheets (HamCommunity, Reddit-Threads, einige private
  Websites). Pragmatisch: leeres Feld zur Zeit, später durch User-Input
  und Community-Mirror füllen.
- **Honor-Roll-Punkte:** WWFF hat Activator/Hunter-Awards bei 11, 22, 33,
  44, 55 … unique Refs. Awards-Tab könnte das als Progress-Bars zeigen —
  nicht in 4e-7 nötig, aber als Folge-Idee notieren.

---

## Out-of-Scope für 4e (kommt später)

- Upload zu wwff-cc.org (manuelle ADIF-Submission an Country-Coordinator
  bleibt)
- Self-Spotting via GMA
- Honor-Roll-Progress-Bars (11/22/33/44/55)
- Cross-Programm-Doppel-Refs außerhalb POTA (z.B. mit BOTA)
- **BOTA-Modul (Bunkers On The Air)** — folgt als Phase 4f nach WWFF,
  separater Plan
