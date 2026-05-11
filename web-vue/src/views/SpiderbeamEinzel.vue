<script setup>
import { reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'
import { openInSim } from '../composables/openInSim.js'

const router = useRouter()

const STRAHLER_FAKTOR = 0.466

const ELEMENT_TABLE = [
  { typ: 'Reflektor',  lenFactor: 1.050, boomLambda: -0.180 },
  { typ: 'Strahler',   lenFactor: 1.000, boomLambda:  0.000 },
  { typ: 'Direktor 1', lenFactor: 0.965, boomLambda: +0.150 },
  { typ: 'Direktor 2', lenFactor: 0.955, boomLambda: +0.300 },
  { typ: 'Direktor 3', lenFactor: 0.945, boomLambda: +0.480 },
  { typ: 'Direktor 4', lenFactor: 0.935, boomLambda: +0.680 },
]

const sbe_bands = [
  { name: '40m', freq: 7.100,  color: '#7d2e12' },
  { name: '30m', freq: 10.125, color: '#b5530a' },
  { name: '20m', freq: 14.150, color: '#dc2626' },
  { name: '17m', freq: 18.118, color: '#eb5a0a' },
  { name: '15m', freq: 21.200, color: '#16a34a' },
  { name: '12m', freq: 24.940, color: '#7d3aed' },
  { name: '10m', freq: 28.400, color: '#2563eb' },
  { name: '6m',  freq: 50.150, color: '#22d3ee' },
]

const sbe = reactive({ bandIdx: 6, freq: '28.400', nElements: 3 })

function selectBand(i) {
  sbe.bandIdx = i
  sbe.freq = String(sbe_bands[i].freq)
}

function elementColor(typ) {
  if (typ === 'Reflektor') return '#f87171'
  if (typ === 'Strahler') return '#60a5fa'
  return '#4ade80'
}

const result = computed(() => {
  const f = pf(sbe.freq)
  if (!f || sbe.nElements < 2 || sbe.nElements > 6) return null
  const lambda = 300 / f
  const strahlerLen = STRAHLER_FAKTOR * lambda
  const types = [
    'Reflektor','Strahler','Direktor 1','Direktor 2','Direktor 3','Direktor 4',
  ].slice(0, sbe.nElements)
  const elements = types.map(typ => {
    const e = ELEMENT_TABLE.find(x => x.typ === typ)
    return {
      typ,
      L: e.lenFactor * strahlerLen,
      S: e.boomLambda * lambda,
      delta_pct: (e.lenFactor - 1) * 100,
    }
  })
  const allS = elements.map(e => e.S)
  const minS = Math.min(...allS)
  const maxS = Math.max(...allS)
  const boom = maxS - minS
  const maxHalf = Math.max(...elements.map(e => e.L)) / 2
  let warn = null
  if (maxHalf > 6.0) warn = `Längste Elemente brauchen ${maxHalf.toFixed(2)} m Halbspreizer. Das überschreitet die WARC-Spreizer (6 m). Sonderspreizer oder weniger Elemente nötig.`
  else if (maxHalf > 5.0) warn = `Längste Elemente brauchen ${maxHalf.toFixed(2)} m Halbspreizer. WARC-Spreizer (6 m) erforderlich.`
  return { f, lambda, strahlerLen, elements, boom, maxHalf, nElements: sbe.nElements, warn }
})

function posStr(s) {
  return s === 0 ? 'S=0.00 m' : (s > 0 ? `S=+${s.toFixed(2)} m` : `S=${s.toFixed(2)} m`)
}

// SVG Skizze
const SVG_W = 700, SVG_H = 420
const mL = 100, mR = 100, mT = 48, mB = 36

const sketch = computed(() => {
  if (!result.value || result.value.boom <= 0) return null
  const r = result.value
  const spreizer = r.maxHalf <= 5.0 ? 5.0 : 6.0
  const allS = r.elements.map(e => e.S)
  const maxSabs = Math.max(Math.abs(Math.max(...allS)), Math.abs(Math.min(...allS)), 0.1)
  const boomX = SVG_W / 2
  const centerY = mT + (SVG_H - mT - mB) / 2
  const usableH = SVG_H - mT - mB
  const scale = Math.min(((SVG_W - mL - mR) / 2) / spreizer, (usableH / 2) / maxSabs)
  const bY = s => centerY - s * scale
  const bX = x => boomX + x * scale
  const rTip = { x: bX(spreizer), y: centerY }
  const lTip = { x: bX(-spreizer), y: centerY }
  const tipPt = (base, target, meters) => {
    const dx = target.x - base.x, dy = target.y - base.y
    const dist = Math.sqrt(dx*dx + dy*dy)
    if (dist < 0.001) return base
    const len = meters * scale
    return { x: base.x + dx/dist * len, y: base.y + dy/dist * len }
  }
  const sorted = [...r.elements].sort((a, b) => b.S - a.S)
  const elements = sorted.map((el, idx) => {
    const base = { x: boomX, y: bY(el.S) }
    const rWire = tipPt(base, rTip, el.L / 2)
    const lWire = tipPt(base, lTip, el.L / 2)
    return {
      el, idx, base, rWire, lWire,
      color: elementColor(el.typ),
      isStrahler: el.typ === 'Strahler',
      onRight: idx % 2 === 0,
      short: el.typ.replace('Direktor ', 'D'),
      sStr: posStr(el.S),
    }
  })
  return {
    boomX, centerY,
    boomTop: bY(maxSabs + 0.3),
    boomBottom: bY(-(maxSabs + 0.3)),
    rTip, lTip, elements,
    barLen: 2.0 * scale,
    spreizerLabel: `${spreizer === 5 ? '5' : '6'} m Spreizer`,
  }
})

const tableRows = computed(() => {
  if (!result.value) return []
  return [...result.value.elements].sort((a, b) => a.S - b.S)
})

// ─── Im Sim öffnen ───────────────────────────────────────────────────────────
// Spiderbeam-Einzelband = Yagi mit Drahtelementen auf Glasfaser-Spreizern.
// Boom entlang X-Achse, Elemente perpendicular entlang Y-Achse.
// Strahler ist immer das zweite Element (Element-Index 1 in der Liste).
function imSimOeffnen() {
  if (!result.value) return
  const r = result.value
  const h = Math.max(8, r.lambda / 2)
  // Strahler-Position auf der Boom-Achse (S=0). Andere Elemente entsprechend.
  // Wir nehmen S als X-Koordinate (S < 0 = hinten, S > 0 = vorne).
  const wires = r.elements.map((el, idx) => {
    const half = el.L / 2
    return {
      tag: idx + 1,
      segments: 21,
      x1: el.S, y1: -half, z1: h,
      x2: el.S, y2:  half, z2: h,
      radius_mm: 1.5,   // Spiderbeam: Draht statt Alurohr
    }
  })
  // Strahler ist Element 'Strahler' — finde dessen Index
  const strahlerIdx = r.elements.findIndex(e => e.typ === 'Strahler')
  const drvTag = (strahlerIdx >= 0 ? strahlerIdx : 1) + 1
  openInSim(router, {
    name: `Spiderbeam Einzel ${r.nElements}-Ele @ ${r.f.toFixed(3)} MHz`,
    freq: r.f,
    ground: 'average',
    height: h,
    wires,
    excitation: { wire_tag: drvTag, segment: 11 },
  })
}
</script>

<template>
  <div class="calc-title">Spiderbeam Einzelband</div>

  <div class="card">
    <h2>Band</h2>
    <div class="band-toggles">
      <button v-for="(b, i) in sbe_bands" :key="b.name"
              class="band-toggle" :class="{ active: sbe.bandIdx === i }"
              :style="{ '--bc': b.color }" @click="selectBand(i)">
        {{ b.name }}
      </button>
    </div>
  </div>

  <div class="card">
    <h2>Parameter</h2>
    <div class="inp-grid">
      <div class="inp-g"><label>Design-Frequenz</label><div class="inp-row"><input type="text" v-model="sbe.freq"><span>MHz</span></div></div>
      <div class="inp-g">
        <label>Anzahl Elemente</label>
        <div class="seg">
          <button v-for="n in [2,3,4,5,6]" :key="n" class="sb" :class="{ on: sbe.nElements === n }" @click="sbe.nElements = n">
            {{ n }} Ele
          </button>
        </div>
      </div>
    </div>
    <div v-if="result" class="small mt8">
      λ = {{ fmt(result.lambda) }} m  ·  Strahler = {{ fmt(result.strahlerLen) }} m
    </div>
  </div>

  <template v-if="result">
    <div v-if="result.warn" class="card" style="background:rgba(251,146,60,0.08);border-color:#fb923c">
      <div style="display:flex;gap:10px;align-items:flex-start">
        <span style="font-size:18px;color:#fb923c">⚠</span>
        <div class="small" style="color:var(--ts)">{{ result.warn }}</div>
      </div>
    </div>

    <div class="card">
      <h2>Übersicht</h2>
      <div class="ken-grid">
        <div class="ken"><div class="ken-val">{{ fmt(result.lambda) }} m</div><div class="ken-lbl">Wellenlänge λ</div></div>
        <div class="ken hi"><div class="ken-val">{{ fmt(result.strahlerLen) }} m</div><div class="ken-lbl">Strahler L_el</div></div>
        <div class="ken"><div class="ken-val">{{ fmt(result.boom) }} m</div><div class="ken-lbl">Boomlänge</div></div>
        <div class="ken"><div class="ken-val">{{ result.nElements }} Ele</div><div class="ken-lbl">Elemente</div></div>
        <div class="ken"><div class="ken-val">{{ result.maxHalf.toFixed(2) }} m</div><div class="ken-lbl">Halbspreizer</div></div>
        <div class="ken"><div class="ken-val">{{ result.maxHalf <= 5 ? 'Klassisch (5m)' : 'WARC (6m)' }}</div><div class="ken-lbl">Spreizer-Typ</div></div>
      </div>
      <div style="margin-top:12px; text-align:right">
        <button class="btn-sim" @click="imSimOeffnen">📡 Im Sim öffnen</button>
      </div>
    </div>

    <div class="card">
      <h2>Elementmaße</h2>
      <table class="tbl sbe-tbl">
        <thead>
          <tr><th>Element</th><th>L_el (m)</th><th>½ Schenkel (cm)</th><th>Zuschnitt (cm)</th><th>S (m)</th><th>Δ Str.</th></tr>
        </thead>
        <tbody>
          <tr v-for="(el, i) in tableRows" :key="i">
            <td class="fw7" :style="{ color: elementColor(el.typ) }">{{ el.typ }}</td>
            <td class="mono">{{ el.L.toFixed(3) }}</td>
            <td class="mono">{{ (el.L * 50).toFixed(1) }}</td>
            <td class="mono">{{ (el.L * 50 + 4).toFixed(1) }}</td>
            <td class="mono c-dim">{{ el.S === 0 ? '0.00' : (el.S > 0 ? '+' + el.S.toFixed(2) : el.S.toFixed(2)) }}</td>
            <td class="mono c-dim">{{ el.typ === 'Strahler' ? '–' : (el.delta_pct >= 0 ? '+' : '') + el.delta_pct.toFixed(1) + ' %' }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>Antennenskizze – Draufsicht</h2>
      <div class="diagram-bg">
        <svg v-if="sketch" :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet">
          <!-- Boom -->
          <line :x1="sketch.boomX" :y1="sketch.boomTop" :x2="sketch.boomX" :y2="sketch.boomBottom"
                stroke="rgba(140,140,140,0.55)" stroke-width="2.5"/>
          <!-- Spreizer-Linie -->
          <line :x1="sketch.lTip.x" :y1="sketch.lTip.y" :x2="sketch.rTip.x" :y2="sketch.rTip.y"
                stroke="rgba(140,140,140,0.35)" stroke-width="1.5" stroke-dasharray="6,4"/>
          <circle :cx="sketch.lTip.x" :cy="sketch.lTip.y" r="5" fill="rgba(140,140,140,0.5)"/>
          <circle :cx="sketch.rTip.x" :cy="sketch.rTip.y" r="5" fill="rgba(140,140,140,0.5)"/>

          <!-- Pfeil/Texte -->
          <text :x="sketch.boomX" :y="sketch.boomTop - 14" text-anchor="middle" font-size="11" font-weight="bold" fill="var(--tp)">▲</text>
          <text :x="sketch.boomX" :y="sketch.boomTop - 26" text-anchor="middle" font-size="10" fill="var(--ts)">Hauptstrahlrichtung</text>
          <text :x="sketch.boomX" :y="sketch.boomBottom + 16" text-anchor="middle" font-size="10" fill="var(--ts)">Reflektor-Seite</text>

          <!-- Maßstabsbalken -->
          <line :x1="12" :y1="sketch.boomTop - 16" :x2="12 + sketch.barLen" :y2="sketch.boomTop - 16" stroke="var(--tp)" stroke-width="1.5"/>
          <line :x1="12" :y1="sketch.boomTop - 19" :x2="12" :y2="sketch.boomTop - 13" stroke="var(--tp)" stroke-width="1.5"/>
          <line :x1="12 + sketch.barLen" :y1="sketch.boomTop - 19" :x2="12 + sketch.barLen" :y2="sketch.boomTop - 13" stroke="var(--tp)" stroke-width="1.5"/>
          <text :x="12 + sketch.barLen / 2" :y="sketch.boomTop - 25" text-anchor="middle" font-size="9" fill="var(--tp)">2 m</text>

          <!-- Schnüre + Drähte + Labels -->
          <g v-for="e in sketch.elements" :key="e.idx">
            <line :x1="e.rWire.x" :y1="e.rWire.y" :x2="sketch.rTip.x" :y2="sketch.rTip.y"
                  stroke="rgba(140,140,140,0.28)" stroke-width="0.8" stroke-dasharray="3,3"/>
            <line :x1="e.lWire.x" :y1="e.lWire.y" :x2="sketch.lTip.x" :y2="sketch.lTip.y"
                  stroke="rgba(140,140,140,0.28)" stroke-width="0.8" stroke-dasharray="3,3"/>
            <line :x1="e.base.x" :y1="e.base.y" :x2="e.rWire.x" :y2="e.rWire.y"
                  :stroke="e.color" stroke-width="2.5" stroke-linecap="round"/>
            <line :x1="e.base.x" :y1="e.base.y" :x2="e.lWire.x" :y2="e.lWire.y"
                  :stroke="e.color" stroke-width="2.5" stroke-linecap="round"/>
            <circle :cx="e.base.x" :cy="e.base.y" :r="e.isStrahler ? 4.5 : 3" :fill="e.color"/>

            <template v-if="e.onRight">
              <text :x="SVG_W - mR + 4" :y="e.base.y - 6" font-size="9" font-weight="bold" :fill="e.color" text-anchor="start">{{ e.short }}</text>
              <text :x="SVG_W - mR + 4" :y="e.base.y + 5" font-size="8" fill="var(--ts)" text-anchor="start">{{ e.sStr }}</text>
            </template>
            <template v-else>
              <text :x="mL - 4" :y="e.base.y - 6" font-size="9" font-weight="bold" :fill="e.color" text-anchor="end">{{ e.short }}</text>
              <text :x="mL - 4" :y="e.base.y + 5" font-size="8" fill="var(--ts)" text-anchor="end">{{ e.sStr }}</text>
            </template>
          </g>

          <!-- Spreizer-Beschriftung -->
          <text :x="sketch.rTip.x + 4" :y="sketch.rTip.y - 12" font-size="8" fill="var(--ts)" text-anchor="start">
            {{ sketch.spreizerLabel }}
          </text>
        </svg>
      </div>
    </div>
  </template>

  <RechnerBeschreibung name="spidereinzel" />
</template>

<style scoped>
.ken-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
.ken {
  background: var(--card2); border: 1px solid var(--sep);
  border-radius: 8px; padding: 12px 10px; text-align: center;
}
.ken.hi { border-color: var(--acc); }
.ken-val { font-size: 15px; font-weight: 700; color: var(--tp); font-family: 'SF Mono', 'Cascadia Mono', monospace; }
.ken.hi .ken-val { color: var(--acc); }
.ken-lbl { font-size: 10px; color: var(--ts); margin-top: 4px; text-transform: uppercase; letter-spacing: 0.5px; }
.diagram-bg { background: var(--card2); border-radius: 8px; padding: 8px; margin-top: 4px; }
.diagram-bg svg { width: 100%; height: auto; max-height: 420px; display: block; }
.sbe-tbl th, .sbe-tbl td { font-size: 11px; }
.sbe-tbl th:nth-child(n+2), .sbe-tbl td:nth-child(n+2) { text-align: right; }
</style>
