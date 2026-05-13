---
title: Contest-Modus — 14 Templates mit Cabrillo V3
description: Vollständiger Contest-Logger für macOS mit Helvetia, CQ-WW, CQ-WPX, ARRL-DX, IARU, DARC-WAG, WAE. Wizard, Live-Score, Dupe-Markierung, Multiplier-Erkennung, Cabrillo V3-Export.
---

# Contest

Vollständiger Contest-Logger mit 14 Templates, Live-Score, Dupe-Markierung und Cabrillo V3-Export.

## Contest starten

1. Top-Bar → **Logs** → **Neues Log** → **Contest**-Karte → öffnet den Wizard
2. **Schritt 1: Template wählen** — Liste aller mitgelieferten Contests mit Suche:
   - **HB-Familie**: Helvetia (H26), USKA Field Day SSB/CW, USKA 50 MHz
   - **CQ-Familie**: CQ-WW CW/SSB, CQ-WPX CW/SSB
   - **DX**: ARRL DX CW/SSB, IARU-HF, DARC-WAG, WAE-DX CW/SSB
3. **Schritt 2: Cabrillo-Kategorien** — Operator (Single-Op, Multi-Two, …), Power (High/Low/QRP), Band (ALL / 160M / …), **Mode (wichtig!)**, Station (Fixed/Portable), Assisted, Time
4. **Anlegen** → der Contest-Log ist erstellt und wird aktiv

::: tip Wichtig: Mode-Auswahl im Wizard
Wenn du im Wizard z.B. **Mode: PH** (= SSB) wählst, filtert die App den **Mode-Picker im Contest-Form**, den **DX-Cluster** und das **Stats-Panel** automatisch auf SSB. Bei **MIXED** sind alle Modes erlaubt.
:::

## Contest-Form

Das Eingabe-Panel im Contest ist schlank gehalten — keine generischen DX-Felder, sondern nur die Felder aus dem Cabrillo-Exchange-Schema des Templates:

- **Call** (mit Dupe-Erkennung — Call+Band+Mode bereits geloggt → roter Border + Toast)
- **Band/Mode** (Band aus CAT, Mode auf erlaubte Werte beschränkt)
- **Sent**: dynamische Felder aus dem Template (z.B. RST + Serial, oder RST + Kanton)
- **Recv**: dynamische Felder (auto-Auswahl je nach Recv-Call: HB → Kanton, DX → Serial)
- **Run / S&P-Toggle** (gespeichert pro QSO im `contestIsRun`-Flag)

### Helvetia-Spezialfall

Bei Helvetia ändert sich das Recv-Feld **live** beim Tippen des Calls:
- `HB9XX` → Recv-Feld zeigt **Kanton** (z.B. `ZH`)
- `DL1ABC` → Recv-Feld zeigt **Serial-Nummer** (z.B. `001`)

Sent ist immer dein eigener Kanton (aus Settings → Station).

## Stats-Panel (rechts)

Im Contest-Modus zeigt das rechte Side-Panel **Live-Score statt Propagation**:

- **Score-Summary**: `X Pkt × Y Mult = Z gesamt` zentriert
- **Rate-Meter**: QSOs/h gerechnet für die letzten 10 und 60 Minuten
- **Score-Matrix** (Tabelle): Pro Band → Multiplier-Count, CW/Data/SSB-QSOs, Total
  - Spalten template-abhängig (Helvetia → "Kant", CQ-WW → "Zone", CQ-WPX → "Pfx", Standard → "DXCC")
  - Nur Contest-Bänder angezeigt (160/80/40/20/15/10m bei ALL)
- **Band Activity Heatmap**: aus DX-Cluster-Spots, gefiltert auf Contest-Bänder

## DX-Cluster im Contest

Der DXClusters-Tab unten ist im Contest **gefiltert**:
- Nur Spots **im richtigen Mode** (PH-Contest → nur SSB-Spots)
- Nur Spots **auf Contest-Bändern**

Plus **farbliche Markierung** pro Spot:
- 🔴 **Rot** — bereits geloggt (Call+Band+Mode-Match in deinem Log)
- 🟢 **Grün** — vermutlich neuer Multiplier (neues Country pro Band, bei WPX neuer Präfix)
- Normal — weder Dupe noch Mult

Doppelklick auf einen Spot → Call und Frequenz landen im Contest-Form, CAT springt mit.

## Contest-Map

Eigener Sub-Tab **Contest-Map** (nur bei Contest-Logs sichtbar):
- **QTH-zentriert** auf deinen Locator aus Station-Settings
- **Linien** vom QTH zu jeder geomappten QSO
- **Band-Filter** zum schnellen Drill-Down
- **"QTH"-Button** zum Re-Center

## Serial-Counter

- **Pro Log** (Default) — bei CQ-WW, CQ-WPX Single-Op, ARRL-DX, IARU
- **Pro Band** — automatisch bei CQ-WPX Multi-Two / Multi-Unlimited / Multi-Distributed (CQ-Regel)

Serial-Nummer wird beim Loggen auto-generiert (höchste vergebene + 1). Bei Undo/Löschen wird die Nummer wiederverwendet.

## Cabrillo-Export

Toolbar des Contest-Logs → **Cabrillo…** → Sheet öffnet sich mit allen Header-Tags vorbelegt aus dem Wizard:
- `CONTEST`, `CALLSIGN`, `OPERATORS`
- Alle `CATEGORY-*`-Tags
- Sent-Exchange als Default-Wert (Per-QSO-Werte aus dem Log überschreiben)
- Claimed-Score, Club, Soapbox

**Datei** landet unter `~/Documents/HAM-Tools/Exports/`. Format ist Cabrillo V3 — wird von ARRL/CQ/DARC/USKA akzeptiert.

## Tipps

- **Quick-Toggle DX ↔ Contest:** die obere Tab-Leiste im QSO-Eingabe-Panel — Klick wechselt direkt zum zuletzt offenen Log dieses Typs
- **Mehrere Contests parallel** möglich (z.B. CQ-WPX am Samstag, lokaler HB-Contest danach). Wechsel via Logs-Popover oben
- **Tester schon vor dem Contest** anlegen — Wizard-Wahl der Cabrillo-Kategorie ist nachträglich nicht änderbar (löschen + neu wäre der Weg)

## Bekannte Einschränkungen

- **WAE-QTC-Block** noch nicht unterstützt (kommt in Etappe 3)
- **SCP (Super Check Partial)** noch nicht eingebaut
- **F1–F8-Macros** noch nicht (Voice-Keyer ist in Roadmap Phase 10/11)
