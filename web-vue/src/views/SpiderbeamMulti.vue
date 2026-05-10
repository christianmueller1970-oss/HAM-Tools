<script setup>
import { ref, computed, watch } from 'vue'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const SB_BAND_COLORS = {
  '30m': '#7D2E12',
  '20m': '#DC2626',
  '17m': '#EB5A0A',
  '15m': '#16A34A',
  '12m': '#7D3AED',
  '10m': '#2563EB',
}

const versions = [
  {
    id: 'v3band', label: '3-Band', name: '3-Band Version (20/15/10m)',
    desc: 'Klassische Original-Version. 3-Element auf 20/15m, 4-Element auf 10m.',
    bands: ['20m','15m','10m'],
    data: {
      '20m': [
        { typ:'Strahler',   Lel:9.80,  arm:547, S:-0.40 },
        { typ:'Reflektor',  Lel:10.24, arm:516, S:-5.00 },
        { typ:'Direktor 1', Lel:9.51,  arm:480, S:+5.00 },
      ],
      '15m': [
        { typ:'Strahler',   Lel:6.66, arm:337, S: 0.00 },
        { typ:'Reflektor',  Lel:6.78, arm:343, S:-2.60 },
        { typ:'Direktor 1', Lel:6.29, arm:319, S:+3.30 },
      ],
      '10m': [
        { typ:'Strahler',   Lel:4.80, arm:297, S:+0.50 },
        { typ:'Reflektor',  Lel:5.11, arm:257, S:-1.30 },
        { typ:'Direktor 1', Lel:4.70, arm:237, S:+2.00 },
        { typ:'Direktor 2', Lel:4.70, arm:237, S:+4.20 },
      ],
    },
  },
  {
    id: 'v5band', label: '5-Band', name: '5-Band Version (20/17/15/12/10m)',
    desc: 'Erweiterte Version mit 17m und 12m als 2-Element Yagis.',
    bands: ['20m','17m','15m','12m','10m'],
    data: {
      '20m': [
        { typ:'Strahler',   Lel:9.80,  arm:547, S:-0.40 },
        { typ:'Reflektor',  Lel:10.24, arm:516, S:-5.00 },
        { typ:'Direktor 1', Lel:9.51,  arm:480, S:+5.00 },
      ],
      '17m': [
        { typ:'Strahler',   Lel:7.20, arm:450, S:-0.80 },
        { typ:'Reflektor',  Lel:7.94, arm:399, S:-3.30 },
      ],
      '15m': [
        { typ:'Strahler',   Lel:6.66, arm:337, S: 0.00 },
        { typ:'Reflektor',  Lel:6.79, arm:342, S:-2.60 },
        { typ:'Direktor 1', Lel:6.35, arm:320, S:+3.30 },
      ],
      '12m': [
        { typ:'Strahler',   Lel:5.46, arm:324, S:+0.40 },
        { typ:'Reflektor',  Lel:5.75, arm:290, S:-1.50 },
      ],
      '10m': [
        { typ:'Strahler',   Lel:4.74, arm:320, S:+0.80 },
        { typ:'Reflektor',  Lel:5.15, arm:259, S:-1.10 },
        { typ:'Direktor 1', Lel:4.74, arm:239, S:+2.00 },
        { typ:'Direktor 2', Lel:4.74, arm:239, S:+4.20 },
      ],
    },
  },
  {
    id: 'vsunspot', label: 'Low-Sun', name: 'Low-Sunspot Version (20/17/15m)',
    desc: 'Für Sonnenflecken-Minimum optimiert. 3-Element auf 20/17/15m.',
    bands: ['20m','17m','15m'],
    data: {
      '20m': [
        { typ:'Strahler',   Lel:10.00, arm:500, S: 0.00 },
        { typ:'Reflektor',  Lel:10.25, arm:517, S:-5.00 },
        { typ:'Direktor 1', Lel:9.55,  arm:481, S:+5.00 },
      ],
      '17m': [
        { typ:'Strahler',   Lel:7.62, arm:438, S:-0.40 },
        { typ:'Reflektor',  Lel:7.92, arm:399, S:-3.30 },
        { typ:'Direktor 1', Lel:7.55, arm:381, S:+4.20 },
      ],
      '15m': [
        { typ:'Strahler',   Lel:6.56, arm:385, S:+0.40 },
        { typ:'Reflektor',  Lel:6.86, arm:346, S:-2.60 },
        { typ:'Direktor 1', Lel:6.47, arm:326, S:+3.30 },
      ],
    },
  },
  {
    id: 'vwarc', label: 'WARC', name: 'WARC Version (30/17/12m)',
    desc: 'WARC-Bänder. 3-Element auf 30/17m, 4-Element auf 12m. 6m lange Spreizer nötig!',
    bands: ['30m','17m','12m'],
    data: {
      '30m': [
        { typ:'Strahler',   Lel:13.48, arm:731, S:-0.40 },
        { typ:'Reflektor',  Lel:14.13, arm:711, S:-6.00 },
        { typ:'Direktor 1', Lel:13.66, arm:687, S:+6.00 },
      ],
      '17m': [
        { typ:'Strahler',   Lel:7.62, arm:386, S: 0.00 },
        { typ:'Reflektor',  Lel:7.89, arm:397, S:-3.00 },
        { typ:'Direktor 1', Lel:7.58, arm:381, S:+3.90 },
      ],
      '12m': [
        { typ:'Strahler',   Lel:5.46, arm:330, S:+0.40 },
        { typ:'Reflektor',  Lel:5.83, arm:294, S:-1.90 },
        { typ:'Direktor 1', Lel:5.47, arm:276, S:+2.30 },
        { typ:'Direktor 2', Lel:5.40, arm:273, S:+4.80 },
      ],
    },
  },
]

const selectedVersion = ref('v5band')
const enabledBands = ref(new Set(['20m','17m','15m','12m','10m']))

const version = computed(() => versions.find(v => v.id === selectedVersion.value))
const activeBands = computed(() => version.value.bands.filter(b => enabledBands.value.has(b)))

watch(selectedVersion, (newId) => {
  const v = versions.find(x => x.id === newId)
  if (v) enabledBands.value = new Set(v.bands)
})

function toggleBand(b) {
  const s = new Set(enabledBands.value)
  if (s.has(b)) s.delete(b); else s.add(b)
  enabledBands.value = s
}

function shortType(t) {
  if (t === 'Strahler') return 'Str'
  if (t === 'Reflektor') return 'Ref'
  return t.replace('Direktor ', 'D')
}

function posStr(s) {
  return s === 0 ? '0.00' : (s > 0 ? `+${s.toFixed(2)}` : s.toFixed(2))
}

const allEls = computed(() => {
  const result = []
  for (const b of activeBands.value) {
    for (const el of (version.value.data[b] || [])) {
      result.push({ band: b, el })
    }
  }
  return result.sort((a, b) => b.el.S - a.el.S)
})

// SVG layout
const SVG_W = 700
const SVG_H = 500
const mL = 108, mR = 108, mT = 52, mB = 44

const sketch = computed(() => {
  const els = allEls.value
  if (els.length === 0) return null

  const spreizer = 5.0
  const allS = els.map(e => e.el.S)
  const maxSabs = Math.max(Math.abs(Math.max(...allS)), Math.abs(Math.min(...allS)), 0.1)
  const boomX = SVG_W / 2
  const centerY = mT + (SVG_H - mT - mB) / 2
  const usableH = SVG_H - mT - mB
  const scale = Math.min(((SVG_W - mL - mR) / 2) / spreizer, (usableH / 2) / maxSabs)

  const bY = s => centerY - s * scale
  const bX = x => boomX + x * scale

  const rTip = { x: bX(spreizer),  y: centerY }
  const lTip = { x: bX(-spreizer), y: centerY }

  const tipPt = (base, target, meters) => {
    const dx = target.x - base.x, dy = target.y - base.y
    const dist = Math.sqrt(dx * dx + dy * dy)
    if (dist < 0.001) return base
    const len = meters * scale
    return { x: base.x + dx / dist * len, y: base.y + dy / dist * len }
  }

  const elements = els.map(({ band, el }, idx) => {
    const base  = { x: boomX, y: bY(el.S) }
    const rWire = tipPt(base, rTip, el.Lel / 2)
    const lWire = tipPt(base, lTip, el.Lel / 2)
    return {
      band, el, idx, base, rWire, lWire,
      color: SB_BAND_COLORS[band] || '#999',
      isStrahler: el.typ === 'Strahler',
      onRight: idx % 2 === 0,
    }
  })

  return {
    boomX,
    boomTop:    bY(maxSabs + 0.25),
    boomBottom: bY(-(maxSabs + 0.25)),
    rTip, lTip, elements,
    barLen: 2.0 * scale,
  }
})

const tableRows = computed(() => {
  const result = []
  const typeOrder = ['Strahler','Reflektor','Direktor 1','Direktor 2','Direktor 3']
  for (const band of activeBands.value) {
    const bandData = version.value.data[band] || []
    for (const t of typeOrder) {
      const el = bandData.find(e => e.typ === t)
      if (el) result.push({ band, ...el })
    }
  }
  return result
})

function legendX(i, count) {
  const itemW = 68
  return (SVG_W - count * itemW) / 2 + i * itemW
}
</script>

<template>
  <div class="calc-title">Spiderbeam Multi-Band</div>

  <div class="card">
    <h2>Version</h2>
    <div class="opt-grid">
      <button
        v-for="v in versions" :key="v.id"
        class="opt-btn"
        :class="{ active: selectedVersion === v.id }"
        @click="selectedVersion = v.id"
      >
        <div class="opt-label">{{ v.label }}</div>
        <div class="opt-sub">{{ v.name }}</div>
      </button>
    </div>
    <div class="opt-desc">{{ version.desc }}</div>
  </div>

  <div class="card">
    <h2>Bänder</h2>
    <div class="band-toggles">
      <button
        v-for="b in version.bands" :key="b"
        class="band-toggle"
        :class="{ active: enabledBands.has(b) }"
        :style="{ '--bc': SB_BAND_COLORS[b] }"
        @click="toggleBand(b)"
      >{{ b }}</button>
    </div>
  </div>

  <div class="card">
    <h2>Antennenskizze – Draufsicht</h2>
    <div class="diagram-bg">
      <svg v-if="sketch" :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet">
        <!-- Boom -->
        <line :x1="sketch.boomX" :y1="sketch.boomTop" :x2="sketch.boomX" :y2="sketch.boomBottom"
              stroke="rgba(140,140,140,0.55)" stroke-width="2.5"/>

        <!-- Spreizer-Linie (S=0 horizontal) -->
        <line :x1="sketch.lTip.x" :y1="sketch.lTip.y" :x2="sketch.rTip.x" :y2="sketch.rTip.y"
              stroke="rgba(140,140,140,0.35)" stroke-width="1.5" stroke-dasharray="6,4"/>

        <!-- Spreizer-Endpunkte -->
        <circle :cx="sketch.lTip.x" :cy="sketch.lTip.y" r="5" fill="rgba(140,140,140,0.5)"/>
        <circle :cx="sketch.rTip.x" :cy="sketch.rTip.y" r="5" fill="rgba(140,140,140,0.5)"/>

        <!-- Richtungstexte -->
        <text :x="sketch.boomX" :y="sketch.boomTop - 14" text-anchor="middle" font-size="11" font-weight="bold"
              fill="var(--tp)">▲</text>
        <text :x="sketch.boomX" :y="sketch.boomTop - 26" text-anchor="middle" font-size="10"
              fill="var(--ts)">Hauptstrahlrichtung</text>
        <text :x="sketch.boomX" :y="sketch.boomBottom + 16" text-anchor="middle" font-size="10"
              fill="var(--ts)">Reflektor-Seite</text>

        <!-- Maßstab (2 m) -->
        <g>
          <line :x1="12" :y1="sketch.boomTop - 16" :x2="12 + sketch.barLen" :y2="sketch.boomTop - 16"
                stroke="var(--tp)" stroke-width="1.5"/>
          <line :x1="12" :y1="sketch.boomTop - 19" :x2="12" :y2="sketch.boomTop - 13"
                stroke="var(--tp)" stroke-width="1.5"/>
          <line :x1="12 + sketch.barLen" :y1="sketch.boomTop - 19" :x2="12 + sketch.barLen" :y2="sketch.boomTop - 13"
                stroke="var(--tp)" stroke-width="1.5"/>
          <text :x="12 + sketch.barLen / 2" :y="sketch.boomTop - 25" text-anchor="middle" font-size="9"
                fill="var(--tp)">2 m</text>
        </g>

        <!-- Schnüre (Drahtspitze → Spreizer-Endpunkt) -->
        <g>
          <template v-for="e in sketch.elements" :key="`s${e.idx}`">
            <line :x1="e.rWire.x" :y1="e.rWire.y" :x2="sketch.rTip.x" :y2="sketch.rTip.y"
                  stroke="rgba(140,140,140,0.28)" stroke-width="0.8" stroke-dasharray="3,3"/>
            <line :x1="e.lWire.x" :y1="e.lWire.y" :x2="sketch.lTip.x" :y2="sketch.lTip.y"
                  stroke="rgba(140,140,140,0.28)" stroke-width="0.8" stroke-dasharray="3,3"/>
          </template>
        </g>

        <!-- Element-Drähte (farbig) + Boom-Punkte -->
        <g>
          <template v-for="e in sketch.elements" :key="`e${e.idx}`">
            <line :x1="e.base.x" :y1="e.base.y" :x2="e.rWire.x" :y2="e.rWire.y"
                  :stroke="e.color" stroke-width="2.5" stroke-linecap="round"/>
            <line :x1="e.base.x" :y1="e.base.y" :x2="e.lWire.x" :y2="e.lWire.y"
                  :stroke="e.color" stroke-width="2.5" stroke-linecap="round"/>
            <circle :cx="e.base.x" :cy="e.base.y" :r="e.isStrahler ? 4.5 : 3" :fill="e.color"/>
          </template>
        </g>

        <!-- Element-Labels (alternierend rechts/links) -->
        <g>
          <template v-for="e in sketch.elements" :key="`l${e.idx}`">
            <template v-if="e.onRight">
              <text :x="SVG_W - mR + 4" :y="e.base.y - 6" font-size="9" font-weight="bold"
                    :fill="e.color" text-anchor="start">{{ e.band }} {{ shortType(e.el.typ) }}</text>
              <text :x="SVG_W - mR + 4" :y="e.base.y + 5" font-size="8"
                    fill="var(--ts)" text-anchor="start">S={{ posStr(e.el.S) }} m</text>
            </template>
            <template v-else>
              <text :x="mL - 4" :y="e.base.y - 6" font-size="9" font-weight="bold"
                    :fill="e.color" text-anchor="end">{{ e.band }} {{ shortType(e.el.typ) }}</text>
              <text :x="mL - 4" :y="e.base.y + 5" font-size="8"
                    fill="var(--ts)" text-anchor="end">S={{ posStr(e.el.S) }} m</text>
            </template>
          </template>
        </g>

        <!-- Band-Legende unten -->
        <g>
          <template v-for="(b, i) in activeBands" :key="`leg${b}`">
            <line :x1="legendX(i, activeBands.length)" :y1="SVG_H - 14"
                  :x2="legendX(i, activeBands.length) + 16" :y2="SVG_H - 14"
                  :stroke="SB_BAND_COLORS[b]" stroke-width="3"/>
            <text :x="legendX(i, activeBands.length) + 18" :y="SVG_H - 11" font-size="9" font-weight="600"
                  :fill="SB_BAND_COLORS[b]">{{ b }}</text>
          </template>
        </g>
      </svg>
    </div>
  </div>

  <div class="card">
    <h2>Drahtlängen (DF4SA Originaldaten)</h2>
    <table class="tbl sb-tbl">
      <thead>
        <tr>
          <th>Band</th>
          <th>Element</th>
          <th>L_el (m)</th>
          <th>Zuschnitt Arm (mm)</th>
          <th>S (m)</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(r, i) in tableRows" :key="i">
          <td class="fw7" :style="{ color: SB_BAND_COLORS[r.band] }">{{ r.band }}</td>
          <td>{{ r.typ }}</td>
          <td class="mono">{{ r.Lel.toFixed(2) }}</td>
          <td class="mono">{{ r.arm }}</td>
          <td class="mono c-dim">{{ posStr(r.S) }}</td>
        </tr>
      </tbody>
    </table>
  </div>

  <div class="card">
    <h2>Spalten-Legende</h2>
    <div class="rr"><span class="lbl">L_el</span><span class="val">Elektrische Drahtlänge (Strahler-Schenkel × 2, ohne Speiseleitung)</span></div>
    <div class="rr"><span class="lbl">Zuschnitt Arm (mm)</span><span class="val">Physikalischer Schnitt für einen Arm (L_el/2 + Toleranz)</span></div>
    <div class="rr"><span class="lbl">S (m)</span><span class="val">Position auf dem Boom; + = Direktor-Seite, – = Reflektor-Seite</span></div>
  </div>

  <RechnerBeschreibung name="spidermulti" />
</template>

<style scoped>
/* Diagramm-Container (SVG Skizze) */
.diagram-bg {
  background: var(--card2);
  border-radius: 8px;
  padding: 8px;
  margin-top: 4px;
}
.diagram-bg svg {
  width: 100%;
  height: auto;
  max-height: 500px;
  display: block;
}

/* Tabellen-Spaltenausrichtung */
.sb-tbl th:nth-child(1), .sb-tbl td:nth-child(1) { width: 14%; }
.sb-tbl th:nth-child(2), .sb-tbl td:nth-child(2) { width: 22%; }
.sb-tbl th:nth-child(n+3), .sb-tbl td:nth-child(n+3) { text-align: right; }
</style>
