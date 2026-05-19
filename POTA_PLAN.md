# HAM-Tools — POTA-Modus (Phase 4c)

**Status (Stand 2026-05-19):** ✅ ABGESCHLOSSEN. Park-DB + Activator/Hunter + P2P + Multi-Park-Hopping + Dupe-Markierung + Spots-Feed mit CAT-QSY + ADIF + QSO-Map alle live. POTA-Self-Spot (api.pota.app/spot) ergänzt. Auto-Upload an pota.app weiterhin manuell (Cognito-SRP-Auth-Versuch 2026-05-16 gescheitert, vertagt). Dieses Dokument ist die historische Plan-Skizze.
**Vorbedingung:** Logbuch-Phase 1+2+3+4b ist live (Multi-Log + ADIF + Callbook + Cabrillo), CAT ist live (5a + 5b/5c Schreibpfad). Phase 4c hängt sich hier ein.

## Entscheidungen (Q&A 2026-05-12)

| Frage | Entscheidung | Folge |
|---|---|---|
| Park-DB-Strategie | **Download beim ersten POTA-Modus-Start** + persistente SQLite. Auf jedem nachfolgenden Start: User-Dialog "Aktualisieren? Letzte Aktualisierung: vor X Tagen" mit Ja/Nein | Eigener `PotaParkService` der Lifecycle + Refresh managed |
| Activator vs Hunter | **Festgelegt pro POTA-Session beim Anlegen** | Session = Activator (mit My-Park-Ref) ODER Hunter, kein Live-Switch |
| POTA-Spots | **Read-only Live-Feed** aus pota.app-API als eigener Tab | Polling alle 60 Sek, Click-to-fill für Call+Park, QSY ans Radio |
| UI-Approach | **Eigene POTA-Ansicht** (analog Referenz-Bild) | Bei POTA-Log übernimmt POTAView die Hauptansicht statt normalem QSOEntryPanel |

---

## Architektur

### Datenbank `parks.sqlite`

Liegt in `~/Documents/HAM-Tools/Cache/parks.sqlite` (über AppDataRoot.cacheDir).

```sql
CREATE TABLE parks (
  reference TEXT PRIMARY KEY,    -- "K-1234", "DA-0001", "HB-0042"
  name TEXT NOT NULL,
  active INTEGER NOT NULL,
  entity_id INTEGER,
  location_desc TEXT,
  latitude REAL,
  longitude REAL,
  grid TEXT,
  country TEXT,
  state TEXT,
  region TEXT
);
CREATE INDEX idx_parks_country ON parks(country);
CREATE INDEX idx_parks_active  ON parks(active);

CREATE TABLE parks_meta (
  key TEXT PRIMARY KEY,
  value TEXT
);
-- key=last_update (ISO 8601), source_url, row_count
```

Quelle: `https://pota.app/all_parks_ext.csv` (~15 MB, ~90'000 Parks weltweit).
CSV-Parse + SQLite-Insert in einem Pass, Transaktion + Indices nach Insert. Erwartete Dauer auf Mac: ~3-5 Sek inkl. Download.

### Park-DB-Lifecycle

`PotaParkService` (Sources/HAMRechner/Features/Logbuch/POTA/Services/):

| Zustand | Aktion |
|---|---|
| Erster App-Start in POTA-Modus | Download + Build, Settings-Modal "Lade Park-DB…" |
| Nachfolgender Start, DB vorhanden, älter X Tage | User-Dialog mit Datum + "Aktualisieren?"-Button |
| Manueller Refresh aus Settings | Bestätigung + Download |
| Offline / Fetch fehlgeschlagen | Weiterarbeiten mit bestehender DB, Warn-Banner |

Default-Schwelle: alle 14 Tage automatisch nachfragen, weil POTA-Parks regelmäßig neu hinzukommen.

### Datenmodelle

```swift
struct Park: Identifiable, Codable, Hashable {
    var id: String { reference }
    let reference: String          // "K-1234"
    let name: String
    let active: Bool
    let country: String
    let state: String?
    let region: String?
    let locationDesc: String?
    let latitude: Double?
    let longitude: Double?
    let grid: String?
}

enum POTARole: String, Codable {
    case activator
    case hunter
}

// Erweiterung von Log-Entity (bestehendes Log-Modell ergänzen):
// logType wird zu .pota, plus neue Felder:
struct POTASessionMeta: Codable {
    let role: POTARole
    let myPark: String?            // K-1234 — nur bei Activator gesetzt
    let myParkName: String?
}
```

### Komponenten (Features/Logbuch/POTA/)

```
POTA/
├── Models/
│   ├── Park.swift
│   ├── POTAEnums.swift                 # Role, AdditionsKey
│   └── POTASpot.swift                  # decoded from api.pota.app
├── Services/
│   ├── PotaParkService.swift           # Download + SQLite + Lookup
│   ├── PotaSpotsService.swift          # 60-Sek-Polling der Spots-API
│   └── PotaParkRepository.swift        # SQLite-Wrapper analog LogbookManager
├── ViewModels/
│   └── POTAViewModel.swift             # Form-State, P2P-Detection, Counter
└── Views/
    ├── POTAView.swift                  # Haupt-Ansicht (ersetzt QSOEntryPanel)
    ├── POTAStatusBar.swift             # UTC · Freq · Mode · Power · Op · My Park · Grid
    ├── POTAEntryForm.swift             # Their Call / RST / Their Park / Comments / Notes / Op-Toggle
    ├── POTAEntriesTab.swift            # Liste der QSOs dieser Session
    ├── POTASpotsTab.swift              # Spots-Feed mit Filter + Click-to-fill
    ├── POTAMapTab.swift                # QSO-Map (reused History-Logik wo möglich)
    ├── ParkPickerSheet.swift           # Autocomplete-Picker für Park-Ref
    └── POTAActivationBadge.swift       # "X/10" Counter mit Farbcode
```

### POTA-Spots-API

Endpoint: `https://api.pota.app/spot/activator` (JSON-Array, no auth).
Response-Items (vereinfacht):
```json
{
  "spotId": 12345678,
  "activator": "HB9HJI",
  "frequency": "14285.0",
  "mode": "SSB",
  "reference": "DA-0042",
  "parkName": "Schwarzwald",
  "spotTime": "2026-05-12T17:40:52Z",
  "comments": "Phone P2P welcome"
}
```

Polling alle 60 Sek. Im Tab anzeigen: Tabelle mit Sort/Filter (Band, Mode, Region). Click → setzt in der Form Their Call + Their Park, und bei aktivem CAT: `cat.setFrequencyMHz(...)`.

### P2P-Erkennung

- Hunter-Modus: wenn Their Park gefüllt → Match gegen `parks` DB → falls valid: "P2P" Indicator in der Form
- Activator-Modus: wenn Their Park gefüllt UND ein Activator-Spot in der Spots-Liste passt zum Call → P2P
- ADIF-Export setzt beides:
  - Activator-Sicht: `SIG=POTA`, `SIG_INFO=<their park>`, `MY_SIG=POTA`, `MY_SIG_INFO=<my park>`
  - Hunter-Sicht: `SIG=POTA`, `SIG_INFO=<their park>`

### 10-QSO-Counter (nur Activator)

Live-Counter rechts oben in POTAView: `X/10 QSOs`.
- Rot bei <10, grün bei ≥10 mit Badge "Aktivierung gültig"
- Counter zählt nur QSOs der aktuellen Log-Session

### POTA-Form (schlanker als Standard)

Felder (vom Referenz-Bild übernommen):

| Feld | Pflicht | Default |
|---|---|---|
| Their Call | ja | leer |
| RST/S | ja | 59 / 599 je nach Mode |
| RST/R | ja | 59 / 599 |
| Their Park | nur Hunter | leer, comma-separated für Multi-Hopping |
| Comments | optional | leer |
| Notes | optional | leer |
| Operator | auto | aus Settings (Stations-Call) |

Status-Bar oben (read-only, aus CAT + Settings):
`UTC-Zeit · Frequenz (Band) · Mode · Power · Operator · My Park · My Grid`

Buttons: **Clear** (leert Form) · **Save** (logged QSO, Form resettet)

### Bestehende Logbook-Erweiterungen

- `LogType` Enum bekommt Wert `.pota` (war eh vorgesehen lt. LOGBUCH_PLAN.md)
- `Log`-Entity ergänzt um optionale POTA-Felder `role`, `my_park`, `my_park_name`
- `LogbookManager.createLog(type: .pota, ...)` mit POTASessionMeta-Param
- ADIF-Exporter prüft logType, setzt SIG/SIG_INFO/MY_SIG/MY_SIG_INFO entsprechend

### Routing (ContentView)

Aktuell: wenn `selectedCalculator == .logbuch` → LogbuchView übernimmt das Fenster.
Erweiterung: LogbuchView prüft `currentLog?.type` — bei `.pota` lädt sie POTAView statt der Default-Layout. Sidebar-Toggle für "Back to Home" bleibt.

---

## Phasen-Aufteilung 4c

| # | Sub-Phase | Inhalt | Aufwand |
|---|---|---|---|
| **4c-1** | Park-DB-Foundation | PotaParkService + Download + SQLite-Schema + Refresh-Dialog + Lookup-API | 1-2 Sessions |
| **4c-2** | POTA-Session anlegen | LogType.pota, Wizard mit Activator/Hunter + My-Park-Picker, LogbookManager-Hook | 1 Session |
| **4c-3** | POTA-Form + Status-Bar | POTAView, POTAEntryForm, POTAStatusBar, Counter-Badge, ParkPickerSheet | 1-2 Sessions |
| **4c-4** | POTA-Spots-Feed | PotaSpotsService + POTASpotsTab + Click-to-fill (Call+Park+QSY) | 1 Session |
| **4c-5** | ADIF-Export-Erweiterung | SIG/SIG_INFO/MY_SIG-Felder, Multi-Park-Split bei comma-separated | 0.5 Sessions |
| **4c-6** | QSO-Map-Tab (optional) | Reused von History-Tab oder eigene mit Park-Markern | 0.5-1 Session |

**Gesamt:** ~5-7 Sessions.

---

## Reihenfolge-Empfehlung

1. **4c-1** zuerst (Foundation), ohne DB kein POTA
2. **4c-2** als nächstes (Session-Anlegen einrichten)
3. **4c-3** danach (UI nutzbar)
4. **4c-5** kurz mit reinpacken (ADIF, weil günstig zu machen wenn Form steht)
5. **4c-4** Spots-Feed als angenehmes Add-On
6. **4c-6** Map als Polish

---

## Risiken / offene Punkte

- **POTA-CSV-Schema-Drift**: pota.app kann Spalten ändern. → Parser tolerant gegen fehlende/unbekannte Spalten, Fehler bei kritischen Feldern (`reference`, `name`).
- **POTA-API-Rate-Limits**: Spots-Endpoint hat unklare Rate-Limits. 60-Sek-Polling sollte safe sein, falls 429: backoff implementieren.
- **Park-DB-Speicher**: 15 MB CSV → ~25 MB SQLite mit Indices. Akzeptabel in ~/Documents/HAM-Tools/Cache/.
- **Offline-Modus**: erstes-Start ohne Internet → keine POTA-DB. UX: Banner "Bitte Internet verbinden", "Später aktualisieren"-Button.
- **Mehrsprachigkeit**: Park-Namen sind oft englisch, manchmal lokalisiert. Wir nehmen, was im CSV steht.

---

## Out-of-Scope für 4c (kommt später)

- Upload zu pota.app/user/api/upload (das ist Phase 6 zusammen mit LoTW/eQSL/Club Log)
- Activator-Spots posten (zukünftig: "Spotten von hier" Button)
- Park-DB-Updates über App-Update-Mechanismus (statt CSV-Refresh)
- SOTA (das ist Phase 4d, hat eigene Quellen + Workflow)

---

**Erstellt:** 2026-05-12 — HB9HJI + Claude
**Vorlage:** Stil-orientiert an LOGBUCH_PLAN.md / CAT_PLAN.md
