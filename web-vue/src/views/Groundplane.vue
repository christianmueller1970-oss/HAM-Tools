<script setup>
import { reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { pf, fmt } from '../composables/useHam.js'
import BandGrid from '../components/BandGrid.vue'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'
import { openInSim } from '../composables/openInSim.js'

const router = useRouter()
const gp = reactive({ freq: '14.175', vf: '0.95', anzahl: 4, winkel: 45 })

const result = computed(() => {
  const f = pf(gp.freq), vf = pf(gp.vf)
  if (!f || !vf) return null
  const strahler = 75 / f * vf
  const radial = strahler * 1.02
  let imp
  switch (gp.winkel) {
    case 0:  imp = '≈ 36 Ω (horizontal, λ/4 Stub nötig)'; break
    case 30: imp = '≈ 42 Ω'; break
    case 45: imp = '≈ 52 Ω (direkt 50 Ω)'; break
    default: imp = '≈ 50 Ω'
  }
  return { f, vf, strahler, radial, anzahl: gp.anzahl, winkel: gp.winkel, imp }
})

// SVG Skizze (Vertikalstrahler + Radiale mit Neigungswinkel, perspektivisch)
const SVG_W = 360, SVG_H = 250
const cx = SVG_W / 2
const topY = 20
const feedY = SVG_H * 0.55
const strahlerPx = feedY - topY

// ─── Im Sim öffnen ───────────────────────────────────────────────────────────
// Vertikalstrahler λ/4 + N geneigte Radials.
// Vertikal-Wire: von (0,0,h) nach oben um Strahler-Länge
// Radials: vom Fußpunkt (0,0,h) gleichmäßig auf 360° verteilt, geneigt um -winkel
// Speisung: am Fuß des Vertikals (segment 1 von Wire 1)
function imSimOeffnen() {
  if (!result.value) return
  const r = result.value
  const lambda = 300 / r.f
  const h = Math.max(lambda * 0.1, 3)   // Fußpunkt über Boden (Mindesthöhe)
  const winkelRad = r.winkel * Math.PI / 180
  const radialDz = -Math.sin(winkelRad) * r.radial   // Radials gehen leicht nach unten
  const radialDr =  Math.cos(winkelRad) * r.radial
  const wires = []
  // Vertikal-Strahler
  wires.push({
    tag: 1, segments: 11,
    x1: 0, y1: 0, z1: h, x2: 0, y2: 0, z2: h + r.strahler,
    radius_mm: 2.0,
  })
  // Radials, gleichmäßig auf 360° verteilt
  for (let i = 0; i < r.anzahl; i++) {
    const angle = (i / r.anzahl) * 2 * Math.PI
    const dx = Math.cos(angle) * radialDr
    const dy = Math.sin(angle) * radialDr
    wires.push({
      tag: 2 + i, segments: 9,
      x1: 0, y1: 0, z1: h,
      x2: dx, y2: dy, z2: h + radialDz,
      radius_mm: 1.0,
    })
  }
  openInSim(router, {
    name: `Groundplane ${r.strahler.toFixed(2)}m @ ${r.f} MHz (${r.anzahl} Radials)`,
    freq: r.f,
    ground: 'average',
    height: h,
    wires,
    excitation: { wire_tag: 1, segment: 1 },
  })
}

const radialEnds = computed(() => {
  if (!result.value) return []
  const radialPx = strahlerPx * 0.9
  const neigung = result.value.winkel * Math.PI / 180
  const radialDx = radialPx * Math.cos(neigung)
  const radialDy = radialPx * Math.sin(neigung)
  const angles = [0, 90, 180, 270, 45, 135, 225, 315].slice(0, result.value.anzahl)
  return angles.map(deg => {
    const a = deg * Math.PI / 180
    const dx = radialDx * Math.cos(a)
    const dy = radialDy + radialDx * Math.sin(a) * 0.3
    return { x: cx + dx, y: feedY + dy }
  })
})
</script>

<template>
  <div class="calc-title">Groundplane / Vertikal</div>

  <BandGrid v-model:freq="gp.freq" />

  <div class="card">
    <h2>Eingabe</h2>
    <div class="inp-grid">
      <div class="inp-g"><label>Frequenz</label><div class="inp-row"><input type="text" v-model="gp.freq"><span>MHz</span></div></div>
      <div class="inp-g"><label>Verkürzungsfaktor VF</label><div class="inp-row"><input type="text" v-model="gp.vf"></div></div>
    </div>
    <hr class="div">
    <div class="inp-grid">
      <div class="inp-g">
        <label>Anzahl Radiale</label>
        <div class="seg">
          <button class="sb" :class="{ on: gp.anzahl === 3 }" @click="gp.anzahl = 3">3</button>
          <button class="sb" :class="{ on: gp.anzahl === 4 }" @click="gp.anzahl = 4">4</button>
          <button class="sb" :class="{ on: gp.anzahl === 8 }" @click="gp.anzahl = 8">8</button>
        </div>
      </div>
      <div class="inp-g">
        <label>Neigungswinkel Radiale</label>
        <div class="seg">
          <button class="sb" :class="{ on: gp.winkel === 0 }" @click="gp.winkel = 0">0° (horizontal)</button>
          <button class="sb" :class="{ on: gp.winkel === 30 }" @click="gp.winkel = 30">30°</button>
          <button class="sb" :class="{ on: gp.winkel === 45 }" @click="gp.winkel = 45">45°</button>
        </div>
      </div>
    </div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Maße</h2>
      <div class="rr hi"><span class="lbl">Strahler (λ/4)</span><span class="val">{{ fmt(result.strahler) }} m</span></div>
      <div class="rr"><span class="lbl">Radial-Länge (je)</span><span class="val">{{ fmt(result.radial) }} m</span></div>
      <div class="rr"><span class="lbl">Gesamtlänge Radiale ({{ result.anzahl }}×)</span><span class="val">{{ fmt(result.radial * result.anzahl) }} m</span></div>
      <div class="rr"><span class="lbl">Radiale-Neigung</span><span class="val">{{ result.winkel }}° unter horizontal</span></div>
      <div class="rr"><span class="lbl">Speisepunkt-Impedanz</span><span class="val">{{ result.imp }}</span></div>
      <div class="rr"><span class="lbl">Frequenz</span><span class="val">{{ fmt(result.f) }} MHz</span></div>
      <div style="margin-top:12px; text-align:right">
        <button class="btn-sim" @click="imSimOeffnen">📡 Im Sim öffnen</button>
      </div>
    </div>

    <div class="card">
      <h2>Skizze</h2>
      <div class="skz-bg" style="display:flex;justify-content:center">
        <svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet" style="max-height:250px">
          <!-- Strahler vertikal -->
          <line :x1="cx" :y1="feedY" :x2="cx" :y2="topY"
                stroke="#60a5fa" stroke-width="4" stroke-linecap="round"/>

          <!-- Radiale -->
          <line v-for="(end, i) in radialEnds" :key="i"
                :x1="cx" :y1="feedY" :x2="end.x" :y2="end.y"
                stroke="rgba(140,140,140,0.7)" stroke-width="2.5" stroke-linecap="round"/>

          <!-- Speisepunkt -->
          <circle :cx="cx" :cy="feedY" r="5" fill="var(--acc)"/>
          <text :x="cx + 14" :y="feedY + 3" text-anchor="start" font-size="11" font-weight="bold" fill="var(--acc)">50Ω</text>

          <!-- Bemaßung -->
          <text :x="cx - 14" :y="(topY + feedY) / 2" text-anchor="end" font-size="11" fill="var(--ts)">
            λ/4 = {{ fmt(result.strahler) }} m
          </text>
          <text :x="cx" :y="SVG_H - 6" text-anchor="middle" font-size="10" fill="var(--ts)">
            {{ result.anzahl }}× {{ fmt(result.radial) }} m
          </text>
        </svg>
      </div>
    </div>

  </template>

  <RechnerBeschreibung name="groundplane" />
</template>
