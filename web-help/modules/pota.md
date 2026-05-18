---
title: POTA — Parks On The Air
description: POTA-Modul in HAM-Tools mit Activator/Hunter, Park-DB, Multi-Park-Hopping, Self-Spotting, Spots-Feed, Map, Awards und pota.app-Upload.
---

# POTA — Parks On The Air

::: tip Komplett in 1.8 (Mai 2026)
POTA-Modul ist voll ausgebaut. Lokale Park-DB von pota.app,
Activator/Hunter-Workflow, Live-Spots, Self-Spotting, Karte, Awards
mit Profil-Sync, ADIF-Export gemäß pota.app-Spec inkl.
Multi-Park-Split.
:::

## Kurz-Überblick

- **Activator / Hunter**-Modi auswählbar beim Anlegen einer POTA-Session
- **Park-Auto-Complete** aus der offiziellen `pota.app/all_parks_ext.csv`
  (~80 000 Parks weltweit, lokale SQLite, einmalig ~15 MB Download)
- **Multi-Park-Hopping**: mehrere Park-Refs pro Session (Komma-Liste)
- **10-QSO-Aktivierungs-Counter** mit Live-Anzeige im QSO-Form
- **P2P-Erkennung** (Park-to-Park): Their-Park-Feld mit DB-Lookup
- **POTA-Spots-Feed**: Live-Stream von `api.pota.app/spot/activator`
  (Polling alle 60 s), mit Filter und CAT-QSY
- **Self-Spotting**: aus dem QSO-Form direkt einen Spot an pota.app
  pushen (anonym, kein Auth)
- **POTA-Map**-Tab: Park-Pins (Tree-Icon, POTA-Grün) + DX-Pins +
  Linien Park → DX, P2P-Indikator pro QSO
- **POTA-Awards** im Awards-Tab: Activator-Parks, Hunter-Parks,
  P2P-Count — wahlweise lokal aus dem Logbuch oder live aus dem
  pota.app-User-Profil
- **ADIF-Konformität**: `MY_SIG=POTA` + `MY_SIG_INFO` (offizielle
  pota.app-Spec, [siehe ADIF for POTA Technical Reference](https://docs.pota.app/docs/use_pota/etc.html))
- **STATION_CALLSIGN-Unifizierung** beim Export — Logs mit gemischten
  Calls (z.B. nach WSJT-X-Umkonfigurieren) werden automatisch
  vereinheitlicht, sonst lehnt pota.app sie ab

## Park-DB einmalig laden

Vor der ersten Aktivierung muss die Park-DB heruntergeladen werden:

1. **Einstellungen → Daten → POTA-Park-Datenbank**
2. Klick **„Jetzt laden"** → Download von
   [`pota.app/all_parks_ext.csv`](https://pota.app/all_parks_ext.csv) (~15 MB)
3. Parsen läuft ~5–10 Sek, danach ist die Datenbank in
   `~/Documents/HAM-Tools/Cache/parks.sqlite` einsatzbereit
4. Refresh-Hinweis nach 30 Tagen (Park-Liste wächst stetig)

## Anlegen einer POTA-Session

1. Top-Bar → **Neues Log** → **POTA-Session** → öffnet den POTA-Wizard
2. **Activator** oder **Hunter** wählen
3. **Verwendetes Rufzeichen** — wichtig für portable Aktivierungen!
   - Default ist dein Standard-Call aus Station-Settings
   - Bei portable Aktivierung im Ausland: hier den **Portable-Call**
     mit Präfix eintragen (z.B. `IT/HB9HJI/P`)
   - Dieser Call wird im ADIF-Export als einheitlicher
     `OPERATOR` + `STATION_CALLSIGN` über alle QSOs geschrieben —
     pota.app verlangt einen einzigen Wert pro Logfile
4. **Eigener Park** eintragen (Activator) — Auto-Complete sucht in
   der Park-DB, zeigt Country + Park-Name pro Vorschlag
5. Optional: **Hopping-Parks** als Komma-Liste (`K-1234, K-5678`)
6. **Anlegen** → Log ist erstellt, POTA-Form wird aktiv

::: warning Activator-Call konsequent gleich halten
Wenn du mit WSJT-X über den Spot-Stream loggst und dort mid-session
das `my_call` änderst (z.B. von `HB9HJI` auf `IT/HB9HJI/P`), lehnt
pota.app das Log mit *„Only a single STATION_CALLSIGN value is
supported per log file"* ab. Seit 1.8.10 überschreibt der
WSJT-X-Importer das automatisch mit dem im Wizard gewählten Call —
trotzdem ist es sauberer, in WSJT-X von Anfang an den korrekten
Portable-Call zu konfigurieren.
:::

## QSO loggen

Sobald ein POTA-Log aktiv ist, rendert das QSO-Panel die POTA-Form:

- **Status-Bar** zeigt UTC · Frequenz/Band · Mode · Power · Log-Name ·
  Mein Park (z.B. `Activator · K-1234 · United States`)
- **Their Call** mit QRZ/HamQTH-Lookup (Auto-Fill nach ~600 ms für
  NAME, QTH, GRIDSQUARE, COUNTRY, CONT, CQZ, ITUZ)
- **Their Park** mit Auto-Complete für P2P — Park-Name wird gezeigt
- **10-QSO-Counter** rechts unten: rot bis 9 QSOs, grün mit
  „Aktivierung gültig"-Badge ab 10 QSOs
- **Dupe-Markierung**: gleicher Call+Band+Mode im Log → oranger Banner
  (Pile-Up auf einer Frequenz bleibt sauber erkennbar)
- **Cmd+Return** speichert das QSO, Fokus springt zurück aufs Call-Feld

## Self-Spotting

Aus dem POTA-Form heraus direkt einen Spot an pota.app senden — kein
DX-Cluster nötig, keine Authentifizierung:

1. Park-Ref, Frequenz und Mode sind im Form gesetzt
2. Klick auf den **Spot-Button** (📡) neben dem Aktivierungs-Counter
3. Spot landet sofort auf `api.pota.app/spot/` und ist auf pota.app
   sichtbar + im POTA-Spots-Tab unserer App
4. Funktioniert sowohl im Activator-Modus (du spottest dich selbst)
   als auch im Hunter-Modus (du spottest einen aktiven Park, den du
   gerade hörst)

Quelle wird als `source=HAM-Tools` markiert.

## POTA-Spots-Tab

Wenn ein POTA-Log aktiv ist, schaltet der untere **„DX Clusters"-Tab**
automatisch auf den POTA-Spots-Feed um:

- Polling alle 60 Sek aus `api.pota.app/spot/activator`
- Filter: Band, Mode, Country-Prefix (`K`, `HB`, `DL` …)
- **„Nur ATNO"**-Toggle blendet Parks aus, die du schon gearbeitet hast
- Sort nach Zeit, Frequenz oder Spotter
- **Copy-Button** füllt Activator-Call + Park-Ref + Frequenz in die
  POTA-Form. Wenn CAT verbunden ist und der QSY-Toggle an ist,
  springt der TRX auf die Spot-Frequenz

## POTA-Map

- Eigener Tab **„POTA-Map"** in der unteren Tab-Bar (Tree-Icon)
- Park-Pins für alle Park-Refs der QSOs im aktiven Log
- DX-Pins für gearbeitete Stationen mit Locator-Auflösung
- Linien Park → DX optional (Toggle in der Filter-Bar)
- P2P-Indikator im Info-Popup beim Klick auf DX-Pin
- Band-Filter persistent über App-Neustarts

## Awards-Tab

Im Awards-Tab gibt es einen eigenen **POTA-Sub-Tab** (wird automatisch
gewählt sobald ein POTA-Log aktiv ist):

- **Activator-Parks**: eindeutige Refs aus `myPotaRef` + `myPotaRefs`
- **Hunter-Parks**: eindeutige `theirPotaRef`-Werte
- **Park-to-Park** (P2P): QSOs mit beiden Feldern gesetzt

::: tip pota.app-Profil als Source-of-Truth
Wenn du Email + Rufzeichen in den App-Settings hast, holt sich der
POTA-Awards-Tab dein **öffentliches Profil von api.pota.app/profile/**.
Damit siehst du geräteübergreifend den echten Stand statt nur dessen,
was in der lokalen `.htlog`-Datei liegt. Der Profil-Cache hält 24 h.
:::

## ADIF-Export

Beim ADIF-Export werden für POTA-QSOs folgende Felder geschrieben
(strikt nach [ADIF for POTA Technical Reference](https://docs.pota.app/docs/use_pota/etc.html)):

```
<CALL:6>DL1ABC <BAND:3>20m <MODE:3>SSB
<OPERATOR:11>IT/HB9HJI/P <STATION_CALLSIGN:11>IT/HB9HJI/P
<MY_SIG:4>POTA <MY_SIG_INFO:6>K-1234
<APP_HAMTOOLS_MY_POTA_REF:6>K-1234
<MY_GRIDSQUARE:6>JN47PN
<SIG:4>POTA <SIG_INFO:6>K-5678 <APP_HAMTOOLS_POTA_REF:6>K-5678
<EOR>
```

- `MY_SIG=POTA` + `MY_SIG_INFO` für Activator (offizielle pota.app-Spec)
- `SIG=POTA` + `SIG_INFO` für Hunter/P2P
- `OPERATOR` + `STATION_CALLSIGN` werden über alle QSOs auf den im
  Log-Wizard gewählten Activator-Call vereinheitlicht (1.8.10) — sonst
  lehnt pota.app das File ab
- `APP_HAMTOOLS_MY_POTA_REF` / `APP_HAMTOOLS_POTA_REF` sind proprietär
  und ermöglichen den verlustfreien Re-Import in HAM-Tools
- `MY_GRIDSQUARE` aus den App-Settings (Stations-Tab → Locator)

### Multi-Park-Hopping → Split pro Park

pota.app verlangt **ein eigenes File pro Park** und akzeptiert
keine Komma-Listen in `MY_SIG_INFO`. Bei einem Log mit mehreren
Park-Refs erzeugt der Export deshalb **automatisch eine Datei pro
Park**, im pota.app-Filename-Schema:

```
HB9HJI@K-1234 20260518.adi
HB9HJI@K-5678 20260518.adi
```

QSOs werden pro Park gefiltert (jedes QSO bekommt nur den Park, den
es tatsächlich aktiviert), die Multi-Ref-Liste wird zur Single-Ref
zusammengefaltet.

## Upload zu pota.app

Aktuell noch **manueller Workflow** (Auto-Upload steht für Phase 6 auf
der Roadmap):

1. Im Logbuch-Toolbar des aktiven POTA-Logs auf **„pota.app…"** klicken
2. Sheet zeigt die generierten ADIF-Files (1 oder mehrere bei
   Multi-Park) — Klick **„Im Finder zeigen"** öffnet den
   Exports-Ordner
3. Browser zu [pota.app/page/logger](https://pota.app/page/logger)
   öffnen, einloggen, ADIF hochladen
4. Bei Multi-Park: jedes File einzeln hochladen (Park wird vom
   Filename erkannt)

## Bekannte Einschränkungen

- **Auto-Upload zu pota.app** noch nicht implementiert — kommt mit
  Phase 6 (Cognito-SRP-Auth ist die Hürde)
- **Park-DB-Refresh** ist manuell — der Refresh-Hinweis erinnert,
  aber automatischer Hintergrund-Sync ist nicht aktiv

## Vergleich POTA ↔ SOTA ↔ WWFF ↔ BOTA

| Aspekt | POTA | SOTA | WWFF | BOTA |
|---|---|---|---|---|
| Aktivierung ab | 10 QSOs | 4 QSOs | 44 QSOs | 1 QSO |
| Refs | `K-1234`, `HB-0001` | `HB/BE-001` | `DLFF-0001` | `DE-1234` |
| Punkte | – | 1–10 + Winterbonus | – | – |
| Datenquelle | API offen | API offen | URL + File | nur File |
| Spots | dediziert (api.pota.app) | dediziert (sotawatch3) | DX-Cluster-Filter | DX-Cluster + DB-Match |
| Self-Spot | ✓ (anonym) | – (Phase 6) | – | – |
| ADIF-Tags | Standard (`MY_SIG=POTA`) | Standard (`MY_SIG=SOTA`) | Standard (`MY_SIG=WWFF`) | proprietär |
