---
title: DX-Cluster — Spots mit ATNO/NEW-BAND/NEW-MODE-Live-Markierung
description: DX-Cluster in HAM-Tools mit eigenem DXSpider, POTA/SOTA-Live-Feeds, WWFF/BOTA-Filter, Watchlist und ATNO-Markierung pro Spot.
---

# DX-Cluster

HAM-Tools verbindet sich beim App-Start mit dem eigenen
**DXSpider-Cluster `dxspider.funkwelt.net:7300`** und ergänzt die
Telnet-Spots um programm-spezifische Live-Feeds:

- **POTA-Spots** aus `api.pota.app/spot/activator` (alle 60 s)
- **SOTA-Spots** aus `api2.sota.org.uk` (alle 60 s)
- **WWFF-Spots** aus dem Cluster-Stream (Pattern-Match auf `XXFF-NNNN`)
- **BOTA-Spots** aus dem Cluster-Stream (Pattern + DB-Match)

Welcher Feed im unteren Tab sichtbar ist, hängt vom aktiven Log ab:
Standard-Log → klassischer DX-Cluster, POTA-Log → POTA-Feed,
SOTA-Log → SOTA-Feed usw.

## ATNO-Live-Markierung 🆕

::: tip Neu in 1.8.9
Pro Spot im DX-Cluster zeigt eine farbige Pille direkt links vom
Rufzeichen, ob das DXCC-Country/Band/Mode für dich noch interessant
ist:
:::

- **🔴 ATNO** — All Time New One: DXCC-Country noch nie gearbeitet
- **🟠 NEW BAND** — Country schon gearbeitet, aber nicht auf diesem Band
- **🟡 NEW MODE** — Country+Band schon, aber nicht in diesem Mode
- **keine Pille** — schon vollständig gearbeitet

Die Worked-Sets werden live aus dem `DXCCAccumulator` abgeleitet, der
ohnehin pro Log läuft — kein zusätzlicher Scan, der Lookup ist O(1)
pro Spot. Update passiert sofort nach jedem geloggten QSO.

::: info Nur im Standard-DX-Log
ATNO ist im **Standard-DX-Log** und im **DX-Cluster-Pop-up** aktiv.
Im Contest dominiert die Dupe/Mult-Färbung (rot = Dupe, grün = neuer
Multiplier). In den Outdoor-Programmen zeigt der jeweilige Spots-Tab
seine eigene Ref-Match-Logik (P2P/S2S/R2R/B2B).
:::

## Bandplan-Live-Awareness in QSO-Forms 🆕

::: tip Neu in 1.8.9
In allen sechs QSO-Forms (DX, Contest, POTA, SOTA, WWFF, BOTA) zeigt
eine Pille in der Status-Bar sofort beim Loggen, ob Frequenz + Mode
IARU-R1-konform sind.
:::

- **🟢 im Band** — Sub-Segment passt zum Mode (z.B. SSB im SSB-Bereich)
- **🟠 falsches Subsegment** — z.B. SSB im CW-Bereich, FT8 außerhalb
  des Digi-Subsegments
- **🔴 außerhalb Amateurfunkband** — Frequenz liegt komplett außerhalb
  aller bekannten Bänder

Datenquelle ist die mitgelieferte `bandplan.json` (22 Bänder + Sub-
Segmente). Die Mode-Compatibility-Tabelle ist tolerant —
„alle Sendearten"-Subsegmente lassen alles durch. Reagiert live auf
CAT-Frequenzwechsel.

## Spalten & Filter

Die Spot-Tabelle zeigt standardmäßig: ATNO-Pille · Spotter · Call ·
Frequenz · Band · Mode · Comment · Alter. Spalten sind
**reorder- und ausblendbar** per Header-Rechtsklick oder den
**„Spalten"-Button** in der Toolbar (mit Reset).

Filter:

- **Watchlist**: bevorzugte Calls werden gelb markiert und können
  optional nach oben gepinnt werden
- **Award-Modes**: zeigt nur Spots in Modes, die du in den
  Award-Settings aktiv hast (z.B. nur CW + Digi)
- **Contest-Modus**: bei einem Contest-Log wird die Spot-Liste
  automatisch auf Contest-Bänder + Mode-Kategorie eingeschränkt

## Aktionen pro Spot

- **Doppelklick** → Call + Frequenz + Mode ins Logbuch-Eingabe-Panel,
  CAT springt mit (falls verbunden)
- **Rechtsklick** → Context-Menü mit „Ins Logbuch eintragen" /
  „Auf Watchlist setzen" / „QRZ.com öffnen"
- **★** vor dem Call → Spot ist auf der Watchlist

Spot-Klick wechselt **nicht** zwangsweise vom DXClusters-Tab in den
Log-Sub-Tab — du bleibst, wo du bist (Fix aus 1.8.4).

## Bandmap-Pop-up

Pro Band kannst du eine eigene **Bandmap als Pop-up-Fenster** öffnen
(neu in 1.8.5). Mehrere parallel auf einem Zweitmonitor möglich —
ideal beim Contest oder bei DX-Pile-Ups, wo du gleichzeitig 20 m und
40 m im Blick haben willst.

## Konfiguration

**Einstellungen → Cluster**:
- Multi-Node-Setup (mehrere DX-Cluster-Verbindungen parallel)
- Eigene Cluster-URLs ergänzen (Hostname:Port + Login-Call)
- Status-Anzeige + Re-Connect-Button pro Node
