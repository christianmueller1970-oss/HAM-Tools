# SOTA — Summits On The Air

::: tip Neu in 1.8 (Mai 2026)
SOTA-Modul ist komplett. Lokale Summit-DB, Activator/Chaser-Workflow,
Live-Spots-Feed, Karte, Awards. Strukturparallel zum POTA-Modul.
:::

## Kurz-Überblick

- **Activator / Chaser**-Modi auswählbar beim Anlegen einer SOTA-Session
- **Summit-Auto-Complete** aus der offiziellen sotadata.org.uk-Datenbank
  (~181 000 Summits weltweit, lokale SQLite, einmalig ~15 MB Download)
- **Multi-Summit-Hopping**: mehrere Summit-Refs pro Session (Komma-Liste)
- **4-QSO-Aktivierungs-Counter** mit Live-Anzeige im QSO-Form
- **Winterbonus-Anzeige**: bei Summits mit Bonus-Punkten zeigt die
  Status-Bar `10 + 3 p` während des Winter-Fensters (NH: 1. Dez – 15. März,
  SH: 1. Juni – 15. Sep)
- **S2S-Erkennung** (Summit-to-Summit): Their-Summit-Feld mit Punkte-Lookup
- **SOTA-Spots-Feed**: Live-Stream von `api2.sota.org.uk` statt regulärer
  DX-Cluster-Spots, mit Filter, Copy-Button und optionalem CAT-QSY
- **SOTA-Map**-Tab: Summit-Pins (mit Elevation + Punkten im Tooltip) +
  DX-Pins + Linien Summit → DX, S2S-Indikator pro QSO
- **SOTA-Awards** im Awards-Tab: Activator-Summits, Chaser-Summits,
  S2S-Count, Chaser-Punkte aggregiert über alle Logs
- **ADIF-Konformität**: `MY_SOTA_REF`, `SOTA_REF`, `MY_SIG=SOTA`,
  `MY_SIG_INFO`, plus proprietäres `APP_HAMTOOLS_THEIR_SOTA_POINTS`
  für Re-Import ohne Summit-DB-Lookup

## Summit-DB einmalig laden

Vor der ersten Aktivierung muss die Summit-DB heruntergeladen werden:

1. **Einstellungen → Daten → SOTA-Summit-Datenbank**
2. Klick **„Jetzt laden"** → Download von
   [`summitslist.csv`](https://www.sotadata.org.uk/summitslist.csv)
3. Parsen läuft ~3-5 Sek, danach ist die Datenbank in
   `~/Documents/HAM-Tools/Cache/summits.sqlite` einsatzbereit
4. Refresh-Hinweis nach 30 Tagen (Summit-Liste ist relativ stabil)

## Anlegen einer SOTA-Session

1. Top-Bar → **Neues Log** → **SOTA-Session** → öffnet den SOTA-Wizard
2. **Activator** oder **Chaser** wählen
3. **Eigener Summit** eintragen (Activator) — Auto-Complete sucht in der
   Summit-DB, zeigt Höhe und Punkte pro Vorschlag
4. Optional: **Hopping-Summits** als Komma-Liste (`HB/BE-002, HB/VS-001`)
5. **Anlegen** → Log ist erstellt, SOTA-Form wird aktiv

## QSO loggen

Sobald ein SOTA-Log aktiv ist, rendert das QSO-Panel die schlanke SOTA-Form:

- **Status-Bar** zeigt UTC · Frequenz/Band · Mode · Power · Log-Name ·
  Mein Summit mit Punkten (z.B. `Activator · HB/BE-001 · 10+3p` mit
  Winterbonus)
- **Their Call** mit QRZ/HamQTH-Lookup (Auto-Fill nach ~600 ms)
- **Their Summit** mit Auto-Complete für S2S — Punkte werden automatisch
  geholt und im QSO als `theirSotaPoints` gespeichert
- **4-QSO-Counter** rechts unten: rot bis 3 QSOs, grün mit
  „Aktivierung gültig"-Badge ab 4 QSOs
- **Dupe-Markierung**: gleicher Call+Band+Mode im Log → oranger Banner
  statt grünem „gespeichert" (Aktivierung-Pile-Up auf einer Frequenz
  bleibt sauber erkennbar)

## SOTA-Spots-Tab

Wenn ein SOTA-Log aktiv ist, schaltet der untere **„DX Clusters"-Tab**
automatisch auf den SOTA-Spots-Feed um:

- Polling alle 60 Sek aus `api2.sota.org.uk/api/spots/50/all`
- Filter: Band, Mode, Assoc-Prefix (`HB`, `DM`, `G/LD` …)
- **„Nur manuell"**-Toggle blendet automatische RBN-Spots (RBNHole) aus
- Sort nach Zeit oder Frequenz
- **Copy-Button** füllt Activator-Call + Summit-Ref + Frequenz in die
  SOTA-Form. Wenn CAT verbunden ist und der QSY-Toggle an ist, springt
  der TRX auf die Spot-Frequenz

## SOTA-Map

- Eigener Tab **„SOTA-Map"** in der unteren Tab-Bar (Mountain-Icon)
- Summit-Pins für alle Summit-Refs der QSOs im aktiven Log
- DX-Pins für gearbeitete Stationen mit Locator-Auflösung
- Linien Summit → DX optional (Toggle in der Filter-Bar)
- Band-Filter persistent über App-Neustarts
- Info-Popup pro QSO zeigt Mode-Farbe + S2S-Gegen-Summit (falls vorhanden)
  in SOTA-Orange

## Awards-Tab

Im Awards-Tab gibt es einen eigenen **SOTA-Sub-Tab** (wird automatisch
gewählt sobald ein SOTA-Log aktiv ist):

- **Activator-Summits**: eindeutige Refs aus `mySotaRef` + `mySotaRefs`
- **Chaser-Summits**: eindeutige `theirSotaRef`-Werte
- **Summit-to-Summit**: QSOs mit beiden Feldern gesetzt
- **Chaser-Punkte**: Summe der `theirSotaPoints` aller QSOs

::: info Activator-Punkte-Aggregation
Activator-Punkte (Base + Winterbonus, pro Aktivierung) werden aktuell **nur
im QSO-Form live angezeigt**, nicht aggregiert. Die Awards-Tab-Auswertung
inkl. Aktivierungs-Daten und Bonusen kommt mit Phase 6 (Upload-Pfad).
:::

## ADIF-Export

Beim ADIF-Export werden für SOTA-QSOs folgende Felder geschrieben:

```
<CALL:6>DL1ABC <BAND:3>20m <MODE:3>SSB
<MY_SIG:4>SOTA <MY_SIG_INFO:9>HB/BE-001 <MY_SOTA_REF:9>HB/BE-001
<MY_GRIDSQUARE:6>JN46pn
<SIG:4>SOTA <SIG_INFO:9>HB/AG-001 <SOTA_REF:9>HB/AG-001
<APP_HAMTOOLS_THEIR_SOTA_POINTS:1>1
<EOR>
```

- `MY_SIG=SOTA` + `MY_SOTA_REF` für Activator
- `SIG=SOTA` + `SOTA_REF` für Chaser/S2S
- `APP_HAMTOOLS_THEIR_SOTA_POINTS` ist proprietär — ermöglicht Re-Import
  ohne erneuten Summit-DB-Lookup
- `MY_GRIDSQUARE` aus den App-Settings (Stations-Tab → Locator)

## Bekannte Einschränkungen

- **Upload zu sotadata.org.uk** ist noch nicht implementiert — kommt mit
  Phase 6. Bis dahin ADIF exportieren und manuell unter
  `sotadata.org.uk/admin/activator_log_upload.aspx` hochladen.
- **Self-Spotting** (eigenen Spot auf SOTAwatch posten) ist Phase 6.
- **Activator-Punkte-Total** wird aktuell nicht über alle Logs aggregiert —
  das QSO-Form zeigt Base+Bonus pro aktiver Aktivierung, der Awards-Tab
  zeigt nur Chaser-Punkte. Pro-Aktivierung-Aggregation kommt mit Phase 6.

## Vergleich SOTA ↔ POTA

| Aspekt | SOTA | POTA |
|---|---|---|
| Datenquelle | sotadata.org.uk CSV | pota.app CSV |
| Refs | `HB/BE-001` (Assoc/Region-Code) | `K-1234`, `HB-0001` |
| Modi | Activator / Chaser | Activator / Hunter |
| Aktivierung gültig ab | 4 QSOs | 10 QSOs |
| Punkte-System | 1–10 Basis + 3 Winterbonus | keine Punkte (Park-Zähl) |
| S2S / P2P | Summit-to-Summit | Park-to-Park |
| Spots-API | `api2.sota.org.uk` (MHz) | `api.pota.app` (kHz) |
| ADIF-Feld | `MY_SOTA_REF` / `SOTA_REF` | `MY_POTA_REF` / `POTA_REF` |

::: info Funkstil
Beide Programme arbeiten ähnlich — wer POTA kennt, findet sich in SOTA
sofort zurecht. Die App spiegelt das wider: identische Tab-Bar, identisches
Form-Layout, identischer Map-Stil.
:::
