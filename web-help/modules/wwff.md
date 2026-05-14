# WWFF — Worldwide Flora & Fauna

::: tip Neu in 1.8.1 (Mai 2026)
WWFF-Modul ist komplett. Doppelpfad-Datenquelle (URL + manueller CSV-Import),
Activator/Hunter-Workflow mit 44-QSO-Counter, Live-Spots aus dem DX-Cluster,
Karte mit R2R-Indikator, Awards. Strukturparallel zu POTA + SOTA.
:::

## Kurz-Überblick

- **Activator / Hunter**-Modi auswählbar beim Anlegen einer WWFF-Session
- **Reference-Auto-Complete** aus einer lokalen SQLite-Datenbank
  (Doppelpfad: URL von `wwff-cc.org` oder manueller CSV-Import via Datei-Picker)
- **Multi-Reference-Hopping**: mehrere WWFF-Refs pro Session (Komma-Liste)
- **44-QSO-Aktivierungs-Counter** mit Live-Anzeige im QSO-Form
  (WWFF-Regel: deutlich strikter als POTA(10)/SOTA(4))
- **R2R-Erkennung** (Reference-to-Reference): Their-Reference-Feld mit DB-Lookup
- **WWFF-Spots-Feed**: gefiltert aus dem regulären DX-Cluster-Stream
  (kein offizielles WWFF-API verfügbar — wir matchen auf `XXFF-NNNN`-Pattern)
- **WWFF-Map**-Tab: Reference-Pins (Leaf-Icon, WWFF-Pink) + DX-Pins +
  Linien Ref → DX, R2R-Indikator
- **WWFF-Awards** im Awards-Tab: Activator-Refs, Hunter-Refs, R2R,
  Country-Programme (DLFF, HBFF, KFF, VKFF …)
- **ADIF-Konformität**: `MY_WWFF_REF`, `WWFF_REF`, `MY_SIG=WWFF`, `MY_SIG_INFO`

## Reference-DB einmalig laden

Vor der ersten Aktivierung muss die WWFF-Reference-DB geladen werden:

1. **Einstellungen → Daten → WWFF-Reference-Datenbank**
2. Klick **„Jetzt laden"** → versucht Download von
   [`wwff-cc.org`](https://wwff-cc.org/) (kann zeitweise nicht erreichbar sein)
3. **Fallback:** Klick **„CSV importieren …"** → wähle eine lokale Country-CSV
   (z.B. vom Country-Coordinator oder offiziellem Mirror)
4. Status sollte auf **„N Refs (M aktiv)"** wechseln

::: warning wwff-cc.org Server-Erreichbarkeit
Die WWFF-Haupt-Domain ist gelegentlich nicht erreichbar (DNS-Probleme).
Der CSV-Import ist der zuverlässige Pfad — die App zeigt einen
hervorgehobenen Button mit Orange-Hinweis, sobald die URL fehlschlägt.
:::

## Anlegen einer WWFF-Session

1. Top-Bar → **Neues Log** → **WWFF-Session** → öffnet den WWFF-Wizard
2. **Activator** oder **Hunter** wählen
3. **Eigene Reference** (Activator): Auto-Complete sucht nach Ref-Code oder Park-Name
4. Optional: **Hopping-Refs** als Komma-Liste (`DLFF-0002, HBFF-0019`)
5. **Anlegen** → Log ist erstellt, WWFF-Form wird aktiv

## QSO loggen

Sobald ein WWFF-Log aktiv ist, rendert das QSO-Panel die WWFF-Form:

- **Status-Bar** zeigt UTC · Frequenz/Band · Mode · Power · Log-Name ·
  `Activator · DLFF-0001 · Germany`
- **Their Call** mit QRZ/HamQTH-Lookup
- **Their Reference** mit Auto-Complete + Country-Anzeige bei R2R
- **44-QSO-Counter** rechts unten:
  - **Rot bis 43 QSOs** mit „noch X bis Aktivierung"-Hinweis
  - **Grün ab 44 QSOs** mit „Aktivierung gültig"-Badge
- **Dupe-Markierung**: gleicher Call+Band+Mode im Log → oranger Banner
- **Enter** speichert das QSO direkt, Fokus springt zurück aufs Call-Feld

## WWFF-Spots-Tab

Wenn ein WWFF-Log aktiv ist, schaltet der untere **„WWFF-Spots"-Tab** auf
den gefilterten DX-Cluster-Stream:

- Filter: Band, Mode, Programm-Prefix (`DLFF`, `HBFF`, `KFF`)
- **„Nur manuell"**-Toggle blendet automatische Skimmer/RBN-Spots aus
- Sort nach Zeit oder Frequenz
- Status-Zeile: „N WWFF-Spots aus M DX-Cluster-Spots"
- **Copy-Button** füllt Activator-Call + Ref + Frequenz in die WWFF-Form,
  optional CAT-QSY

## WWFF-Map

- Eigener Tab **„WWFF-Map"** in der unteren Tab-Bar (Leaf-Icon)
- Reference-Pins für alle Refs im aktiven Log
- DX-Pins für gearbeitete Stationen mit Locator-Auflösung
- Linien Reference → DX optional
- R2R-Indikator im Info-Popup beim Klick auf DX-Pin

## Awards-Tab

Im Awards-Tab gibt es einen eigenen **WWFF-Sub-Tab**:

- **Activator-Refs** (+ QSOs)
- **Hunter-Refs** (+ QSOs)
- **Reference-to-Reference** (R2R-QSOs)
- **Country-Programme** (eindeutige Land-Prefixe wie DLFF, HBFF, KFF, …)

## ADIF-Export

Für WWFF-QSOs schreibt der Export:

```
<MY_SIG:4>WWFF <MY_SIG_INFO:9>DLFF-0001 <MY_WWFF_REF:9>DLFF-0001
<MY_GRIDSQUARE:6>JN47PN
<SIG:4>WWFF <SIG_INFO:9>HBFF-0019 <WWFF_REF:9>HBFF-0019
```

::: info MY_SIG-Konflikt mit POTA
In Europa sind viele Parks gleichzeitig POTA + WWFF. Beim Export werden
**beide** Refs in ihren eigenen Tag-Namen geschrieben (`MY_POTA_REF` und
`MY_WWFF_REF`). Das `MY_SIG`-Feld dominiert beim Re-Import — Logger, die
nur das SIG-Tag lesen, sehen das QSO als WWFF.
:::

## Bekannte Einschränkungen

- **Upload zu wwff-cc.org** noch nicht implementiert — Phase 6
- **Self-Spotting** in WWFFwatch — Phase 6
- **POTA/WWFF-Doppel-Refs**: noch keine automatische Vorschlag-Logik beim
  POTA-Wizard (kommt als Polish-Feature)
