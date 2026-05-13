---
title: HAM-Tools Lizenz aktivieren
description: Lifetime-Lizenz mit 12 Monaten Updates. Offline-signiert (Ed25519), 50-QSO-Demo, Lizenz-String aus Mail einspielen.
---

# Lizenz aktivieren

HAM-Tools nutzt ein **Offline-Lizenz-System** (Ed25519-signiert). Kein Server-Check, kein Online-Zwang nach der Aktivierung.

## Lizenz anfragen

Eine kurze Mail an **hb9hji@funkwelt.net** mit:
- **Name**
- **Rufzeichen** (1–3 Stück möglich, wenn du mehrere hast)
- Optional: woher du HAM-Tools kennst

Du bekommst per Antwort einen **~300-Zeichen-Lizenz-String** im Format:
```
ham1.eyJjYWxscy...Q.SGVsbG8...4
```

## Lizenz einspielen

1. **Cmd+,** → **Lizenz**-Tab
2. **Lizenz-String** ins Textfeld einfügen (Cmd+V oder Button *"Aus Zwischenablage einfügen"*)
3. **"Lizenz übernehmen"** klicken
4. Status sollte direkt auf **"Vollversion aktiv"** springen (grün)

## Modell: Lifetime mit 12 Monaten Updates

- **Einmal-Kauf** — die Lizenz läuft technisch nie ab
- **Updates für 12 Monate inkludiert** ab Ausstellungs-Datum
- **Alte App-Versionen** bleiben mit der ursprünglichen Lizenz **lebenslang** voll funktionsfähig
- Für Versionen jenseits der Update-Frist: Verlängerung anfragen (günstiger als Neukauf)

::: tip
Die App prüft beim Start, ob das **Build-Datum der aktuellen App-Version** vor dem `updates_until`-Datum deiner Lizenz liegt. Wenn ja → Vollmodus. Wenn nein → Demo-Modus mit Hinweis auf Update-Verlängerung.
:::

## Demo-Modus

Ohne gültige Lizenz:
- **50 QSOs cumulativ** in allen Logs zusammen
- Danach **Read-Only**: alle QSOs sind weiter lesbar, ADIF + Cabrillo-Export geht, aber kein neues Loggen
- Banner oben in der App zeigt jederzeit den Stand

## Mehrere Macs

Du kannst eine Lizenz auf **mehreren Macs** verwenden, wenn alle dasselbe Callsign nutzen. Das Lizenz-Modell prüft das Callsign der App-Settings gegen die in der Lizenz hinterlegten 1–3 Rufzeichen.

## Probleme?

| Fehler | Bedeutung |
|---|---|
| *"Signatur ungültig"* | Lizenz wurde verkürzt beim Kopieren oder ist von einem anderen Build-Schlüsselpaar |
| *"Call passt nicht zur Lizenz"* | Das in Einstellungen → Station eingetragene Callsign ist nicht in der Lizenz hinterlegt |
| *"Update-Verlängerung nötig"* | App-Version wurde nach dem `updates_until`-Datum gebaut — entweder ältere App-Version installieren oder Verlängerung anfragen |

[Bug melden →](/report-bug) oder Mail an `hb9hji@funkwelt.net`.
