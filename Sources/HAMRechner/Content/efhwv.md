# EFHW-Verkürzung

## Beschreibung
Wenn die volle λ/2-Drahtlänge einer EFHW-Antenne aus Platzgründen nicht
möglich ist, lässt sich die Antenne mit einer **Verlängerungsspule** auf
ihre elektrische Resonanzlänge bringen. Dieser Rechner berechnet die
benötigte Induktivität und die mechanischen Wickeldaten der Spule
(Windungen, Wickellänge) nach der **Wheeler-Formel** für einlagige
Luftspulen.

## Funktionsweise
Eine zu kurze Antenne erscheint kapazitiv (negativer Blindwiderstand).
Die Verlängerungsspule kompensiert diese Kapazität durch ihre induktive
Reaktanz – die Antenne wird wieder resonant. Die Spule wird **in Serie
in den Strahler eingeschleift**, idealerweise:

- **Mitte des Strahlers:** symmetrische Stromverteilung, weniger Verluste
- **Ende des Strahlers:** einfacher Aufbau, größere Spannungsbelastung an der Spule

Die Praxisnäherung: benötigte Induktivität ≈ fehlende Länge × 2,5 (in µH/m).
Genauer wird's mit der elektrischen-Längen-Methode (siehe
Strahler-Verlängerung).

## Bauanleitung Spule
- **Spulenkörper:** PVC-Rohr (KG-Rohr aus dem Baumarkt) oder Hartfaser-Rohr
- **Drahtdurchmesser:** 1,0–1,5 mm CuL für QRP, 1,5–2,5 mm für höhere Leistung
- **Wickelart:** dicht gewickelt (Windung an Windung) – einfachste Variante
- **Wetterfestigkeit:** Spule mit Schrumpfschlauch oder Klarlack vor Witterung schützen
- **Zugentlastung:** Draht beidseitig mechanisch fixieren, nicht nur die Spule belasten

## Praxis-Tipps
- **Wheeler-Formel** ist nur für einlagige Luftspulen genau – bei Spulen-Kern
  (Ferrit etc.) gelten andere Formeln
- **Antenne durchstimmen:** nach Aufbau die Resonanzfrequenz mit Antennenanalysator
  prüfen, ggf. ein paar Windungen hinzufügen/entfernen
- **Q-Faktor:** dickerer Draht und größerer Spulen-Ø erhöhen die Güte
- **Frequenz-Wahl beachten:** bei sehr starker Verkürzung (< 50 % λ/2) sinkt der Wirkungsgrad spürbar

## Quellen
- H. A. Wheeler: "Simple Inductance Formulas for Radio Coils" (1928)
- DJ4PI: "Spulenwickeln in der Praxis"
