# Balun / Unun

## Beschreibung
**Baluns** (BAL-UN: balanced-unbalanced) und **Ununs** (UNbalanced-UNbalanced)
sind Transformatoren auf Ringkernen, die Impedanzen umsetzen oder Symmetrie-
Übergänge schaffen. Sie sind essentiell zwischen Koaxkabel und symmetrischen
Antennen (Dipol, Loop) sowie zwischen 50 Ω und höheren Impedanzen
(Windom 4:1, EFHW 49:1).

## Typen im Überblick

| Typ | Verhältnis | Anwendung |
|---|---|---|
| **1:1 Strombalun** | 50 Ω → 50 Ω, symmetriert | Dipol, Yagi, Mantelwellensperre |
| **4:1 Balun (Guanella)** | 50 Ω → 200 Ω | Windom (OCFD), Faltdipol |
| **9:1 Unun** | 50 Ω → 450 Ω | Random-Wire, Langdraht |
| **49:1 Unun** | 50 Ω → 2450 Ω | EFHW-Antenne |
| **64:1 Unun** | 50 Ω → 3200 Ω | Random-Wire mit Tuner |
| **Mantelwellensperre** | 1:1 | Symmetrierung am Speisepunkt |

## Funktionsweise
Die Berechnung der Windungen folgt der Formel **N = √(L_nH / Al)**, wobei:
- **L_nH:** Ziel-Induktivität in Nanohenry (= L_µH × 1000)
- **Al:** Induktivitätsfaktor des Ringkerns (nH/Wdg²) — siehe Datenblatt

Das tatsächliche Impedanz-Verhältnis ergibt sich aus dem **Wicklungsverhältnis
zum Quadrat**: 7 Wdg-Verhältnis → 49:1 Impedanz.

## Bauanleitung
- **Material 43 (Ferrit):** breitbandig 1–30 MHz, ideal für KW-Baluns
- **Material 61 (Ferrit):** 10–200 MHz, niedrigere Verluste, für VHF/UHF
- **Material 31:** sehr gut für Mantelwellensperren, hoher Common-Mode-Choke
- **Eisenpulver Mix 2/6:** für LC-Schwingkreise und schmalbandige Anpassnetze
- **Drahtdurchmesser:** abhängig von der Leistung — bei 100 W ca. 1,5 mm CuL
- **Kernauslastung:** maximal 80 % des Innenumfangs nutzen, sonst zu eng

## Praxis-Tipps
- **Wetterfest:** Kern in PVC-Box oder mit Schrumpfschlauch
- **SO-239 Buchse + Klemmen** für Drahtanschluss
- **Leistungsgrenzen beachten:** FT240-43 typ. bis 100–200 W
- **Keine Sättigung:** zu wenig Windungen → Kern sättigt → Verzerrung
- **Bifilar / Trifilar wickeln:** beide Drähte gleichzeitig führen, gleichmäßig verteilen

## Quellen
- Jerry Sevick W2FMI: "Transmission Line Transformers"
- Amidon Inc.: Datenblätter aller Ringkerne
- Fair-Rite Products: Material-Eigenschaften
