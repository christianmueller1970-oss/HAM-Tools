# Strahler-Verlängerung

## Beschreibung
Wenn ein vertikaler λ/4-Strahler (z.B. eine Mobil-Antenne oder ein zu kurzer
Vertikal) nicht die volle elektrische Länge erreicht, kann eine
**Verlängerungsspule** ihn auf Resonanz bringen. Dieser Rechner nutzt die
**Antennenleitungstheorie** (Z₀-Methode) für höhere Genauigkeit als die
einfache 2,5-µH-pro-Meter-Praxisformel.

## Funktionsweise
Eine zu kurze Antenne erscheint **kapazitiv** (negativer Blindwiderstand).
Die Verlängerungsspule kompensiert mit ihrer induktiven Reaktanz:

1. **Wellenwiderstand Z₀** des Strahlers berechnen:
   `Z₀ = 60 × (ln(2h/d) − 1)` (h = Höhe, d = Durchmesser)
2. **Elektrische Länge G** in Grad: `G = 360 × h / λ`
3. **Blindwiderstand Xa**: `Xa = −Z₀ / tan(G°)`
4. **Benötigte Induktivität L**: `L = |Xa| / (2π × f)`
5. **Wheeler-Formel** für Windungszahl der Luftspule

Die Spule wird **am Fußpunkt** oder an der **idealen Stelle** im Strahler
eingeschleift. Fußpunkt ist einfacher, Mitte hat besseren Wirkungsgrad.

## Praxis-Tipps
- **Spulenkörper:** PVC-Rohr, GFK oder Hartfaser — wetterfest und nicht-leitend
- **Drahtdurchmesser:** 1,5–2,5 mm CuL für 100 W, dicker für höhere Leistung
- **Wickelung:** dicht gewickelt (kein Windungsabstand) → einfache Wheeler-Formel
- **Eng gewickelt:** kein Spacing für maximale L pro Windung
- **Spule mit Isolierabstand zur Erde** und zum Mast (Spannungsknoten in der Nähe)
- **Wetterschutz:** Klarlack oder Schrumpfschlauch über die Spule
- **Q-Faktor:** dickerer Draht und größerer Spulendurchmesser erhöhen die Güte

## Wirkungsgrad-Hinweis
Bei sehr starker Verkürzung (h < 25 % λ/4) sinkt der Wirkungsgrad spürbar:
- 80 % der Länge → Wirkungsgrad ~95 %
- 50 % der Länge → Wirkungsgrad ~70 %
- 25 % der Länge → Wirkungsgrad ~30 %

Eine längere Antenne mit kleinerer Spule ist immer effizienter als eine
sehr kurze Antenne mit großer Spule.

## Quellen
- Rothammels Antennenbuch: Verlängerung kurzer Strahler
- W. C. Boucher: "Antenna Theory and Design"
