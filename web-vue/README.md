# HAM-Tools Web-Version

Vue 3 + Vite Portierung der nativen macOS-App. 1:1 Übersetzung der Berechnungen
und Skizzen, deployed als statische Site auf **https://toolbox.funkwelt.net**.

**Native = Source of Truth.** Erst SwiftUI-View erweitern/anpassen, dann Vue-Datei
nachziehen.

---

## Quickstart

```bash
# Dev-Server (Hot-Reload auf http://localhost:5173)
npm install
npm run dev

# Production-Build (Output in dist/)
npm run build

# Deployment auf Server
scp -r dist/* root@187.124.10.252:/var/www/toolbox/
```

---

## Stack

- **Vue 3** mit `<script setup>` und Composition API
- **Vite** (Bundler, Hot-Reload)
- **Vue Router** (Hash-Mode `/#/...`, kein Server-Rewrite nötig)
- **Lucide-Icons** (`lucide-vue-next`, tree-shakeable, SF-Symbol-Pendant)
- **Keine UI-Library** — alles handgemachtes CSS in `src/style.css`
- **Charts/Skizzen:** inline SVG mit computed Geometrie (kein Chart.js)

---

## Projektstruktur

```
web-vue/
├── index.html              Vite-Entry, lädt /src/main.js
├── package.json
├── vite.config.js
├── src/
│   ├── main.js             createApp + Router-Mount
│   ├── App.vue             Sidebar + RouterView, Theme-Switcher
│   ├── style.css           Themes (classic/light/dark) + globale Klassen
│   ├── router.js           25 Routen (Lazy-Loading per Calculator)
│   ├── composables/
│   │   └── useHam.js       pf(), fmt(), bands[], isBandActive()
│   ├── components/
│   │   └── BandGrid.vue    Wiederverwendete Band-Schnellwahl
│   └── views/              25 Calculator-Komponenten
│       ├── Dipol.vue
│       ├── Groundplane.vue
│       └── ...
└── dist/                   npm run build Output
```

---

## Theme-System

Drei Themes über CSS-Klasse auf `<body>`:
- **`body`** (default) — Ham Classic: Sidebar amber, Cards System-Style
- **`body.light`** — heller Hintergrund, dunkler Text
- **`body.dark`** — dunkelblau-grau

Zwei Variablen-Sets im Classic (im Light/Dark identisch):
- `--nav-tp / --nav-ts / --nav-td` für **Sidebar** (theme-akzentuiert: amber)
- `--tp / --ts / --td` für **Card-Inhalte** (System-Style: weiß/grau)
- `--acc / --hi` für Akzente (System-Blau im Classic, nicht amber)

Wenn Werte in einer Card amber statt weiß/blau sind → vermutlich `var(--nav-tp)`
statt `var(--tp)` versehentlich verwendet.

---

## Globale CSS-Klassen

| Klasse | Zweck | SwiftUI-Pendant |
|---|---|---|
| `.card` | Card-Container | `SectionCard` |
| `.card h2` | Section-Titel (uppercase, dim) | `GroupBox` Titel |
| `.calc-title` | Page-Titel oben | `.navigationTitle` |
| `.rr` | Result-Row (Label links, Value rechts) | `ResultRow` |
| `.rr.hi` | Hervorgehobene Row (Wert in Akzent + bold) | `ResultRow(highlight: true)` |
| `.rr .lbl` / `.rr .val` | Label / Value Spans | |
| `.band-grid` + `.bb` / `.bb.on` | Band-Schnellwahl-Grid | `LazyVGrid` mit `.tint(.accentColor)` |
| `.seg` + `.sb` / `.sb.on` | Segment-Buttons (horizontale Picker) | `Picker(.segmented)` |
| `.opt-grid` + `.opt-btn` / `.opt-btn.active` | Picker-Cards mit Label+Sub | `.bordered` Buttons mit `.tint` |
| `.opt-label` / `.opt-sub` | Innerhalb `.opt-btn` | |
| `.band-toggle` (mit `--bc` inline) | Farbige Bandfarben-Toggles | `Toggle(.button).tint(bandColor)` |
| `.skz-bg` | Diagramm-Container für SVG | `Canvas` Wrapper |
| `.tbl`, `.mono`, `.fw7` | Tabellen, Monospace, Bold | `LazyVGrid` Tabellen |
| `.info` / `.warn` / `.ok-box` | Status-Boxen mit farbigem Border-Left | Badge-artige HStacks |
| `.ken-grid` + `.ken` / `.ken.hi` | Kennzahlen-Kacheln | `KenngroesseKachel` |
| `.ken-val` / `.ken-lbl` | Wert + Label in Kachel | |

---

## Native → Vue Mapping

| SwiftUI | Vue 3 |
|---|---|
| `@State private var freqText = "14.175"` | `const state = reactive({ freq: '14.175' })` |
| `private var ergebnis: Erg? { ... }` | `const result = computed(() => { ... })` |
| `Picker(...).pickerStyle(.segmented)` | `<div class="seg"><button class="sb" :class="{on: ...}">` |
| `Toggle(...).toggleStyle(.button)` | `<button class="band-toggle" :class="{active}" :style="{'--bc': color}">` |
| `SectionCard(title: "X") { ... }` | `<div class="card"><h2>X</h2>...</div>` |
| `ResultRow(label:, value:, highlight: true)` | `<div class="rr hi"><span class="lbl">...</span><span class="val">...</span></div>` |
| `KenngroesseKachel(wert:, label:)` | `<div class="ken"><div class="ken-val">...</div><div class="ken-lbl">...</div></div>` |
| `LazyVGrid(columns: ..., spacing: 12) { ... }` | `<div style="display:grid;grid-template-columns:...;gap:12px">` |
| `Canvas { ctx, size in ... }` | inline `<svg :viewBox="...">` mit `computed` für Koordinaten |
| `Color.accentColor` (System Blue) | `var(--acc)` (= System Blue im Classic) |
| `.foregroundStyle(.secondary)` | `var(--ts)` |

---

## Skizzen-Portierung (Canvas → SVG)

**SwiftUI:**
```swift
ctx.stroke(Path { p in
    p.move(to: CGPoint(x: cx - armLen, y: cy))
    p.addLine(to: CGPoint(x: cx + armLen, y: cy))
}, with: .color(.blue), lineWidth: 4)

ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: cy-5, width: 10, height: 10)),
         with: .color(.accentColor))

ctx.draw(Text("50Ω").font(.caption).bold().foregroundStyle(Color.accentColor),
         at: CGPoint(x: cx, y: cy + 20), anchor: .center)
```

**Vue/SVG:**
```html
<svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`">
  <line :x1="cx - armLen" :y1="cy" :x2="cx + armLen" :y2="cy"
        stroke="#60a5fa" stroke-width="4"/>
  <circle :cx="cx" :cy="cy" r="5" fill="var(--acc)"/>
  <text :x="cx" :y="cy + 20" text-anchor="middle"
        font-size="11" font-weight="bold" fill="var(--acc)">50Ω</text>
</svg>
```

Patterns:
- ViewBox in Konstanten (`SVG_W = 600, SVG_H = 200`)
- Geometrie über `computed()` aus `result` ableiten (skaliert mit Frequenz/Größe)
- Element-Farben: Strahler `#60a5fa` (blau), Reflektor `#f87171` (rot), Direktor `#4ade80` (grün)
- Akzent-Texte: `fill="var(--acc)"` (50Ω-Labels, Speisepunkt)
- Sekundär-Texte: `fill="var(--ts)"` (Bemaßung, m/cm)
- Hilfslinien: `stroke="rgba(140,140,140,0.5)"` mit `stroke-dasharray="3,2"`

---

## Neuen Rechner hinzufügen

1. **SwiftUI-View lesen:** `Sources/HAMRechner/Features/<Name>/<Name>View.swift`
2. **Vue-Datei anlegen:** `web-vue/src/views/<Name>.vue` nach diesem Template:

```vue
<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import BandGrid from '../components/BandGrid.vue'

const state = reactive({ freq: '14.175', vf: '0.95' })

const result = computed(() => {
  const f = pf(state.freq), vf = pf(state.vf)
  if (!f || !vf) return null
  // ... 1:1 Übersetzung der Swift-Berechnung
  return { f, vf, ergebnis: 150/f*vf }
})
</script>

<template>
  <div class="calc-title">Mein Rechner</div>
  <BandGrid v-model:freq="state.freq" />
  <div class="card">
    <h2>Eingabe</h2>
    <div class="inp-grid">
      <div class="inp-g"><label>Frequenz</label>
        <div class="inp-row"><input v-model="state.freq"><span>MHz</span></div>
      </div>
    </div>
  </div>
  <template v-if="result">
    <div class="card">
      <h2>Ergebnis</h2>
      <div class="rr hi"><span class="lbl">Wert</span><span class="val">{{ fmt(result.ergebnis) }} m</span></div>
    </div>
    <div class="card">
      <h2>Skizze</h2>
      <div class="skz-bg"><svg :viewBox="`0 0 600 200`">...</svg></div>
    </div>
  </template>
</template>
```

3. **Route registrieren** in `src/router.js`:
   ```js
   { path: '/meinrechner', component: () => import('./views/MeinRechner.vue') },
   ```

4. **Sidebar-Eintrag** in `src/App.vue` (Icon aus Lucide importieren):
   ```js
   import { Antenna } from 'lucide-vue-next'
   // im richtigen navGroup:
   { label: 'Mein Rechner', to: '/meinrechner', icon: Antenna },
   ```

5. **Testen:** `npm run dev` → Hot-Reload zeigt Änderung sofort
6. **Deploy:** `npm run build && scp -r dist/* root@187.124.10.252:/var/www/toolbox/`

---

## Bewusste Auslassungen

| Native-Feature | Status Web | Begründung |
|---|---|---|
| DX-Cluster (WebSocket auf Port 7300) | nicht portiert | Eigenes Folge-Projekt mit nginx-WS-Proxy |
| QTH-Locator MapKit | nur Locator↔Coord | Karte/SOTA/POTA/Fresnel = eigenes Projekt mit Leaflet |
| Settings-Modal | Theme-Picker im Sidebar-Footer | Kompakter, kein Settings-State |
| Welcome-View | Auto-Redirect auf /dipol | Web-UX-Standard |
| SF-Symbols-Icons | Lucide-Icons | Open-Source-Pendant |

---

## Deployment

**Server:** Debian 12 auf 187.124.10.252, nginx 1.22, HTTPS via Let's Encrypt (Auto-Renewal).
**Webroot:** `/var/www/toolbox/`
**Nginx-Config:** `/etc/nginx/sites-available/toolbox.funkwelt.net` (mit Asset-Caching für `/assets/*`)
**Firewall (ufw):** Ports 22/80/443 offen, **Port 7300 für DXSpider niemals beeinträchtigen**

```bash
# Optional als Alias in ~/.zshrc
alias deploy-toolbox='cd "<absoluter Pfad>/web-vue" && npm run build && scp -r dist/* root@187.124.10.252:/var/www/toolbox/'
```

---

## Workflow für neue Native-Features

1. Feature in Native (SwiftUI) implementieren + testen
2. View-Datei + Model-Datei in `Sources/HAMRechner/Features/<Name>/` lesen
3. Neue/aktualisierte Vue-Datei in `web-vue/src/views/`
4. `npm run dev` für Hot-Reload-Test
5. `npm run build && scp ...` für Deploy
6. Im Browser auf https://toolbox.funkwelt.net verifizieren
