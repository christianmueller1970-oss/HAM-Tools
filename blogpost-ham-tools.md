---
title: "HAM-Tools — Die Schweizer-Taschenmesser-App für Funkamateure auf macOS"
date: 2026-05-15
author: Christian Mueller, HB9HJI
tags: [Amateurfunk, Software, macOS, Logbuch, POTA, SOTA, WWFF, BOTA, DX-Cluster, CAT, Hamlib]
summary: >
  Eine native macOS-App, die Logbuch, vier Award-Programme, DX-Cluster,
  CAT-Steuerung und über 25 Berechnungswerkzeuge in einem einzigen Tool
  vereint — plus eine Web-Version für alle, die nicht auf dem Mac sitzen.
---

# HAM-Tools — Die Schweizer-Taschenmesser-App für Funkamateure

*73 de HB9HJI* — heute möchte ich euch ein Projekt vorstellen, an dem ich
die letzten Monate intensiv gearbeitet habe: **HAM-Tools**, eine native
macOS-Anwendung, die ich ursprünglich aus reinem Eigenbedarf gestartet
habe und die inzwischen zu einer ausgewachsenen Funkamateurs-Workstation
gewachsen ist.

## Warum noch eine Amateurfunk-App?

Wer kennt es nicht: Für jede Aufgabe ein eigenes Tool. Ein Logbuch hier,
ein Antennenrechner da, ein DX-Cluster-Client als Drittes, ein
CAT-Programm für den Transceiver dazu — und zwischen allen Programmen
springt man hin und her, kopiert Frequenzen manuell und führt am Ende
doch wieder Papierlisten für Aktivierungen.

Mein Ziel mit **HAM-Tools** war es, all das in **einer einzigen, sauber
integrierten macOS-App** zusammenzuführen. Nativ in Swift / SwiftUI
entwickelt, ohne Electron-Bloat, ohne Java-Runtime — einfach öffnen
und funken.

## Was kann HAM-Tools (Stand V1.8.2)?

Die App ist in drei große Bereiche gegliedert:

### 1. Logbuch mit vier vollwertigen Award-Programmen

Im Zentrum steht ein **Desktop-Logger** mit Multi-Log-Architektur —
sprich: Ein Logbuch pro Aktivität, alle als eigene `.htlog`-SQLite-Datei.
Daneben laufen vier komplett ausgebaute Award-Programme:

- **POTA** (Parks on the Air) — ~91 000 Parks aus *pota.app*, Activator
  und Hunter, 10-QSO-Counter, Multi-Park-Hopping, Live-Spots, Karte mit
  Park-Markern
- **SOTA** (Summits on the Air) — ~181 000 Gipfel aus *sotadata.org.uk*,
  Activator und Chaser, 4-QSO-Counter mit Winterbonus, Summit-to-Summit
- **WWFF** (Worldwide Flora & Fauna) — Doppelpfad-Datenquelle (URL +
  CSV-Import), 44-QSO-Counter, Reference-to-Reference
- **BOTA** (Bunkers on the Air) — CSV-Import-DB, Bunker-to-Bunker,
  DX-Cluster-Spots mit DB-Match

Die Award-Programme teilen sich einen gemeinsamen **Outdoor-Sub-Picker**,
sodass die Bedienung über alle vier konsistent bleibt und sich das
Layout problemlos um weitere Programme erweitern lässt.

Zusätzlich:

- **Callbook-Lookup** über QRZ.com und HamQTH.com mit Primary/Fallback,
  30-Tage-Cache und Profilbild
- **Auto-Fill bei TAB** — Name, QTH, Locator, CQ-Zone, ITU, DXCC werden
  beim Eintippen des Calls automatisch ergänzt
- **Previous-Button** zeigt alle früheren QSOs mit demselben Call über
  *alle* Logs
- **Duplicate-Warnung** (Exact + Recent-Match in 30 min)
- **ADIF 3.x Import / Export / Merge** mit drei Strategien
- **Cabrillo V3 Export** für Contest-Einreichungen
- **Auto-Backup** vor jeder riskanten Aktion

Neu in **V1.8.2**:

- **Multi-Call-Lizenz** — die App kennt jetzt mehrere Calls (Privatcall +
  Club-Call) und validiert Portabel-Suffixe (`HB9HJI/P`, `DL/HB9HJI`,
  `F/HB9HJI/MM`) sauber an den `/`-Grenzen
- **Pro-Log-Callsign** — jedes Logbuch kann ein eigenes Stations-Call
  führen (Portabel, Ausland, Club), Live-Validation gegen die Lizenz
- **Multi-Op-Contest** — OP-Liste pro Contest-Log, OP-Switcher in der
  Header-Bar, Pro-Operator-Auswertung im Awards-Tab
- **Lizenz-Generator als App-Bundle** — Developer-ID-signiert, einfach
  per Drag & Drop nach `/Applications`

### 2. Live-Tools — Volle DX-Cluster-Workstation + CAT

Statt eines simplen Spot-Listings habe ich eine **komplette
DX-Cluster-Workstation** eingebaut:

- TCP-Verbindung zu mehreren DXSpider-Knoten parallel
  (Funkwelt, HB9W, DB0ERF, OE5TXF, ON0ANT, VE7CC)
- **Bandmap** mit Frequenz-Balkendiagramm pro Band
- **MapKit-Weltkarte** mit Spot-Markern und Spotter-Linien
- **Statistik** mit SwiftUI-Charts (Spots/Band, Spots/Mode, Top-15-DX,
  24h-Verlauf)
- **Propagations-Panel** mit NOAA SFI/Kp-Gauges und Band-Activity-Heatmap
- **REST-API-Fetcher** für SOTA, POTA und WWFF (Live-Polling)
- **DX-Spot senden** direkt aus der App
- **Watch List / Alerts** mit macOS-Benachrichtigungen und
  ★-Markierung im Logbuch
- **Spotter-Radius-Filter** über Haversine-Distanz vom eigenen QTH
- **Spot-Bridge ins Logbuch** — Doppelklick auf einen Spot füllt das
  QSO-Formular vor und extrahiert POTA-/SOTA-Refs automatisch aus dem
  Kommentar

**CAT-Steuerung via Hamlib** ist seit V1.6 fester Bestandteil der App:

- 13 vorbereitete TRX-Profile: **Icom** IC-7300 / IC-705 / IC-9700,
  **Yaesu** FT-991 / FT-857 / FT-817, **Kenwood** TS-2000 / TS-590S /
  TS-480, **Elecraft** K3 / KX2 / KX3 plus Hamlib-Dummy zum Testen ohne
  Hardware
- Hamlib 4.7.1 als statischer Universal2-Build (arm64 + x86_64) **im
  App-Bundle mitgeliefert** — keine Homebrew-Abhängigkeit, kein extra
  Setup
- **Multi-Config**: mehrere benannte CAT-Profile (z.B. "Home-IC7300",
  "Portable-IC705"), beliebig umschaltbar
- Frequenz und Mode kommen live vom Transceiver in das QSO-Formular,
  „QSY-bei-Copy" auf Spots springt direkt auf die gespotteten Frequenz

Außerdem gibt es **3 Themes** (HAM Style, Dark, Ham Classic), die im
laufenden Betrieb gewechselt werden können.

### 3. Über 25 Berechnungswerkzeuge

Das ursprüngliche Herzstück und der Grund, warum die App intern noch
„HAMRechner" heißt:

- **Drahtantennen:** Dipol, Groundplane, J-Pole / Slim Jim, Sperrtopf,
  Windom (OCFD), EFHW mit Verkürzungsspule, Loop
- **Richtstrahler:** Moxon, HB9CV, Hexbeam (G3TXQ, mehrbandig mit Drauf-
  und Seitenansicht), Yagi nach Rothammel (2–6 Elemente),
  Spiderbeam Mono- und Multiband
- **Spezialantennen:** Magnetic Loop (Kapazität, Güte, Bandbreite),
  freier Antennen-Designer
- **Spulen & Transformatoren:** Balun / Unun (1:1, 4:1, 9:1…),
  Strahler-Verlängerung, Luftspulen-Wickler
- **Anpassung & Leitungen:** L-Netz, λ/4- und λ/2-Koax-Stub mit Schema,
  Kabeldämpfung verschiedener Koax-Typen
- **Signale & Tools:** Pegel-Umrechner (dBm / dBW / V / µV / W),
  SWR-Simulator, Linkbudget / Reichweite (Friis), **QTH-Locator** mit
  Maidenhead-Konvertierung, Karte, Höhenprofil, Fresnel-Zonen und
  LOS-Berechnung mit Erdkrümmung
- **NEC2-Antennensimulator** im Browser via WebAssembly — Drahtmodell
  zeichnen, Strahlungsdiagramm und SWR-Sweep direkt im Web; in der
  nativen App per WKWebView eingebettet, sodass nur eine Code-Basis
  gepflegt werden muss

## Auch im Browser: toolbox.funkwelt.net

Wer nicht am Mac sitzt — die **Rechner-Tools sind 1:1 als Web-App
portiert** und laufen unter:

→ **[toolbox.funkwelt.net](https://toolbox.funkwelt.net)**

Stack: Vue 3 + Vite, gehostet auf eigenem Debian-Root-Server mit
HTTPS via Let's Encrypt. Die Web-Version umfasst aktuell die
Berechnungs-Tools (Antennen, Spulen, Anpassung, Locator, Linkbudget …)
und denselben Theme-Schalter. Das Logbuch und die DX-Cluster-Workstation
bleiben aufgrund der lokalen SQLite- und TCP-Anbindung der nativen
macOS-App vorbehalten.

## Was steckt unter der Haube?

- **Sprache:** Swift 5.9 / SwiftUI, sauber in Features/Models/Views/
  ViewModels strukturiert
- **Persistenz:** SQLite pro Logbuch, JSON-Caches für Spots / Callbook /
  Memories, App-Settings in UserDefaults
- **Daten zentral:** Alles unter einem konfigurierbaren Datenordner
  (Default `~/Documents/HAM-Tools/`) — Logs, Cache, Exports, Backups,
  Audio in jeweils eigenen Unterordnern
- **Auto-Migration** vom Legacy-Pfad beim ersten Start
- **Native macOS-Features:** Benachrichtigungen, MapKit, SwiftUI-Charts,
  Dark Mode, hochauflösende Icons
- **In-App-Update-Check** via signiertem JSON-Manifest auf
  `toolbox.funkwelt.net` — App erkennt neue Versionen beim Start und
  bietet Download an

## Voraussetzungen

- **macOS 14 (Sonoma) oder neuer**  
  *(Hintergrund: SwiftUI-APIs, die für die App nötig sind, sind erst ab
  Sonoma verfügbar. macOS 12/13 läuft leider nicht — Beta-Tester-Feedback
  hat das bestätigt.)*
- Apple Silicon oder Intel (Universal2-Build)

## Lizenz und Verfügbarkeit

HAM-Tools steht unter **MIT-Lizenz** — freie Nutzung, Weitergabe und
Modifikation mit Nennung des Autors. Der Quellcode ist auf GitHub
einsehbar:

→ [github.com/christianmuller1970-oss/HAM-Tools](https://github.com/christianmuller1970-oss/HAM-Tools)

Die aktuelle Version **V1.8.2** gibt es als Developer-ID-signiertes DMG
zum Download — direkt aus der App heraus über den Update-Check oder
manuell unter toolbox.funkwelt.net.

## Was kommt als nächstes?

Auf der Roadmap stehen unter anderem:

- **Upload-APIs** für LoTW, eQSL, Club Log und pota.app direkt aus der
  App heraus (Phase 6)
- **Voice-Keyer / Audio-Recordings** (Phase 11)
- Weitere **Award-Programme** im Outdoor-Sub-Picker
- **Contest-Engine** mit live Score, Super-Check-Partial und F1–F8-Macros
- Erweiterung des **NEC2-Simulators** um 3D-Pattern und komplexere
  Mehrelement-Antennen

## Feedback gesucht!

HAM-Tools ist und bleibt ein **Hobbyprojekt aus der Praxis** — gerade
deshalb ist mir das Feedback aus der Community besonders wichtig.
Wenn ihr Bugs findet, Features vermisst oder einfach mal Hallo sagen
wollt:

- **Issues / Bugs:** [GitHub Issues](https://github.com/christianmuller1970-oss/HAM-Tools/issues)
- **Web-Tools & Direkt-Kontakt:** [toolbox.funkwelt.net](https://toolbox.funkwelt.net) / [funkwelt.net](https://funkwelt.net)
- **Im Cluster:** HB9HJI — meistens auf 40 / 20 / 17 m anzutreffen

Ich freue mich riesig, wenn die App dem einen oder anderen OM oder YL
das Funkerleben erleichtert.

**73 de HB9HJI**  
*Christian Mueller, JN47PN*
