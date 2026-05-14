---
title: FAQ — Häufige Fragen zu HAM-Tools
description: Antworten zu Lizenz, Logbuch, Contest, CAT, Update-System und macOS-Kompatibilität.
---

# FAQ — Häufige Fragen

## Allgemein

### Auf welchen Macs läuft HAM-Tools?
**macOS 14 (Sonoma) oder neuer** — sowohl Apple Silicon (M1+) als auch Intel. Die App ist als **Universal Binary** gebaut.

::: warning macOS 12 / 13 wird nicht unterstützt
Auf älteren Systemen erscheint *„Du kannst diese Version des Programms nicht
mit dieser Version von macOS verwenden"*. Grund: die App nutzt SwiftUI-APIs
aus macOS 14 (MapKit-DSL, neue `onChange`-Signatur). macOS 14 ist ein
**kostenloses Apple-Update** für alle Macs ab Baujahr **2018**.
:::

### Brauche ich Internet?
Nein. Für **DX-Cluster** und **POTA/SOTA-Spots** ja, für alles andere (Logbuch, Rechner, Cabrillo-Export, CAT) nicht. Die Lizenz-Validierung läuft **offline** (signiert).

### Wo liegen meine Daten?
`~/Documents/HAM-Tools/`:
- `Logs/` — alle `.htlog`-Dateien (SQLite)
- `Exports/` — ADIF + Cabrillo + Lizenz-Sicherungen
- `Cache/` — Callbook-Cache + Spot-History

## Lizenz

### Wie bekomme ich eine Lizenz?
Mail an `hb9hji@funkwelt.net` mit Rufzeichen + Name. Du bekommst einen Lizenz-String zur Aktivierung in der App.

### Was passiert nach 12 Monaten?
Deine **aktuelle App-Version läuft weiter unbegrenzt**. Nur App-Versionen, die *nach* deinem Update-Frist-Datum released werden, brauchen eine **Update-Verlängerung** (anfragen wie Erst-Lizenz).

### Kann ich die Lizenz auf zwei Macs nutzen?
Ja, solange beide Macs dasselbe Callsign aus den lizenzierten Rufzeichen verwenden. Lizenz-String einfach auf beiden Macs einspielen.

## Logbuch

### Wo liegen meine Log-Files?
`~/Documents/HAM-Tools/Logs/*.htlog`. Sind reguläre SQLite-Datenbanken — kannst du mit jedem SQLite-Tool öffnen wenn du forensisch ran willst.

### Wie sichere ich meine Logs?
Standard-Backup via Time Machine reicht. Plus **ADIF-Export** pro Log als Sekundär-Backup.

### Kann ich alte Logs importieren?
Ja, **ADIF-Import** legt ein neues Log mit allen QSOs aus der Datei an.

### QSO versehentlich gelöscht — Rückgängig?
Aktuell **nicht direkt** in der App. Aus dem Time-Machine-Backup oder per ADIF-Re-Import.

## Contest

### Welche Contests sind vorbereitet?
14 Templates: HB-Helvetia, USKA Field Day SSB/CW, USKA 50 MHz, CQ-WW CW/SSB, CQ-WPX CW/SSB, ARRL-DX CW/SSB, IARU-HF, DARC-WAG, WAE-DX CW/SSB.

### Kann ich eigene Contests definieren?
Aktuell nicht. Etappe 3 bringt einen User-Overlay-Folder für eigene `contests.json`-Einträge.

### Wo landet der Cabrillo-Output?
`~/Documents/HAM-Tools/Exports/<Contest-ID>-<Datum>.cbr`. Beim Klick auf "Exportieren" auch direkt im Finder geöffnet.

## CAT

### Mein Radio wird nicht erkannt — Hilfe?
Häufigste Ursachen:
1. **CI-V-Adresse falsch** (bei ICOM) — Default im Settings, Radio-Menü prüfen
2. **Port ist von einer anderen App belegt** (WSJT-X, fldigi etc.) — die andere App schließen
3. **USB-Kabel-Driver fehlt** — FTDI-Driver installieren bei No-Name-Kabeln

Test mit dem **"Hamlib Dummy-Rig"**-Profil — wenn das verbindet, ist Hamlib OK; dann liegt's an der Hardware-Konfig.

### PTT-Steuerung?
Aktuell nicht. CAT ist read + Frequenz-Set, kein PTT.

## Update-System

### Wie weiß ich, dass ein Update da ist?
Beim App-Start (max 1× / 24h) prüft die App automatisch. Plus **Cmd+Opt+U** für manuellen Check.

### Updates rückgängig machen?
Ältere DMGs unter https://toolbox.funkwelt.net/app/dmg/ — manuell herunterladen + ersetzen.

## Mehr Fragen?

[Bug melden](/report-bug) bzw. Mail an `bugs@funkwelt.net` mit der Frage.
