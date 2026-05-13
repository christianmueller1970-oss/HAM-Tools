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
3. Name + Notizen → **Anlegen**

### Log wechseln

Top-Bar → Klick auf Log-Namen → Popover mit allen offenen Logs → klick zum Wechsel. Sub-Tab-State (Spaltenbreiten, Filter) wird **pro Log-Typ separat** gespeichert.

## Sub-Tabs

Unter dem QSO-Eingabe-Panel siehst du die **Tab-Leiste** mit modul-spezifischen Ansichten. Welche Tabs sichtbar sind, hängt vom Log-Typ ab:

| Tab | Standard | POTA | Contest |
|---|---|---|---|
| Log (QSO-Tabelle) | ✓ | ✓ | ✓ |
| Map (weltweit) | ✓ | ✓ | ✓ |
| Bands (Heatmap) | ✓ | ✓ | ✓ |
| DXClusters | ✓ | ✓ (POTA-Spots-Feed) | ✓ (gefiltert) |
| Awards (DXCC/WAZ/WAS/POTA) | ✓ | ✓ | — |
| Memories (Sked-Liste) | ✓ | ✓ | — |
| History (QSO-Karten-Chronik) | ✓ | ✓ | — |
| POTA-Map | — | ✓ | — |
| Contest-Map | — | — | ✓ |
| Bandplan | ✓ | ✓ | ✓ |

::: tip
Der **DXClusters-Tab** ist der Standard beim App-Start — direkt nach dem Öffnen siehst du die aktuellen Spots und kannst per Doppelklick auf einen interessanten Spot direkt loggen.
:::

## QSO-Eingabe-Panel

Drei Modi via Tabs ganz oben im Panel:

- **DX** — generischer QSO-Workflow (Call, RST, Name, Locator, POTA/SOTA-Refs)
- **Contest** — schlanke Eingabe mit dynamischen Exchange-Feldern aus dem Contest-Template
- **POTA** — Hunter- oder Activator-Workflow mit Park-Referenzen

Der aktive Modus folgt automatisch dem Log-Typ:
- Standard-Log → DX-Modus
- Contest-Log → Contest-Modus
- POTA-Log → POTA-Modus

### Auto-Fill aus DX-Cluster

Doppelklick auf einen Spot in der **DXClusters**-Tabelle oder **Cluster-Tab** füllt Call + Frequenz + Mode ins Eingabe-Panel. Wenn CAT aktiv ist, springt zusätzlich das Radio auf die Frequenz.

### Auto-Fill aus Callbook

Sobald du das Call-Feld verlässt (Tab oder Enter), startet ein **QRZ/HamQTH-Lookup**. Name, Locator, Country werden eingetragen. Auto-Retry läuft beim Loggen, falls der erste Versuch nichts brachte.

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

## Tastenkürzel

| Kürzel | Aktion |
|---|---|
| `Cmd+Return` | QSO loggen |
| `Cmd+,` | Einstellungen |
| `Cmd+Opt+U` | Auf Updates prüfen |
| `Cmd+Shift+B` | Bug melden |
| `Tab` | nächstes Feld |
| `Shift+Tab` | vorheriges Feld |
