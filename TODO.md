# HAM-Tools — TODO

Featurelist und Backlog für **Native (macOS / SwiftUI)** und **Web (Vue 3 auf toolbox.funkwelt.net)**.

Convention:
- `[ ]` offen · `[~]` in Arbeit · `[x]` erledigt
- **N:** = nur Native · **W:** = nur Web · **NW:** = beide
- Items werden bei Erledigung NICHT gelöscht, sondern abgehakt — damit man die Historie sieht

---

## In Arbeit

- [ ] _(noch nichts)_

---

## Native (macOS)

### Geplant
- [ ] _(deine nächsten Native-Features hier)_

### DX-Cluster
- [ ] **N:** **Alerting** — Ton/Notification wenn ein bestimmtes Rufzeichen oder seltenes DXCC gespottet wird
- [ ] **N:** **Award-Tracking** — DXCC, SOTA, POTA Fortschritt visualisieren (Karte + Statistiken)
- [ ] **N:** **Logbuch-Integration** — Abgleich mit ADIF-Log, bereits gearbeitete Stationen markieren

### Ideen
- [ ] _(Brainstorm-Liste)_

---

## Web (toolbox.funkwelt.net)

### Geplant
- [ ] **W:** Mobile-Verfeinerungen (falls bei Nutzung Probleme auftreten — Touch-Targets, Skizzen-Skalierung)

### Ideen / Bekannte Auslassungen
- [ ] **W:** DX-Cluster im Web (WebSocket-Proxy via nginx auf bestehenden Port 7300, eigenes Folge-Projekt)
- [ ] **W:** QTH-Locator mit Karte (Leaflet) inkl. SOTA/POTA-Overlay, Höhenprofil, Fresnel-Zonen — eigenes Folge-Projekt
- [ ] **W:** Welcome-View statt Auto-Redirect auf /dipol (optional, aktuell ist Web-UX-Standard)
- [ ] **W:** PWA-Setup (manifest.json + Service Worker für Offline-Nutzung)
- [ ] **W:** Print-Stylesheet für Skizzen + Maße (Druck eines Bauplans)

---

## Cross-Cutting (Native + Web parallel)

### Neue Rechner (in beiden Versionen umsetzen)
- [ ] **NW:** _(neue Antennen-/Tools-Rechner hier eintragen)_

### Daten-Updates
- [ ] **NW:** Kabel-Datenbank um neue Typen erweitern (z.B. Messi & Paoloni)
- [ ] **NW:** Ringkern-Datenbank prüfen / aktualisieren

---

## Bugs

- [ ] **N:** Propagation-Panel: keine Filter für Cluster und Mode (Verhalten prüfen, ggf. Filter ergänzen)

---

## Recherche / Notizen

- [ ] _(offene Fragen, Quellen die noch geprüft werden müssen)_

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
