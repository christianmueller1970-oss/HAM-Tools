---
title: CAT-Steuerung für Yaesu, Icom, Kenwood, Elecraft
description: Radio-Steuerung mit Hamlib für 24 Modelle. ICOM mit korrekter CI-V-Adresse pro Modell. Multi-Config zum schnellen Wechseln zwischen mehreren Radios.
---

# CAT / Radio-Steuerung

HAM-Tools steuert dein Radio via **Hamlib** (rigctld). 24 Modelle vorkonfiguriert: Yaesu, Icom, Kenwood, Elecraft.

## Erste Inbetriebnahme

1. **Cmd+,** → **CAT**-Tab
2. **Hersteller** wählen (Icom / Yaesu / Kenwood / Elecraft / Hamlib Dummy zum Testen ohne Hardware)
3. **Modell** wählen — Werkseinstellungen (Baud, Datenbits, Parity, Handshake) werden automatisch geladen
4. **Serieller Port** auswählen — Dropdown listet alle `/dev/cu.*` (USB-CAT-Kabel werden automatisch erkannt)
5. **CI-V Address** (nur ICOM) — Default aus dem Profil, kannst du überschreiben falls dein Radio anders konfiguriert ist
6. **"Start"** klicken — Badge oben wechselt von grau auf blau (Starten) auf grün (Verbunden)

## CI-V Adresse (ICOM)

Jedes ICOM-Modell hat eine Standard-CI-V-Adresse. HAM-Tools kennt:

| Modell | CI-V | Modell | CI-V |
|---|---|---|---|
| IC-7300 | `0x94` | IC-7100 | `0x88` |
| IC-7610 | `0x98` | IC-9100 | `0x7C` |
| IC-705 | `0xA4` | IC-7600 | `0x7A` |
| IC-9700 | `0xA2` | IC-7700 | `0x74` |
| IC-7200 | `0x76` | IC-7000 | `0x70` |
| IC-746PRO | `0x66` | | |

::: tip
Wenn dein Radio die CI-V im Menü auf einen anderen Wert geändert wurde, einfach den Wert im Feld überschreiben. Mit dem **"Default (0xXX)"**-Button setzt du wieder den Werkswert.
:::

Bei **Yaesu / Kenwood / Elecraft** ist die Section unsichtbar — diese Hersteller nutzen kein CI-V.

## Multi-Config

Du kannst **mehrere Konfigurationen** speichern (z.B. eine pro Radio). Workflow:

1. Settings für **Radio A** machen (Modell + Port + ggf. CI-V)
2. **"Speichern unter…"** klicken → Name eingeben (z.B. `IC-705 Mobile`) → **Speichern**
3. Radio B konfigurieren (Modell wechseln, Port ändern)
4. Wieder **"Speichern unter…"** → `IC-7300 Shack`
5. Zwischen Configs wechseln: oben im **"Aktive Konfig"**-Picker

::: warning
Änderungen wirken in der **aktuell aktiven** Konfig. Wenn du z.B. von IC-705 zu IC-7300 wechselst und an der IC-7300-Config rumdrehst, ändert sich die IC-705-Config nicht — die ist gespeichert.
:::

## Was die App mit CAT macht

- **Frequenz lesen**: alle 500 ms (Default, einstellbar 200–2000 ms) → wird im Logbuch-Eingabe-Panel und im POTA/Contest-Form angezeigt
- **Frequenz setzen**: beim Klick auf einen DX-Cluster-Spot oder QTH-Memory springt das Radio auf die Frequenz
- **Mode lesen**: synchron zur Frequenz, bestimmt RST-Default (599 für CW/Digi, 59 für SSB)
- **Mode setzen**: Mode-Picker im Radio/CAT-Panel sendet `setMode` an Hamlib → Radio dreht USB/LSB/CW/PKTUSB
- **VFO A/B + Split**: per Klick im Radio/CAT-Panel
- **S-Meter**: live aus dem Radio gelesen (Hamlib-`get_strength`)
- **PTT**: aktuell nicht angesteuert — die App ist read-only beim Funken (kein Voice-Keyer in dieser Version)

## Mode-Picker auch ohne CAT nutzbar

::: tip Neu in 1.8.10
Mode-Auswahl funktioniert auch ohne aktive CAT-Verbindung — wichtig
für Remote-Setups, Reise-Loggen ohne TRX in Reichweite oder das
nachträgliche Pflegen von Papier-Logs.
:::

- **Mit CAT**: Mode-Klick schickt `setMode` ans Radio, das Radio
  dreht, der Poll-Loop bestätigt den neuen Wert. Auswahl beschränkt
  auf Hamlib-Modes: USB, LSB, CW, CWR, AM, FM, RTTY, RTTYR, PKTUSB,
  PKTLSB.
- **Ohne CAT**: Mode-Klick setzt den Wert direkt im internen
  RadioState (USB/LSB werden zu `SSB` gemappt, PKTUSB/PKTLSB zu
  `DATA`, der Rest 1:1). Zusätzlich erscheinen **digitale Modes**
  unter einem Divider: **FT8, FT4, JT65, JT9, PSK31, JS8, Q65,
  MSK144**. Diese laufen am TRX über PKTUSB-Modulation — Hamlib
  kennt sie nicht direkt, deshalb sind sie ohne CAT-Verbindung
  ausgeblendet.

Der Status unter der Frequenz-Anzeige zeigt `CAT` (grün) oder
`manuell` (grau), damit du jederzeit weißt, woher die aktuellen
Werte kommen.

## Hamlib unter der Haube

HAM-Tools bringt eine **eigene `rigctld`-Binary** mit (Universal2, in `Contents/Helpers/rigctld` im App-Bundle). Du brauchst kein separates Hamlib zu installieren.

`rigctld` wird beim CAT-Start als Subprocess gespawnt mit den passenden Argumenten:
```
rigctld -m <hamlibRigNumber> -r <port> -s <baud> -C data_bits=8,stop_bits=1,...
```

Bei ICOM kommt `civaddr=0xXX` automatisch ans `-C`-Argument.

## Troubleshooting

| Symptom | Mögliche Ursache |
|---|---|
| Badge bleibt grau auf "Idle" | Kein Radio-Modell gewählt oder Port nicht ausgewählt |
| Badge wechselt auf rot "Fehler" | Port belegt (andere App läuft), Baud passt nicht, Kabel ab |
| Verbunden aber Freq bleibt auf 0 | Falsche CI-V (bei ICOM), Radio im falschen Modus |
| Verbunden aber Mode bleibt auf "—" | Hamlib-Modul für dieses Modell unterstützt kein Mode-Read |
| Verbindung bricht ab | USB-Adapter-Treiber-Problem — anderes Kabel testen, FTDI-Driver aktualisieren |

Bei wiederholbaren Problemen → **Bug melden** (Cmd+Shift+B) mit Diagnose-Anhang aktiviert.

## Tipps

- **Multi-Radio-Shack:** für jedes Radio eine Config — Wechsel per Picker, kein Eingabe-Marathon
- **Portable:** zweite Config mit anderem USB-Adapter-Port (kann je nach USB-Hub variieren)
- **Test ohne Hardware:** Profile `Hamlib Dummy-Rig (Test ohne Hardware)` → setzt willkürliche Werte, gut für UI-Tests
