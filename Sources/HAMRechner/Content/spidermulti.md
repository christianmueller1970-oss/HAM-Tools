# Spiderbeam Multi-Band

## Beschreibung
Die Multi-Band Spiderbeam (DF4SA) ist eine 3- oder 5-Band-Yagi auf
einem einzigen Spreizer-Set. Mehrere unabhängige Drahtsysteme
(eines pro Band) teilen sich denselben Antennenkörper. Jedes Band
hat eigene Strahler, Reflektoren und ggf. Direktoren – mit
gemeinsamer Speiseleitung am Strahler.

## Verfügbare Versionen
- **3-Band (20/15/10 m):** Klassische Original-Version, 3-Element auf 20/15 m, 4-Element auf 10 m
- **5-Band (20/17/15/12/10 m):** Erweiterung mit 17 m und 12 m als 2-Element-Yagis
- **Low-Sunspot (20/17/15 m):** Für Sonnenflecken-Minimum optimiert
- **WARC (30/17/12 m):** WARC-Bänder, 6 m lange Spreizer nötig

## Funktionsweise
Pro Band werden eigene Drähte mit den vorberechneten Maßen verlegt:
- **L_el:** elektrische Drahtlänge (Strahler-Schenkel × 2, ohne Speiseleitung)
- **Zuschnitt Arm:** physikalischer Schnitt für einen Schenkel (L_el/2 + Toleranz)
- **S:** Position auf dem Boom in Meter (+ = Direktor-Seite, − = Reflektor-Seite)

Originalmaße sind für **Kupferlitze (CuLi)** auf dem
Original-Spiderbeam-Spreizersystem optimiert. Andere Materialien
(z.B. blanker Kupferdraht) ergeben leicht abweichende Resonanzen.

## Praxis-Tipps
- **Glasfaser-Spreizer:** spiderbeam.com Original-Set verwenden
- **Drahtmaterial:** CuLi 1,5 mm² – nicht durch andere Drähte ersetzen
- **Speisung:** über separate Speiseleitung (Koax-Schnitzel) am Strahler
- **Reihenfolge beim Aufbau:** untere Bänder zuerst (innen), höhere Bänder darüber
- **Trimmen:** alle Bänder einzeln mit Antennenanalysator durchprüfen
- **Nicht für Direktmontage** auf Alurohr geeignet – dafür Einband-Yagi nutzen

## Quellen
- DF4SA (Cornelius Paul): Multi-Band Spiderbeam Original-Designs
- spiderbeam.com: Komplettsätze, Bauanleitungen
