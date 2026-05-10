<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const hb = reactive({
  freq: '144.3', d_mm: '6.0', boomFaktor: 0.125, speise: 'gamma', isWire: false,
})

const hbBands = [
  ['80m',3.65],['40m',7.1],['20m',14.175],['15m',21.225],
  ['10m',28.5],['6m',50.15],['2m',144.3],['70cm',432.1],
]

function vfFromDLambda(d_mm, lambda) {
  const d_lambda = d_mm / (lambda * 1000)
  let vf = 0.985 - 0.04 * Math.pow(d_lambda * 100, 0.4)
  return Math.max(0.92, Math.min(0.985, vf))
}

const result = computed(() => {
  const f = pf(hb.freq), d = pf(hb.d_mm)
  if (!f || !d) return null
  const lambda = 300 / f
  let vf = vfFromDLambda(d, lambda)
  if (hb.isWire && vf < 0.97) vf = Math.min(0.985, vf + 0.01)
  const l_refl = 0.5 * lambda * vf
  const l_dir = 0.46 * lambda * vf
  const boom = hb.boomFaktor * lambda
  const gPos = 0.08 * l_refl
  return { f, lambda, vf, d_mm: d, l_refl, l_dir, boom, gammaPos: gPos }
})

// SVG Skizze (Draufsicht)
const SVG_W = 600, SVG_H = 340
const margin = 40

const svgGeom = computed(() => {
  if (!result.value) return null
  const r = result.value
  const maxLen = Math.max(r.l_refl, r.l_dir)
  const scale = Math.min((SVG_W - 2 * margin) / maxLen, (SVG_H - 100) / (r.boom + 0.2))
  const refl_y = margin
  const dir_y = refl_y + r.boom * scale
  const cx = SVG_W / 2
  return {
    cx, refl_y, dir_y,
    refl_w: r.l_refl * scale,
    dir_w: r.l_dir * scale,
    arrowY: dir_y + 36,
  }
})
</script>

<template>
  <div class="calc-title">HB9CV Beam</div>

  <div class="card">
    <h2>Parameter</h2>
    <div class="band-grid" style="grid-template-columns:repeat(4,1fr);margin-bottom:10px">
      <button v-for="[name, f] in hbBands" :key="name"
              class="bb" :class="{ on: Math.abs(pf(hb.freq) - f) < 0.5 }"
              @click="hb.freq = String(f)">{{ name }}</button>
    </div>
    <div class="inp-grid">
      <div class="inp-g"><label>Frequenz</label><div class="inp-row"><input type="text" v-model="hb.freq"><span>MHz</span></div></div>
      <div class="inp-g"><label>Element-Ø</label><div class="inp-row"><input type="text" v-model="hb.d_mm"><span>mm</span></div></div>
    </div>
    <div class="inp-grid" style="margin-top:10px">
      <div class="inp-g">
        <label>Boom-Abstand</label>
        <div class="seg">
          <button class="sb" :class="{ on: hb.boomFaktor === 0.10 }" @click="hb.boomFaktor = 0.10">0.1 λ</button>
          <button class="sb" :class="{ on: hb.boomFaktor === 0.125 }" @click="hb.boomFaktor = 0.125">0.125 λ</button>
          <button class="sb" :class="{ on: hb.boomFaktor === 0.15 }" @click="hb.boomFaktor = 0.15">0.15 λ</button>
        </div>
      </div>
      <div class="inp-g">
        <label>Speisung</label>
        <div class="seg">
          <button class="sb" :class="{ on: hb.speise === 'gamma' }" @click="hb.speise = 'gamma'">Gamma-Match</button>
          <button class="sb" :class="{ on: hb.speise === 'direkt' }" @click="hb.speise = 'direkt'">Direkt 50 Ω</button>
        </div>
      </div>
    </div>
    <label class="check-row" style="margin-top:10px">
      <input type="checkbox" v-model="hb.isWire">
      <span>Drahtantenne / Spiderbeam-Style</span>
    </label>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Maße</h2>
      <div class="rr"><span class="lbl">Wellenlänge λ</span><span class="val">{{ fmt(result.lambda) }} m</span></div>
      <div class="rr"><span class="lbl">Verkürzungsfaktor VF</span><span class="val">{{ result.vf.toFixed(4) }}</span></div>
      <hr class="div">
      <div class="rr hi"><span class="lbl">Reflektor (L1, hinten)</span><span class="val">{{ fmt(result.l_refl) }} m  ({{ (result.l_refl * 100).toFixed(0) }} cm)</span></div>
      <div class="rr"><span class="lbl">Reflektor, halbe Seite</span><span class="val">{{ fmt(result.l_refl / 2) }} m  ({{ (result.l_refl * 50).toFixed(0) }} cm)</span></div>
      <div class="rr hi"><span class="lbl">Direktor (L2, vorne)</span><span class="val">{{ fmt(result.l_dir) }} m  ({{ (result.l_dir * 100).toFixed(0) }} cm)</span></div>
      <div class="rr"><span class="lbl">Direktor, halbe Seite</span><span class="val">{{ fmt(result.l_dir / 2) }} m  ({{ (result.l_dir * 50).toFixed(0) }} cm)</span></div>
      <div class="rr"><span class="lbl">Boom-Länge</span><span class="val">{{ fmt(result.boom) }} m  ({{ (result.boom * 100).toFixed(0) }} cm)</span></div>
      <div class="rr"><span class="lbl">Refl–Direk Abstand</span><span class="val">{{ fmt(result.boom) }} m  ({{ (result.boom * 100).toFixed(0) }} cm)</span></div>
    </div>

    <div class="card">
      <h2>Draufsicht</h2>
      <div class="skz-bg">
        <svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet" v-if="svgGeom">
          <!-- Boom -->
          <line :x1="svgGeom.cx" :y1="svgGeom.refl_y" :x2="svgGeom.cx" :y2="svgGeom.dir_y"
                stroke="rgba(140,140,140,0.5)" stroke-width="2"/>

          <!-- Phasenleitungen (X-Kreuz) -->
          <line :x1="svgGeom.cx - 20" :y1="svgGeom.refl_y" :x2="svgGeom.cx + 20" :y2="svgGeom.dir_y"
                stroke="rgba(248,113,113,0.85)" stroke-width="2"/>
          <line :x1="svgGeom.cx + 20" :y1="svgGeom.refl_y" :x2="svgGeom.cx - 20" :y2="svgGeom.dir_y"
                stroke="rgba(248,113,113,0.85)" stroke-width="2"/>

          <!-- Reflektor (blau) -->
          <line :x1="svgGeom.cx - svgGeom.refl_w/2" :y1="svgGeom.refl_y"
                :x2="svgGeom.cx + svgGeom.refl_w/2" :y2="svgGeom.refl_y"
                stroke="#60a5fa" stroke-width="4" stroke-linecap="round"/>
          <!-- Direktor (grün) -->
          <line :x1="svgGeom.cx - svgGeom.dir_w/2" :y1="svgGeom.dir_y"
                :x2="svgGeom.cx + svgGeom.dir_w/2" :y2="svgGeom.dir_y"
                stroke="#4ade80" stroke-width="4" stroke-linecap="round"/>

          <!-- Speisepunkt -->
          <circle :cx="svgGeom.cx" :cy="svgGeom.refl_y" r="5" fill="#fb923c"/>

          <!-- Beschriftung -->
          <text :x="svgGeom.cx" :y="svgGeom.refl_y - 14" text-anchor="middle" font-size="11" font-weight="bold" fill="#60a5fa">
            Reflektor  {{ (result.l_refl * 100).toFixed(0) }} cm
          </text>
          <text :x="svgGeom.cx" :y="svgGeom.dir_y + 18" text-anchor="middle" font-size="11" font-weight="bold" fill="#4ade80">
            Direktor  {{ (result.l_dir * 100).toFixed(0) }} cm
          </text>
          <text :x="svgGeom.cx + 26" :y="(svgGeom.refl_y + svgGeom.dir_y) / 2" text-anchor="start" font-size="10" fill="rgba(248,113,113,0.85)">
            Phasenltg.
          </text>
          <text :x="SVG_W - 30" :y="(svgGeom.refl_y + svgGeom.dir_y) / 2" text-anchor="end" font-size="10" fill="var(--ts)">
            ← {{ (result.boom * 100).toFixed(0) }} cm →
          </text>

          <!-- Richtungspfeil -->
          <line :x1="svgGeom.cx" :y1="svgGeom.dir_y + 6" :x2="svgGeom.cx" :y2="svgGeom.arrowY"
                stroke="rgba(96,165,250,0.6)" stroke-width="1.5"/>
          <text :x="svgGeom.cx" :y="svgGeom.arrowY + 12" text-anchor="middle" font-size="10" fill="rgba(96,165,250,0.7)">
            ▼ Abstrahlrichtung
          </text>
        </svg>
      </div>
    </div>

    <div class="card">
      <h2>{{ hb.speise === 'gamma' ? 'Gamma-Match Anpassung' : 'Direkte 50Ω Speisung' }}</h2>
      <template v-if="hb.speise === 'gamma'">
        <div class="rr"><span class="lbl">Gamma-Stab Position (von Mitte)</span><span class="val">{{ fmt(result.gammaPos) }} m  ({{ (result.gammaPos * 1000).toFixed(0) }} mm)</span></div>
        <div class="rr"><span class="lbl">Gamma-Stab Länge (typ.)</span><span class="val">{{ (result.l_refl * 40).toFixed(0) }} mm</span></div>
        <div class="rr"><span class="lbl">Anpass-Kondensator</span><span class="val">variabel, ca. 10–60 pF</span></div>
        <div class="rr"><span class="lbl">Eingangsimpedanz HB9CV</span><span class="val">≈ 25–35 Ω (original)</span></div>
      </template>
      <template v-else>
        <div class="small">
          Die Eingangsimpedanz der HB9CV liegt original bei ca. 25–35 Ω. Für direkte 50Ω-Speisung
          ist ein Ferrite-Kern Balun oder ein λ/4 Transformator (≈ 35 Ω Koax) nötig.
        </div>
      </template>
    </div>

  </template>

  <RechnerBeschreibung name="hb9cv" />
</template>

<style scoped>
.check-row { display: flex; gap: 8px; align-items: center; cursor: pointer; font-size: 13px; color: var(--ts); }
.check-row input { width: 16px; height: 16px; cursor: pointer; }
</style>
