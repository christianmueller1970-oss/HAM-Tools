# Bekannte Bugs

Aktive Issues + Workarounds. Wird händisch gepflegt; gemeldete Bugs landen im Posteingang `bugs@funkwelt.net`.

## Aktiv

::: warning In Bearbeitung
Aktuell sind keine kritischen Bugs offen.
:::

## Behoben in v1.8.13

- Auto-Update-Check meldete »HAM-Tools ist aktuell«, obwohl auf dem Server eine neuere Version bereitstand — `isNewerBuild()` verglich nur das Build-Datum als String, Hotfix-Releases vom selben Tag (1.8.11 → 1.8.12 → 1.8.13) wurden so nicht erkannt. Jetzt numerischer Semver-Vergleich primär, Build-Datum nur als Tiebreaker. Wirkt ab dem 1.8.13-Build — wer auf 1.8.12 oder älter sitzt, muss einmalig manuell aus `/app/dmg/latest.dmg` updaten.
- Multi-Cluster: Host- oder Port-Änderungen an einem bereits aktiven Cluster-Node wurden vom Pool-Resync ignoriert (alter Client lief weiter). `applyActiveNodes()` macht jetzt einen Field-Diff und startet betroffene Clients gezielt neu.

## Behoben in v1.8.12

- App-Startcrash auf macOS 26.5 (echte Ursache): macOS 26.5's `Bundle.init(url:)` liefert für SwiftPM-Resource-Bundles bei manchen Setups nil — `Bundle.module` greift dann auf seinen `fatalError`-Fallback zurück und die App crashed direkt in `BOTARefService.init`. Der 1.8.11-Fix (Bundle-Format kanonisch umbauen) hat das nicht behoben. Ab 1.8.12 wird `Bundle.module` komplett umgangen: ein neuer `AppResource`-Helper sucht das Resource-Bundle selbst, toleriert verschiedene Bundle-Layouts und gibt nil statt zu crashen.

## Behoben in v1.8.11

- App-Startcrash auf macOS 26.5 (erster Versuch — siehe v1.8.12 für die echte Behebung): Bundle-Format-Korrektur in `build-dmg.sh`. Brachte allein noch keinen Erfolg, ist aber für saubere Code-Signing-Hygiene weiter im Build drin.

## Behoben in v1.8.10

- POTA-ADIF-Upload abgelehnt mit „Only a single STATION_CALLSIGN value is supported per log file" — beim FT8-Loggen über WSJT-X-Spots konnte mid-session der `my_call` von Home- auf Portable-Call wechseln (z.B. `HB9HJI` ↔ `IT/HB9HJI/P`). Jetzt zwei Sicherungen: WSJT-X-Importer nimmt für Outdoor-Logs immer das im Log-Wizard gewählte Aktivierungs-Rufzeichen; zusätzlich vereinheitlicht der POTA-Export auch alte gemischte Logs.
- Mode-Picker im Radio/CAT-Panel war ohne CAT-Verbindung gedimmt und nicht klickbar — Loggen ohne Funkgerät (z.B. Remote/Reise-Setup) war damit auf den zuletzt aktiven Mode festgenagelt. Jetzt immer klickbar; ohne CAT zusätzlich FT8/FT4/JT65/JT9/PSK31/JS8/Q65/MSK144 wählbar (Hamlib kennt diese nicht direkt — laufen am TRX über PKTUSB).

## Behoben in v1.8.9

- Club-Log-Upload: 403 Forbidden bei Email-Adressen mit `@` und anderen Sonderzeichen — Form-Encoding war nicht RFC-3986-konform und wurde von Club Logs nginx-WAF blockiert. Jetzt strikt RFC-3986-kodiert.
- Standard-DX-Log warnte bei Mehrfach-Logs desselben Calls (Lebens-Log/Stammrunde/Tages-Log) mit „Schon gearbeitet" — dort sinnlos. Dupe-Warnung jetzt nur noch in Programm-Logs (POTA/SOTA/WWFF/BOTA) und Contest.

## Behoben in v1.8.8

- POTA-ADIF-Upload wurde von pota.app abgelehnt — Export verwendete das ältere nicht-dokumentierte Feld `MY_POTA_REF`. Jetzt standardkonform mit `MY_SIG=POTA` + `MY_SIG_INFO`.
- WWBOTA-ADIF: alter Stub erzeugte kein hochladbares File — jetzt offizielles Format mit `MY_SIG=WWBOTA` und Komma-Liste in `MY_SIG_INFO` für Multi-Bunker.
- POTA Multi-Park-Hopping: pota.app verweigerte Komma-Listen in `MY_SIG_INFO` — Export schreibt jetzt automatisch eine eigene Datei pro Park.
- QRZ-Auto-Fill in POTA/SOTA/WWFF/BOTA-Logs übernahm nur den Namen, der Rest blieb leer — ADIF war DXCC-unvollständig. Jetzt zusätzlich QTH, Locator, Country, Continent, CQ-/ITU-Zone.
- Hopping-Feld beim Log-Anlegen zeigte nur Häkchen ohne Kontext — jetzt voller Name + Details (Park/Summit/Bunker) pro Eintrag.
- Bandplan war beengter Sub-Tab im Logbuch — jetzt eigenes Fenster (⌘⇧P, Menü *Fenster → Bandplan-Fenster*).

## Behoben in v1.8.7

- Update-System verglich die macOS-Mindestversion als String — „10.9" hätte fälschlich als höher als „10.15" gegolten. Jetzt strikt numerischer Versionsvergleich.
- Inkompatibler Update-Dialog zeigte aktivierbaren „Download öffnen"-Button, obwohl die DMG auf dem System nicht laufen würde. Jetzt deaktiviert mit klarer Begründung.

## Behoben in v1.8.6

- FAQ-Link „Updates rückgängig machen?" verwies auf `/app/dmg/` — der Pfad lieferte 403 statt eines Versions-Listings. Jetzt Verzeichnis-Index aller DMG-Versionen.
- Top-Nav-Download zeigte auf eine versionsspezifische DMG und veraltete bei jedem Release — jetzt versionsloses `latest.dmg` mit Auto-Symlink.

## Behoben in v1.8.5

- Bandmap als Sub-Tab im Logbuch eingeschränkt — jetzt zusätzlich als Pop-up-Fenster pro Band öffenbar, mehrere parallel auf einem Zweitmonitor sichtbar.
- DX-Propagation: keine globale Tag/Nacht-Sicht — neue Grayline-Karte als eigenes Fenster.
- Einstellungs-Zahnrad in der Logbuch-Top-Bar wurde schnell übersehen — entfernt, Einstellungen jetzt über das App-Menü "HAM-Tools → Einstellungen…" (⌘,) bzw. das Transceiver-Menü.

## Behoben in v1.8.4

- CAT-Verbindung trennte sich nach einem QSY oder Mode-Wechsel — Race-Condition zwischen Poll-Loop und Write-Operationen auf demselben rigctld-TCP-Socket. Neuer Client-Lock im CATController serialisiert alle Operationen.
- Spot-Klick wechselte zwangsweise vom DXClusters- in den Log-Sub-Tab. Du bleibst jetzt, wo du bist — der Draft füllt sich im Hintergrund.
- DX-Cluster-Tabelle zeigte „SSB" als Mode, obwohl LSB/USB band-abhängig korrekt ableitbar ist (jetzt automatisch).
- "Einstellungen…"-Eintrag im Transceiver-Menü reagierte nicht (alter NSApp-Selector durch SwiftUI-API ersetzt).
- 13"-MacBook-Air-Layout: rechte Sidebar (Propagation/Solar/Band Activity) passte nicht auf den Bildschirm, man musste scrollen.

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
