# HAM-Tools — Logbuch + Contest-Modul

**Status:** Brainstorming / Konzept-Phase.
**Architektur-Annahme:** Erst native macOS (SwiftUI + SwiftData/CoreData),
Web-Portierung später dort wo möglich (CAT-Anbindung geht im Browser nicht,
QSO-Erfassung schon).

## Priorisierung (nach Q&A 2026-05-11)

**HB9HJI-Setup:**
- **Migration:** kein bestehendes Log — Start von Null. ADIF-Import bleibt
  wichtig, aber NICHT blockierend für Phase 1 → Phase 2.
- **Contests:** große Internationale (CQ WW, CQ WPX, IARU HF) +
  WAE EU DX (mit QTC-Feature) + Outdoor (SOTA/POTA/WWFF/Field Day).
  → Contest-Modus muss QTC unterstützen + Activator-Mode für SOTA/POTA.
- **CAT:** Icom CI-V + klassische Yaesu/Kenwood/Elecraft. FlexRadio raus.
  → Hamlib-Subprocess als alleinige Strategie (deckt alles ab).
- **Sync:** lokal first. iCloud-Toggle erst später als Settings-Option.

**Daraus abgeleiteter Phasen-Plan:**

| # | Phase | Dauer | Begründung |
|---|---|---|---|
| 1 | QSO-Form + lokale DB + Tabellen-Ansicht | 2–3 Sessions | MVP |
| 2 | ADIF Import/Export + Cabrillo Skelett | 1–2 | Datenaustausch |
| 3 | QRZ.com-Lookup + Geo (Distance/Bearing/Locator) | 1 | sichtbarer Nutzen |
| 4 | **Contest-Mode (CQ WW + CQ WPX + IARU HF)** | 2–3 | erste 3 Templates |
| 4b | **WAE mit QTC** | 1 | spezieller Modus |
| 4c | **SOTA/POTA-Activator** + DX-Cluster-Integration | 1–2 | Outdoor |
| 5 | CAT via Hamlib-Subprocess (Icom + Yaesu/Kenwood) | 2 | Auto-Fill TRX |
| 6 | LoTW + eQSL + Club Log Upload | 2–3 | Konfirmationen |
| 7 | Award-Tracking (DXCC, WAS, IOTA, SOTA, POTA) | 2 | Visualisierung |
| 8 | QSO-Karte + Stats-Dashboard | 1–2 | Sahnehäubchen |
| 9 | iCloud-Sync (CloudKit, optional) | 1–2 | als Settings-Toggle |
| 10 | QSL-Management + Druck | optional |  |
| 11 | Voice/CW-Keyer | optional | nur wenn gewünscht |

**Grob 18–25 Sessions** für ein produktionsreifes Logbuch das alle wichtigen
HB9HJI-Workflows abdeckt. Cabrillo + QTC + SOTA-Activator sind die
"besonderen" Punkte gegenüber generischen Loggern.

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
- [ ] **QSO-Form** mit allen Standard-Feldern
  - Call, RST sent/received, Frequenz/Band, Mode, Datum/Zeit (UTC), Name, QTH,
    Locator, Comment, Operator, Station-Call, Power
  - Auto-Fill aktueller UTC-Zeit + Band aus Frequenz
- [ ] **Local DB** mit SwiftData (CoreData-Nachfolger, schnell + iCloud-ready)
  - QSO-Entity, Indexe auf Call/Date/Band/Mode
  - Lookup-Geschwindigkeit ist kritisch (10.000+ QSOs üblich)
- [ ] **Tabellen-Ansicht** mit Sort + Filter (Datum / Call / Band / Mode / Confirmed)
- [ ] **QSO-Detailansicht** mit Edit + Delete + Duplicate-Warnung
- [ ] **Backup**: Datei-basiert + iCloud-Sync optional (Settings-Toggle)

### Phase 2 — Import/Export
- [ ] **ADIF 3.x Import** (LoTW, eQSL, anderer Logger)
  - Robust gegen Encoding-Probleme
  - Duplicate-Detection beim Import
  - Mapping unbekannter Felder ins Comment
- [ ] **ADIF Export** (gefiltert: Range, Band, Mode, alle, nur unconfirmed …)
- [ ] **CSV Export** für Excel/Numbers-Auswertung
- [ ] **Cabrillo Export** für Contests (siehe Phase 4)
- [ ] **JSON Backup/Restore** für saubere Vollsicherung

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

### Phase 4 — Contest-Modus
- [ ] **Contest-Templates** für bekannte Tests:
  - CQ WW (DX, Multipliers per zone/country)
  - CQ WPX (prefix)
  - IARU HF World Championship
  - ARRL DX, ARRL Sweepstakes
  - SP DX, OK/OM DX, Russian DX
  - WAE (mit QTC!)
  - Field Day (national, ARRL/REF/DARC)
  - SOTA-Activator-Modus / POTA-Activator-Modus
- [ ] **Exchange-Felder pro Contest** dynamisch
- [ ] **Live-Score** (Q × Multiplier, pro Band-Bonus etc.)
- [ ] **Rate Meter** (QSOs/h, letzte 10/60 min)
- [ ] **Duplicate-Check während Contest** (gleicher Call/Band/Mode → roter Flash)
- [ ] **Super Check Partial (SCP)** Database — Auto-Complete-Vorschlag aus
  bekannten Calls beim Tippen
- [ ] **Cabrillo Export** kontestspezifisch (V3 Format)
- [ ] **Run / S&P Toggle** (Run-Mode-Speech-Macros vs Search-and-Pounce)
- [ ] **CW/SSB Macros** (F1–F8 Sendefenster, Variablen wie $MYCALL $RST $NR)

### Phase 5 — CAT / Radio Control
- [ ] **Hamlib / rigctld als Universal-Layer**
  - Subprocess starten + TCP-Verbindung
  - Unterstützt ~200 Rigs out-of-the-box
- [ ] **Direkt-Implementationen** (für Spezial-Features die Hamlib nicht hat):
  - Icom CI-V (Yaesu CAT, Kenwood CAT, Elecraft)
  - FlexRadio SmartSDR API (TCP/JSON)
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
@Model class QSO {
    var id: UUID
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
    var contest: String?              // Contest-ID
    var contestExchange: String?      // sent/received exchange
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

## Geklärte Fragen (2026-05-11)

- [x] **iCloud-Sync:** lokal first, CloudKit als Settings-Toggle (Phase 9).
- [x] **Migration:** kein bestehendes Log — von Null. ADIF-Import in Phase 2.
- [x] **Contests:** CQ WW + CQ WPX + IARU HF (Standard-Multis), WAE mit QTC,
  SOTA/POTA/WWFF + Field Day als Activator.
- [x] **CAT:** Icom CI-V + Yaesu/Kenwood/Elecraft via Hamlib-Subprocess.
  FlexRadio entfällt vorerst.
- [ ] **Audio-Features?** noch offen — Voice-Keyer + CW-Sender. Vorschlag:
  weglassen für MVP, später als Phase 11.

## Noch offene Detail-Fragen

- [ ] Konkrete Icom-Modelle? (für CI-V-Adressen-Voreinstellungen)
- [ ] Antennen-Setup das geloggt werden soll? (Hexbeam, EFHW, vertikal?)
- [ ] Operator: nur HB9HJI oder auch Club-Call / Multi-OP-Sessions?
- [ ] Sprache UI: Deutsch only oder D/E-Toggle?

---

**Quellen für Detail-Recherche:**
- ADIF-Spec: https://adif.org/
- Cabrillo V3: https://wwrof.org/cabrillo/
- LoTW Tech-Docs: https://lotw.arrl.org/lotw-help/
- Hamlib: https://hamlib.github.io/
- Club Log API: https://clublog.freshdesk.com/support/solutions/articles/3000027450
- SwiftData Doku: https://developer.apple.com/documentation/swiftdata
