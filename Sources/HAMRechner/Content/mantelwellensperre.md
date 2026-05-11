# Mantelwellensperre (Common-Mode-Choke)

## Beschreibung
Eine **Mantelwellensperre** (engl. *Common-Mode Choke* oder *Choke Balun*)
unterdrückt unerwünschte Common-Mode-Ströme auf dem Koaxialkabel-Mantel.
Diese entstehen, wenn die Antenne unsymmetrisch gespeist wird, oder
wenn der Koax-Mantel selbst zur Antenne wird und HF zurück in den
Shack führt — mit allen typischen Folgen: TVI/BCI, RFI, instabile SWR,
Beam-Diagramm verzerrt, F/B-Verhältnis bricht ein.

## Funktionsweise
Das Koaxialkabel wird durch oder um einen Ferrit-Ringkern gewickelt.
Für Common-Mode-Ströme (gleichphasig auf Innenleiter und Mantel)
bildet die Spule eine **hohe Impedanz** und sperrt sie. Differential-Mode
(das Nutzsignal) sieht den Choke nicht — Innen- und Außenfeld heben sich
im Kern auf.

```
Z_CM ≈ 2π · f · L     mit  L = N² · A_L
```

- **L:** Induktivität in µH (N = Windungen, A_L in nH/N²)
- **Z_CM:** Common-Mode-Impedanz in Ohm
- **Ziel: Z_CM ≥ 1 kΩ** über alle genutzten Bänder, optimal **≥ 5 kΩ**

Die Formel ist konservativ — bei Ferritmaterialien (Mix 31/43/77) liegen
die realen Werte im Verlust-Resonanz-Fenster oft **2–3× höher** dank des
Material-Imaginärteils µ" (resistive Verluste, die HF in Wärme umwandeln).

## Materialwahl

| Mix | Frequenzbereich | Anwendung |
|---|---|---|
| **77** | 0,5–2 MHz | NF/MW |
| **31** | 1–10 MHz top, bis 30 MHz brauchbar | EFHW-Choke, KW-Sperre |
| **43** | 5–50 MHz universell | KW-Antennen, Stations-Choke |
| **61** | 30–300 MHz | VHF/UHF-Choke |
| **2 / 6** (Eisenpulver) | **NICHT für Chokes!** | Hohes Q, kaum Verluste |

## Praxis-Tipps
- **Standard-KW-Station 100 W:** FT-240-43 mit 10–14 Windungen
  Aircell-5 / RG-58 — deckt 80–10 m sauber ab
- **EFHW-Choke:** FT-240-31 mit 7–10 Windungen — speziell gegen die
  Common-Mode-Probleme an Endgespeisten Halbwellenantennen
- **Wickel-Trick:** Windungen **gleichmäßig** um den Kern verteilen
  (nicht alle nebeneinander) → weniger Eigenkapazität, breiteres
  Sperrband, höhere Selbstresonanz
- **Position:** Choke direkt am Speisepunkt der Antenne, nicht erst
  unten am Mast — dort wirkt der Mast schon als Strahler
- **Mehrfach-Choke:** Ein zweiter Choke alle paar Meter Koax kann
  sehr lange Speiseleitungen sauber halten
- **Schnelltest:** Choke wirkt, wenn die SWR-Anzeige NICHT mehr von
  Hand- oder Mast-Berührung beeinflusst wird

## Quellen
- Jim Brown K9YC: "RFI Tips & Techniques" — die Bibel für Common-Mode-Chokes
- Steve Hunt G3TXQ: Choke-Design-Tabellen für Hexbeam & Yagi
- Fair-Rite & Amidon Datasheets (Mix 31/43/61/77 Permeabilität & Impedanz vs. Frequenz)
