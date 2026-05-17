# Changelog

Alle nennenswerten Änderungen am Projekt werden hier dokumentiert.  
Format angelehnt an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

---

## [1.8.9] — 2026-05-17

### Live-ATNO-Markierung im DX-Cluster

Pro Cluster-Spot eine kleine Pille links vom Call:
- rot **»ATNO«** — Country noch nie geloggt
- orange **»NEW BAND«** — Country gearbeitet, aber nicht auf diesem Band
- gelb **»NEW MODE«** — Country+Band gearbeitet, aber nicht in diesem Mode
- gearbeitet → kein Marker

`LogbookManager.recomputeAwards` leitet die Worked-Sets aus dem
bestehenden `DXCCAccumulator` ab (bands/modes pro Country) — kein
Extra-Scan, Lookup ist O(1) pro Spot. Sichtbar nur im Standard-DX-Log
+ DX-Cluster-Pop-up; Contest und Outdoor-Programme blenden ATNO aus
(dupe/mult-Färbung bzw. Ref-Match dominieren dort).

### Bandplan-Live-Awareness in allen QSO-Forms

Pille in der QSO-Status-Bar zeigt sofort beim Loggen, ob Frequenz +
Mode IARU-R1-konform sind:
- grün **»im Band«** — Sub-Segment passt
- orange **»falsches Subsegment«** — z.B. SSB im CW-Bereich
- rot **»außerhalb Amateurfunkband«**

`BandplanChecker` nutzt die existierende `bandplan.json`-Quelle (22
Bänder + Sub-Segmente), Mode-Compatibility-Tabelle ist tolerant
(»alle Sendearten«-Subsegmente lassen alles durch). Eingebunden in
allen sechs QSO-Forms: DX, Contest, POTA, SOTA, WWFF, BOTA. Reagiert
live auf CAT-Frequenzwechsel.

### Club Log scharfgeschaltet

Der von Club Log zugeteilte Application-API-Key (HAM-Tools-spezifisch,
seit 2026 verpflichtend) ist jetzt obfuskiert in der App enthalten
(XOR + Salt in `BuildInfo.swift`). Der `api`-Parameter wird damit
korrekt mitgesendet — nginx-403 vor dem PHP-Layer ist Geschichte. User
brauchen den Key NICHT selbst zu beantragen.

Zusätzlich Form-Encoding-Fix: `CharacterSet.urlQueryAllowed` war zu
lasch für `application/x-www-form-urlencoded` (lässt z.B. `@`
unkodiert), Club Logs nginx-WAF lehnt das mit 403 ab. Jetzt
RFC-3986-strikt: nur ALPHA/DIGIT/-._~ bleiben unkodiert, alles andere
wird %XX-escaped.

### Standard-DX-Log: keine Dupe-Warnung mehr

Im Standard-DX-Log ist es legitim, denselben Call mehrfach zu loggen
(Lebens-Log, Tages-Log, Stammrunde) — die Dupe-Warnung war dort nur
lästig. Programm- und Contest-Logs behalten ihre eigenen Dupe-Regeln
in den jeweiligen EntryForms (POTA-Band-Dupe, SOTA-Call-Band-Mode,
Contest-Multiplier-Logik). `DupeWarning`-Struct + `findDuplicate()` +
zugehöriger `.alert(item:)`-Modifier sind aus `QSOEntryPanel` raus
(toter Code).

---

## [1.8.8] — 2026-05-17

### Outdoor-Programme — Upload-Konformität + Spotting

**ADIF jetzt plattform-konform** für alle vier Outdoor-Programme:
- POTA: `MY_SIG=POTA` + `MY_SIG_INFO` als alleinige sichtbare Tags
  (docs.pota.app verbietet zusätzliche Tags explizit). `MY_POTA_REF` /
  `POTA_REF` wandern in `APP_HAMTOOLS_*` für Re-Import-Roundtrip.
- WWBOTA: `MY_SIG=WWBOTA` + `MY_SIG_INFO` (Komma-Liste laut Guide
  erlaubt), Schema aus wwbota.net/adifguide. `APP_HAMTOOLS_*`-Felder
  bleiben für Roundtrip in unsere App.
- WWFF / SOTA: bereits konform, unverändert.
- Codec-Header-Fix: `PROGRAMVERSION` zieht jetzt `BuildInfo.appVersion`
  dynamisch statt hardcoded "HAM-Tools 1.5" und doppelt den App-Namen
  nicht mehr.

**POTA Multi-Park-Split** beim Export: bei Multi-Park-Hopping schreibt
HAM-Tools automatisch pro Park ein eigenes File mit `MY_SIG_INFO=einzelnem
Park`. Filename `{CALL}@{PARK} YYYYMMDD.adi` — pota.app erkennt das
Pattern beim Upload automatisch.

**SOTA-CSV-V2-Export** für sotadata.org.uk: eigener Toolbar-Button im
SOTA-Log, pro Summit gruppiert + zeit-sortiert (sotadata-Pflicht), S2S
in Spalte 9, Band-Mapping (40m → 7.0MHz). Schließt das Phase-4d-Polish.

**POTA Self-Spot** direkt aus dem Activator-Modus: Button in der POTA-
Status-Bar öffnet ein Sheet mit Vorschau (Call/Park/Frequenz/Mode) +
optionalem Comment. Senden via `api.pota.app/spot/` (anonym, kein Auth-
Token, kein Cognito-SRP — der frühere Auth-Bug betraf nur den Logbook-
Upload). Spot landet im POTA-Cluster, sichtbar für alle Hunter.

### WWBOTA-Anbindung (vorher Stub)

- **api.wwbota.org** als Datenquelle für die Bunker-Referenz-DB
  (vorher: bunkersontheair.com — Stub, kein API).
- **Initial-CSV-Snapshot** (~26.7k Bunker weltweit) im App-Bundle, wird
  beim ersten Start automatisch ingestet. Versionsstand via
  `bundle_snapshot_date`-Meta-Key, App-Updates ziehen neue Snapshots
  nach.
- **`B/`-Präfix-Format** durchgängig korrekt (`B/9A-0001` statt
  `9A-0001`): `programFromRef` strippt den globalen Präfix für
  Awards-Aggregation, Spot-Pattern erkennt mit + ohne Präfix, Service
  normalisiert User-Eingaben.
- Settings-Sektion umgeschrieben auf neue Quelle: prominenter
  „Aktualisieren"-Button für Live-Refresh, CSV-Import bleibt als
  Override.

### Logbuch — Polish

**Callbook-Auto-Fill in Outdoor-Logs komplett** (Bug-Fix): in den
EntryForms für POTA/SOTA/WWFF/BOTA wurden beim QRZ/HamQTH-Lookup
bisher nur der Name ins QSO geschrieben — QTH, GRIDSQUARE, COUNTRY,
CONT, CQZ, ITUZ fielen unter den Tisch. Mit `applyFillingEmpty(to:)`
landen jetzt alle vom Service gelieferten Felder im QSO (überschreibt
keine vom User selbst getippten Werte).

**Hopping-Live-Lookup beim Log-Anlegen**: das »Weitere Parks/Summits/
Refs/Bunker (Hopping)«-Feld in den vier New-Sheets zeigt jetzt pro
Komma-Eintrag eine eigene Zeile mit Programm-Namen + Detail (Land/
Region/Höhe/Kategorie/Bunker-Typ je nach Programm). Vorher nur
Status-Icon mit Namen im Tooltip.

**Multi-File-Alert** bei Export: konsolidierter Alert-Pfad in der
LogContextBar auf moderne SwiftUI-Alert-API. Bei Multi-File-Output
zeigt der Alert die Filenamen und bietet „Im Finder zeigen" für alle.

### UI

**Bandplan als eigenes Fenster** statt Logbuch-Sub-Tab: zu wenig
Höhe im Sub-Tab für die langen Band-Listen. Jetzt Single-Instance-
Pop-up über *Fenster → Bandplan-Fenster* (⌘⇧P), Default 980×760.

---

## [1.8.7] — 2026-05-16

### Logbuch — Phase 6 Schritt 3 (Club Log)
**Live-Upload** an clublog.org: pro QSO automatisch beim Log-QSO (`realtime.php`)
oder per Bulk via Rechtsklick-Menü „N QSOs an Club Log hochladen" (`putlogs.php`).
Credentials kommen aus *Einstellungen → Lookup & Upload → Club Log*: Email +
Application Password (kein Login-Passwort — Club Log Settings → Application
Passwords). Den eigentlichen App-API-Key (seit 2026 von Club Log gefordert)
bringt HAM-Tools obfuskiert in der App mit — User müssen den nicht selbst
anfragen. Auto-Upload greift nur in Standard-Logs (DX); Outdoor-Programme nutzen
weiterhin ihre eigenen Pfade. Erfolgreich hochgeladene QSOs werden lokal mit
`clublogSent = true` markiert (taucht im QSL-Tab und in der Tabellen-Übersicht
auf).

**Firewall-Schutz**: Club Log sperrt die Client-IP nach wiederholten
4xx-Fehlern. Bei Auth-Fail wird der Auto-Upload-Toggle deshalb automatisch
deaktiviert, der User bekommt einen klaren Hinweis statt eines stillen
Retry-Loops. Auch fehlender API-Key wird clientseitig abgefangen — kein
Request geht raus, bevor er hinterlegt ist.

### Logbuch — Phase 4d Closing (SOTA)
**Activator-Punkte-Card** im Awards-Tab → SOTA: zeigt die Summe aller gültigen
Aktivierungen (≥ 4 QSOs auf demselben Summit / UTC-Tag) inklusive Winterbonus
nach saisonalen Regeln (Nordhalbkugel: 1. Dezember – 15. März, Südhalbkugel:
1. Juni – 15. September). Multi-Summit-Hopping: jeder Summit in der
Komma-Liste zählt eigene 4-QSO-Schwelle. Damit ist die Phase-4d-Funktionalität
komplett — Upload zu sotadata.org.uk kommt mit Phase 6.

### Update-System
- macOS-Min-Version-Check vor dem Anbieten eines Updates: numerischer
  Version-Compare über `OperatingSystemVersion.major/minor/patch` (vorher
  String-Vergleich — bei „10.15" vs „10.9" hätte der lexikografisch das
  Falsche gesagt).
- Inkompatible Updates: Download-Button im Update-Sheet wird **deaktiviert**;
  Warning-Text erklärt warum. Das Sheet erscheint trotzdem, damit User wissen,
  dass es ein Update gibt.

---

## [1.8.6] — 2026-05-16

### Logbuch — Phase 6 Schritt 1 + 2 (QRZ Logbook)
**Live-Upload** an QRZ.com: pro QSO automatisch beim Log-QSO oder per Bulk via
Rechtsklick-Menü „N QSOs an QRZ Logbook hochladen". API-Key kommt aus
*Einstellungen → Lookup & Upload → QRZ.com → Logbook*. Auto-Upload greift nur in
Standard-Logs (DX); Outdoor-Programme (POTA/SOTA/WWFF/BOTA) bleiben außen vor,
weil die ihre eigenen Upload-Pfade haben. Status pro QSO im neuen `QRZ-LB`-
Spalten-Badge (default ausgeblendet): ✓ neu / ✓ schon drin / ⚠ Fehler (klick =
retry). Schema v9 → v10 mit `qrzLogbookStatus`-Spalte.

**Confirmation-Sync**: QSL-Tab hat neuen Button „QRZ-Bestätigungen abrufen". Holt
paginiert (MAX:250 + AFTERLOGID) das komplette QRZ-Logbook, matcht via
Call+Datum+Band+Mode gegen die lokalen QSOs und ergänzt fehlende
LoTW-/eQSL-/Direkt-Bestätigungen *additiv* — lokale manuelle Bestätigungen
bleiben unberührt.

### Logbuch — neue Tabs
- **QSL-Tab** (Briefumschlag, zwischen Memories und History) mit Filter
  Offen/Bestätigt/Alle, Service-Filter (LoTW/eQSL/Club Log/Direkt), Sortierung
  und Doppelklick-Edit.
- **Stats-Dashboard** (Balken-Icon, zwischen Awards und Memories) mit
  4 Kennzahl-Karten (QSOs / Best DX / DXCC / Jahre), 2×2 Charts pro Jahr / Band
  / Mode / Kontinent und zwei Top-Listen (DXCC-Länder, längste DX-Strecken).

### Logbuch — Phase 3-Rest
- **Distance/Bearing pro QSO** automatisch beim Anlegen oder Bearbeiten —
  Haversine + Initial-Bearing aus eigenem QTH-Locator und QSO-Locator.
  Spalten *Distanz (km)* und *Peil (°)* zeigen die Werte. Bulk-Backfill für
  bestehende QSOs via Spalten-Menü → „Wartung → Distanz/Peilung für alle
  QSOs nachrechnen…".
- **QRZ-Profilbild-Cache** persistent in `~/Documents/HAM-Tools/Cache/qrz-images/`
  mit 30-Tage-TTL. Beim zweiten Öffnen erscheint das Bild sofort statt mit
  Lade-Spinner.

### Logbuch — Workflow-Verbesserungen
- **Bulk-Vervollständigen via Rechtsklick** in der QSO-Tabelle: mehrere QSOs
  markieren → „N QSOs aus QRZ/HamQTH vervollständigen". Lookups laufen parallel,
  greifen auf den 30-Tage-Cache zu, befüllen nur leere Felder.
- **ADIF-Import** läuft jetzt asynchron im Hintergrund mit „Importiere…"-Spinner;
  früher blockierte die UI bei großen Dateien (7 MB QRZ-Exports). UTF-8 mit
  ISO-Latin-1-Fallback, klarer Alert bei 0 erkannten QSOs.

### Web/Download
- FAQ-Link auf ältere DMGs lieferte 403 — nginx mit `autoindex on;` ergänzt,
  jetzt steht das Versions-Listing unter `/app/dmg/`.
- Top-Nav „Download" zeigte auf eine veraltete 1.7.1; jetzt auf
  `/app/dmg/latest.dmg` — Symlink wird bei jedem Release automatisch
  nachgezogen (siehe `build-dmg.sh`-Anleitung).

---

## [1.8.2] — 2026-05-14

### Multi-Call-Lizenz + Portabel-Validation (Phase A + B)
Lizenz-Schema akzeptiert mehrere Calls (`calls: [String]`, im Generator
als Komma-Liste eingebbar) — z.B. Privatcall + Club-Call.
`CallValidator.isLicensed` macht **Substring-Match an `/`-Grenzen**:
`HB9HJI` ✓, `DL/HB9HJI` ✓, `HB9HJI/P` ✓, `F/HB9HJI/MM` ✓,
`HB0HJI` ✗ (kein Buchstaben-Drift). 14 Unit-Test-Cases grün.

### Pro-Log-Callsign (Phase C, Schema v7 → v8)
Jedes Log hält eine eigene `usedCallsign`-Spalte. Im NewLogSheet,
NewContestLogSheet und den vier Award-Wizards (POTA/SOTA/WWFF/BOTA)
erscheint das **MyCallField** mit Live-Lizenz-Validation
(grünes Häkchen / orange Warnung). Beim Loggen wird das Pro-Log-Callsign
in jedes QSO als `stationCall` + `operatorCall` geschrieben — leer
lassen ⇒ Fallback auf den Settings-Default. Auch das Standard-Log
(QSOEntryPanel) setzt jetzt diese Felder, vorher nur die Award-Forms.

### Multi-Op-Contest (Phase D, Schema v8 → v9)
NewContestLogSheet bekommt ein zusätzliches Feld **„Operatoren"**
(Komma-Liste, optional). Daraus baut ContestEntryForm einen
**OP-Switcher** rechts in der Header-Bar; Wechsel betrifft das nächste
QSO. Awards-Tab bekommt im Contest-Modus einen neuen Sub-Tab
**„OPs"** mit Pro-Operator-Aufschlüsselung (Tabelle Operator / QSOs /
Anteil, sortiert nach QSO-Zahl). MyCallField bekommt zusätzlich einen
**Quick-Picker** bei Multi-Call-Lizenz — Tap füllt das Eingabefeld vor.

### Lizenz-Generator als App-Bundle (Phase E)
`tools/HAMToolsLicenseGen/build.sh` produziert ein Developer-ID-signiertes
`.app`-Bundle (916 KB, hardened runtime). Drag&Drop nach
`/Applications`, fertig — `swift run` ist nicht mehr nötig.
**Privater Key bleibt extern** unter
`~/Library/Application Support/HAM-Tools License Generator/keypair.json`
(Sicherheits-Pattern; im Bundle wäre er via `strings` extrahierbar).

### Fix: Awards-Tab im Contest sichtbar
LogbookTabBar hatte `.awards` im Contest-Modus komplett ausgeblendet,
damit war der neue OPs-Sub-Tab unerreichbar. Fix: Awards bleibt im
Contest sichtbar; programm-spezifische Maps + Memories bleiben weiter
versteckt.

### Help-Site
Systemvoraussetzungen prominent dokumentiert nach Beta-Tester-Feedback
(User mit macOS 12.7.6). Neue Section in `getting-started`, Warning-Block
in der FAQ, Info-Hinweis auf der Startseite — macOS 14.0 Sonoma ist
Voraussetzung, macOS 12/13 läuft nicht (SwiftUI-APIs).

---

## [1.8.1] — 2026-05-14

### Phase 4e — WWFF (Worldwide Flora & Fauna)
Komplette WWFF-Integration analog POTA/SOTA mit den Programm-Eigenheiten:
**Doppelpfad-Datenquelle** (URL `wwff-cc.org` + manueller CSV-Import via
Datei-Picker — wwff-cc.org war beim Build down, daher fail-safe-Architektur),
NewWWFFLogSheet mit Activator/Hunter + Multi-Reference-Hopping,
WWFFEntryForm mit **44-QSO-Aktivierungs-Counter** (deutlich strikter als
POTA(10) / SOTA(4)), R2R-Erkennung (Reference-to-Reference) mit DB-Lookup,
WWFF-Spots als gefilterter DX-Cluster-Stream (kein offenes WWFF-Spots-API),
WWFF-Map mit Reference-Pins (Leaf-Icon, Pink), Awards-Sub-Tab mit
Activator/Hunter/R2R/Country-Programme-Counter. ADIF schreibt
`MY_SIG=WWFF`, `MY_WWFF_REF`, `WWFF_REF`. **Schema v5 → v6** mit fünf
neuen Spalten (log_meta.wwffRef/Refs + qsos.myWwffRef/Refs/theirWwffRef).

### Phase 4f — BOTA (Bunkers On The Air)
CSV-Import-primärer Pfad weil **kein zentrales öffentliches API** existiert
(bunkersontheair.com nur Stub, GMA kein BOTA-Endpoint). NewBOTALogSheet,
**BOTAEntryForm ohne QSO-Counter** (BOTA hat keine strikten Regeln),
B2B-Erkennung, BOTA-Spots mit Pattern-Match GEGEN die lokale Bunker-DB
(vermeidet Pattern-Konflikte mit POTA/WWFF), BOTA-Map mit Shield-Pins,
Awards-Sub-Tab. Proprietäre `APP_HAMTOOLS_MY_BOTA_REF` ADIF-Felder weil
kein Standard-Tag existiert. **Schema v6 → v7**. `bota_demo.csv` im Repo
mit 15 echten EU-Bunkern als Start-Datenset.

### Outdoor-Sammel-Tab (Phase 4e-0)
QSO-Panel umgebaut von **DX/Contest/POTA/SOTA** (4 Tabs) auf
**DX/Contest/Outdoor** (3 Tabs) mit zweistöckiger Sub-Tab-Bar
POTA/SOTA/WWFF/BOTA. Skaliert auf weitere zukünftige Award-Programme
ohne UI-Überfüllung.

### Testlauf-Polish (User-Bug-Reports)
- **QSO-Tabellen-Spalten** programm-abhängig: SOTA zeigt „Region" + „Their
  Summit", WWFF „Country" + „Their Reference", BOTA „Their Bunker"
- **Bottom-Tab-Bar** im POTA/SOTA/WWFF/BOTA-Modus auf programm-spezifische
  Tabs reduziert (Log, [Programm]-Spots, [Programm]-Map, Awards, Memories)
- **DXClusters-Tab-Label** dynamisch („POTA-Spots" / „SOTA-Spots" / …)
- **WWFF-DNS-Fehler-UX**: CSV-Import-Button hervorgehoben bei Server-Ausfall
- **Awards-Sub-Tab-Picker** im Programm-Modus auf das aktive Programm
  fokussiert
- **Enter** speichert QSO direkt in allen Logging-Forms (statt Cmd+Enter)
- **Update-Check** zeigt Alert auch bei „up to date" / Fehler
- **Helvetia-Contest**: myCanton-Picker in den Station-Settings
- **ContestStatsPanel** Alignment .top (war .center → leerer Bereich oben)

## [1.8.0] — 2026-05-14

### Phase 4d — SOTA (Summits On The Air)
Komplette SOTA-Integration: ~181'000 Summits aus sotadata.org.uk,
NewSOTALogSheet mit Activator/Chaser + Multi-Summit-Hopping,
SOTAEntryForm mit 4-QSO-Counter + Winterbonus-Anzeige (NH: 1.12.–15.03.,
SH: 1.6.–15.9.), S2S-Erkennung, SOTA-Spots-Tab mit Live-Polling aus
api2.sota.org.uk, SOTA-Map mit Summit-Pins + S2S-Indikator, Awards-Sub-Tab
SOTA, ADIF mit MY_SIG=SOTA + MY_SOTA_REF + proprietäre Punkte-Persistenz.
Schema v4 → v5 für sotaSummitRefs/mySotaRefs.

## [1.6.1] — 2026-05-12

### Neu: POTA-Modul (Phase 4c)

Komplette POTA-Integration vom Park-Lookup bis zum pota.app-konformen ADIF-Export. Live mit IC-705 getestet, P2P-QSOs erfolgreich geloggt und Export gegen valide Referenz (HAMRS DA-0005) verifiziert.

#### Park-Datenbank
- **PotaParkService** lädt `all_parks_ext.csv` (~91'000 Parks, ~9 MB) von pota.app und schreibt es in `~/Documents/HAM-Tools/Cache/parks.sqlite`
- Byte-basierter CSV-Parser mit korrekter Behandlung von CRLF-Zeilenenden + escaped quotes (`""`) — 2'256 escaped-quote-Stellen im echten Datensatz erfolgreich verarbeitet
- Settings → Daten → "POTA-Park-Datenbank" mit Status-Anzeige, "Jetzt laden" / "Aktualisieren"-Button, 14-Tage-Refresh-Empfehlung
- Lookup-API: `park(reference:)` für Detail, `search(prefix:)` für Autocomplete

#### POTA-Session-Anlegen
- **NewPOTALogSheet**: Wizard mit Segmented-Picker "Bestehende öffnen / Neue anlegen"
  - "Öffnen": Liste aller bisherigen POTA-Logs mit Name, Park-Ref, QSO-Count, Datum → Klick öffnet
  - "Anlegen": Activator/Hunter-Toggle, bei Activator Park-Autocomplete-Picker mit Live-Suche, Session-Name-Auto-Gen
- POTA-Tab im QSO-Form klickt das Sheet auf, wenn kein POTA-Log aktiv ist

#### POTA-Entry-Form
- **POTAEntryForm**: schlanke Logging-Maske analog Referenz-Bild aus dem POTA-Logger
- Top-Status-Bar: Live-UTC, Frequenz/Band (aus CAT), Mode, Power, Session-Name, eigener Park
- Felder: Their Call, RST/S, RST/R, Their Park (comma-separated für P2P-Hopping), Power, Comments, Notes
- **QRZ-Lookup** mit 600 ms Debounce: bei Eingabe wird Name aus Callbook geladen und grün unter dem Call-Feld angezeigt (nicht zwingend ins Log gespeichert, aber als "Hi John!"-Hilfe)
- **10-QSO-Counter** im Activator-Modus: rot < 10, grün ≥ 10 mit "Aktivierung gültig"-Badge
- Save speichert automatisch myPotaRef, theirPotaRef, OPERATOR + STATION_CALLSIGN aus Settings, Name aus QRZ

#### POTA-Spots Live-Feed
- **PotaSpotsService** pollt `api.pota.app/spot/activator` alle 60 Sek (read-only, kein Upload), tolerant gegen Server-Format-Drift
- **PotaSpotsView**: Card-Grid statt Liste, analog Referenz-Bild
  - Pro Card: Activator @ Park-Ref, Zeit-ago, Frequenz + Mode, locationDesc, Park-Name, Spotter, Comments, Source ("RBN" / "Manual" / etc.)
  - Filter-Bar: Time/Freq-Sort, Band, Mode, Ref-Prefix-Suche
  - "QSY bei Copy"-Toggle: bei aktivem CAT springt der TRX auf die Spot-Frequenz beim Klick auf Copy
- **Copy-Button** füllt Their Call + Their Park automatisch ins POTA-Form via LogEntryBridge
- Bei POTA-Logs ersetzt PotaSpotsView den klassischen DXCluster-Tab unten — bei Non-POTA-Logs bleibt der DX-Cluster wie gehabt (komplett unabhängige Services, keine Interferenz)

#### QSO-Tabelle
- Spalten **Name**, **Country/Locator**, **QSL-Status** default versteckt (per Rechtsklick im Header wieder einblendbar)
- Neue **State**-Spalte: liest aus POTA-Park-DB via `park.locationDesc` → "CH-AG" → "AG"
- Neue **Their Park**-Spalte: theirPotaRef
- Neue **QRZ-Status**-Spalte am Ende: grüner Haken wenn Callbook-Name vorhanden, oranges Fragezeichen sonst — Klick darauf forciert Re-Lookup und speichert den gefundenen Namen

#### ADIF-Export (POTA-konform)
- **QSO_DATE_OFF + TIME_OFF** immer geschrieben (= ON falls keine separate End-Zeit)
- **MY_GRIDSQUARE** aus App-Settings (`qthLocator`) wenn `MY_POTA_REF` gesetzt
- **OPERATOR + STATION_CALLSIGN** aus QSO-Feld oder Fallback auf App-Settings.callsign — pota.app verweigert Upload ohne diese Felder
- LOTW/EQSL-QSL-Status-Felder nur noch geschrieben wenn `Y` (war vorher immer `N` in jeder Zeile, unnötig)
- **Pre-Header-Text raus**: `<ADIF_VER>` jetzt erster Tag (strikt-konform für LoTW / Club Log / eQSL). Log-Name als `APP_HAMTOOLS_LOGNAME` im Header erhalten.
- Verifikation: 4 QSOs aus POTA-CH-0001-Session gegen valide HAMRS-Referenz (DA-0005, eigener Activator-Log vom Februar 2024) Feld-für-Feld geprüft

#### Frontend
- **POTA-Tab** neben DX/Contest im QSO-Entry-Panel
- POTA-Modus rendert POTAEntryForm statt DX-Grid und PotaSpotsView statt DXCluster
- LogEntryBridge ergänzt um `pendingPotaSpot` für POTA-spezifische Form-Prefills

#### Dokumentation
- **POTA_PLAN.md** dokumentiert Architektur, Phasen 4c-1 bis 4c-6, UI-Referenzen, Bundling-Strategie

#### Offen für 1.6.x-Polish (Folge-Patches)
- 4c-6 QSO-Map mit Park-Markern
- Multi-Park-Hopping vollständig durchziehen (`MY_POTA_REF` mit Komma-Liste, ADIF-Splitting)
- POTA-Upload-API direkt aus der App (Phase 6, zusammen mit LoTW/eQSL)
- POTA-Aktivierungs-Statistiken im Awards-Tab

---

## [1.6.0] — 2026-05-12

### Neu: CAT-Anbindung (Phase 5a)

Erstes funktionsfähiges Live-CAT-Modul für IC-7300 / IC-705 / IC-9700 (und 9 weitere Profile vorbereitet) via Hamlib-Subprocess. Frequenz und Mode kommen live vom Funkgerät in die App und werden in `RadioState` gespiegelt.

#### Hamlib-Build-Pipeline
- **`scripts/build-hamlib.sh`** — reproducible Build von Hamlib 4.7.1 als Universal2 (arm64 + x86_64), statisch, `--without-libusb`, Ad-Hoc codesigned mit Hardened Runtime
- Resultat: `vendor/hamlib/rigctld` 22 MB, **truly self-contained** (nur `libSystem` + `libedit` als macOS-Dylibs), keine Third-Party-Dependencies
- `build-dmg.sh` baut Hamlib automatisch falls fehlend und packt `rigctld` in `Contents/Helpers/` des App-Bundles
- Smoke-Test gegen Dummy-Rig grün

#### CAT-Architektur (Sources/HAMRechner/Features/CAT/)
- **`TRXProfile`** + `trx-profiles.json`: Brand/Model/Hamlib-Rig-Number + Werkseinstellungen (Baud, DataBits, StopBits, Parity, Handshake) für 13 Rigs:
  - **Hamlib** Dummy (Test ohne Hardware)
  - **Icom** IC-7300 / IC-705 / IC-9700
  - **Yaesu** FT-991 / FT-857 / FT-817
  - **Kenwood** TS-2000 / TS-590S / TS-480
  - **Elecraft** K3 / KX2 / KX3
- **`CATConfig`**: benannte User-Konfiguration mit allen Verbindungs-Parametern. Mehrere Configs speicherbar (z.B. "Home-IC7300", "Portable-IC705"), beliebig umschaltbar
- **`CATSettings`**: Multi-Config-Store, UserDefaults-persistiert, analog zu ClusterSettingsStore
- **`RigctldProcess`**: Lifecycle des `rigctld`-Subprocess. Bundle-Lookup mit Dev-Fallback auf `vendor/hamlib/rigctld`, ENV-Override, defensiv chmod+x (Google-Drive frisst Exec-Bits). Serial-Parameter via `-C "data_bits=..,stop_bits=..,serial_parity=..,serial_handshake=.."` an rigctld
- **`RigctldClient`**: TCP-Client zu localhost:4532 via URLSessionStreamTask, line-based Protocol für `f`/`m`-Commands. Phase 5b wird `F`/`M` ergänzen
- **`CATController`**: Orchestrator. Connect-Retry-Loop (30 × 150 ms = 4.5 s) für rigctld-Bind-Race, stopInternal-vor-start gegen Orphan-rigctld-Prozesse. Status `disconnected/starting/connected/errored`, Poll-Loop (default 500 ms) spiegelt Frequenz und Mode in `RadioState`. Mode-Mapping Hamlib → UI (USB/LSB → SSB, PKTUSB → DATA, …)

#### Settings-UI (Einstellungen → CAT)
- **Multi-Config-Manager** oben: Aktive Konfig-Picker + "Neu…" + "Löschen", Name-Edit
- **Zwei-Stufen-Radio-Picker**: Hersteller → Modell. Auto-Fill der Werkseinstellungen bei Modell-Wechsel, alle Felder weiterhin editierbar
- **Vollständiger Serial-Editor**: Port (USB-Serial-Discovery via `/dev/cu.*` + Refresh-Button), Baudrate, Datenbits 7/8, Stopbits 1/2, Parität None/Odd/Even, Flusskontrolle None/Hardware/XONXOFF
- **"Werkseinstellungen zurücksetzen"**-Button für Quick-Recovery aus verfiddelten Configs
- **Polling-Intervall** als Slider 200-2000 ms
- **Diagnose-Section** zeigt zuletzt empfangene Frequenz/Mode, bei Fehler auch rigctld-stderr (kopierbar)
- Settings-Fenster resize-fähig (ideal 640 × 860, min 580 × 480), damit alle Sections ohne Scrollen Platz haben

#### Frontend-Integration
- **Klickbarer `CATStatusBadge`** in der Sidebar unten — One-Click-Toggle für schnelles Reconnect nach Fehlern, ohne Settings öffnen zu müssen
- **`RadioControlPanel`** Updates:
  - TRX-Selector zeigt aktive Konfiguration + Radio-Modell bei aktivem CAT (grünes Antennen-Icon), "Kein Radio aktiv" bei Off
  - Frequenz-Anzeige im **Ham-Style MHz.kHz.10Hz** (z.B. `7.164.39 MHz`), Parser akzeptiert sowohl Klassik `7.16439` als auch Ham-Style
  - CAT-Updates spiegeln immer in Display, auch wenn TextField fokussiert ist (CAT ist Wahrheit); Focus wird beim Aktivwerden automatisch freigegeben
- `RadioState`-Instanz wird in `HAMRechnerApp` zentral erzeugt und mit `CATController` geteilt (single source of truth)

#### Dokumentation
- **`CAT_PLAN.md`** dokumentiert Architektur-Entscheidungen, Phasen-Plan (5a/5b/5c/5d), UI-Referenzen, Bundling-Strategie, Test-Strategie, Risiken
- **`hamlog-update-system-spec.md.gdoc`** als Google-Doc-Referenz im Repo

#### Bekannte Einschränkungen / nächste Schritte
- Phase 5b: Write-Pfad (Set-Frequenz/Mode aus App ans Radio, "Set Radio to Spot" aus DX-Cluster)
- Phase 5c: Reconnect-Watchdog, automatische USB-Yank-Erkennung
- Phase 5d: PTT-Control (für künftige Digi-Mode-Integration)
- Ad-Hoc-Codesigning für Dev; für öffentliche Verteilung kommt Developer-ID + Notarization
- `swift build` aus dem Drive-synced Projektordner kann hängen — Workaround: `--build-path /tmp/hamtools-build` (Empfehlung für `run.sh`/`build-dmg.sh` in Folge-Commit)

---

## [1.5.0] — 2026-05-11

### Neu: Logbuch-Modul (Phase 1 + 2 + 3 + 4b)

Komplettes Logger-Modul im Desktop-Logger-Stil, von Multi-Log-Architektur über Online-Lookups bis Cabrillo-Export. Über 30 Commits an einem Tag.

#### Datenarchitektur
- **Multi-Log statt Mega-Log**: pro Logbuch eine eigene SQLite-Datei (`.htlog`), Typ-Auswahl beim Anlegen (Standard / Contest / POTA / SOTA, letztere drei vorbereitet für spätere Phasen)
- **AppDataRoot** als zentraler konfigurierbarer Datenordner. Default `~/Documents/HAM-Tools/`. Unter-Struktur: `Logs/ · Cache/ · Exports/ · Backups/ · Audio/`. Auto-Migration vom Legacy-Pfad.
- **SQLite direkt via C-API** — Command-Line-Toolchain hat keine SwiftDataMacros, also schlanker eigener Wrapper. Schema: `log_meta` + `qsos` + `schema_info` mit Indizes auf datetime/call/band.
- **Persistenz aller UI-States** via `@AppStorage`: Tab, Filter, Awards-Sub-Tab, Heatmap-Minutes, Spots-Mode/Radius, Cluster-Source-Toggles, etc.

#### Desktop-Layout
- **Vollbild-Logbuch**: wenn aktiv, übernimmt das Modul das ganze Fenster mit eigener Sidebar/Toolbar
- **Top-Bar**: Zurück-Button · Aktives-Log-Selector · Live-UTC-Uhr · Callsign · Settings-Zahnrad
- **Entry-Sektion** (HSplitView): RadioControlPanel (195 px) · QSOEntryPanel · Propagation-Panel (240-360 px)
- **QSOEntryPanel**: vier Spalten — Adresse · Funk-Daten · Award-Refs · QRZ-Profil-Bild (250 × 200)
- **LogActionBar**: LookUp · Previous · Time On · Time Off · **Log QSO** (⌘↩) · Send Spot · Beam · Reset · Stacking — Phase-tagged disabled
- **Tab-Bar mit Context-Filter-Zeile** unter den Tabs — pro Tab eigene Filter/Aktionen, konsistente Höhe
- **QSO-Tabelle**: sortierbar per Klick, drag-reorder, hide/show 15 Spalten via Header-Rechtsklick, Customization persistiert
- **Color-Coding**: rot=unbestätigt, gelb=upload pending, grün=LoTW/eQSL confirmed

#### Datenfluss & Bridges
- **LogEntryBridge** (Singleton, analog AntennaSimBridge): DX-Cluster-Spot oder Memory → QSO-Form vorausgefüllt
- **POTA/SOTA/WWFF-Ref-Extraktion** aus Spot-Kommentaren via Regex
- **RadioState** als zentrale Frequenz-Quelle (manuell jetzt, ab Phase 5 via CAT/Hamlib)
- **Time-On läuft sekündlich mit** — Timer-publish, beim Loggen wird aktuelle Zeit übernommen

#### Online-Schnittstellen (Phase 3)
- **QRZService**: XML-API mit Session-Login + Re-Login bei Timeout, parsed alle Standard-Felder + `<ccode>` + `<image>` + `<url>`
- **HamQTHService**: XML-API kostenlos, parsed nick/adr_name + adr_city + adif + picture etc.
- **CallbookService**-Protokoll als Plug-In-Architektur — weitere Services trivial dazuzustellen
- **CallbookManager**: Primary/Fallback-Logik mit persistentem Cache (30 Tage TTL)
- **Auto-Fill** beim TAB im Call-Feld via `@FocusState` — leere Felder werden gefüllt, keine Überschreibung
- **Bulk-Lookup**: Tabellen-Selection markieren → »QRZ für N Auswahl« mit Live-Progress

#### Cross-Log-Suche
- **Previous-Button**: Popover mit allen früheren QSOs des aktuellen Calls über ALLE Logs (in-memory für aktives, lazy SQLite für andere)
- **Duplicate-Warnung beim Loggen**: Exact-Match (Call+Band+Mode in aktivem Log) + Recent-Match (selber Call irgendwo in letzten 30 min) → Alert mit Details

#### Import / Export (Phase 2)
- **ADIF 3.x Codec**: Encoder + Parser (UTF-8-Byte-genau), Field-Mapping aller QSO-Felder inkl. POTA/SOTA via SIG/MY_SIG, LoTW/eQSL-Flags, Solar
- **ADIF-Import-Sheet** mit drei Strategien: nur-neue / alle / neues-Log. Duplikat-Erkennung Call+Band+Mode+±5min
- **Auto-Backup** vor riskanten Operationen (Log-Löschen + ADIF-Import): ADIF nach `Backups/{Logname}-{Stamp}-{tag}.adi`
- **Cabrillo V3 Export** (Phase 4b): Sheet mit allen Header-Tags (Contest-ID, Category-Operator/Band/Mode/Power/Station/Time, Claimed-Score, Sent-Exchange, Soapbox), Mode-Mapping CW/PH/RY/DG, Datei nach `Exports/`

#### Tabs (Bottom-Sektion)
- **Log**: QSO-Tabelle mit Filter-Bar (Call/Band/Mode/Country) + Status-Zeile mit Dateinamen
- **Map**: Weltkarte mit DX-Cluster-Spots (zentriert auf eigenen QTH, Mode-Farben, Radius/Mode-Filter)
- **Bands**: Frequenz/Zeit-Diagramm pro Band (wiederverwendet aus DX-Cluster)
- **DXClusters**: Spot-Liste inline mit Status-Bar, Doppelklick öffnet Spot im Log-Form
- **Awards**: DXCC-Tabelle / WAZ-Grid (40 Zonen) / WAS-Tabelle mit Worked/Confirmed-Status
- **Memories**: Schnellzugriffs-Karten mit Pin · Call · Band/Mode · Frequenz · Sked-Termin (Live-Countdown) · Notes
- **History**: Karte eigener QSOs als Linien Home→DX, Mode-Farben, Filter Band/Mode/Zeitraum

#### Persistenz
- **Letztes aktives Log**: UUID in UserDefaults, beim Neustart wieder geöffnet
- **Spalten-Anpassung** der QSO-Tabelle (TableColumnCustomization als Codable JSON)
- **Callbook-Cache** als JSON in `Cache/callbook-cache.json`
- **Memories** als JSON in `Cache/memories.json`
- **Cluster-Filter** (Source-Toggles, Band/Mode/Continent/Search/Radius) in UserDefaults

### Sonstiges in 1.5
- Map-Initial-Camera auf QTH (statt fest 47°/8°), engerer Span (80×160°)
- Cluster-Default-Toggles: nur DX an, SOTA/POTA/WWFF aus
- HB9HJI/JN47PN-Vorbelegungen neutralisiert — Placeholder zeigen jetzt »Call«, »Locator«, »Rufzeichen« etc.
- Settings-Button in der Logbook-Top-Bar
- SpotListView Spotter+Quelle in einer Zeile statt übereinander → flacher

### Code-Statistik (Schätzung)
- ~4500 Zeilen neuer Swift-Code im Logbuch-Modul
- 35 neue Source-Dateien
- Über 30 Commits in einer Session
- Build clean unter Swift 5.9 / macOS 14+

---

## [1.3.0] — 2026-05-09

### Neu: QTH-Locator Erweiterungen

Umfassender Ausbau des QTH-Locator-Werkzeugs zu einer vollständigen Standort- und Ausbreitungsanalyse-Station.

#### Interaktive Karte & Locator
- MapKit-Karte direkt in den „Karte & Locator"-Tab integriert (NSViewRepresentable-Workaround für macOS-Gestenkonflikte)
- Klickbarer Pins für Quelle und Ziel direkt auf der Karte setzbar (Fadenkreuz-Cursor)
- Koordinaten-Panel oben im Tab: Locator, Lat/Lon, Distanz, Richtung für Quelle und Ziel
- 8-stelliger Maidenhead Extended Square (~500 m Auflösung, Raster 2/240° × 1/240°)
- Prominente Quelle→Ziel-Linie auf der Karte (weisser 6 px Halo + orangefarbener 3 px Kern)

#### SOTA / POTA Suche auf Karte
- SOTA-Gipfel und POTA-Parks in einstellbarem Radius um Quelle anzeigen
- Vergrösserte, gut lesbare Marker mit dunklem Hintergrund-Label auf der Karte
- VSplitView: Karte oben, Ergebnisliste unten (kollabierbar)
- Konverter-Funktionalität (Koordinaten ↔ Locator) direkt in Karte & Locator integriert (eigener Tab entfernt)

#### Höhenprofil & Sichtlinie
- Sichtverbindungs-Linie (LOS) von Quelle zu Ziel mit Erdkrümmungs-Korrektur (k = 4/3, Standardatmosphäre)
- Erdkrümmungsformel: `bulge(d) = d × (D−d) / (2 × Re × k)` über dem linearen Interpolationspfad
- Fresnel-Zonen-Visualisierung für 70 cm, 2 m, 4 m, 6 m (einzeln ein-/ausblendbar)
- Fresnel-Radius-Formel: `r = sqrt(λ × d1 × d2 / D)`
- Darstellung als LineMark-Paare (obere + untere Grenze) je Band — kein AreaMark-Artefakt
- Statistik-Kacheln (2×2 LazyVGrid): Min. Höhe, Max. Höhe, Differenz, Distanz

---

## [1.1.0] — 2026-05-09

### Neu: DX-Cluster Live-Workstation

Vollständige DX-Cluster-Integration als neue Live-Tools-Kategorie in der Seitenleiste.

#### Verbindung & Daten
- TCP-Client für DXSpider-Protokoll (Port 7300) mit Auto-Reconnect (NWConnection)
- Multi-Cluster-Verwaltung: beliebig viele Knoten konfigurierbar, Einzel-Aktivierung
- Login-Sequenz: connect → warte auf "login:" → sende Rufzeichen → `sh/dx 50`
- REST-API-Fetcher: SOTAwatch3, POTA, WWFF mit konfigurierbarem Poll-Intervall
- Propagation-Fetcher: NOAA SFI, Kp-Index, A-Index alle 15 Minuten
- Spot-Parser: `DX de SPOTTER: FREQ DXCALL COMMENT HHMM` inkl. DXCC-Lookup

#### Spot-Liste (Tab 0)
- SwiftUI Table mit 10 Spalten: Zeit, Freq, Band, Mode, DX-Rufzeichen, Land, Kontinent, Kommentar, Spotter
- Band-Farbkodierung (14 Bänder), sortierbar nach allen Spalten
- ★-Spalte und goldene Textfarbe für Spots auf der Watch List

#### Bandmap (Tab 1)
- Canvas-basiertes Frequenzdiagramm pro Band
- Farbkodierung nach Mode (FT8 grün, CW orange, SSB gelb, …)
- Zeitfenster-Filter (15 / 30 / 60 / 120 min)

#### Weltkarte (Tab 2)
- MapKit-Karte (macOS 14 SwiftUI API) mit Spot-Markern als farbige Punkte
- Spotter-Linien (MapPolyline) ein-/ausblendbar
- Auswahl-Ring mit Spot-Detailleiste
- Zeitfenster-Filter (15 / 30 / 60 min / Alle)

#### Statistik (Tab 3)
- 2×2-Grid mit SwiftUI Charts
- Spots/Band (horizontale Balken mit Band-Farben)
- Spots/Mode (Balken)
- Top-15 DX-Calls (grüne Balken)
- 24h-Verlauf (Area-Chart + Linie)

#### Filter & Suche
- Band, Mode, Kontinent (Picker-Menüs)
- Quelle: DX / SOTA / POTA / WWFF (Checkboxen)
- Freitext-Suche über DX-Call, Kommentar, Spotter
- Spotter-Radius-Filter (0 / 500 / 1000 / 2500 / 5000 km vom eigenen QTH, Haversine)
- Reset-Button für alle Filter
- Leeren-Button: löscht Spot-Liste und Persistenz

#### DX-Spot senden
- Sheet-Dialog mit Frequenz, DX-Rufzeichen, Kommentar
- Sendet `DX freq call comment` via TCP an aktiven Cluster
- Button deaktiviert wenn nicht verbunden

#### Watch List / Alerts
- WatchListStore: Prefix- oder Exakt-Match (Gross-/Kleinschreibung ignoriert)
- Einstellungen → Alerts-Tab: Watch-Liste verwalten, Benachrichtigungs-Toggle
- macOS-Benachrichtigungen (UNUserNotificationCenter) bei neuem Watch-Spot
- Deduplizierung innerhalb einer Session (gleicher Call + Frequenz)
- Alarm-Badge (🔔 N) in der Verbindungsleiste, tippbar zum Zurücksetzen

#### Persistenz & Settings
- Spot-Persistenz: JSON in `~/Library/Application Support/HAMRechner/spots.json`
  - Max. 500 Spots, 24h-Retention, atomarer Schreibvorgang
  - Geladen beim Start, gespeichert alle 25 neuen Spots
- Einstellungen (Cmd+,):
  - **Station**: Rufzeichen + QTH-Locator (AppStorage)
  - **Cluster**: Tabelle mit +/−/Bearbeiten, Aktiv-Auswahl, autoConnect-Markierung
  - **Darstellung**: 3 Themes mit Mini-Swatch-Vorschau
  - **Alerts**: Watch-Liste + Benachrichtigungs-Toggle

#### 3-Theme-System
- **HAM Style** (Standard): helles Design, weiße Tabelle, schwarzes Terminal
- **Dark**: dunkles blau-graues Design
- **Ham Classic**: bernsteinfarbenes Terminal-Design
- ThemeManager mit AppStorage-Persistenz, wechselbar im laufenden Betrieb

#### Propagation-Panel (Rechte Spalte)
- SFI-Gauge (Halbkreis, 0–300)
- Kp-Gauge (Halbkreis, 0–9)
- Band-Activity-Heatmap: Bänder × Kontinente, zeitgefiltert (15/30/60 min)

---

## [1.0.0] — 2026-05-09

### Erstveröffentlichung

Vollständige SwiftUI macOS-App mit 25 Amateurfunk-Rechnern in 6 Kategorien.

#### Drahtantennen
- Dipol-Rechner (Halbwellen, alle Bänder)
- Groundplane / Vertikal (λ/4 mit Radials)
- J-Pole / Slim Jim
- Sperrtopf (koaxiale Mantelwellensperre)
- Windom / OCFD
- EFHW-Verkürzungsspule
- Loop-Antenne

#### Richtstrahler
- Moxon Rectangle
- HB9CV Beam
- **Hexbeam** (G3TXQ, mehrbandig 10/15/20/40m)
  - Parametrische Draufsicht: Treiber (V), Reflektor (gestrichelt), Schnüre (grau), Tip Spacer
  - Seitenansicht: Halbkreis-Schüssel, horizontale Drähte, Träger, Höhenmass
- Yagi-Rechner (2–6 Elemente nach Rothammel)
- Spiderbeam Einzelband
- Spiderbeam Multi-Band

#### Spezialantennen
- Magnetic Loop (Kapazität, Güte, Bandbreite)
- Antennen-Designer

#### Spulen & Transformatoren
- Balun / Unun (Wicklungsrechner, verschiedene Übersetzungen)
- Strahler-Verlängerung
- Spulen-Wickler (Luftspule, Induktivität)

#### Anpassung & Leitungen
- Anpassnetzwerk (L-Netz)
- Koax-Stub (λ/4, λ/2, offen/kurzgeschlossen, Schema-Canvas)
- Kabeldämpfung

#### Signale & Tools
- Pegel-Umrechner (dBm / dBW / V / µV / W)
- SWR-Simulator
- Linkbudget / Reichweite (Friis-Formel)
- QTH-Locator (Maidenhead ↔ Koordinaten, Distanz, Bearing)

#### UI
- NavigationSplitView mit kategorisierter Seitenleiste (Mindestbreite 220 px)
- Konsistentes `SectionCard` + `ResultRow` Design-System
- Dark Mode nativ unterstützt
