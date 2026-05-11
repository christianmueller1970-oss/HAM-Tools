# HAM-Tools — Logbuch + Contest-Modul

**Status:** Brainstorming / Konzept-Phase.
**Architektur-Annahme:** Erst native macOS (SwiftUI + SwiftData/CoreData),
Web-Portierung später dort wo möglich (CAT-Anbindung geht im Browser nicht,
QSO-Erfassung schon).

## Priorisierung (nach Q&A 2026-05-11, revidiert)

**Kern-Architektur — "Multi-Log statt Mega-Log":**

Beim Anlegen einer neuen Logsession wählt der User den **Log-Typ**:

| Log-Typ | Workflow | Spezial-Export |
|---|---|---|
| **Standard-Log** | Normales Tages-/Lebens-Log, beliebige Felder | ADIF |
| **Contest-Log** | Contest-Template + Exchange + Live-Score | **Cabrillo V3** |
| **POTA-Session** | Park-Referenz, Aktivierungs-/Hunter-Modus | ADIF mit POTA-Feldern (SIG/SIG_INFO) |
| **SOTA-Session** | Summit-Referenz, Aktivierungs-/Chaser-Modus | ADIF mit SOTA-Feldern + SOTA-CSV |

Jede Session ist ein **eigenes Log-Objekt** (`Log`-Entity) mit eigenen QSOs.
Ein Standard-Log läuft "ewig" (mein Lebens-Log), Contest-/POTA-/SOTA-Sessions
sind kurz und in sich abgeschlossen. Über alle Logs hinweg gibt es ein
**Master-Index** für Award-Tracking + Duplicate-Check.

**HB9HJI-Setup:**
- **Migration:** kein bestehendes Log — Start von Null. ADIF-Import bleibt
  wichtig, aber NICHT blockierend für Phase 1 → Phase 2.
- **Contests:** **ALLE gängigen Contests** als ladbare Templates
  (CQ WW / WPX / IARU / ARRL DX / WAE mit QTC / Field Day national /
  Russian DX / SP / OK-OM / IARU R1 UHF/SHF / VHF Marconi etc.).
  Templates kommen aus einer JSON-Definition (`contests.json`) die per Update
  erweitert werden kann, ohne App-Rebuild.
- **POTA + SOTA als Fokus-Modi:** eigene UI-Modi mit Park-/Summit-Referenz,
  Activator/Hunter-Toggle, P2P-Erkennung (Park-to-Park, Summit-to-Summit),
  Activation-Status (10-QSO-Schwelle bei POTA, 4 bei SOTA).
- **CAT:** Hamlib-Subprocess als Universal-Layer (~200 Rigs out-of-the-box).
  **Architektur muss offen für Zukunft sein:** TRX-Profile in der DB, neue
  Rigs ohne Code-Änderung anlegbar. Konkret heute: Icom IC-7300/705/9700,
  klassische Yaesu/Kenwood/Elecraft — morgen alles was Hamlib spricht.
- **Sprache:** **Deutsch + Englisch** (i18n-Setup von Anfang an, sonst wird
  Nach-Migration teuer). Schweizer + deutsche + österreichische User lesen
  beides, internationale POTA-/SOTA-Hunter wollen EN.
- **Sync:** lokal first. iCloud-Toggle erst später als Settings-Option.

**Daraus abgeleiteter Phasen-Plan:**

| # | Phase | Dauer | Begründung |
|---|---|---|---|
| 1 | QSO-Form + Log-Entity (Standard) + lokale DB + i18n-Setup (DE/EN) | 3–4 Sessions | MVP, ein Log-Typ als Anfang |
| 2 | ADIF Import/Export pro Log | 1–2 | Datenaustausch |
| 3 | QRZ.com-Lookup + Geo (Distance/Bearing/Locator) | 1 | sichtbarer Nutzen |
| 4 | **Contest-Engine: Template-System aus `contests.json` + alle gängigen Tests** | 3–4 | Generisch statt fest verdrahtet |
| 4b | **Cabrillo V3 Export** + WAE-QTC-Spezialfall | 1–2 | Einreichungsfähig |
| 4c | **POTA-Modus** (Park-DB, Activator/Hunter, P2P, 10-QSO-Aktivierung) | 2 | Fokus-Feature |
| 4d | **SOTA-Modus** (Summit-DB, Activator/Chaser, S2S, 4-QSO-Aktivierung) | 2 | Fokus-Feature |
| 5 | CAT via Hamlib-Subprocess + erweiterbare TRX-Profile in DB | 2–3 | Auto-Fill, offen für Zukunft |
| 6 | LoTW + eQSL + Club Log + POTA-Upload (pota.app) + SOTA-Upload (sotadata.org.uk) | 3–4 | Konfirmationen + Activator-Logs |
| 7 | Award-Tracking (DXCC, WAS, IOTA) + **POTA/SOTA-Awards prominent** | 2 | Visualisierung |
| 8 | QSO-Karte + Stats-Dashboard (alle Logs aggregiert) | 1–2 | Sahnehäubchen |
| 9 | iCloud-Sync (CloudKit, optional) | 1–2 | als Settings-Toggle |
| 10 | QSL-Management + Druck | optional |  |
| 11 | Voice/CW-Keyer | optional | nur wenn gewünscht |

**Grob 22–30 Sessions** für ein produktionsreifes Logbuch das den
HB9HJI-Workflow plus POTA/SOTA-Outdoor + beliebige Contests abdeckt.
Das Multi-Log-Modell + die contests.json-Engine sind die "besonderen"
Architektur-Punkte gegenüber generischen Loggern.

---


**Inspirationen / Referenz-Tools:**
- [MacLoggerDX](https://www.dogparksoftware.com/MacLoggerDX.html) — der Klassiker
  auf macOS, Multi-Radio, Live-Spot-Map, eingebaute Audio, sehr feature-reich
- [Aether (DL2RUM)](https://www.dl2rum.de/) — moderne SwiftUI-App, schick,
  iCloud-Sync, schöne Award-Visualisierungen
- N1MM+, DXLog, WriteLog (Contest-Standards, Windows)
- TR4W (Linux-Contest), TQSL (LoTW-Tool)
- Cloudlog (selbstgehostet, Web)

---

## Phasen-Vorschlag

### Phase 1 — QSO-Erfassung & Lokale Datenbank
- [ ] **Log-Auswahl-UI beim Start**:
  - "Neues Log anlegen" mit Typ-Picker (Standard / Contest / POTA / SOTA)
  - Liste vorhandener Logs (Name, Typ, Anzahl QSOs, letztes Datum)
  - Standard-Log "Lebens-Log" wird beim ersten Start automatisch angelegt
- [ ] **Log-Entity** (Container für QSOs, eigener Typ + Metadaten)
  - Felder: id, name, type, startDate, endDate, contestID?, potaRef?, sotaRef?,
    notes, createdAt
- [ ] **QSO-Form** mit allen Standard-Feldern
  - Call, RST sent/received, Frequenz/Band, Mode, Datum/Zeit (UTC), Name, QTH,
    Locator, Comment, Operator, Station-Call, Power
  - Auto-Fill aktueller UTC-Zeit + Band aus Frequenz
  - QSO ist immer Teil genau eines Logs (Foreign Key)
- [ ] **Local DB** mit SwiftData (CoreData-Nachfolger, schnell + iCloud-ready)
  - Log-Entity + QSO-Entity, Indexe auf Call/Date/Band/Mode + logID
  - Lookup-Geschwindigkeit ist kritisch (10.000+ QSOs üblich)
- [ ] **Tabellen-Ansicht** pro Log mit Sort + Filter (Datum / Call / Band / Mode / Confirmed)
- [ ] **QSO-Detailansicht** mit Edit + Delete + Duplicate-Warnung (innerhalb des Logs)
- [ ] **Backup**: Datei-basiert + iCloud-Sync optional (Settings-Toggle)
- [ ] **i18n-Setup von Anfang an** (DE + EN)
  - SwiftUI `LocalizedStringKey` + `Localizable.xcstrings`
  - Sprach-Toggle in Settings (Default: Systemsprache)
  - String-Konstanten konsequent außen halten, kein Inline-Deutsch

### Phase 2 — Import/Export
- [ ] **ADIF 3.x Import** in beliebiges Log (LoTW, eQSL, anderer Logger)
  - Robust gegen Encoding-Probleme
  - Duplicate-Detection beim Import
  - Mapping unbekannter Felder ins Comment
- [ ] **ADIF Export** (gefiltert: Range, Band, Mode, alle, nur unconfirmed …)
  - Pro Log oder Log-übergreifend (für DXCC-Submission)
  - **Log-Typ-spezifisch:**
    - Standard-Log: generisches ADIF 3.x
    - POTA-Session: ADIF mit `MY_SIG=POTA`, `MY_SIG_INFO=<Park-Ref>`,
      `SIG=POTA` für Park-to-Park-QSOs, ready for pota.app-Upload
    - SOTA-Session: ADIF mit SOTA-Feldern + zusätzlich SOTA-CSV-Export
      (Format für sotadata.org.uk: V2-CSV-Schema)
    - Contest-Log: ADIF + Cabrillo (siehe Phase 4b)
- [ ] **CSV Export** für Excel/Numbers-Auswertung
- [ ] **JSON Backup/Restore** für saubere Vollsicherung (alle Logs)

### Phase 3 — Online-Integration
- [ ] **QRZ.com Lookup** (XML-API mit Abo, Free-Tier-Fallback)
  - Name, QTH, Country, Locator, Image, Bio
  - Lokaler Cache pro Call (TTL 30 Tage)
- [ ] **Callbook Lookup alternativ**: HamQTH, qrzcq.com
- [ ] **LoTW (Logbook of the World)**
  - tqsl-CLI als Backend (lokal installiert) oder direkte Signing-Library
  - QSO-Sign + Upload + Status-Pull
  - LoTW-Status pro QSO im Log (sent / confirmed / nothing)
- [ ] **eQSL**: Upload via XML + Inbox-Pull
- [ ] **Club Log**: Real-time Upload + DXCC-Stats
- [ ] **HRDLog** (klassischer Online-Service)
- [ ] **POTA-Upload** (pota.app API)
  - Activator-Log nach Aktivierung mit einem Klick einreichen
  - ADIF mit MY_SIG/MY_SIG_INFO direkt akzeptiert
- [ ] **SOTA-Upload** (sotadata.org.uk)
  - SOTA-CSV V2 + ADIF-Variante
  - Activator + Chaser separat

### Phase 4 — Contest-Engine (generisch, Template-getrieben)
- [ ] **Contest-Definitions-Datei** `contests.json` im App-Bundle
  - JSON-Schema pro Contest: id, name, sponsor, period, exchange-fields[],
    scoring (QSO-points pro Band/Continent), multiplier-rules,
    cabrillo-template-block
  - Beim App-Start in DB laden, User kann zusätzlich eigene Templates
    importieren (für seltene/lokale Tests)
  - **Updates ohne App-Rebuild** möglich (neue contests.json per
    Auto-Download oder als Settings-Import)
- [ ] **Mitgelieferte Contest-Templates** (Startset):
  - Major DX: CQ WW (CW/SSB/RTTY), CQ WPX (CW/SSB), IARU HF, ARRL DX, WAE (mit QTC)
  - Regional: SP DX, OK/OM DX, Russian DX, REF, DARC WAG, HB-Contest
  - VHF/UHF: IARU R1 VHF/UHF/SHF, Marconi, Helvetia VHF
  - Sprint/Mini: NA Sprint, CWops Mini-Test, FOC Marathon
  - Field Day national: ARRL FD, REF FD, DARC FD, IARU FD
  - User-Forderung: "alle die es gibt" → Template-Liste mit Auto-Update-Quelle
    (vorgeschlagen: GitHub-Repo `hamtools/contests`)
- [ ] **Exchange-Felder pro Contest** dynamisch (aus Template generiert)
- [ ] **Live-Score** (Q × Multiplier, pro Band-Bonus etc., aus Scoring-Rules)
- [ ] **Rate Meter** (QSOs/h, letzte 10/60 min)
- [ ] **Duplicate-Check während Contest** (gleicher Call/Band/Mode → roter Flash)
- [ ] **Super Check Partial (SCP)** Database — Auto-Complete-Vorschlag aus
  bekannten Calls beim Tippen
- [ ] **Run / S&P Toggle** (Run-Mode-Speech-Macros vs Search-and-Pounce)
- [ ] **CW/SSB Macros** (F1–F8 Sendefenster, Variablen wie $MYCALL $RST $NR)

### Phase 4b — Cabrillo V3 Export + WAE-QTC
- [ ] **Cabrillo V3 Generator** aus Contest-Log
  - Header (CALLSIGN, CATEGORY-OPERATOR/POWER/MODE/BAND, CLAIMED-SCORE etc.)
  - QSO-Zeile passend zum Contest-Template
  - Per-Contest-Validation (Pflichtfelder gesetzt? Score plausibel?)
- [ ] **WAE-QTC-Spezialfall**: QTC-Eingabemaske + QTC-Reporting im Cabrillo

### Phase 4c — POTA-Modus (Parks On The Air)
- [ ] **POTA-Park-Datenbank** offline (CSV-Import von pota.app oder Live-Sync)
  - Park-Ref (z.B. HB-0123), Name, Locator, Geo, Park-Typ
- [ ] **POTA-Log-Anlage**:
  - Activator vs. Hunter (Park-to-Park ist beides)
  - Aktivierungs-Park-Ref oben gesetzt (für Activator)
  - QSO-Form schlank: Call, RST sent/received, Park-Ref des Partners (wenn P2P)
- [ ] **Park-to-Park-Erkennung**: Wenn Gegenstation auch im POTA-Cluster
  spotted ist → Park-Ref vorgeschlagen
- [ ] **Aktivierungs-Status-Anzeige**: "X/10 QSOs für Aktivierung" Live-Counter
- [ ] **Multi-Park-Aktivierung** (n-fers): wenn der Standort mehrere Parks deckt
- [ ] **Export ADIF mit POTA-Feldern** + One-Click-Upload zu pota.app (Phase 6)

### Phase 4d — SOTA-Modus (Summits On The Air)
- [ ] **SOTA-Summit-Datenbank** offline (CSV von sotadata.org.uk)
  - Summit-Ref (z.B. HB/BE-001), Name, Locator, Höhe, Punkte, Aktivierungszone
- [ ] **SOTA-Log-Anlage**:
  - Activator vs. Chaser (S2S ist beides)
  - Aktivierungs-Summit-Ref oben gesetzt (für Activator)
- [ ] **Summit-to-Summit-Erkennung** über RBN/SOTAwatch-Spots
- [ ] **Aktivierungs-Status**: "X/4 QSOs für Aktivierung" + Activator-Punkte-
  Vorschau (saisonaler Bonus Winter)
- [ ] **SOTA-CSV-Export** im sotadata.org.uk-Format (V2)
- [ ] **ADIF mit SOTA-Feldern** als Alternative

### Phase 5 — CAT / Radio Control (erweiterbar)
- [ ] **Hamlib / rigctld als Universal-Layer**
  - Subprocess starten + TCP-Verbindung
  - Unterstützt ~200 Rigs out-of-the-box → deckt jetzt + zukünftig fast alles ab
- [ ] **TRX-Profil-Tabelle in der DB** (offene Architektur):
  - Felder: name, rigID (Hamlib-Modell-Nummer), port, baudrate, civAddress (Icom),
    pollInterval, notes, isDefault
  - User legt neue Rigs ohne Code-Änderung an
  - Vor-Profile mitgeliefert: IC-7300 (rig=3073, addr=0x94, 115200),
    IC-705 (rig=3085, addr=0xA4), IC-9700 (rig=3081, addr=0xA2),
    FT-991A, TS-590S, K3 — als Inspiration, nicht hart codiert
- [ ] **Direkt-Implementationen** als Fallback (Spezial-Features die Hamlib
  nicht hat): Icom CI-V Stack als eigene Swift-Implementation für Sub-RX,
  Memories, Band-Stacking
- [ ] **Auto-Fill aus Rig**: Frequenz, Mode, Band, Power → in QSO-Form bei Submit
- [ ] **PTT-Control** (HW-PTT via DTR/RTS oder VOX)
- [ ] **Multi-Radio** Setup (Logger entscheidet aus welchem TRX QSO kommt)
- [ ] **CAT-Polling-Frequenz** konfigurierbar (Default 250 ms)

### Phase 6 — Award-Tracking
- [ ] **DXCC** Visualisierung
  - Pro Band/Mode: worked vs confirmed
  - Karte (Leaflet/MapKit) mit Country-Färbung
  - Most Wanted Liste (aus Club Log generiert)
- [ ] **WAS** (Worked All States) für US-Operator
- [ ] **WAC** (Worked All Continents)
- [ ] **WPX** (Prefixes worked, hilfreich für CQ WPX)
- [ ] **IOTA** (Islands On The Air)
- [ ] **SOTA / POTA / WWFF / GMA / HEMA** (Park/Berg-Aktivitäten)
  - Direkt verlinkt mit aktuell laufenden Spots aus unserem DX-Cluster
- [ ] **Diplome regional**: HB-Diplom-Programme, DLD, Distrikt-Diplome
- [ ] **ATNO-Live-Erkennung** im DX-Cluster:
  - Spot kommt rein → Cluster prüft Log → "ATNO!" / "New on band" / "Already worked"

### Phase 7 — Integration ins HAM-Tools-Ökosystem
- [ ] **QTH-Locator-Verknüpfung**: Distance/Bearing auto-berechnet aus
  QTH-Locator-Feld
- [ ] **Solar-Daten beim QSO speichern** (SFI/Kp/A vom DX-Cluster-Panel)
  → später Korrelations-Auswertungen (welche Band-Bedingungen waren günstig)
- [ ] **DX-Cluster Click-to-Log**: Spot anklicken → QSO-Form vorausgefüllt
- [ ] **Antennen-Verwaltung**: Liste eigener Antennen, pro QSO welche genutzt
- [ ] **Bandplan-Awareness**: warnt wenn QSO außerhalb Lizenz-Range
- [ ] **Smith-Chart / Anpassnetzwerk** weiterhin separat — kein direkter Logger-
  Bezug, aber Cross-Linking sinnvoll

### Phase 8 — Visualisierungen
- [ ] **QSO-Karte** (MapKit) mit allen Verbindungen als Linien Home → DX
  - Filter nach Band/Mode/Datum
  - Heatmap-Modus für DX-Häufung
- [ ] **Statistik-Dashboard**
  - QSOs pro Band/Mode/Jahr
  - Best DX / längste Verbindungen
  - Operator-Aktivität über Zeit
- [ ] **CQ-Zonen / ITU-Zonen** Karte mit Status

### Phase 9 — QSL-Management
- [ ] **QSL-Status** pro QSO: Bureau-out, Direct-out, LoTW-Status, eQSL-Status
- [ ] **QSL-Label-Druck** (Avery-Formate, eigene Layouts)
- [ ] **QSL-Card-Druck** (eigenes Template mit eigener Antenne, Foto, etc.)
- [ ] **Routing-Hinweise**: QRZ-Manager-Liste, OQRS, ClubLog-OQRS-Buttons
- [ ] **Bureau-Tracking**: was wartet auf nächsten Bureau-Versand

### Phase 10 — Audio / Voice / CW
- [ ] **Voice-Keyer**: aufgenommene WAV-Sätze per F-Tasten senden (für Contest)
- [ ] **CW-Macros** Plain-Text → CW per CAT-Keyer oder Audio-Out
- [ ] **QSO-Audio-Recording** (optional, datenschutz-relevant!)
- [ ] **WSJT-X-Bridge**: ADIF-Pull aus FT8/FT4 Logs

---

## Datenmodell-Skizze (SwiftData)

```swift
enum LogType: String, Codable {
    case standard       // Lebens-Log, dauerhaft
    case contest        // ein Contest-Wochenende
    case pota           // POTA-Aktivierungs- oder Hunter-Session
    case sota           // SOTA-Aktivierungs- oder Chaser-Session
}

@Model class Log {
    var id: UUID
    var name: String                  // "Lebens-Log", "CQ WW CW 2026", "POTA HB-0123 11.05."
    var type: LogType
    var startDate: Date
    var endDate: Date?
    // Typ-spezifisch:
    var contestID: String?            // Referenz in contests.json
    var contestCategory: String?      // "SOAB HP", "M/S" etc.
    var potaParkRef: String?          // "HB-0123" (Activator-Park)
    var sotaSummitRef: String?        // "HB/BE-001" (Activator-Summit)
    var role: String?                 // "activator" | "hunter" | "chaser" | nil
    var notes: String?
    var createdAt: Date
    // Beziehung:
    @Relationship(deleteRule: .cascade, inverse: \QSO.log) var qsos: [QSO]
}

@Model class QSO {
    var id: UUID
    var log: Log                      // welches Log gehört das QSO
    var call: String                  // Indexed
    var datetime: Date                // Indexed (UTC)
    var frequency_mhz: Double
    var band: String                  // "20m", "40m" …
    var mode: String                  // "SSB", "CW", "FT8", …
    var rstSent: String
    var rstReceived: String
    var name: String?
    var qth: String?
    var locator: String?              // Maidenhead 6+ char
    var country: String?              // DXCC entity
    var continent: String?            // EU/AS/NA/SA/AF/OC/AN
    var cqZone: Int?
    var ituZone: Int?
    var comment: String?
    var operatorCall: String?
    var stationCall: String?          // wenn Multi-OP
    var power_w: Double?
    var antenna: String?
    var contest: String?              // Contest-ID (redundant zu log.contestID, hilft Queries)
    var contestExchange: String?      // sent/received exchange
    // POTA/SOTA pro QSO (für Park-to-Park / Summit-to-Summit + Hunter-Mode):
    var myPotaRef: String?            // mein Park (Activator)
    var myPotaRefs: String?           // mehrere bei n-fers, komma-sep
    var theirPotaRef: String?         // Park-to-Park: Park der Gegenstation
    var mySotaRef: String?            // mein Summit (Activator)
    var theirSotaRef: String?         // Summit-to-Summit: Summit der Gegenstation
    var theirSotaPoints: Int?         // SOTA-Punkte (Chaser-Score)
    var qslSentDate: Date?
    var qslSentVia: String?           // "bureau", "direct", "lotw", "eqsl"
    var qslReceivedDate: Date?
    var qslReceivedVia: String?
    var lotwSent: Bool
    var lotwConfirmed: Bool
    var eqslSent: Bool
    var eqslConfirmed: Bool
    var clublogSent: Bool
    // Solar conditions at QSO time
    var sfi: Int?
    var kIndex: Double?
    var aIndex: Double?
    // Geo
    var distanceKm: Double?
    var bearingDeg: Double?
    // Meta
    var createdAt: Date
    var modifiedAt: Date
}

@Model class StationProfile {
    var name: String        // "HB9HJI Home"
    var call: String        // "HB9HJI"
    var operatorName: String
    var qth: String
    var locator: String
    var country: String     // "Switzerland"
    var antennas: [String]  // Bezeichner für Antennen
    var isDefault: Bool
}

@Model class Antenna {
    var name: String        // "Hexbeam @ 12m"
    var description: String
    var antennenSimModelJSON: String? // Link in unseren AntennenSim
}
```

---

## Web-Portierung — Abschätzung

| Feature | Native | Web | Anmerkung |
|---|---|---|---|
| QSO-Erfassung + lokale DB | ✓ SwiftData | ✓ IndexedDB | machbar |
| ADIF Import/Export | ✓ | ✓ | machbar |
| Cabrillo Export | ✓ | ✓ | machbar |
| QRZ.com Lookup | ✓ | ⚠ CORS | Backend-Proxy nötig |
| LoTW Upload | ✓ tqsl-CLI | ✗ | Cert-Signing braucht lokales Programm |
| **CAT / Hamlib** | ✓ | ✗ | Serial-Port nicht im Browser |
| Contest-Mode + Live-Score | ✓ | ✓ | machbar |
| Award-Tracking | ✓ | ✓ | machbar |
| Karten | ✓ MapKit | ✓ Leaflet (haben wir schon im QTH) | machbar |
| Audio-Recording / Voice Keyer | ✓ | ✗ | Browser-Permissions begrenzt |
| iCloud-Sync | ✓ CloudKit | ✗ | Plattform-spezifisch |

→ **Web-Portierung möglich für ~70% der Features**, aber das "Killer-Set"
(CAT-Steuerung, LoTW, Audio) bleibt nativ. Vorschlag: nativ first, dann
QSO-Erfassung + Award-Tracking + ADIF als Web-Read-only-Variante anbieten
(Logs anschauen, Stats checken, ADIF-Konverter), aber loggen + contest IMMER
im Native-Client.

---

## Erste Schritte — wenn wir loslegen

1. **Phase 1 + 2** (QSO-Form + DB + ADIF I/O) als MVP — ohne Online-Features,
   ohne CAT, ohne Contest. Funktionierendes Logbuch das ADIF importieren kann
   und QSOs eintragen lässt. ~3–5 Sessions.
2. Dann Online (Phase 3): QRZ-Lookup zuerst (sofort sichtbarer Nutzen),
   dann LoTW.
3. Dann Contest (Phase 4): startet als isoliertes Modul, später integriert.
4. CAT (Phase 5) parallel zur Reife — Hamlib-Subprocess ausprobieren.
5. Award-Tracking + Visualisierungen (6/8) am Schluss als "Sahnehäubchen".

---

## Geklärte Fragen (2026-05-11, finale Runde)

- [x] **iCloud-Sync:** lokal first, CloudKit als Settings-Toggle (Phase 9).
- [x] **Migration:** kein bestehendes Log — von Null. ADIF-Import in Phase 2.
- [x] **Multi-Log-Modell:** beim Anlegen wählt User Log-Typ — **Standard,
  Contest, POTA, SOTA**. Jede Session ist ein eigenes Log. Standard-Log
  "Lebens-Log" ist dauerhaft.
- [x] **Contests:** **alle gängigen Tests** — über erweiterbares Template-
  System `contests.json` (Auto-Update-fähig, keine hart codierte Liste).
  Cabrillo-V3-Export pro Contest + WAE-QTC-Spezialfall.
- [x] **POTA + SOTA als Fokus-Modi:** eigene UI mit Park-/Summit-DB,
  Activator/Hunter-Toggle, P2P-/S2S-Erkennung, Aktivierungs-Counter
  (10/4 QSOs), Export ins pota.app- bzw. sotadata.org.uk-Format.
- [x] **CAT:** Hamlib-Subprocess + **TRX-Profil-Tabelle in DB** (offen für
  Zukunft, neue Rigs ohne Code-Änderung). Mitgelieferte Voreinstellungen:
  IC-7300, IC-705, IC-9700, FT-991A, TS-590S, K3 — User kann frei
  ergänzen.
- [x] **Antennen-Pool:** **EFHW** (HF) und **VHF/UHF separat**
  (Yagi/Vertikal für 2m/70cm). Hexbeam ergänzt nach Juni-Aufbau.
  Antennen-Editor ist flexibel, User legt seine Antennen selbst an.
- [x] **Operator:** **Multi-OP** — StationProfile bekommt Liste aller
  Operator-Calls, pro QSO wählbar (Field Day / Club).
- [x] **Sprache:** **Deutsch + Englisch** (i18n von Anfang an) —
  Localizable.xcstrings, Sprach-Toggle in Settings, Default = Systemsprache.
  Format-Felder (ADIF/Cabrillo) bleiben sowieso EN.
- [x] **Audio-Features:** **nicht prio** — kein Voice-/CW-Keyer. Phase 10/11
  bleibt im Plan als optional-später.

**Damit ist die Konzept-Phase abgeschlossen — startklar für Phase 1.**

---

**Quellen für Detail-Recherche:**
- ADIF-Spec: https://adif.org/
- Cabrillo V3: https://wwrof.org/cabrillo/
- LoTW Tech-Docs: https://lotw.arrl.org/lotw-help/
- Hamlib: https://hamlib.github.io/
- Club Log API: https://clublog.freshdesk.com/support/solutions/articles/3000027450
- POTA API + Park-DB: https://docs.pota.app/
- SOTA Datenbank: https://www.sotadata.org.uk/
- SwiftData Doku: https://developer.apple.com/documentation/swiftdata
- SwiftUI Localization (xcstrings): https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
