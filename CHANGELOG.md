# Changelog

Alle nennenswerten Änderungen am Projekt werden hier dokumentiert.  
Format angelehnt an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

---

## [1.0.0] — 2026-05-09

### Erstveröffentlichung

Vollständige SwiftUI macOS-App mit 25 Amateurfunk-Rechnern in 6 Kategorien.

#### Drahtantennen
- Dipol-Rechner (Halbwellen, alle Bänder)
- Groundplane / Vertikal (λ/4 mit Radials)
- J-Pole / Slim Jim
- Sperrtopf (koaxiale Mantelwellensperre)
- Windom / OCFD
- EFHW-Verkürzungsspule
- Loop-Antenne

#### Richtstrahler
- Moxon Rectangle
- HB9CV Beam
- **Hexbeam** (G3TXQ, mehrbandig 10/15/20/40m)
  - Parametrische Draufsicht: Treiber (V), Reflektor (gestrichelt), Schnüre (grau), Tip Spacer
  - Seitenansicht: Halbkreis-Schüssel, horizontale Drähte, Träger, Höhenmass
- Yagi-Rechner (2–6 Elemente nach Rothammel)
- Spiderbeam Einzelband
- Spiderbeam Multi-Band

#### Spezialantennen
- Magnetic Loop (Kapazität, Güte, Bandbreite)
- Antennen-Designer

#### Spulen & Transformatoren
- Balun / Unun (Wicklungsrechner, verschiedene Übersetzungen)
- Strahler-Verlängerung
- Spulen-Wickler (Luftspule, Induktivität)

#### Anpassung & Leitungen
- Anpassnetzwerk (L-Netz)
- Koax-Stub (λ/4, λ/2, offen/kurzgeschlossen, Schema-Canvas)
- Kabeldämpfung

#### Signale & Tools
- Pegel-Umrechner (dBm / dBW / V / µV / W)
- SWR-Simulator
- Linkbudget / Reichweite (Friis-Formel)
- QTH-Locator (Maidenhead ↔ Koordinaten, Distanz, Bearing)

#### UI
- NavigationSplitView mit kategorisierter Seitenleiste (Mindestbreite 220 px)
- Konsistentes `SectionCard` + `ResultRow` Design-System
- Dark Mode nativ unterstützt
