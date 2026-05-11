# HAM-Tools — TODO

Featurelist und Backlog für **Native (macOS / SwiftUI)** und **Web (Vue 3 auf toolbox.funkwelt.net)**.

Convention:
- `[ ]` offen · `[~]` in Arbeit · `[x]` erledigt
- **N:** = nur Native · **W:** = nur Web · **NW:** = beide
- Items werden bei Erledigung NICHT gelöscht, sondern abgehakt — damit man die Historie sieht

---

## In Arbeit

- [x] **N:** **Local Time zusätzlich rechts anzeigen** — UTC bleibt unverändert (bold, primary), rechts daneben Local Time (regular, secondary) im Format `HH:mm:ss LT` aus `TimeZone.current`, gleicher 1-Sekunden-Timer. DXClusterView.swift Header.
- [x] **NW:** **Hexbeam-Rechner G3TXQ-konform überarbeitet (mit Topologie-Korrektur)** — Quelle: WiMo EAntenna HEX6B Bauanleitung Rev. V2.1 (offizielle G3TXQ-Lizenz). Faktoren aus 20m-Referenzmaßen abgeleitet, linear mit λ skaliert: ½ Driver 0,2570·λ · Reflector 0,4849·λ · Tip Spacer 0,0288·λ · Spreader-Radius (horiz.) 0,1635·λ. Schüsselform: Pole-Bogenlänge ≈ π/2 × Horizontal-Radius. Tabelle: ½ Driver / Driver gesamt / Reflektor / Tip Spacer (Spreader-Länge in Summary). Draufsicht-Topologie nach Vergleich mit G3TXQ-Original-Bild durch HB9EIZ revidiert: Reflector ist SOLID 5-Sehnen-Polylinie mit 2 kurzen Schultern nach vorn (Reflector-Tip → 90° → 150° → 210° → 270° → Reflector-Tip); Driver-V hat langen Tail über Front-Spreader-Tip hinaus Richtung hinterem Nachbar-Spreader (75% der Sehne); Tip Spacer ist einzige gestrichelte Linie (18% der Sehne, entspricht echtem 24″/11′4″-Verhältnis); Treffpunkt knapp über horizontaler Mittelachse. Warning-Banner durch grünen G3TXQ-Quellen-Hinweis ersetzt. hexbeam.md mit Bracket-Anordnung + HEX6B-Specs.
- [ ] **NW:** **Hexbeam-Modell mit echtem Aufbau verifizieren (Juni 2026)** — gemeinsamer Aufbau eigener WiMo HEX6B mit Markus HB9EIZ geplant. Dabei: alle relevanten Maße am realen Aufbau nachmessen (Pole-Bogenlänge pro Segment 20mm/16mm/12mm, Eyelet-Positionen pro Band entlang dem Pole, Drahtlängen pro Band ½ Driver / Reflector / Tip Spacer, Hexagon-Horizontal-Durchmesser, Schüssel-Tiefe/Sag). Anschließend Modell-Werte gegen die Messungen prüfen und die λ-Faktoren ggf. nachjustieren — falls WiMo intern andere Werte als die G3TXQ-20m-Skalierung verwendet (z. B. Tip Spacer konstant 24″ statt λ-skaliert).

---

## Native (macOS)

### Geplant
- [ ] _(deine nächsten Native-Features hier)_

### DX-Cluster
- [x] **N:** **Alerting** — vollständig: (a) Watch-Liste für Calls/Präfixe (gold-Markierung in Spot-Liste, macOS-Notification mit Sound), (b) DXCC-Watch-Liste mit Picker auf 57 Most-Wanted-Entitäten beschränkt (`MOST_WANTED_DXCC` in WatchListStore.swift; häufige Länder bewusst ausgeschlossen, dafür gibt's die Call-/Präfix-Watch), (c) konfigurierbarer Cooldown 1–60 Min (Slider in Settings, `@AppStorage("alertCooldownMin")`, Default 15) — verhindert Pile-Up-Spam. `lastNotifiedAt: [String: Date]` ersetzt `notifiedThisSession: Set<String>`. Bell-Counter im Header bleibt. DXCC_DATA von 108 auf 163 Entitäten erweitert (Most-Wanted: Bouvet, Crozet, Heard, Pratas, Scarborough Reef, Spratly, North Korea, Pitcairn, Tristan da Cunha etc. — Caveat: Sub-Präfix-Konflikte z.B. VP8 → defaultet auf Falklands).
- [ ] **N:** **Logbuch-Modul (eigenes Folge-Projekt — Konzept noch offen)** — größeres Vorhaben, das mehrere Komponenten umfasst:
  - **CAT-Anbindung** an TRX (Hamlib/rigctld als Universal-Layer, oder direkt CI-V Icom / Yaesu CAT / FlexRadio API) — Frequenz, Band, Mode automatisch auslesen beim Loggen
  - **In-App-QSO-Erfassung** mit allen Standard-Feldern (Call, RST, Name, QTH, Locator, Comment …) + Auto-Fill via Cluster-Spot oder Callbook
  - **Multi-Format-Export**: ADIF (LoTW/eQSL/Club Log), Cabrillo (Contest)
  - **ADIF-Import** bestehender Logs (z.B. Migration von Logger32, MacLoggerDX, N1MM)
  - **Award-Tracking** baut darauf auf: DXCC/SOTA/POTA-Fortschritt (gearbeitet/bestätigt) → Karte + Statistiken
  - **Live-ATNO-Erkennung** im DX-Cluster: Spot-Liste markiert "neu" / "neue Band" / "neuer Mode" / "schon gearbeitet"
  - Erst gründlich planen, dann iterativ umsetzen — kein Quick-Fix.
- [x] **N:** **Spot-Quelle anzeigen** — Spotter-Spalte mit zweiter Zeile (Cluster-Name + Farbcode DX/SOTA/POTA/WWFF), Cluster-Log mit Header beim Connect/Disconnect + Kurz-Tag am Zeilenende
- [x] **N:** **Top-15-Statistik lesbarer machen** — Calls + Bands jetzt in Monospace, größere Schrift, theme.textPrimary, mit Count-Annotation rechts vom Balken; Card-Höhe pro Chart konfigurierbar (Top-15: 380px, Spots pro Band: 320px)
- [x] **N:** **Rechtes Seiten-Panel füllen** — Solar-Daten Section (SSN/X-Ray/Solar Wind/Helium 304Å/Aurora-Lat/Geomag-Feld via hamqsl.com XML, farbig nach Schwellwerten) + "Eigene Spots"-Section (filtert `dxCall == myCallsign` aus `@AppStorage("callsign")`, Top 5 mit Zeit/Freq/Spotter); Panel scrollbar; SFI-Gauge `invertColors: true` (hoher SFI = grün rechts, niedriger = rot links); Kp-Gauge unverändert (niedrig = grün, hoch = rot)

### Ideen
- [ ] _(Brainstorm-Liste)_

---

## Web (toolbox.funkwelt.net)

### Geplant
- [ ] **W:** Mobile-Verfeinerungen (falls bei Nutzung Probleme auftreten — Touch-Targets, Skizzen-Skalierung)

### Ideen / Bekannte Auslassungen
- [ ] **W:** DX-Cluster im Web (WebSocket-Proxy via nginx auf bestehenden Port 7300, eigenes Folge-Projekt)
- [ ] **W:** QTH-Locator mit Karte (Leaflet) inkl. SOTA/POTA-Overlay, Höhenprofil, Fresnel-Zonen — eigenes Folge-Projekt
- [x] **W:** Welcome-View statt Auto-Redirect auf /dipol — umgesetzt (Welcome-Page mit Kategorien-Übersicht + Projekt-Info ist Default-Route)
- [ ] **W:** PWA-Setup (manifest.json + Service Worker für Offline-Nutzung)
- [ ] **W:** Print-Stylesheet für Skizzen + Maße (Druck eines Bauplans)
- [x] **W:** **Antennen-Simulator (NEC2 via WASM)** — alle Phasen erledigt. **Phase 1+2+3 (2026-05-10):** PoC mit nec2c.wasm + Worker; Mehrelement-Editor (Drahtmodell-Tabelle, 5 Templates, Excitation-Picker, 2D-Modellvorschau Top-Down + Side); Frequenz-Sweep (Multi-Frequenz mit SWR/R+jX-Charts, Resonanz-Erkennung, Bandbreiten-Auswertung). Live auf toolbox.funkwelt.net/#/antennensim. **Phase 5 (Native-Integration):** WKWebViewWrapper als NSViewRepresentable, Sidebar-Eintrag in "Signale & Tools". **Phase 4A (2026-05-11):** 3D-Strahlungsdiagramm via Three.js (Pattern3D.vue) — Sphären-Mesh, Viridis-Color-Map, OrbitControls, 3-Achsen + Boden-Grid. **Phase 4B (2026-05-11):** Template-Import in allen 14 Antennen-Rechnern via "Im Sim öffnen"-Button. composables/openInSim.js für URL-safe Base64-JSON. Saubere 1:1-Exporte: Dipol, Yagi, Hexbeam (mit Band-Picker), EFHW, Windom, Groundplane, JPole/Slim Jim, LoopAntenne (4 Varianten), Moxon, SpiderbeamEinzel, SpiderbeamMulti (mit Band-Picker). Best-Effort-Approximationen mit Tooltip-Warnung: HB9CV (als Yagi, kein Phaseshifter), EFHWVerkuerzung (idealisierter λ/2 ohne Spule), MagneticLoop (ohne Abstimm-C — Strahlungspattern sichtbar, nicht resonant).

---

## Cross-Cutting (Native + Web parallel)

### Neue Rechner (in beiden Versionen umsetzen)
- [x] **NW:** **IARU R1 Bandplan-Visualisierung** — vollwertige Detail-Visualisierung wie funkwelt.net: Balken pro Band mit pct-basierten farbigen Sub-Segmenten, Click-to-Expand zeigt detaillierte Tabelle (VON–BIS / Bandbreite / Modus / Hinweis pro Subsegment). Header pro Band mit Status (Primär/Sekundär), Max-Leistung-Badge, Mode-Chips (CW/SSB/FT8/PSK31...), Contest-Badge. Filter (Bandkategorie, Contest, WARC, Digi), Frequenz-Lookup. Single Source of Truth `Sources/HAMRechner/Content/bandplan.json` (Datenstruktur + Inhalte 1:1 aus dem funkwelt-bandguide PHP-Plugin extrahiert: 22 Bänder von 2200m bis 1,25cm). Native + Web synchron, deployed.

### Neue Rechner
- [x] **NW:** **Mantelwellensperre-Rechner** — Common-Mode Choke Auslegung. Auswahl Ringkern aus DB (Filter nach Material/Kern), Eingabe Windungen + Test-Frequenz + Koax-Durchmesser. Berechnet L (µH), X_L (Ω), Z_CM mit Bewertung (top/ok/akzeptabel/ungenügend). Multiband-Tabelle 160m–6m mit Status pro Band. Wickel-Check (max. Windungen, Auslastung, Warnung wenn Wickelfenster überfüllt). Warnung bei Eisenpulver-Mix (für Chokes ungeeignet). Praxis-Empfehlungen pro Mix. Native + Web synchron.
- [x] **NW:** **Smith-Chart-Rechner** (Phase 1+2) — Smith-Karte mit konstanten R-Kreisen (blau) und X-Bögen (lila), normalisiert auf wählbare Z₀ (50/75/300/450/600 Ω). Eingabe: Frequenz, R, X. Berechnet: Γ, |Γ|, ∠Γ, VSWR, RL, ML, Admittanz, Serien-Äquivalent. Optionen: VSWR-Kreis, Admittanz-Karte (Y, gespiegelt orange). **Phase 2: L-Network-Anpassung** mit bis zu 4 Lösungen je nach Topologie (Shunt-zuerst wenn R_eq>Z₀, Series-zuerst wenn R_L<Z₀, jeweils Tiefpass + Hochpass). Pro Lösung: Topologie, Bauteilwerte (L in nH/µH, C in pF/nF) bei aktueller Frequenz, Zwischen-Impedanz. Pfad-Visualisierung auf Smith-Karte: grüner Bogen = erste Komponente vom Last-Punkt, oranger Bogen = zweite Komponente bis Match-Mitte. Native + Web synchron.

### Daten-Updates
- [x] **NW:** Kabel-Datenbank erweitert: neue Gruppe **Messi & Paoloni** mit 8 Typen (Hyperflex 5/10/13, Ultraflex 7/10/13, Airborne 5/10). Hyperflex 10 von "H-Typen" zu "Messi & Paoloni" verschoben (war falsch zugeordnet, ID `hypflex10` beibehalten). Native + Web synchron, deployed auf toolbox.funkwelt.net.
- [x] **NW:** Ringkern-Datenbank erweitert: 8 neue Typen — **Mix 31** (FT-114/140/240, beliebt für EFHW & Mantelwellensperren <10 MHz), **Mix 77** (FT-240, MF/LW <2 MHz), kleine Eisenpulver T-50-2/T-68-2/T-94-2 (QRP-Tuner, LPF) und großer T-300-2 (PA-Filter >500W). Native + Web synchron, deployed auf toolbox.funkwelt.net.

---

## Bugs

- [x] **N:** Propagation-Panel Band-Activity: Verhalten geprüft — Heatmap speist sich aus `vm.spots` (alle Quellen: aktiver Cluster + SOTA + POTA + WWFF), bewusst kein Filter (immer Gesamtbild). Passt so.
- [x] **N:** DX-Cluster Status-Indikator zeigt **immer grün** — Inactivity-Watchdog ergänzt: nach 5 Min ohne Daten → `.error` Status + automatischer Reconnect (Check alle 60s)
- [x] **N:** DX-Cluster Spot-Filter unbeschriftet — Custom-Menu mit Label IM Dropdown ("Band: Alle", "Mode: FT8" etc.), aktiver Filter-Wert in Akzentfarbe blau, Häkchen vor ausgewähltem Eintrag im Menü

---

## Recherche / Notizen

- [ ] **W:** **Konzept DX-Cluster für Web** erstellen (read-only, ohne SPOT-Funktion).
  Themen: WebSocket-Proxy via nginx auf bestehendem Port 7300, Live-Stream-Architektur,
  UI-Pattern für rollende Spot-Liste, Filter, Mobile-Tauglichkeit. Umsetzung in späterem Schritt.
- [ ] **NW:** **Brainstorm neue Rechner** — was wäre noch sinnvoll?
  Beispiele zur Diskussion: Smith-Chart Anpassung, Mantelwellensperre Auslegung, Antennen-Tuner-Verluste,
  Kondensator-Spannungsfestigkeit, Rauschtemperatur/NF, S-Meter-Kalibrierung, dBµV/m ↔ µV,
  AC-Spannungsfestigkeit Drehko, Antennen-Diagramm-Visualisierer (NEC2-Light), Sonnenfleckenrelative,
  MUF/LUF-Vorhersage (mit externen Daten?)

---

## Erledigt (Archiv)

### Web
- [x] Vue 3 + Vite Portierung aller 25 Rechner mit Skizzen
- [x] Theme-System (Classic / Light / Dark) mit Sidebar/Card-Trennung
- [x] Lucide-Icons in Sidebar
- [x] Mobile-Hamburger-Menü mit Drawer
- [x] HTTPS via Let's Encrypt + Auto-Renewal
- [x] Production-Deploy auf toolbox.funkwelt.net
- [x] Welcome-Page mit Kategorien-Übersicht + Projekt-Info

### Cross-Cutting
- [x] **NW:** Beschreibungs-Texte für alle 25 Rechner via Markdown (Single Source of Truth in `Sources/HAMRechner/Content/*.md`)

### Native
- [x] EFHW-Rechner aus Antennen-Designer extrahiert
- [x] Ham Classic als Default-Theme
- [x] Light-Theme mit besserem Kontrast
- [x] QTH-Locator mit Karte, Höhenprofil, Fresnel-Zonen, 8-Char-Locator
- [x] **N:** Spot-Retention beim App-Start von 24h auf **60 Min** reduziert (alte Sessions werden nicht mehr reanimiert)
- [x] **N:** Zeit-Picker (15/30/60 min) breiter (80→100 px) — "60 min" wird nicht mehr abgeschnitten (Bandmap, Band Activity, Weltkarte)
