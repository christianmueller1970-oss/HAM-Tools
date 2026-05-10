# Spulen-Wickler

## Beschreibung
Berechnet die Wickeldaten für **einlagige Luftspulen** nach der
**Wheeler-Formel**. Anwendungen: Verlängerungsspulen für Antennen,
LC-Schwingkreise, Anpassnetze, Filter. Zusätzlich werden
Resonanzfrequenz und Q-Faktor (näherungsweise) berechnet.

## Funktionsweise
Die Wheeler-Formel (1928) ist die Standardberechnung für einlagige
Luftspulen:

`L_µH = (r² × N²) / (9r + 10ℓ)`

mit:
- **r:** Spulenradius in **Inch** (Achtung: imperial!)
- **N:** Windungszahl
- **ℓ:** Spulenlänge in **Inch**

Der Rechner iteriert intern, weil ℓ von N abhängt (ℓ = N × Pitch).

**Resonanzfrequenz** mit gegebenem Kondensator:
`f = 1 / (2π × √(L × C))`

**Q-Faktor** näherungsweise aus DC-Widerstand und induktivem Blindwiderstand —
HF-Verluste (Skin-Effekt, Strahlungsverluste) sind nicht berücksichtigt.

## Bauanleitung
- **Spulenkörper:** PVC-Rohr (KG-Rohr aus dem Baumarkt), Hartfaser oder GFK
- **Drahtdurchmesser:** 0,8–1,5 mm CuL für QRP, 1,5–2,5 mm für 100 W
- **Wickelart:**
  - **Dicht gewickelt** (s = 0): einfachste Variante, geringere Q
  - **Mit Abstand** (s > 0): besseres Q, mehr Platzbedarf
- **Wickelhilfe:** Bohrung im Körper für Drahtanfang, Klebepunkt am Anfang/Ende
- **Wetterschutz:** Klarlack, Schrumpfschlauch oder PVC-Rohr-Hülle

## Praxis-Tipps
- **Wheeler-Genauigkeit:** ±5 % bei korrekter Wickelung
- **L vs. Spulen-Ø:** größerer Ø → mehr L pro Windung → weniger Windungen
- **L vs. Länge:** längere Spule → höhere Q, aber niedrigere L pro Windung
- **Schlankheit ℓ/d** sollte zwischen 0,5 und 2,0 liegen für besten Q
- **Maximale L:** kompakt = ℓ ≈ d
- **Maximales Q:** lang = ℓ ≈ 2d

## Q-Faktor in der Praxis
Tatsächlicher Q ist meist 80–90 % des berechneten Werts (HF-Verluste).
Für hohe Q-Werte:
- dicker Draht (Skin-Effekt minimieren)
- versilberter Draht für VHF/UHF
- Litzendraht (HF-Litze) für 1–10 MHz
- Spulenkörper mit niedrigem Verlustfaktor (Polystyrol > PVC)

## Quellen
- H. A. Wheeler: "Simple Inductance Formulas for Radio Coils" (Proc. IRE, 1928)
- ARRL Handbook: Inductors
