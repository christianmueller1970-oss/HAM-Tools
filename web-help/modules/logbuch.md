---
title: Logbuch — Multi-Log und Award-Workflows
description: Logbuch-Modul von HAM-Tools mit Multi-Log-Architektur, Sub-Tabs, Award-Tracking (DXCC/WAZ/WAS/POTA), ADIF-Import/Export und Tastenkürzeln.
---

# Logbuch

Das Logbuch ist das Herz von HAM-Tools. Multi-Log, persistente Sub-Tabs, alle Award-Workflows.

## Multi-Log

Du kannst beliebig viele Logbücher parallel führen — z.B.:
- **Lebens-Log** (Standard-Log, sammelt alle QSOs lebenslang)
- **POTA-Sessions** (eine pro aktiviertem Park)
- **Contests** (eine pro Contest-Wochenende)

Jedes Log ist eine eigene `.htlog`-Datei (SQLite) im Daten-Ordner. Standard:
`~/Documents/HAM-Tools/Logs/`.

### Log anlegen

1. Top-Bar oben → Klick auf den Log-Namen → **"Neues Log anlegen"**
2. **Typ wählen**:
   - **Standard-Log** für den alltäglichen DX-Betrieb
   - **Contest** — öffnet den [Contest-Wizard](/modules/contest)
   - **POTA-Session** — öffnet den [POTA-Wizard](/modules/pota)
   - **SOTA-Session** — öffnet den [SOTA-Wizard](/modules/sota)
   - **WWFF-Session** — öffnet den [WWFF-Wizard](/modules/wwff)
   - **BOTA-Session** — öffnet den [BOTA-Wizard](/modules/bota)
3. Name + Notizen → **Anlegen**

### Log wechseln

Top-Bar → Klick auf Log-Namen → Popover mit allen offenen Logs → klick zum Wechsel. Sub-Tab-State (Spaltenbreiten, Filter) wird **pro Log-Typ separat** gespeichert.

## Sub-Tabs

Unter dem QSO-Eingabe-Panel siehst du die **Tab-Leiste** mit modul-spezifischen Ansichten. Welche Tabs sichtbar sind, hängt vom Log-Typ ab:

| Tab | Standard | POTA | SOTA | WWFF | BOTA | Contest |
|---|---|---|---|---|---|---|
| Log (QSO-Tabelle) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Map (weltweit) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Bands (Heatmap) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| DXClusters | ✓ | POTA-Feed | SOTA-Feed | WWFF-Filter | BOTA-Filter | gefiltert |
| Awards | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| Memories (Sked-Liste) | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| History (QSO-Karten-Chronik) | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| Programm-Map | — | POTA-Map | SOTA-Map | WWFF-Map | BOTA-Map | Contest-Map |
| Bandplan | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

::: tip
Der **DXClusters-Tab** ist der Standard beim App-Start — direkt nach dem Öffnen siehst du die aktuellen Spots und kannst per Doppelklick auf einen interessanten Spot direkt loggen.
:::

## QSO-Eingabe-Panel

Form-Typ folgt automatisch dem Log-Typ:

- **Standard-Log** → generischer **DX**-Workflow (Call, RST, Name, Locator)
- **Contest-Log** → schlanke **Contest**-Eingabe mit dynamischen Exchange-Feldern
- **POTA / SOTA / WWFF / BOTA-Log** → programm-spezifische Form mit
  Ref-Auto-Complete, Aktivierungs-Counter (10 / 4 / 44 / 1 QSOs) und
  P2P/S2S/R2R/B2B-Erkennung

### Auto-Fill aus DX-Cluster

Doppelklick auf einen Spot in der **DXClusters**-Tabelle oder **Cluster-Tab** füllt Call + Frequenz + Mode ins Eingabe-Panel. Wenn CAT aktiv ist, springt zusätzlich das Radio auf die Frequenz.

### Auto-Fill aus Callbook

Sobald du das Call-Feld verlässt (Tab oder Enter), startet ein **QRZ/HamQTH-Lookup**. Name, QTH, Locator, Country, Continent, CQ-/ITU-Zone werden eingetragen. Auto-Retry läuft beim Loggen, falls der erste Versuch nichts brachte.

### Live-Markierungen pro Spot & QSO

::: tip Neu in 1.8.9
- **ATNO/NEW-BAND/NEW-MODE-Pille** pro Spot im DX-Cluster, live aus
  dem geloggten Bestand — Details siehe [DX-Cluster-Modul](/modules/dx-cluster#atno-live-markierung).
- **Bandplan-Live-Pille** in der QSO-Status-Bar zeigt sofort beim
  Loggen, ob Frequenz + Mode IARU-R1-konform sind (grün im Band,
  orange falsches Subsegment, rot außerhalb Band). Aktiv in allen
  sechs QSO-Forms — Details siehe [DX-Cluster-Modul](/modules/dx-cluster#bandplan-live-awareness-in-qso-forms).
:::

### Bandplan als eigenes Fenster (⌘⇧P)

::: tip Neu in 1.8.8
Der Bandplan ist nicht mehr nur Sub-Tab, sondern öffnet auch als
eigenes Fenster über **⌘⇧P** oder Menü **Fenster → Bandplan-Fenster**.
Praktisch auf dem Zweitmonitor während des Loggens.
:::

## Award-Counter

Oben rechts im Logbuch siehst du im Standard- und POTA-Log:
- **DXCC**: Länder gearbeitet / bestätigt (LoTW + eQSL)
- **WAZ**: CQ-Zonen
- **WAS**: US-States (zählt nur QSOs aus den USA)
- **QSOs**: Gesamt-Anzahl über alle Logs

Im Contest-Log wechselt der Counter auf **QSOs / Bands** des aktiven Contest-Logs.

## ADIF Import/Export

- **Export ADIF**: Toolbar des aktuellen Logs → exportiert alle QSOs als ADIF 3.x
- **Import ADIF**: legt ein neues Log mit allen QSOs aus der Datei an
- **Cabrillo-Export**: nur bei Contest-Logs sichtbar, mit allen Header-Feldern aus dem Wizard vorbelegt
- **POTA-Multi-Park-Split**: bei einem POTA-Log mit mehreren Park-Refs schreibt der Export **eine Datei pro Park** im pota.app-Filename-Schema (`HB9HJI@K-1234 20260518.adi`). Details: [POTA-Modul](/modules/pota#multi-park-hopping-split-pro-park).

## Auto-Upload zu externen Logbüchern

::: tip Neu in 1.8.9
**Club Log** ist live: in **Einstellungen → Lookup & Upload → Club Log**
Email + Application-Password eintragen — alle neuen QSOs werden im
Hintergrund automatisch hochgeladen. Der App-API-Key ist enthalten,
seit dem 2026-Update von Club Log muss man den nicht mehr selbst
beantragen.
:::

Weitere Auto-Uploads (Stand 1.8.10):

- **QRZ Logbook** — API-Key in den Lookup-Settings eintragen
- **HamQTH Logbook** — Username + Password
- **LoTW** und **eQSL** — über regulären ADIF-Export-Workflow
- **pota.app** und **sotadata.org.uk** — aktuell manueller Upload
  via Browser, Auto-Upload steht für Phase 6 auf der Roadmap

## Tastenkürzel

| Kürzel | Aktion |
|---|---|
| `Cmd+Return` | QSO loggen |
| `Cmd+,` | Einstellungen |
| `Cmd+Shift+P` | Bandplan-Fenster öffnen |
| `Cmd+Opt+U` | Auf Updates prüfen |
| `Cmd+Shift+B` | Bug melden |
| `Tab` | nächstes Feld |
| `Shift+Tab` | vorheriges Feld |
