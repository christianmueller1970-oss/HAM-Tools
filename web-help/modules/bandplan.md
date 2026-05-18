---
title: IARU R1 Bandplan
description: Bandplan-Modul in HAM-Tools mit Sub-Tab, eigenem Fenster, Live-Frequenz-Marker und automatischer Awareness-Pille in allen QSO-Forms.
---

# IARU R1 Bandplan

HAM-Tools liefert den **IARU Region 1 Bandplan** mit — 22 Bänder
von 2200 m bis 1,25 cm, vollständig mit Subsegment-Aufteilung
(CW · SSB · Digital · Beacons · Satellite · etc.). Daten kommen aus
der mitgelieferten [`bandplan.json`](https://github.com/christianmueller1970-oss/HAM-Tools/blob/main/Sources/HAMRechner/Content/bandplan.json) im App-Bundle.

## Drei Zugriffswege

### 1. Sub-Tab im Logbuch
In der unteren Tab-Bar jedes Logbuch-Typs (DX, POTA, SOTA, WWFF, BOTA,
Contest) gibt es einen Sub-Tab **»Bandplan«**. Zeigt das aktive Band
mit allen Subsegmenten als Lineal-Darstellung. CAT-Frequenz wird als
Live-Marker eingezeichnet — verschiebt sich beim QSY am Radio
unmittelbar.

### 2. Eigenes Fenster (⌘⇧P) 🆕

::: tip Neu in 1.8.8
Tastenkürzel **⌘⇧P** oder Menü **Fenster → Bandplan-Fenster** öffnet
den kompletten Bandplan in einem eigenständigen Fenster — praktisch
auf einem Zweitmonitor während des Loggens oder Contests.
:::

Im Fenster:
- Alle 22 Bänder als horizontale Lineale untereinander
- Subsegmente farbcodiert nach Sendart (CW blau, Digital violett,
  SSB orange, Beacons rot, …)
- Aktive CAT-Frequenz als roter Marker
- Tooltip pro Subsegment mit Modus + Bandbreite + Lizenzklasse

### 3. Live-Awareness-Pille in allen QSO-Forms 🆕

::: tip Neu in 1.8.9
Beim Loggen sagt eine Pille in der Status-Bar sofort, ob deine
aktuelle Frequenz + Mode IARU-konform sind.
:::

| Pille | Bedeutung |
|---|---|
| 🟢 **im Band** | Frequenz im Band, Subsegment passt zum Mode |
| 🟠 **falsches Subsegment** | im Band, aber im falschen Bereich (z.B. SSB im CW-Subsegment) |
| 🔴 **außerhalb Amateurfunkband** | Frequenz liegt nicht in einem bekannten Band |

Reagiert live auf CAT-Frequenzwechsel. Aktiv in allen sechs
QSO-Forms (DX, Contest, POTA, SOTA, WWFF, BOTA).

Implementierung in `BandplanChecker.swift` — Mode-Compatibility ist
tolerant gehalten: »alle Sendearten«-Subsegmente (z.B. weite Bereiche
ab 50 MHz) lassen alles durch, damit du im 6 m Bandplan-Wildwest
keine Falschpositive bekommst.

## Bandüberblick

Die App kennt diese Bänder:

| Frequenzbereich | Bezeichnung |
|---|---|
| 135,7 – 137,8 kHz | **2200 m** |
| 472 – 479 kHz | **630 m** |
| 1810 – 1850 kHz | **160 m** |
| 3500 – 3800 kHz | **80 m** |
| 5351,5 – 5366,5 kHz | **60 m** |
| 7000 – 7200 kHz | **40 m** |
| 10100 – 10150 kHz | **30 m** |
| 14000 – 14350 kHz | **20 m** |
| 18068 – 18168 kHz | **17 m** |
| 21000 – 21450 kHz | **15 m** |
| 24890 – 24990 kHz | **12 m** |
| 28000 – 29700 kHz | **10 m** |
| 50000 – 52000 kHz | **6 m** |
| 70000 – 70500 kHz | **4 m** |
| 144000 – 146000 kHz | **2 m** |
| 430000 – 440000 kHz | **70 cm** |
| 1240 – 1300 MHz | **23 cm** |
| 2300 – 2450 MHz | **13 cm** |
| 3400 – 3410 MHz | **9 cm** |
| 5650 – 5850 MHz | **6 cm** |
| 10,0 – 10,5 GHz | **3 cm** |
| 24,000 – 24,050 GHz | **1,25 cm** |

## Mode-Compatibility (vereinfacht)

| Mode | Standard-Subsegment |
|---|---|
| CW | CW-Bereich (typisch Bandanfang) |
| SSB | Phone-Bereich (LSB <10 MHz, USB ≥10 MHz) |
| FT8/FT4/JT65 | dediziertes Digital-Segment (z.B. 7074 kHz für FT8 auf 40 m) |
| RTTY/PSK31 | Digital-Segment (oft direkt unter SSB) |
| AM | meist Phone-Segment |
| FM | nur 10 m und höher (29,5 MHz+, 6 m+, 2 m+) |

Bandplan-spezifische Sonderbereiche (Beacons z.B. 14,099–14,101 MHz,
Satellite-Subsegmente, EME-Fenster) sind in der `bandplan.json`
ausgelagert — Mode-Konflikte werden dort erkannt, aber tolerant
behandelt (orange »falsches Subsegment« statt »außerhalb Band«).

## Hinweis zu Region 2 / 3

Die App ist auf **IARU Region 1** ausgelegt (Europa, Afrika, Naher
Osten). Für die USA (Region 2) oder Asien-Pazifik (Region 3) gelten
abweichende Band-Grenzen und Subsegmente — die Pille kann dort
fälschlich »außerhalb Band« melden, obwohl die Frequenz lokal
zulässig wäre. Ein Multi-Region-Bandplan ist auf der Roadmap, aber
nicht für 1.x geplant.
