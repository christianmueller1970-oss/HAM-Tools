# EFHW-Antenne

## Beschreibung
Die **EFHW** (*End Fed Half Wave*, endgespeister Halbwellen-Dipol) ist eine
sehr beliebte Multiband-Antenne im Amateurfunk. Sie besteht aus einem
einzelnen λ/2 langen Draht, der **am Ende gespeist** wird – über einen
49:1 Unun-Transformator. Die Antenne ist einfach im Aufbau, braucht
wenig Platz für die Speisung und arbeitet ohne Tuner auf vielen
Harmonischen der Grundwelle.

## Funktionsweise
Am Ende eines λ/2-Drahts herrscht ein **Spannungsmaximum** mit sehr hoher
Impedanz von etwa **2200–3200 Ω** (typischer Designwert: 2450 Ω). Ein
49:1 Unun (Untertransformator, Verhältnis 7:1 Windungszahl) wandelt
diese hohe Impedanz auf 50 Ω für das Koaxkabel.

Da die EFHW endgespeist ist, braucht sie **theoretisch kein
Gegengewicht** – aber ein kurzes Counterpoise (≈ 5 % der Wellenlänge)
verbessert die Anpassung deutlich und reduziert Mantelwellen.

Auf den geradzahligen Harmonischen (2 × f, 3 × f, 4 × f …) ergibt sich
ebenfalls ein λ/2-, λ-, 3λ/2-Verhalten mit hoher End-Impedanz – die
Antenne arbeitet so direkt auf 80/40/20/15/10 m (bei 80 m als Grundwelle).

## Bauanleitung 49:1 Unun
- **Ringkern:** FT240-43 (für 100 W) oder FT140-43 (für QRP bis 25 W)
- **Wicklungsverhältnis:** 2 Primär : 14 Sekundär Windungen (= 7:1, ergibt 49:1 Impedanz)
- **Kondensator:** 100 pF NP0-Keramik parallel zur Primärwicklung – verbessert Anpassung auf hohen Bändern
- **Drahtdurchmesser:** 0,8 – 1,2 mm CuL-Draht für die Wicklung
- **Gehäuse:** wetterfest, mit SO-239 Buchse + Drahtklemme

## Praxis-Tipps
- **Drahtlänge präzise abstimmen** – bei zu langer Draht: Spannungsknoten verschieben sich
- **Inverted-L-Aufhängung** funktioniert gut: Speisepunkt am Boden, Draht steigt schräg auf
- **Counterpoise 0,05 λ:** kann am Unun-Gehäuse befestigt werden, beliebig verlegt
- **Mantelwellensperre 1:1** am Koax direkt unter dem Unun für saubere Symmetrierung
- **Höhe variieren** – die EFHW ist erstaunlich tolerant bei der Aufhängung

## Multiband-Verhalten (40m Grundwelle = 7,1 MHz)
- Resonant auf: 40, 20, 15, 10 m – ohne Tuner
- Mit Tuner: zusätzlich 30, 17, 12 m nutzbar

## Quellen
- Steve N5KB: "EFHW Multiband Antenna"
- AA5TB: EFHW-Untersuchungen und Trafo-Designs
