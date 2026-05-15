# Bekannte Bugs

Aktive Issues + Workarounds. Wird händisch gepflegt; gemeldete Bugs landen im Posteingang `bugs@funkwelt.net`.

## Aktiv

::: warning In Bearbeitung
Aktuell sind keine kritischen Bugs offen.
:::

## Behoben in v1.8.3

- BOTA-Map Sub-Tab erschien fälschlich im Standard-DX-Log (nur im BOTA-Programm-Log sinnvoll)
- "Neuer Contest"-Sheet war zu klein → Buttons "Abbrechen / Anlegen" im Kategorien-Schritt abgeschnitten
- POTA-Spalten "State" und "Their Park" wurden im Standard-Log angezeigt, obwohl sie nur in POTA-Logs Sinn ergeben
- Spalten-Auswahl der QSO-Tabelle war nur via Header-Rechtsklick erreichbar → neuer "Spalten"-Button in der Toolbar mit allen 32 Spalten + Reset
- Spot-Tabellen (DX/POTA/SOTA/BOTA/WWFF) hatten keine Reorder-/Hide-Show-Funktion → komplett auf SwiftUI Table umgestellt

## Behoben in v1.7.1

- Cluster-Click füllte das Contest/POTA-Form nicht — Race-Condition zwischen QSOEntryPanel und dem spezialisierten Form
- Mode-Picker im Contest zeigte alle Modes statt nur die zur Cabrillo-Mode-Kategorie passenden
- "Neu…"-Button für CAT-Config kopierte den Serial-Port nicht mit
- DX-Cluster im Contest zeigte Spots in allen Modes statt nur Contest-Mode

## Behoben in v1.7.0

- Sidebar mit 42 Tools war unübersichtlich → 3 Top-Punkte (Logbuch / DX-Cluster / Rechner) mit Akkordeon
- Bandplan war eigener Sidebar-Eintrag → in Logbuch-Sub-Tab verschoben
- DX-Cluster verband erst beim Tab-Klick → jetzt global beim App-Start

## Bug melden

In der App: **Cmd+Shift+B** oder Menüleiste → Hilfe → Bug melden…
Per Mail: `bugs@funkwelt.net`
