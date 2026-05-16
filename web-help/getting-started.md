---
title: Erste Schritte mit HAM-Tools
description: Installation, Lizenz aktivieren und erstes QSO loggen in 5 Minuten. Schritt-für-Schritt-Anleitung für macOS-Funkamateure.
---

# Erste Schritte

Vom Download bis zum ersten geloggten QSO — in 5 Minuten.

## Systemvoraussetzungen

| Anforderung | Wert |
|---|---|
| **macOS** | **14.0 Sonoma** oder neuer |
| **Architektur** | Apple Silicon (M1/M2/M3/M4) oder Intel (Universal2-Build) |
| **Festplatte** | ~80 MB für die App + Logs |
| **Internet** | nur für DX-Cluster, QRZ/HamQTH-Lookup, Updates — Logging selbst läuft offline |

::: warning macOS 12 / 13 wird nicht unterstützt
HAM-Tools nutzt SwiftUI-APIs aus macOS 14 (z.B. die neue MapKit-DSL und
`onChange`-Signatur). Auf älteren Systemen erscheint *„Du kannst diese Version
des Programms nicht mit dieser Version von macOS verwenden"*.

macOS 14 ist als **kostenloses Apple-Update** für alle Macs ab Baujahr **2018**
verfügbar. Falls dein Mac älter ist, gibt es leider aktuell keine Version für
dich — ein Backport auf macOS 13 ist mittelfristig möglich, aber nicht für 1.x
geplant.
:::

## 1. App installieren

1. Lade das aktuelle DMG: [HAM-Tools (latest.dmg)](https://toolbox.funkwelt.net/app/dmg/latest.dmg) — der Link zeigt immer auf die aktuelle Version. Ältere Versionen findest du im [Versions-Archiv](https://toolbox.funkwelt.net/app/dmg/).
2. Doppelklick auf das DMG → das Fenster zeigt die `HAM-Tools.app` und einen `Applications`-Shortcut
3. **App in den Applications-Ordner ziehen** (per Drag&Drop)
4. DMG schließen + auswerfen

### Gatekeeper-Hinweis (entfällt ab notarisiertem Build)

Bei einer **nicht-notarisierten** Vorversion erscheint beim ersten Öffnen evtl. *"App ist beschädigt"* oder *"Nicht identifizierter Entwickler"*. Workaround:

```sh
sudo xattr -dr com.apple.quarantine /Applications/HAM-Tools.app
```

Oder ohne Terminal: **Systemeinstellungen → Datenschutz & Sicherheit** ganz unten scrollen → *"HAM-Tools.app wurde blockiert"* → **Trotzdem öffnen**.

::: tip
Ab Version 1.7.1 ist die App **Apple-notarisiert**. Der Workaround entfällt damit.
:::

## 2. Lizenz aktivieren

Ohne Lizenz läuft die App im **Demo-Modus**: 50 QSOs cumulativ, danach Read-Only (alles lesbar + exportierbar, aber kein neues Loggen). Die Lizenz schaltet unbegrenztes Loggen frei.

1. **Mail an `hb9hji@funkwelt.net`** mit deinem Rufzeichen + Name
2. Du bekommst einen ~300-Zeichen-Lizenz-String per Antwort
3. In der App: **Cmd+,** → **Lizenz**-Tab
4. **Lizenz-String einfügen** → **"Lizenz übernehmen"**
5. Status sollte grün auf **"Vollversion aktiv"** springen

Details: [Lizenz aktivieren →](/license)

## 3. Station konfigurieren

Damit die App weiß, wer du bist:

1. **Cmd+,** → **Station**-Tab
2. Eintragen:
   - **Rufzeichen:** dein offizielles Call (z.B. `HB9HJI`)
   - **QTH-Locator:** dein Maidenhead-Locator 6-stellig (z.B. `JN47PN`)
   - Optional: Name, CQ-Zone (CH = 14), ITU-Zone (CH = 28), Kanton

::: tip
Das **Callsign** wird mit der Lizenz abgeglichen — es muss zu den lizenzierten
Rufzeichen passen, sonst geht die App in den Demo-Modus.
:::

## 4. Erstes QSO

Die App startet direkt im **Logbuch** mit dem **DXClusters-Sub-Tab** aktiv. Beim ersten Start ist noch kein Log angelegt — Sheet erscheint automatisch.

1. Im DX-Cluster-Tab unten einen interessanten Spot **doppelklicken** → Call + Frequenz werden ins Eingabe-Panel übernommen, CAT (falls aktiv) springt auf die Frequenz
2. RST eingeben, ggf. weitere Felder (Name aus Callbook, Locator …)
3. **Cmd+Return** oder Klick auf **"Log QSO"** → QSO landet in der Tabelle

## 5. Nächste Schritte

- [Logbuch-Module verstehen](/modules/logbuch) — Multi-Log, Sub-Tabs, History
- [Contest starten](/modules/contest) — Wizard, Score-Panel, Cabrillo-Export
- [CAT verbinden](/modules/cat) — Radio-Modell wählen, CI-V (bei ICOM), Multi-Config
- [POTA-Workflow](/modules/pota) — Activator vs. Hunter, Park-Hopping
