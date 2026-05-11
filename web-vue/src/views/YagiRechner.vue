<script setup>
import { reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'
import { openInSim } from '../composables/openInSim.js'

const router = useRouter()
const yg = reactive({ band: '20', numEle: 3, preset: 'ssb', material: 'alu' })

const YAGI_BANDS = {
  '40': { name: '40 m', min: 7.000, max: 7.200, cw: 7.030, ssb: 7.130, ft8: 7.074 },
  '30': { name: '30 m', min: 10.100, max: 10.150, cw: 10.120, ssb: 10.130, ft8: 10.136 },
  '20': { name: '20 m', min: 14.000, max: 14.350, cw: 14.030, ssb: 14.200, ft8: 14.074 },
  '17': { name: '17 m', min: 18.068, max: 18.168, cw: 18.080, ssb: 18.140, ft8: 18.100 },
  '15': { name: '15 m', min: 21.000, max: 21.450, cw: 21.030, ssb: 21.250, ft8: 21.074 },
  '12': { name: '12 m', min: 24.890, max: 24.990, cw: 24.900, ssb: 24.960, ft8: 24.915 },
  '10': { name: '10 m', min: 28.000, max: 29.700, cw: 28.030, ssb: 28.400, ft8: 28.074 },
}
const bandOrder = ['40','30','20','17','15','12','10']

const YAGI_DESIGNS = {
  2: { refl: 0.501, drv: 0.470, dir: [],                    spacings: [0.15],                    gain: 6.0, fb: 10, impedance: 35 },
  3: { refl: 0.500, drv: 0.470, dir: [0.446],               spacings: [0.15, 0.15],              gain: 7.5, fb: 20, impedance: 28 },
  4: { refl: 0.500, drv: 0.469, dir: [0.444, 0.440],        spacings: [0.15, 0.17, 0.20],        gain: 8.5, fb: 22, impedance: 25 },
  5: { refl: 0.500, drv: 0.469, dir: [0.442, 0.438, 0.434], spacings: [0.15, 0.18, 0.22, 0.25],  gain: 9.8, fb: 25, impedance: 22 },
}

const result = computed(() => {
  const band = YAGI_BANDS[yg.band]
  const design = YAGI_DESIGNS[yg.numEle]
  if (!band || !design) return null
  const freq = yg.preset === 'mid' ? (band.min + band.max) / 2
              : yg.preset === 'cw' ? band.cw
              : yg.preset === 'ssb' ? band.ssb
              : band.ft8
  const lambda = 299.792458 / freq
  const vf = yg.material === 'alu' ? 0.95 : 0.96
  const reflLen = lambda * design.refl * vf
  const drvLen = lambda * design.drv * vf
  const dirLens = design.dir.map(f => lambda * f * vf)
  const spacings = design.spacings.map(s => lambda * s)
  const positions = [0]
  let pos = 0
  for (const sp of spacings) { pos += sp; positions.push(pos) }
  const boom = positions[positions.length - 1] || 0
  const elements = [
    { name: 'Reflektor', length: reflLen, position: positions[0] },
    { name: 'Strahler',  length: drvLen,  position: positions[1] },
    ...dirLens.map((l, i) => ({ name: `Direktor ${i + 1}`, length: l, position: positions[2 + i] })),
  ]
  return { band, freq, lambda, numEle: yg.numEle, material: yg.material, vf, design, elements, boom }
})

function elementColor(name) {
  if (name === 'Reflektor') return '#f87171'
  if (name === 'Strahler') return '#60a5fa'
  return '#4ade80'
}

function shortName(n) { return n.replace('Direktor ', 'D') }

// SVG (Draufsicht)
const SVG_W = 600, SVG_H = 360
const marginL = 40, marginR = 80, marginT = 40, marginB = 60

const svgGeom = computed(() => {
  if (!result.value) return null
  const r = result.value
  if (r.boom <= 0) return null
  const usableW = SVG_W - marginL - marginR
  const usableH = SVG_H - marginT - marginB
  const maxLen = Math.max(...r.elements.map(e => e.length))
  const scale = Math.min(usableW / r.boom, usableH / maxLen)
  const centerY = marginT + maxLen * scale / 2
  const boomStartX = marginL
  const boomEndX = marginL + r.boom * scale
  const arrowX = boomEndX + 20
  return { centerY, boomStartX, boomEndX, scale, arrowX, totalDimY: marginT - 18 }
})

const elementsSvg = computed(() => {
  if (!result.value || !svgGeom.value) return []
  const r = result.value
  const g = svgGeom.value
  return r.elements.map((el, idx) => ({
    el, idx,
    x: marginL + el.position * g.scale,
    half: el.length / 2 * g.scale,
    color: elementColor(el.name),
    short: shortName(el.name),
    prevX: idx > 0 ? marginL + r.elements[idx-1].position * g.scale : null,
    distMm: idx > 0 ? Math.round((el.position - r.elements[idx-1].position) * 1000) : null,
  }))
})

const totalEleLen = computed(() => result.value ? result.value.elements.reduce((s, e) => s + e.length, 0) : 0)
const maxHalf = computed(() => result.value ? Math.max(...result.value.elements.map(e => e.length)) / 2 : 0)

// ─── Im Sim öffnen ───────────────────────────────────────────────────────────
// Yagi-Elemente → NEC2-Drahtmodell:
//   Boom entlang X-Achse, Elemente perpendicular (entlang Y-Achse, zentriert bei y=0).
//   Reflektor bei x=0, Driver bei x=positions[1], Direktoren weiter entlang Boom.
//   Höhe h = max(λ/2, 10m) — typisches HF-Setup.

function buildYagiModel() {
  if (!result.value) return null
  const r = result.value
  const h = Math.max(10, r.lambda / 2)
  const radius_mm = r.material === 'alu' ? 5.0 : 1.5
  const segs = 21

  const wires = r.elements.map((el, idx) => {
    const half = el.length / 2
    return {
      tag: idx + 1,
      segments: segs,
      x1: el.position, y1: -half, z1: h,
      x2: el.position, y2:  half, z2: h,
      radius_mm,
    }
  })

  // Driver ist Element-Index 1 (Reflektor=0, Driver=1, Dir1=2, …)
  const drvTag = 2

  return {
    name: `${r.numEle}-Element Yagi ${r.band.name} (${r.freq.toFixed(3)} MHz)`,
    freq: r.freq,
    ground: 'average',
    height: h,
    wires,
    excitation: { wire_tag: drvTag, segment: Math.ceil(segs / 2) },
  }
}

function imSimOeffnen() {
  const m = buildYagiModel()
  if (m) openInSim(router, m)
}
</script>

<template>
  <div class="calc-title">Yagi-Rechner</div>

  <div class="card">
    <h2>Parameter</h2>
    <div style="margin-bottom:10px">
      <div class="small" style="margin-bottom:6px">Band</div>
      <div class="band-grid" style="grid-template-columns:repeat(7,1fr)">
        <button v-for="key in bandOrder" :key="key"
                class="bb" :class="{ on: yg.band === key }"
                @click="yg.band = key">{{ YAGI_BANDS[key].name }}</button>
      </div>
    </div>
    <div class="inp-grid">
      <div class="inp-g">
        <label>Elemente</label>
        <div class="seg">
          <button v-for="n in [2,3,4,5]" :key="n" class="sb" :class="{ on: yg.numEle === n }" @click="yg.numEle = n">{{ n }} Ele</button>
        </div>
      </div>
      <div class="inp-g">
        <label>Frequenz-Preset</label>
        <div class="seg">
          <button class="sb" :class="{ on: yg.preset === 'mid' }" @click="yg.preset = 'mid'">Mitte</button>
          <button class="sb" :class="{ on: yg.preset === 'cw' }" @click="yg.preset = 'cw'">CW</button>
          <button class="sb" :class="{ on: yg.preset === 'ssb' }" @click="yg.preset = 'ssb'">SSB</button>
          <button class="sb" :class="{ on: yg.preset === 'ft8' }" @click="yg.preset = 'ft8'">FT8</button>
        </div>
      </div>
    </div>
    <div class="inp-g" style="margin-top:10px">
      <label>Bauweise</label>
      <div class="seg">
        <button class="sb" :class="{ on: yg.material === 'alu' }" @click="yg.material = 'alu'">Alurohr</button>
        <button class="sb" :class="{ on: yg.material === 'draht' }" @click="yg.material = 'draht'">Draht/Spiderbeam</button>
      </div>
    </div>
    <div v-if="result" class="small mt8">
      {{ fmt(result.freq) }} MHz · λ = {{ fmt(result.lambda) }} m · VF = {{ result.vf.toFixed(2) }}
    </div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Übersicht</h2>
      <div class="ken-grid">
        <div class="ken hi"><div class="ken-val">{{ result.numEle }} Ele</div><div class="ken-lbl">Elemente</div></div>
        <div class="ken"><div class="ken-val">{{ fmt(result.boom) }} m</div><div class="ken-lbl">Boom-Länge</div></div>
        <div class="ken"><div class="ken-val">{{ result.design.gain.toFixed(1) }} dBi</div><div class="ken-lbl">Gewinn (ca.)</div></div>
        <div class="ken"><div class="ken-val">{{ result.design.fb }} dB</div><div class="ken-lbl">F/B (ca.)</div></div>
        <div class="ken"><div class="ken-val">{{ result.design.impedance }} Ω</div><div class="ken-lbl">Impedanz (ca.)</div></div>
        <div class="ken"><div class="ken-val">{{ result.material === 'alu' ? 'Alurohr' : 'Draht' }}</div><div class="ken-lbl">Bauweise</div></div>
        <div class="ken"><div class="ken-val">{{ result.band.name }}</div><div class="ken-lbl">Band</div></div>
        <div class="ken"><div class="ken-val">{{ fmt(result.freq) }} MHz</div><div class="ken-lbl">Frequenz</div></div>
      </div>
      <div style="margin-top:12px; text-align:right">
        <button class="btn-sim" @click="imSimOeffnen">📡 Im Sim öffnen</button>
      </div>
    </div>

    <div class="card">
      <h2>Elementmaße</h2>
      <table class="tbl yagi-tbl">
        <thead>
          <tr><th>Element</th><th>Länge</th><th>Halbe Seite</th><th>Position</th><th>Abstand</th></tr>
        </thead>
        <tbody>
          <tr v-for="(e, idx) in result.elements" :key="idx">
            <td class="fw7" :style="{ color: elementColor(e.name) }">{{ e.name }}</td>
            <td class="mono">{{ (e.length * 1000).toFixed(0) }} mm</td>
            <td class="mono">{{ (e.length * 500).toFixed(0) }} mm</td>
            <td class="mono">{{ (e.position * 1000).toFixed(0) }} mm</td>
            <td class="mono c-dim">{{ idx === 0 ? '—' : ((e.position - result.elements[idx-1].position) * 1000).toFixed(0) + ' mm' }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>Draufsicht</h2>
      <div class="skz-bg">
        <svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet" v-if="svgGeom">
          <!-- Boom -->
          <line :x1="svgGeom.boomStartX" :y1="svgGeom.centerY" :x2="svgGeom.boomEndX" :y2="svgGeom.centerY"
                stroke="rgba(140,140,140,0.6)" stroke-width="3"/>

          <!-- Richtungspfeil -->
          <line :x1="svgGeom.boomEndX" :y1="svgGeom.centerY" :x2="svgGeom.arrowX" :y2="svgGeom.centerY"
                stroke="rgba(96,165,250,0.6)" stroke-width="1.5"/>
          <text :x="svgGeom.arrowX + 6" :y="svgGeom.centerY + 3" font-size="11" fill="rgba(96,165,250,0.7)">▶</text>

          <!-- Elemente -->
          <g v-for="e in elementsSvg" :key="e.idx">
            <line :x1="e.x" :y1="svgGeom.centerY - e.half" :x2="e.x" :y2="svgGeom.centerY + e.half"
                  :stroke="e.color" stroke-width="3" stroke-linecap="round"/>
            <text :x="e.x" :y="svgGeom.centerY - e.half - 8" text-anchor="middle" font-size="10" font-weight="bold" :fill="e.color">
              {{ e.short }}
            </text>
            <text :x="e.x" :y="svgGeom.centerY + e.half + 14" text-anchor="middle" font-size="10" fill="var(--ts)">
              {{ (e.el.length * 1000).toFixed(0) }} mm
            </text>
            <!-- Abstandsmaß zwischen Elementen -->
            <template v-if="e.idx > 0">
              <line :x1="e.prevX" :y1="SVG_H - marginB + 18" :x2="e.x" :y2="SVG_H - marginB + 18"
                    stroke="rgba(140,140,140,0.5)" stroke-width="1"/>
              <text :x="(e.prevX + e.x) / 2" :y="SVG_H - marginB + 10" text-anchor="middle" font-size="10" fill="var(--ts)">
                {{ e.distMm }} mm
              </text>
            </template>
          </g>

          <!-- Boom-Gesamtmaß oben -->
          <line :x1="svgGeom.boomStartX" :y1="svgGeom.totalDimY" :x2="svgGeom.boomEndX" :y2="svgGeom.totalDimY"
                stroke="rgba(96,165,250,0.6)" stroke-width="1.2"/>
          <text :x="(svgGeom.boomStartX + svgGeom.boomEndX) / 2" :y="svgGeom.totalDimY - 8"
                text-anchor="middle" font-size="11" font-weight="bold" fill="rgba(96,165,250,0.85)">
            Boom: {{ (result.boom * 1000).toFixed(0) }} mm
          </text>
        </svg>
      </div>
    </div>

    <div class="card">
      <h2>Stückliste</h2>
      <template v-if="result.material === 'alu'">
        <div class="rr"><span class="lbl">Boom (Alurohr)</span><span class="val">{{ fmt(result.boom + 0.2, 2) }} m (inkl. Überstand)</span></div>
        <div class="rr"><span class="lbl">Alurohr Elemente gesamt</span><span class="val">{{ fmt(totalEleLen + 0.5, 2) }} m</span></div>
        <div class="rr"><span class="lbl">Element-Halterungen</span><span class="val">{{ result.numEle }} Stück</span></div>
        <div class="rr"><span class="lbl">Balun / Mantelwellensperre</span><span class="val">1:1, am Strahler</span></div>
        <div class="rr"><span class="lbl">Isolator Strahler-Mitte</span><span class="val">1 Stück</span></div>
      </template>
      <template v-else>
        <div class="rr"><span class="lbl">Fiberglas-Boom/GFK-Rohr</span><span class="val">{{ fmt(result.boom + 0.3, 2) }} m</span></div>
        <div class="rr"><span class="lbl">Fiberglas-Spreizer (je Element)</span><span class="val">je {{ fmt(maxHalf + 0.3, 2) }} m × 2, total {{ result.numEle * 2 }} Stück</span></div>
        <div class="rr"><span class="lbl">Kupferlitze / CuLi-Draht</span><span class="val">{{ fmt(totalEleLen + 1.0, 1) }} m gesamt</span></div>
        <div class="rr"><span class="lbl">Zentral-Nabe / Spinne</span><span class="val">1 Stück</span></div>
        <div class="rr"><span class="lbl">Balun / Mantelwellensperre</span><span class="val">1:1, am Strahler</span></div>
      </template>
      <div class="rr"><span class="lbl">Koax-Kabel</span><span class="val">nach Mast-Länge</span></div>
    </div>
  </template>

  <RechnerBeschreibung name="yagi" />
</template>

<style scoped>
.ken-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }
.ken {
  background: var(--card2); border: 1px solid var(--sep);
  border-radius: 8px; padding: 12px 10px; text-align: center;
}
.ken.hi { border-color: var(--acc); }
.ken-val { font-size: 16px; font-weight: 700; color: var(--tp); font-family: 'SF Mono', 'Cascadia Mono', monospace; }
.ken.hi .ken-val { color: var(--acc); }
.ken-lbl { font-size: 10px; color: var(--ts); margin-top: 4px; text-transform: uppercase; letter-spacing: 0.5px; }
@media(max-width:640px){ .ken-grid { grid-template-columns: 1fr 1fr; } }

.yagi-tbl th:nth-child(n+2), .yagi-tbl td:nth-child(n+2) { text-align: right; }
</style>
