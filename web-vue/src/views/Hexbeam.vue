<script setup>
import { reactive, computed } from 'vue'
import { fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const bandColors = {
  '40m': '#a855f7', '30m': '#6366f1', '20m': '#3b82f6', '17m': '#06b6d4',
  '15m': '#22c55e', '12m': '#eab308', '10m': '#f97316', '6m': '#ef4444', '2m': '#ec4899',
}

const baender = reactive([
  { id:'40m', name:'40m', fMHz:7.100,  istWARC:false, aktiv:false },
  { id:'30m', name:'30m', fMHz:10.125, istWARC:true,  aktiv:false },
  { id:'20m', name:'20m', fMHz:14.175, istWARC:false, aktiv:true },
  { id:'17m', name:'17m', fMHz:18.118, istWARC:true,  aktiv:false },
  { id:'15m', name:'15m', fMHz:21.225, istWARC:false, aktiv:true },
  { id:'12m', name:'12m', fMHz:24.940, istWARC:true,  aktiv:false },
  { id:'10m', name:'10m', fMHz:28.500, istWARC:false, aktiv:true },
  { id:'6m',  name:'6m',  fMHz:50.150, istWARC:false, aktiv:false },
  { id:'2m',  name:'2m',  fMHz:145.00, istWARC:false, aktiv:false },
])

function bandData(b) {
  const lambda = 300 / b.fMHz
  return {
    ...b,
    lambda,
    treiber: lambda * 0.440,
    reflektor: lambda * 0.495,
    arm: lambda * 0.260,
  }
}

const aktiveBaender = computed(() => baender.filter(b => b.aktiv).map(bandData))
const referenzBand = computed(() => {
  if (aktiveBaender.value.length === 0) return null
  return [...aktiveBaender.value].sort((a, b) => a.fMHz - b.fMHz)[0]
})
const maxArm = computed(() => aktiveBaender.value.length > 0 ? Math.max(...aktiveBaender.value.map(b => b.arm)) : 0)

// Draufsicht SVG
const TOP_W = 600, TOP_H = 440
const topGeom = computed(() => {
  if (maxArm.value === 0) return null
  const margin = 72
  const cx = TOP_W / 2
  const cy = TOP_H / 2 + 10
  const radius = Math.min(TOP_W - 2 * margin, TOP_H - 2 * margin) / 2
  if (radius < 30) return null
  const armScale = radius / maxArm.value
  const brgs = [30, 90, 150, 210, 270, 330]
  function pt(bearing, dist) {
    const r = bearing * Math.PI / 180
    return { x: cx + dist * Math.sin(r), y: cy - dist * Math.cos(r) }
  }
  // Spreader-Endpunkte
  const spreaders = brgs.map(b => pt(b, radius))
  // Bänder, sortiert größte zuerst
  const sorted = [...aktiveBaender.value].sort((a, b) => b.arm - a.arm)
  const bands = sorted.map(band => {
    const r = band.arm * armScale
    const reflPts = [330, 270, 210, 150, 90, 30].map(b => pt(b, r))
    const reflPath = reflPts.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x} ${p.y}`).join(' ')
    const drvLeft = pt(30, r), drvRight = pt(330, r)
    const drvPath = `M ${drvLeft.x} ${drvLeft.y} L ${cx} ${cy} L ${drvRight.x} ${drvRight.y}`
    const labelP = pt(90, r)
    return {
      band, color: bandColors[band.id] || '#3b82f6',
      reflPath, drvPath, drvLeft, drvRight, labelP,
    }
  })
  // Pfeil
  const arrowBase = pt(0, radius + 8)
  const arrowTip = pt(0, radius + 36)
  return { cx, cy, radius, spreaders, bands, arrowBase, arrowTip }
})

// Seitenansicht SVG
const SIDE_W = 600, SIDE_H = 320
const sideGeom = computed(() => {
  if (aktiveBaender.value.length === 0 || maxArm.value === 0) return null
  const marginL = 60, marginR = 72, marginT = 28, marginB = 14
  const availW = SIDE_W - marginL - marginR
  const availH = SIDE_H - marginT - marginB
  const R = Math.min(availW / 2, availH)
  const cx = marginL + availW / 2
  const rimY = marginT
  const k = R * 0.5523
  const bowlPath = `M ${cx - R} ${rimY}
    C ${cx - R} ${rimY + k}, ${cx - k} ${rimY + R}, ${cx} ${rimY + R}
    C ${cx + k} ${rimY + R}, ${cx + R} ${rimY + k}, ${cx + R} ${rimY}`
  const sorted = [...aktiveBaender.value].sort((a, b) => b.arm - a.arm)
  const wires = sorted.map(band => {
    const f = band.arm / maxArm.value
    const lineY = rimY + R * Math.sqrt(Math.max(0, 1 - f * f))
    const halfW = R * f
    return {
      band, color: bandColors[band.id] || '#3b82f6',
      x1: cx - halfW, x2: cx + halfW, y: lineY,
    }
  })
  const physDepthM = maxArm.value * 0.20
  return { cx, rimY, R, bowlPath, wires, physDepthM, marginL }
})
</script>

<template>
  <div class="calc-title">Hexbeam</div>

  <div class="card">
    <h2>Bänder auswählen  (W = WARC)</h2>
    <div class="band-toggles" style="display:grid;grid-template-columns:repeat(3,1fr);gap:8px">
      <button v-for="b in baender" :key="b.id"
              class="band-toggle" :class="{ active: b.aktiv }"
              :style="{ '--bc': bandColors[b.id] }"
              @click="b.aktiv = !b.aktiv">
        {{ b.name }}<span v-if="b.istWARC" style="font-size:9px;margin-left:3px;color:#fb923c">W</span>
      </button>
    </div>
  </div>

  <template v-if="aktiveBaender.length > 0">
    <div class="card">
      <h2>Maße pro Band</h2>
      <table class="tbl hex-tbl">
        <thead>
          <tr><th>Band</th><th>Frequenz</th><th>Treiber</th><th>Reflektor</th><th>Arm</th></tr>
        </thead>
        <tbody>
          <tr v-for="b in aktiveBaender" :key="b.id">
            <td class="fw7" :style="{ color: bandColors[b.id] }">{{ b.name }}</td>
            <td class="mono">{{ fmt(b.fMHz) }} MHz</td>
            <td class="mono">{{ fmt(b.treiber) }} m</td>
            <td class="mono">{{ fmt(b.reflektor) }} m</td>
            <td class="mono">{{ fmt(b.arm) }} m</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>Bauplan – Draufsicht (Vogelperspektive)</h2>
      <div class="skz-bg">
        <svg v-if="topGeom" :viewBox="`0 0 ${TOP_W} ${TOP_H}`" preserveAspectRatio="xMidYMid meet">
          <!-- 6 Spreader-Arme -->
          <g v-for="(tip, i) in topGeom.spreaders" :key="`sp${i}`">
            <line :x1="topGeom.cx" :y1="topGeom.cy" :x2="tip.x" :y2="tip.y" stroke="rgba(140,140,140,0.4)" stroke-width="2"/>
            <circle :cx="tip.x" :cy="tip.y" r="5" fill="none" stroke="rgba(140,140,140,0.5)" stroke-width="1.5"/>
          </g>
          <!-- Wire elements -->
          <g v-for="(b, i) in topGeom.bands" :key="`b${i}`">
            <!-- Reflektor (gestrichelt) -->
            <path :d="b.reflPath" fill="none" :stroke="b.color" stroke-width="1.8" stroke-dasharray="5,3" opacity="0.6"/>
            <!-- Treiber (V solid) -->
            <path :d="b.drvPath" fill="none" :stroke="b.color" stroke-width="2.5"/>
            <!-- Schnur -->
            <line :x1="b.drvLeft.x" :y1="b.drvLeft.y" :x2="b.drvRight.x" :y2="b.drvRight.y"
                  stroke="rgba(140,140,140,0.45)" stroke-width="0.8" stroke-dasharray="3,4"/>
            <!-- Tip Spacer Dots -->
            <circle :cx="b.drvLeft.x" :cy="b.drvLeft.y" r="4" :fill="b.color" opacity="0.85"/>
            <circle :cx="b.drvRight.x" :cy="b.drvRight.y" r="4" :fill="b.color" opacity="0.85"/>
            <!-- Band-Label rechts -->
            <text :x="b.labelP.x + 14" :y="b.labelP.y + 4" font-size="10" font-weight="bold" :fill="b.color">{{ b.band.name }}</text>
          </g>
          <!-- Center Hub -->
          <circle :cx="topGeom.cx" :cy="topGeom.cy" r="8" fill="var(--acc)"/>
          <text :x="topGeom.cx" :y="topGeom.cy + 22" text-anchor="middle" font-size="9" font-weight="bold" fill="var(--acc)">
            Koax-Einspeisung
          </text>
          <!-- Strahlungsrichtungspfeil -->
          <line :x1="topGeom.arrowBase.x" :y1="topGeom.arrowBase.y" :x2="topGeom.arrowTip.x" :y2="topGeom.arrowTip.y"
                stroke="#ef4444" stroke-width="2.5"/>
          <polygon :points="`${topGeom.arrowTip.x},${topGeom.arrowTip.y} ${topGeom.arrowTip.x - 7},${topGeom.arrowTip.y + 13} ${topGeom.arrowTip.x + 7},${topGeom.arrowTip.y + 13}`" fill="#ef4444"/>
          <text :x="topGeom.cx" :y="topGeom.arrowTip.y - 4" text-anchor="middle" font-size="10" font-weight="bold" fill="#ef4444">
            Strahlungsrichtung
          </text>
          <!-- Legende -->
          <text :x="TOP_W / 2" :y="TOP_H - 10" text-anchor="middle" font-size="9" fill="var(--ts)">
            ─── Treiber (Driver)   - - - Reflektor   ● Tip Spacer
          </text>
        </svg>
      </div>
    </div>

    <div class="card">
      <h2>Bauplan – Seitenansicht</h2>
      <div class="skz-bg">
        <svg v-if="sideGeom" :viewBox="`0 0 ${SIDE_W} ${SIDE_H}`" preserveAspectRatio="xMidYMid meet">
          <!-- Bowl-Bogen -->
          <path :d="sideGeom.bowlPath" fill="none" stroke="rgba(140,140,140,0.65)" stroke-width="3"/>
          <!-- Rim oben -->
          <line :x1="sideGeom.cx - sideGeom.R" :y1="sideGeom.rimY" :x2="sideGeom.cx + sideGeom.R" :y2="sideGeom.rimY"
                stroke="rgba(140,140,140,0.65)" stroke-width="3"/>
          <!-- Spannweite oben -->
          <line :x1="sideGeom.cx - sideGeom.R" :y1="sideGeom.rimY - 12" :x2="sideGeom.cx + sideGeom.R" :y2="sideGeom.rimY - 12"
                stroke="rgba(140,140,140,0.45)" stroke-width="1"/>
          <text :x="sideGeom.cx" :y="sideGeom.rimY - 17" text-anchor="middle" font-size="9" fill="var(--ts)">
            ⌀ {{ (maxArm * 200).toFixed(0) }} cm
          </text>
          <!-- Center Mast -->
          <line :x1="sideGeom.cx" :y1="sideGeom.rimY" :x2="sideGeom.cx" :y2="sideGeom.rimY + sideGeom.R"
                stroke="rgba(140,140,140,0.85)" stroke-width="3"/>
          <!-- Höhen-Bemaßung links -->
          <line :x1="sideGeom.cx - sideGeom.R - 14" :y1="sideGeom.rimY"
                :x2="sideGeom.cx - sideGeom.R - 14" :y2="sideGeom.rimY + sideGeom.R"
                stroke="rgba(140,140,140,0.6)" stroke-width="1"/>
          <text :x="sideGeom.cx - sideGeom.R - 19" :y="sideGeom.rimY + sideGeom.R / 2 + 4"
                text-anchor="end" font-size="9" fill="var(--ts)">
            ca. {{ (sideGeom.physDepthM * 100).toFixed(0) }} cm
          </text>
          <!-- "band" Header -->
          <text :x="sideGeom.cx + 8" :y="sideGeom.rimY - 12" font-size="10" font-weight="600" fill="var(--ts)">band</text>
          <!-- Wire-Linien -->
          <g v-for="(w, i) in sideGeom.wires" :key="i">
            <line :x1="w.x1" :y1="w.y" :x2="w.x2" :y2="w.y" :stroke="w.color" stroke-width="1.5"/>
            <text :x="w.x2 + 7" :y="w.y + 4" font-size="10" font-weight="bold" :fill="w.color">{{ w.band.name }}</text>
          </g>
        </svg>
      </div>
    </div>

    <div class="card">
      <h2>Zusammenfassung</h2>
      <div class="rr"><span class="lbl">Anzahl Bänder</span><span class="val">{{ aktiveBaender.length }}</span></div>
      <div class="rr"><span class="lbl">Niedrigstes Band</span><span class="val">{{ referenzBand ? `${referenzBand.name} (${fmt(referenzBand.fMHz)} MHz)` : '–' }}</span></div>
      <div class="rr hi"><span class="lbl">Längster Arm</span><span class="val">{{ fmt(maxArm) }} m</span></div>
      <div class="rr hi"><span class="lbl">Gesamtdurchmesser</span><span class="val">{{ fmt(maxArm * 2) }} m</span></div>
      <template v-if="referenzBand">
        <div class="rr"><span class="lbl">Treiber {{ referenzBand.name }}</span><span class="val">{{ fmt(referenzBand.treiber) }} m</span></div>
        <div class="rr"><span class="lbl">Reflektor {{ referenzBand.name }}</span><span class="val">{{ fmt(referenzBand.reflektor) }} m</span></div>
      </template>
      <div class="rr"><span class="lbl">Speisepunkt-Impedanz</span><span class="val">≈ 50 Ω (direktgekoppelt)</span></div>
      <div class="rr"><span class="lbl">Gewinn</span><span class="val">≈ 5–6 dBd (HF-Bänder)</span></div>
    </div>
  </template>

  <RechnerBeschreibung name="hexbeam" />
</template>

<style scoped>
.hex-tbl th, .hex-tbl td { font-size: 11px; }
.hex-tbl th:nth-child(n+2), .hex-tbl td:nth-child(n+2) { text-align: right; }
</style>
