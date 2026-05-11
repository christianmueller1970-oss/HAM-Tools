// SEO-Metadaten pro Route. Wird beim Pre-Rendering in den <head> der erzeugten
// statischen HTML-Datei geschrieben, sodass Google sofort vollständigen
// Inhalt + Titel + Description sieht — keine JS-Ausführung nötig.
//
// Pflichtfelder: title, description.
// Optional: keywords (Komma-getrennt).

const SITE_NAME = 'HAM-Tools Toolbox'
const SITE_URL  = 'https://toolbox.funkwelt.net'
const AUTHOR    = 'HB9HJI / Funkwelt'

export const SEO_DEFAULT = {
  title: `${SITE_NAME} — Amateurfunk-Rechner`,
  description: 'Online-Toolbox für Amateurfunk: Antennen-Rechner (Dipol, Hexbeam, Yagi, EFHW, Magnetic Loop, …), Anpassnetzwerke, Smith-Chart, NEC2-Antennen-Simulator, QTH-Locator. Kostenlos, offen, ohne Anmeldung.',
  keywords: 'Amateurfunk, Ham Radio, Antennen-Rechner, Antennenrechner, HF-Antenne, Dipol, Hexbeam, Yagi, EFHW, Magnetic Loop, NEC2, Smith-Chart, SWR, Kabeldämpfung, HB9HJI, Funkwelt',
}

export const SEO_ROUTES = {
  '/': {
    title: SEO_DEFAULT.title,
    description: SEO_DEFAULT.description,
    keywords: SEO_DEFAULT.keywords,
  },
  '/dipol': {
    title: `Dipol-Rechner λ/2 — ${SITE_NAME}`,
    description: 'Online-Rechner für Halbwellen-Dipol-Antennen: Gesamtlänge λ/2 und Arm-Länge λ/4 berechnen, mit Verkürzungsfaktor. Klassischer Dipol und Faltdipol (4:1 Balun).',
    keywords: 'Dipol Rechner, λ/2 Dipol, Halbwellendipol, Faltdipol, Antenne, Verkürzungsfaktor, KW-Antenne',
  },
  '/groundplane': {
    title: `Groundplane / Vertikal-Antenne — ${SITE_NAME}`,
    description: 'Berechnet vertikalen λ/4-Strahler mit Radials: Strahlerlänge, Radial-Länge, Anzahl + Neigungswinkel, Impedanz je nach Winkel (36–52 Ω).',
    keywords: 'Groundplane Rechner, Vertikalantenne, λ/4 Vertikal, Radials, GP-Antenne',
  },
  '/jpole': {
    title: `J-Pole & Slim Jim Rechner — ${SITE_NAME}`,
    description: 'Auslegung J-Pole und Slim Jim (J-Zepp): λ/2 Strahler + λ/4 Anpassstub, Einspeisepunkt-Position, von 10m bis 23cm Band.',
    keywords: 'J-Pole, Slim Jim, J-Zepp, 2m Antenne, 70cm Antenne, UKW-Antenne, Anpassstub',
  },
  '/sperrtopf': {
    title: `Sperrtopf (Bazooka-Balun) Rechner — ${SITE_NAME}`,
    description: 'Sperrtopf (Bazooka-Balun) Auslegung: λ/4-Mantelsperre auf Koaxleitung. Berechnet Länge, Material-Empfehlung, Sperrwirkung pro Band.',
    keywords: 'Sperrtopf, Bazooka, Mantelsperre, Koax-Choke, Common Mode',
  },
  '/windom': {
    title: `Windom (OCFD) Rechner — Off-Center-Fed Dipol — ${SITE_NAME}`,
    description: 'Windom-Antenne (Off-Center-Fed Dipol) berechnen: 36 % / 64 % Schenkel, Multiband-Eigenschaften, 4:1 oder 6:1 Balun.',
    keywords: 'Windom, OCFD, Off Center Fed Dipol, Multiband-Antenne, KW-Drahtantenne',
  },
  '/efhw': {
    title: `EFHW-Antenne Rechner (End-Fed Half Wave) — ${SITE_NAME}`,
    description: 'Endgespeister Halbwellen-Strahler (EFHW): λ/2-Drahtlänge, Gegengewicht, 49:1 Unun, Multiband-Harmonische. Ideal für /P und Field Day.',
    keywords: 'EFHW, End Fed Half Wave, endgespeister Strahler, 49:1 Unun, Portabel-Antenne, /P',
  },
  '/efhwv': {
    title: `EFHW verkürzt mit Loading-Spule — ${SITE_NAME}`,
    description: 'Verkürzte EFHW mit Verlängerungsspule: berechnet benötigte Induktivität, Windungszahl auf gegebenem Spulenkörper, Wickeldaten, Wirkungsgrad.',
    keywords: 'EFHW verkürzt, Verlängerungsspule, Loading Coil, Helical, kompakt-Antenne',
  },
  '/loop': {
    title: `Loop-Antenne Rechner (Delta + Quad) — ${SITE_NAME}`,
    description: 'Ganzwellen-Loop berechnen: Delta-Loop gleichseitig (110 Ω), Delta 40/30/30 (50 Ω), Delta Apex unten, Quad-Loop. Mit λ/4-Anpassleitung.',
    keywords: 'Delta Loop, Quad Loop, Vollwellen-Loop, Ganzwellen-Loop, Schleifen-Antenne',
  },
  '/moxon': {
    title: `Moxon Rectangle Rechner — ${SITE_NAME}`,
    description: '2-Element-Moxon-Rechteckantenne: 5 Geometrie-Werte (A/B/C/D/E) nach G3TXQ/VK2ZOI, kompakte Richtantenne mit ca. 50 Ω.',
    keywords: 'Moxon, Moxon Rectangle, 2-Element, kompakte Yagi, Richtantenne',
  },
  '/hb9cv': {
    title: `HB9CV Beam Rechner — ${SITE_NAME}`,
    description: 'HB9CV 2-Element-Beam Auslegung: Reflektor + Direktor, Boomlänge, Verkürzungsfaktor nach Stab-Durchmesser, Gamma-Match oder Direkt-Speisung.',
    keywords: 'HB9CV, 2 Element Beam, Phaseshifter, kompakte Yagi, 2m Beam, UKW Beam',
  },
  '/hexbeam': {
    title: `Hexbeam Rechner (G3TXQ Broadband) — ${SITE_NAME}`,
    description: 'G3TXQ Broadband Hexbeam-Auslegung 6 Bänder (20–6 m) nach offizieller HEX6B Bauanleitung. ½ Driver, Reflector, Tip Spacer, Spreader-Radius pro Band.',
    keywords: 'Hexbeam, G3TXQ, Broadband Hexbeam, HEX6B, 6-Band Beam, Multiband Richtantenne, KW Beam',
  },
  '/yagi': {
    title: `Yagi-Rechner (2–5 Elemente) — ${SITE_NAME}`,
    description: '2- bis 5-Element-Yagi auslegen: Reflektor, Driver, Direktoren, Boomlänge, Impedanz, Gewinn je Element-Anzahl. Alurohr oder Draht.',
    keywords: 'Yagi Rechner, Yagi-Uda, 3 Element Yagi, 5 Element Yagi, Richtantenne, KW-Beam',
  },
  '/spidereinzel': {
    title: `Spiderbeam Einzelband — ${SITE_NAME}`,
    description: 'Spiderbeam-Auslegung Einzelband mit Draht-Elementen auf Glasfaser-Spreizern: 2–6 Elemente, Strahler-Länge, Boom, Halbspreizer-Bedarf.',
    keywords: 'Spiderbeam, Drahtantenne Beam, leichte Yagi, Glasfaser-Spreizer, /P Beam',
  },
  '/spidermulti': {
    title: `Spiderbeam Multi-Band (DF4SA) — ${SITE_NAME}`,
    description: 'Multi-Band-Spiderbeam-Varianten nach DF4SA: 3-Band, 5-Band, Low-Sunspot, WARC. Originalmaße pro Band, Spreizer-Anforderungen.',
    keywords: 'Spiderbeam Multi, DF4SA, 5-Band Spiderbeam, WARC Spiderbeam, Multiband-Beam',
  },
  '/magloop': {
    title: `Magnetic Loop Rechner — ${SITE_NAME}`,
    description: 'Magnetic Loop (kleine Schleifenantenne) berechnen: Induktivität, Resonanzkapazität, Spannung am Drehkondensator, Q, Bandbreite, Wirkungsgrad. Kreis/Quadrat/Achteck.',
    keywords: 'Magnetic Loop, Magnetantenne, kompakte Antenne, Drehkondensator, kleine Schleife, Indoor-Antenne',
  },
  '/balun': {
    title: `Balun / Unun Wicklungsrechner — ${SITE_NAME}`,
    description: 'Übertrager-Rechner für Balun und Unun (1:1, 4:1, 9:1, 49:1, …) auf Ringkernen. Windungszahl, Drahtlänge, AL-Wert, Mix-Empfehlung.',
    keywords: 'Balun, Unun, 4:1 Balun, 49:1 Unun, Ringkern, Wicklungen, Übertrager',
  },
  '/mantelwellensperre': {
    title: `Mantelwellensperre / Common-Mode Choke — ${SITE_NAME}`,
    description: 'Mantelwellensperre auf Ringkern auslegen: L, X_L, Z_CM pro Band, Wickel-Check, Mix-Empfehlung (z.B. FT240-43 mit Koax).',
    keywords: 'Mantelwellensperre, Common Mode Choke, FT240, Ringkern Choke, Koax-Drossel',
  },
  '/strahlerverl': {
    title: `Strahler-Verlängerung mit Spule — ${SITE_NAME}`,
    description: 'Verkürzte Vertikalantenne mit Verlängerungsspule: benötigte Induktivität, Position (Basis/Mitte/Top), Q-Faktor.',
    keywords: 'Strahlerverlängerung, Loading Coil, Verkürzungsspule, Vertikal verkürzt',
  },
  '/spulenwickler': {
    title: `Spulen-Wickler (Wheeler-Formel) — ${SITE_NAME}`,
    description: 'Luftspule berechnen nach Wheeler: Windungen, Wickellänge, Drahtlänge aus L, Spulendurchmesser, Drahtstärke. Optimierung Q.',
    keywords: 'Luftspule, Wheeler Formel, Spule wickeln, Induktivität berechnen, HF-Spule',
  },
  '/anpassnetz': {
    title: `Anpassnetzwerk (L-Netz) Rechner — ${SITE_NAME}`,
    description: 'L-Netz-Anpassung berechnen: bis zu 4 Topologien (Tief-/Hochpass × Shunt/Series), Bauteilwerte (L in µH, C in pF) bei Zielfrequenz.',
    keywords: 'Anpassnetzwerk, L-Netz, Matching Network, Impedanzanpassung, ATU-Berechnung',
  },
  '/koaxstub': {
    title: `Koax-Stub Rechner (λ/4, λ/2) — ${SITE_NAME}`,
    description: 'Koax-Stubs auslegen: λ/4-Stub als Anpassung, λ/2 als Notch-Filter, mit Verkürzungsfaktor für RG58, RG213, H2000, Aircell etc.',
    keywords: 'Koax-Stub, λ/4 Stub, λ/2 Stub, Notch Filter, Anpassleitung',
  },
  '/kabeldaempfung': {
    title: `Koaxialkabel-Dämpfungsrechner — ${SITE_NAME}`,
    description: 'Koax-Dämpfung über Frequenz, Länge und Kabeltyp: 30+ Kabel (RG58, RG213, Aircell 7, Ecoflex, H2000, Messi & Paoloni Hyperflex/Ultraflex/Airborne).',
    keywords: 'Koax Dämpfung, Kabelverlust, RG213, Aircell, Ecoflex, Hyperflex, Ultraflex, dB pro Meter',
  },
  '/pegelrechner': {
    title: `Pegel-Umrechner (dBm, dBµV, S-Meter) — ${SITE_NAME}`,
    description: 'Umrechnung dBm ↔ dBµV ↔ V ↔ Watt, S-Stufen (S0–S9+60), Feldstärke dBµV/m bei gegebener Bandbreite.',
    keywords: 'dBm Rechner, dBµV, S-Meter, Pegel-Umrechner, S-Stufe, Feldstärke',
  },
  '/swr': {
    title: `SWR-Simulator — ${SITE_NAME}`,
    description: 'Stehwellenverhältnis (SWR/VSWR) interaktiv simulieren: Vorlauf/Rücklauf, Verluste, reflektierte Leistung, kritische Werte für Endstufen.',
    keywords: 'SWR Simulator, VSWR, Stehwelle, Reflexionsfaktor, Endstufe Schutz',
  },
  '/linkbudget': {
    title: `Linkbudget / Reichweiten-Rechner — ${SITE_NAME}`,
    description: 'Linkbudget HF/VHF/UHF: Sendeleistung, Antennengewinn, Kabelverlust, Freiraumdämpfung, Empfänger-Empfindlichkeit, Reichweite-Abschätzung.',
    keywords: 'Linkbudget, Reichweite, Freiraumdämpfung, Pfaddämpfung, HF-Reichweite',
  },
  '/qthlocator': {
    title: `QTH-Locator (Maidenhead Grid) — ${SITE_NAME}`,
    description: 'Maidenhead-Locator berechnen + umrechnen: Lat/Lon ↔ 6- oder 8-stelliger Locator. Distanz und Azimut zwischen zwei Locatoren.',
    keywords: 'QTH Locator, Maidenhead, Grid Square, JN47, Distanz, Azimut, Funkkontakt',
  },
  '/bandplan': {
    title: `IARU R1 Bandplan — ${SITE_NAME}`,
    description: 'Vollständiger IARU Region 1 Bandplan für 22 Amateurfunk-Bänder (2200 m bis 1,25 cm) mit Modus-Segmenten, Bandbreiten, Contests und Max-Leistungen.',
    keywords: 'IARU Bandplan, Region 1, Frequenzplan, Amateurfunk-Bänder, CW SSB FT8 Segmente',
  },
  '/smithchart': {
    title: `Smith-Chart Rechner (Z₀ 50/75/300/450 Ω) — ${SITE_NAME}`,
    description: 'Interaktives Smith-Diagramm mit Γ, VSWR, RL, ML, Admittanz, L-Network-Anpassung mit bis zu 4 Lösungen.',
    keywords: 'Smith Chart, Smith-Diagramm, Reflexionskoeffizient, VSWR, L-Network, Impedanz-Matching',
  },
  '/antennensim': {
    title: `Antennen-Simulator (NEC2 im Browser) — ${SITE_NAME}`,
    description: 'NEC2-Antennen-Simulator im Browser (WASM): Drahtmodelle bauen, Frequenz-Sweep mit SWR/Z-Charts, 2D + 3D-Strahlungsdiagramm, LD-Karten (Spule/Kondensator), Vergleichs-Modus, Templates.',
    keywords: 'NEC2 Online, Antennen Simulator, Strahlungsdiagramm, WebAssembly NEC2, Antennen-Software, 4nec2 alternative',
  },
}

export function seoFor(path) {
  return SEO_ROUTES[path] || SEO_DEFAULT
}

export { SITE_NAME, SITE_URL, AUTHOR }
