# HAM-Tools — SOTA-Modus (Phase 4d)

**Status:** Konzept fertig, Implementation startet 2026-05-14.
**Vorbedingung:** Logbuch Phase 1–4b + 4c (POTA) + 5 (CAT) sind live (v1.7.1).
**Vorlage:** POTA-Modul (`Sources/HAMRechner/Features/Logbuch/POTA/`) zu ~95% strukturidentisch übernehmen.

---

## Entscheidungen (Q&A 2026-05-14)

| Frage | Entscheidung | Folge |
|---|---|---|
| Summit-DB-Quelle | `https://www.sotadata.org.uk/summitslist.csv` (vollständige Welt-Liste, ~181k Summits) | Bulk-Download + lokale SQLite analog POTA |
| Aktivierungs/Chaser-Wechsel | Session-Festlegung (Activator vs. Chaser), nicht live-switch | NewSOTALogSheet bei Anlage |
| Spots-Feed | `https://api2.sota.org.uk/api/spots/50/all` (read-only, 60-Sek-Polling analog POTA) | SotaSpotsService + SotaSpotsView |
| UI | Eigener SOTA-Tab-Pfad, Routing in `LogbuchView` über `currentLogIsSOTA` | Parallel zu POTA |
| Punkte-Logik | **Vollständig** — Activator-Punkte + Chaser-Punkte + S2S separat + Winterbonus | Saisonale Datum-Logik in `SOTAPointsCalculator` |
| Multi-Summit-Hopping | Wie POTA via Komma-Liste (`mySotaRefs`) | Logbuch-Schema ggf. erweitern um `mySotaRefs` |
| Out-of-scope für 4d | Upload zu sotadata.org.uk (kommt in Phase 6), Self-Spotting, Mountain-Foto-Badge |

---

## Architektur

### Datenbank `summits.sqlite`

```sql
CREATE TABLE summits (
  reference         TEXT PRIMARY KEY,      -- "HB/BE-001", "G/LD-001"
  association       TEXT NOT NULL,         -- "Switzerland"
  region            TEXT NOT NULL,         -- "Berner Alpen"
  name              TEXT NOT NULL,         -- "Finsteraarhorn"
  altitude_m        INTEGER,
  altitude_ft       INTEGER,
  latitude          REAL,
  longitude         REAL,
  points            INTEGER NOT NULL,      -- 1..10
  bonus_points      INTEGER NOT NULL,      -- 0 oder 3 (Winterbonus, falls anwendbar)
  valid_from        TEXT,                  -- ISO 8601 (vom DD/MM/YYYY konvertiert)
  valid_to          TEXT,                  -- ISO 8601
  is_active         INTEGER NOT NULL,      -- 1 wenn valid_to > today
  activation_count  INTEGER,
  last_activation   TEXT                   -- ISO 8601, optional
);
CREATE INDEX idx_summits_active ON summits(is_active);
CREATE INDEX idx_summits_assoc  ON summits(association);

CREATE TABLE summits_meta (
  key   TEXT PRIMARY KEY,
  value TEXT
);
```

**Download-Quelle:**
- URL: `https://www.sotadata.org.uk/summitslist.csv`
- Größe: ~15 MB, ~181k Zeilen
- Header in Zeile 2 (Zeile 1 ist Titel "SOTA Summits List (Date=14/05/2026)" → skippen)
- Spalten (17): SummitCode, AssociationName, RegionName, SummitName, AltM, AltFt, GridRef1, GridRef2, Longitude, Latitude, Points, BonusPoints, ValidFrom, ValidTo, ActivationCount, ActivationDate, ActivationCall
- Datum-Format: `DD/MM/YYYY` (britisch) → in Parser nach ISO konvertieren
- `is_active` = `valid_to >= today`
- Refresh-Empfehlung: alle 30 Tage (langlebiger als POTA, da Summit-Liste sich seltener ändert)

### Datenmodelle

```swift
// Sources/HAMRechner/Features/Logbuch/SOTA/Models/Summit.swift
struct Summit: Identifiable, Codable, Hashable {
    var id: String { reference }
    let reference: String          // "HB/BE-001"
    let association: String
    let region: String
    let name: String
    let altitudeM: Int?
    let altitudeFt: Int?
    let latitude: Double?
    let longitude: Double?
    let points: Int                // Activator-Punkte aus CSV
    let bonusPoints: Int           // 0 oder 3 (saisonal anwendbar)
    let validFrom: Date?
    let validTo: Date?
    let isActive: Bool
    let activationCount: Int?
    let lastActivation: Date?

    var displayLabel: String      // "HB/BE-001 — Finsteraarhorn (Switzerland, 4274m, 10p)"
    var prefix: String            // "HB" oder "HB/BE" für Filter
}

// Sources/HAMRechner/Features/Logbuch/SOTA/Models/SOTAEnums.swift
enum SOTARole: String, Codable, CaseIterable, Identifiable {
    case activator = "Activator"
    case chaser    = "Chaser"
    var id: String { rawValue }
    var displayName: String { ... }
}

// Sources/HAMRechner/Features/Logbuch/SOTA/Models/SOTASpot.swift
struct SOTASpot: Identifiable, Hashable, Codable {
    let id: Int                    // SOTAwatch-internal-ID
    let timeStamp: Date            // UTC
    let callsign: String           // "HB9XYZ/P"
    let associationCode: String    // "HB"
    let summitCode: String         // "BE-001" (ohne Assoc-Prefix!)
    let summitDetails: String?     // "Finsteraarhorn, 4274m, 10pts"
    let frequencyMHz: Double       // kommt im JSON als String in MHz
    let mode: String               // "SSB", "CW", "FT8"
    let comments: String?
    let highlightColor: String?    // "green", "yellow", "red"
    let type: String?              // "SPOT" oder "TEST"
    // Abgeleitet:
    var fullReference: String { "\(associationCode)/\(summitCode)" }
    var band: String { ... }
}
```

### Komponenten

```
Sources/HAMRechner/Features/Logbuch/SOTA/
├── Models/
│   ├── Summit.swift
│   ├── SOTAEnums.swift            (SOTARole)
│   └── SOTASpot.swift
├── Services/
│   ├── SotaSummitDatabase.swift   (SQLite, analog PotaParkDatabase)
│   ├── SotaSummitService.swift    (CSV-Parser, Status-Lifecycle)
│   ├── SotaSpotsService.swift     (60-Sek-Polling)
│   └── SOTAPointsCalculator.swift (Aktivierungs-Punkte + Winterbonus + Chaser-Punkte)
└── Views/
    ├── NewSOTALogSheet.swift      (Session-Wizard analog NewPOTALogSheet)
    ├── SOTAEntryForm.swift        (schlanke Form mit 4-QSO-Counter + Punkte-Live)
    ├── SotaSpotsView.swift        (Live-Spots-Tab mit Copy + CAT-QSY)
    └── SOTAMapTab.swift           (Summit-Pins + DX-Pins + Linien)
```

### SOTA-Spots-API

- Endpoint: `https://api2.sota.org.uk/api/spots/50/all`
- Methode: GET, JSON-Array
- Polling-Rate: 60 Sek (gleicher Wert wie POTA)
- Felder pro Spot: id, timeStamp, callsign, associationCode, summitCode, summitDetails, frequency (String, MHz), mode, comments, highlightColor, type
- Filter "type=SPOT" (ignoriere "TEST"-Einträge)
- Decoder muss timeStamp toleranter Parser sein (ISO 8601 mit/ohne Z)

### Aktivierungs-Logik

**Activator-Punkte:**
- Pro gültiger Aktivierung erhält der Operator die `points`-Wert des Summits
- "Gültig" = mindestens **4 QSOs** im Activator-Modus auf dem Summit
- Winterbonus: zusätzliche `bonus_points` (typisch +3), wenn Aktivierungsdatum im Winter-Window:
  - Nordhalbkugel (Lat > 0): 1. Dezember – 15. März
  - Südhalbkugel (Lat < 0): 1. Juni – 15. September
- Hopping über mehrere Summits am selben Tag: pro Summit eigene 4-QSO-Aktivierung
  → `mySotaRefs` Komma-Liste, aber Punkte werden **pro Ref separat** vergeben

**Chaser-Punkte:**
- Bekommt der Chaser pro QSO mit einem aktivierenden Summit
- Punkte = `points` des Summits (kein Bonus für Chaser)
- Gleicher Summit mehrfach hintereinander (Hopping) zählt nur **1× pro Tag** für denselben Chaser
  → Dupe-Check pro (call, summit, date)

**S2S (Summit-to-Summit):**
- Beide Operatoren auf einem Summit
- Activator zählt Aktivierungs-Punkte plus S2S-Bonus (Punkte des Gegen-Summits, einmalig pro Tag pro Gegen-Summit)
- Chaser-Modus existiert hier nicht — beide sind Activator zueinander

### S2S-Erkennung

- In `SOTAEntryForm`: Feld `theirSotaRef` mit Autocomplete gegen `summits.sqlite`
- Wenn `currentLog.role == .activator` und `theirSotaRef != nil` → S2S
- Punkte automatisch berechnen und in `theirSotaPoints` cachen (QSO-Feld existiert bereits)
- Spot-Bridge: wenn aktiver Spot eine Gegenstation auf einem Summit ist → vorbefüllen

### SOTA-Form

**Felder:**
- `call` — Pflicht
- `theirSotaRef` — optional (für S2S oder Chaser-Mode)
- `theirSotaPoints` — read-only, auto-berechnet aus Summit-DB
- `rstSent` / `rstReceived`
- `powerW`, `comments`
- `timeOn` — auto

**Status-Bar (read-only):**
```
UTC · Freq (Band) · Mode · Power · My Summit (Punkte+Bonus) · My Grid
```

**Counter (nur Activator):**
```
4-QSO-Aktivierung: 3/4 [orange/grün]
Aktuelle Punkte: 10 + 3 Bonus = 13
```

### Bestehende Logbook-Erweiterungen

- `LogType.sota` existiert bereits in `LogType.swift`
- `Log.sotaSummitRef` existiert bereits
- `QSO.mySotaRef`, `QSO.theirSotaRef`, `QSO.theirSotaPoints` existieren bereits
- **Erweitern:**
  - `Log.sotaSummitRefs` (Komma-Liste für Hopping)
  - `Log.role` wird für SOTA auch genutzt (Aktivator/Chaser)
  - `QSO.mySotaRefs` (Komma-Liste analog `myPotaRefs`)
  - **SQLite-Migration:** schema_version bump + `ALTER TABLE` für neue Spalten

### Routing (LogbuchView)

```swift
private var currentLogIsSOTA: Bool {
    guard let id = manager.currentLogID,
          let log = manager.logs.first(where: { $0.id == id }) else { return false }
    return log.type == .sota
}
```

Steuert wie bei POTA:
1. QSO-Eingabe-Panel: SOTAEntryForm statt Standard
2. Awards-Sub-Tab: auto-switch auf `.sota`
3. DX-Cluster-Tab: SotaSpotsView statt Cluster
4. Map-Tab: SOTAMapTab statt History-Map

---

## Phasen-Aufteilung 4d

| # | Sub-Phase | Inhalt | Aufwand |
|---|---|---|---|
| **4d-1** | Summit-DB-Foundation | Summit.swift, SOTAEnums.swift, SotaSummitDatabase.swift (SQLite + Bulk-Replace + Lookup), SotaSummitService.swift (CSV-Parser für 17-Spalten-Schema + 30-Tage-Refresh) | 1 Session |
| **4d-2** | Session-Anlage | NewSOTALogSheet (Activator/Chaser + Summit-Picker + Hopping + Auto-Name). Logbuch-Schema-Migration für `sotaSummitRefs` + `QSO.mySotaRefs` | 1 Session |
| **4d-3** | Entry-Form + Counter | SOTAEntryForm, SOTAPointsCalculator (Activator + Chaser + Winterbonus), Routing in LogbuchView, Status-Bar, Dupe-Markierung | 1 Session |
| **4d-4** | Spots-Tab | SotaSpotsService (Polling), SotaSpotsView (Filter, Copy, CAT-QSY) | 1 Session |
| **4d-5** | ADIF-Export | ADIFCodec.swift erweitern um MY_SOTA_REF, SOTA_REF, MY_SIG=SOTA, SIG=SOTA. Optional separater SOTA-CSV-V2-Export für sotadata.org.uk | 0.5 Session |
| **4d-6** | Map-Tab | SOTAMapTab (Summit-Pins mit Elevation-Tooltip, DX-Pins, Linien, Band-Filter) | 0.5–1 Session |
| **4d-7** | Awards-Sub-Tab | Awards-Tab `.sota`-Case: Aktivierungen, Activator-Punkte, Chaser-Punkte, S2S-Count, einzigartige Summits. Auto-Switch wie POTA | 0.5 Session |

**Gesamt:** ~5–6 Sessions, deckungsgleich mit POTA-Aufwand.

---

## Reihenfolge-Empfehlung

1. **4d-1** zuerst — Foundation steht und ist isoliert testbar.
2. **4d-2** + **4d-3** als Block — Session anlegen + QSO loggen muss zusammen funktionieren.
3. **4d-5** (ADIF) gleich nach 4d-3 — Export ist trivial, sichert die Logging-Phase.
4. **4d-4** (Spots) + **4d-6** (Map) parallel als Polish-Block.
5. **4d-7** (Awards) zum Schluss als Krönung.

---

## Risiken / Offene Punkte

- **CSV-Schema-Drift:** sotadata.org.uk hat in der Vergangenheit Spalten verschoben. Header-Detection robust + Fallback-Indizes (analog POTA).
- **Spots-API-Rate-Limit:** keine offizielle Doku zu Limits. Bei 60-Sek-Polling sicher unproblematisch.
- **Datum DD/MM/YYYY:** typische Falle, klar dokumentieren im Parser.
- **Offline-Modus:** Summit-DB einmal heruntergeladen funktioniert offline (DB lokal). Spots-Tab braucht Online.
- **Punkte-Edge-Cases:** Bonus-Saison-Berechnung bei Lat=0 (Äquator) — Default Nordhalbkugel.
- **Hopping-Award-Tracking:** Komma-Liste bei `mySotaRefs` muss in Awards-Stats korrekt pro Summit zählen, nicht 1× pro QSO.

---

## Out-of-Scope für 4d (kommt später)

- Upload zu sotadata.org.uk (CSV V2) — Phase 6
- Self-Spotting via SOTAwatch (POST) — analog POTA self-spot, separat
- Mountain-Artwork / Badge-Generierung
- Höhenprofil pro Summit (SRTM-Daten)
- Activator-Marathon / saisonale Auswertungen
