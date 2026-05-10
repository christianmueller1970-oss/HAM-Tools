# Linkbudget / Reichweite

## Beschreibung
Das **Linkbudget** rechnet aus, ob eine Funkverbindung über eine
gegebene Distanz funktioniert. Aus Sendeleistung, Antennen-Gewinnen,
Frequenz, Distanz und Empfänger-Empfindlichkeit ergibt sich die
**Link-Marge** in dB — positiv bedeutet "sicher", negativ "nicht möglich".

## Funktionsweise (Friis-Formel)
Die Freiraumdämpfung (*Free Space Path Loss*, FSPL) wächst quadratisch
mit Frequenz und Distanz:

`FSPL [dB] = 20 × log₁₀(d_km) + 20 × log₁₀(f_MHz) + 32,45`

Daraus die Empfangsleistung:

`P_RX [dBm] = P_TX [dBm] + G_TX [dBi] + G_RX [dBi] − FSPL [dB]`

Die **Link-Marge** ist der Abstand zur Empfänger-Empfindlichkeit:

`Marge = P_RX − Empfindlichkeit`

Positiv = Verbindung möglich. Bei < 10 dB Marge ist die Verbindung
empfindlich gegen Schwund (Fading).

## Annahmen der Formel
- **Freier Sicht-Pfad** (Line-of-Sight, LOS) ohne Hindernisse
- **Keine atmosphärische Dämpfung** (außer Regen ab 10 GHz)
- **Keine Mehrwegausbreitung** (Reflexionen, Interferenzen)
- **Punkt-Antennen** (keine Höhenberücksichtigung)

In der Realität sind Verluste **deutlich höher** durch:
- Bodendämpfung (Erdkrümmung, Hindernisse)
- Vegetation, Gebäude
- Atmosphäre (besonders > 10 GHz: Sauerstoff-/Wasser-Absorption)
- Mehrwege (Auslöschungen durch Reflexionen)

Faustregel: **+10 bis +30 dB Reserve einplanen** über die Friis-Berechnung.

## Praxis-Tipps
- **Empfänger-Empfindlichkeit** je nach Modulationsart:
  - SSB: -120 dBm typ.
  - FM (5 kHz Hub): -116 dBm
  - CW: -130 dBm
  - Digi-Modes (FT8): -130 dBm und besser
- **Antennen-Gewinn dBi vs. dBd:** dBd ist 2,15 dB weniger als dBi
- **EIRP** (Effective Isotropic Radiated Power): P_TX + G_TX (legaler Begriff)
- **VHF/UHF DX**: oft nur über Tropo, Sporadic-E oder Aurora — nicht durch Friis vorhersagbar

## Beispiel-Berechnung
- 100 W (50 dBm) auf 145 MHz, 100 km Distanz, beide Antennen 6 dBd
- FSPL = 20·log(100) + 20·log(145) + 32,45 = 40 + 43,2 + 32,5 = **115,7 dB**
- P_RX = 50 + 8,15 + 8,15 − 115,7 = **−49,4 dBm**
- Bei -120 dBm Empfindlichkeit: **+70 dB Marge** → sehr sichere Verbindung

## Quellen
- Harald T. Friis (1946): Originalformel
- Rothammels Antennenbuch: Reichweitenberechnung
