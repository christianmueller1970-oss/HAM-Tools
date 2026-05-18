---
title: Antennen- und Funk-Rechner
description: 25+ Rechner in HAM-Tools für Drahtantennen, Richtstrahler, Spulen, Anpassung, Smith-Chart und Antennen-Simulator.
---

# Antennen- & Funk-Rechner

HAM-Tools bringt **25+ Rechner** aus der Funk-Praxis mit — alle nativ
in SwiftUI, ohne Webview, mit Live-Diagrammen wo sinnvoll und kurzen
Markdown-Beschreibungen pro Rechner (Tipp-Button im Form-Header).

In der **Sidebar links** unter „Rechner" findest du sie gruppiert:

## Drahtantennen

| Rechner | Zweck |
|---|---|
| **Dipol** | λ/2-Halbwellendipol mit Verkürzungsfaktor, isoliert/blank, alle Bänder |
| **Groundplane / Vertikal** | λ/4 mit Radials (2–4 Stück), Stockungsfaktor je Aufbau |
| **J-Pole / Slim Jim** | Endspeisung mit Stub-Anpassung, beliebte Portable-Antenne |
| **Sperrtopf (Bazooka)** | Koax-Choke direkt am Speisepunkt |
| **Windom / OCFD** | Off-Center-Fed-Dipol mit 4:1- oder 6:1-Balun |
| **EFHW-Antenne** | End-Fed Half-Wave mit 49:1-Trafo, Multiband-Variante |
| **EFHW-Verkürzung** | Spulen-Verkürzung für portable EFHW |
| **Loop-Antenne** | Voll-Wellen-Loop oder λ/2-Loop, vertikal/horizontal |

## Richtstrahler

| Rechner | Zweck |
|---|---|
| **Moxon Rectangle** | 2-Element-Beam, kompakt, breitbandig |
| **HB9CV Beam** | 2-Element-Phased-Array nach HB9CV-Original |
| **Hexbeam** | 6-Band-G3TXQ-Hexbeam, WiMo HEX6B-konform |
| **Yagi-Rechner** | 3–7-Element-Yagi mit Reflektor + Direktoren |
| **Spiderbeam Einzelband** | Drahtkreuz mit Direktoren, pro Band |
| **Spiderbeam Multi-Band** | Multiband-Drahtkreuz 20-17-15-12-10 m |

## Spezialantennen

| Rechner | Zweck |
|---|---|
| **Magnetic Loop** | Kondensator + Schleifenfläche, Q-Faktor, Bandbreite |

## Spulen & Transformatoren

| Rechner | Zweck |
|---|---|
| **Balun / Unun** | Spannungs- und Stromsymmetrie mit Trafo (1:1 / 4:1 / 9:1) |
| **Mantelwellensperre** | Common-Mode-Choke mit Ferrit, Wicklungszahlen |
| **Strahler-Verlängerung** | Verkürzungs-/Verlängerungs-Spule für Mobilantennen |
| **Spulen-Wickler** | Luftspulen, Drahtdurchmesser, Windungszahl, Induktivität |

## Anpassung & Leitungen

| Rechner | Zweck |
|---|---|
| **Anpassnetzwerk (L-Netz)** | L-Match mit zwei Elementen, Hoch-/Tiefpass-Variante |
| **Koax-Stub** | λ/4 oder λ/2-Stub-Anpassung mit Wellenwiderstand |
| **Kabeldämpfung** | Dämpfung pro 100 m bei Wunsch-Frequenz, Standardkabel-DB |

## Signale & Tools

| Rechner | Zweck |
|---|---|
| **Pegel-Umrechner** | dBm ↔ dBW ↔ W ↔ V ↔ S-Stufen |
| **SWR-Simulator** | Reflexionsfaktor, Rücklauf-Dämpfung, VSWR-Visualisierung |
| **Linkbudget / Reichweite** | Funkstrecken-Berechnung mit Pfaddämpfung |
| **QTH-Locator** | Maidenhead ↔ Geo-Koordinaten, Distance/Bearing |
| **Smith-Chart** | Interaktives Smith-Diagramm mit Matching-Pfaden |
| **Antennen-Simulator** | Web-NEC2-Simulator (in Vorbereitung, siehe [Erweiterungs-Plan](https://github.com/christianmueller1970-oss/HAM-Tools/blob/main/ERWEITERUNGEN_PLAN.md)) |

## Einheitliches Bedienkonzept

Jeder Rechner hat denselben Aufbau:

- **Eingaben** links/oben — Frequenz, Materialparameter, Geometrie
- **Ergebnisse** rechts/unten — Live-Update bei jeder Eingabe, kein
  »Berechnen«-Button nötig
- **Diagramm / Visualisierung** wo es Sinn macht (Smith-Chart, SWR-
  Kurve, Strahler-Geometrie, Spulen-Schnitt)
- **Material-Auswahl** wo relevant (Draht-Durchmesser AWG/CCS, Koax-
  Typ RG-58/RG-213/H2000, Spulen-Form)
- **Info-Button** im Form-Header öffnet die Markdown-Doku pro Rechner
  mit Hintergrund + Formel + Praxisempfehlungen

## Web-Variante

Die Hauptrechner gibt es auch auf
**[toolbox.funkwelt.net](https://toolbox.funkwelt.net)** als
Web-App — gleiche Engine, Vue-3-UI, ideal für mobile Nutzung im
Feld oder zum schnellen Nachsehen am Smartphone. Die macOS-App ist
funktional umfangreicher (mehr Rechner, Smith-Chart, Antennen-Simu,
Logbuch-Integration).

## Hexbeam: G3TXQ-Konformität

::: tip Verifizierung Juni 2026
Der **Hexbeam-Rechner** wurde auf Basis der offiziellen WiMo
EAntenna HEX6B Bauanleitung (G3TXQ-Lizenz, Rev. V2.1) implementiert
und durch HB9EIZ topologisch korrigiert. Reale Verifikation am
eigenen WiMo-HEX6B-Aufbau zusammen mit HB9EIZ ist für Juni 2026
geplant — Ergebnisse fließen in eine eventuelle Modell-Nachjustierung.
:::

## Mehr im Detail

Die ausführlichen Rechner-Beschreibungen mit Formeln, Quellen und
Praxisempfehlungen sind **in der App** pro Rechner verfügbar
(Info-Symbol im Form-Header). Diese Seite hier ist absichtlich knapp
gehalten — eine eigene Web-Doku pro Rechner kommt in einer späteren
Iteration.
