<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const variants = [
  { id: 'delta110',    label: 'Delta-Loop 110Ω',                    impLabel: '≈ 110Ω → 50Ω via λ/4' },
  { id: 'delta50',     label: 'Delta-Loop 50Ω (40/30/30)',         impLabel: '≈ 50Ω direkt' },
  { id: 'delta50apex', label: 'Delta-Loop 50Ω (Apex 18/41/41)',    impLabel: '≈ 50Ω direkt' },
  { id: 'quad',        label: 'Quad-Loop 110Ω',                     impLabel: '≈ 110Ω → 50Ω via λ/4' },
]

const lp = reactive({ variant: 'delta110', freq: '7.1', vf: '0.98', coaxVF: 0.67 })

const loopBands = [
  ['160m',1.85],['80m',3.65],['60m',5.36],['40m',7.1],
  ['30m',10.125],['20m',14.175],['17m',18.118],['15m',21.225],
]

const result = computed(() => {
  const f = pf(lp.freq), vf = pf(lp.vf)
  if (!f || !vf) return null
  const total = (306.3 / f) * (vf / 0.98)
  const matchLen = (300 / f / 4) * lp.coaxVF
  const r = { f, vf, total, matchLen, variant: lp.variant, coaxVF: lp.coaxVF }
  switch (lp.variant) {
    case 'delta110':    r.seite = total / 3; break
    case 'delta50':     r.basis = total * 0.40; r.schenkel = total * 0.30; break
    case 'delta50apex': r.basis = total * 0.18; r.schenkel = total * 0.41; break
    case 'quad':        r.seite = total / 4; break
  }
  return r
})

const needsMatch = computed(() => lp.variant === 'delta110' || lp.variant === 'quad')

// SVG layout
const SVG_W = 360, SVG_H = 280

// Delta gleichseitig (delta110)
const deltaEq = computed(() => {
  if (!result.value || lp.variant !== 'delta110') return null
  const marginX = 40, marginT = 22, marginB = 50
  const availW = SVG_W - 2 * marginX
  const availH = SVG_H - marginT - marginB
  const hRatio = Math.sqrt(3) / 2
  const bPx = Math.min(availW, availH / hRatio)
  const hPx = bPx * hRatio
  const cx = SVG_W / 2
  const botY = marginT + (availH + hPx) / 2
  const topY = botY - hPx
  return { lX: cx - bPx / 2, rX: cx + bPx / 2, cx, topY, botY }
})

// Delta flach (delta50)
const deltaFlach = computed(() => {
  if (!result.value || lp.variant !== 'delta50') return null
  const b = result.value.basis, l = result.value.schenkel
  const triH = Math.sqrt(l * l - (b / 2) * (b / 2))
  const marginX = 40, marginT = 22, marginB = 50
  const availW = SVG_W - 2 * marginX
  const availH = SVG_H - marginT - marginB
  const scale = Math.min(availW / b, availH / triH) * 0.9
  const bPx = b * scale, hPx = triH * scale
  const cx = SVG_W / 2
  const botY = marginT + (availH + hPx) / 2
  const topY = botY - hPx
  return { lX: cx - bPx / 2, rX: cx + bPx / 2, cx, topY, botY }
})

// Delta Apex (delta50apex) — kurze Basis oben, Apex unten
const deltaApex = computed(() => {
  if (!result.value || lp.variant !== 'delta50apex') return null
  const b = result.value.basis, l = result.value.schenkel
  const triH = Math.sqrt(l * l - (b / 2) * (b / 2))
  const marginX = 40, marginT = 30, marginB = 50
  const availW = SVG_W - 2 * marginX
  const availH = SVG_H - marginT - marginB
  const scale = Math.min(availW / b, availH / triH) * 0.9
  const bPx = b * scale, hPx = triH * scale
  const cx = SVG_W / 2
  const topY = marginT + (availH - hPx) / 2
  const botY = topY + hPx
  return { lX: cx - bPx / 2, rX: cx + bPx / 2, cx, topY, botY }
})

// Quad
const quad = computed(() => {
  if (!result.value || lp.variant !== 'quad') return null
  const marginX = 40, marginT = 22, marginB = 44
  const availW = SVG_W - 2 * marginX
  const availH = SVG_H - marginT - marginB
  const side = Math.min(availW, availH)
  const x0 = (SVG_W - side) / 2
  const y0 = marginT + (availH - side) / 2
  return { x0, y0, side, feedX: x0 + side / 2, feedY: y0 + side }
})
</script>

<template>
  <div class="calc-title">Loop-Antenne</div>

  <div class="card">
    <h2>Loop-Variante</h2>
    <div class="variant-list">
      <button v-for="v in variants" :key="v.id"
              class="variant-row" :class="{ active: lp.variant === v.id }"
              @click="lp.variant = v.id">
        <span class="variant-radio">{{ lp.variant === v.id ? '●' : '○' }}</span>
        <span class="variant-label">{{ v.label }}</span>
        <span class="variant-imp">{{ v.impLabel }}</span>
      </button>
    </div>
  </div>

  <div class="card">
    <h2>Eingabe</h2>
    <div class="band-grid" style="grid-template-columns:repeat(4,1fr);margin-bottom:10px">
      <button v-for="[name, f] in loopBands" :key="name"
              class="bb" :class="{ on: Math.abs(pf(lp.freq) - f) < 0.5 }"
              @click="lp.freq = String(f)">{{ name }}</button>
    </div>
    <div class="inp-grid">
      <div class="inp-g"><label>Frequenz</label><div class="inp-row"><input type="text" v-model="lp.freq"><span>MHz</span></div></div>
      <div class="inp-g">
        <label>Verkürzungsfaktor VF</label>
        <div class="inp-row"><input type="text" v-model="lp.vf"><span>(Draht ≈ 0.98)</span></div>
      </div>
    </div>
    <div v-if="needsMatch" class="inp-g" style="margin-top:10px">
      <label>Koax VF für Anpassleitung (75Ω)</label>
      <div class="seg">
        <button class="sb" :class="{ on: lp.coaxVF === 0.66 }" @click="lp.coaxVF = 0.66">0.66 (Foam)</button>
        <button class="sb" :class="{ on: lp.coaxVF === 0.67 }" @click="lp.coaxVF = 0.67">0.67 (typ.)</button>
        <button class="sb" :class="{ on: lp.coaxVF === 0.70 }" @click="lp.coaxVF = 0.70">0.70 (Luft)</button>
      </div>
    </div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Maße</h2>
      <div class="rr hi"><span class="lbl">Gesamtumfang</span><span class="val">{{ fmt(result.total) }} m</span></div>
      <hr class="div">
      <template v-if="lp.variant === 'delta110'">
        <div class="rr"><span class="lbl">Seite (3×, gleichseitig)</span><span class="val">{{ fmt(result.seite) }} m</span></div>
      </template>
      <template v-else-if="lp.variant === 'delta50'">
        <div class="rr"><span class="lbl">Basis (40%, horizontal)</span><span class="val">{{ fmt(result.basis) }} m</span></div>
        <div class="rr"><span class="lbl">Schenkel (2×, je 30%)</span><span class="val">{{ fmt(result.schenkel) }} m</span></div>
      </template>
      <template v-else-if="lp.variant === 'delta50apex'">
        <div class="rr"><span class="lbl">Basis (18%, kurze Seite)</span><span class="val">{{ fmt(result.basis) }} m</span></div>
        <div class="rr"><span class="lbl">Schenkel (2×, je 41%)</span><span class="val">{{ fmt(result.schenkel) }} m</span></div>
      </template>
      <template v-else>
        <div class="rr"><span class="lbl">Seite (4×, Quadrat)</span><span class="val">{{ fmt(result.seite) }} m</span></div>
      </template>
      <hr class="div">
      <div class="rr"><span class="lbl">Wellenlänge λ</span><span class="val">{{ fmt(300 / result.f) }} m</span></div>
      <div class="rr"><span class="lbl">Frequenz</span><span class="val">{{ fmt(result.f) }} MHz</span></div>
    </div>

    <div class="card">
      <h2>Skizze</h2>
      <div class="skz-bg" style="display:flex;justify-content:center">
        <svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet" style="max-height:280px">
          <!-- Delta gleichseitig 110Ω -->
          <template v-if="deltaEq">
            <polygon :points="`${deltaEq.lX},${deltaEq.botY} ${deltaEq.rX},${deltaEq.botY} ${deltaEq.cx},${deltaEq.topY}`"
                     fill="none" stroke="#60a5fa" stroke-width="2.5"/>
            <circle :cx="deltaEq.cx" :cy="deltaEq.botY" r="5" fill="var(--acc)"/>
            <text :x="deltaEq.cx" :y="deltaEq.botY + 18" text-anchor="middle" font-size="10" font-weight="bold" fill="var(--acc)">50Ω</text>
            <text :x="SVG_W / 2" :y="SVG_H - 8" text-anchor="middle" font-size="10" fill="var(--ts)">
              110Ω  ·  Seite: {{ fmt(result.seite) }} m
            </text>
          </template>

          <!-- Delta flach 50Ω -->
          <template v-if="deltaFlach">
            <polygon :points="`${deltaFlach.lX},${deltaFlach.botY} ${deltaFlach.rX},${deltaFlach.botY} ${deltaFlach.cx},${deltaFlach.topY}`"
                     fill="none" stroke="#60a5fa" stroke-width="2.5"/>
            <circle :cx="deltaFlach.cx" :cy="deltaFlach.botY" r="5" fill="var(--acc)"/>
            <text :x="deltaFlach.cx" :y="deltaFlach.botY + 18" text-anchor="middle" font-size="10" font-weight="bold" fill="var(--acc)">50Ω</text>
            <text :x="SVG_W / 2" :y="SVG_H - 8" text-anchor="middle" font-size="10" fill="var(--ts)">
              Basis: {{ fmt(result.basis) }} m (40%) · Schenkel: {{ fmt(result.schenkel) }} m (30%)
            </text>
          </template>

          <!-- Delta Apex (Spitze unten) -->
          <template v-if="deltaApex">
            <polygon :points="`${deltaApex.lX},${deltaApex.topY} ${deltaApex.rX},${deltaApex.topY} ${deltaApex.cx},${deltaApex.botY}`"
                     fill="none" stroke="#60a5fa" stroke-width="2.5"/>
            <circle :cx="deltaApex.cx" :cy="deltaApex.botY" r="5" fill="var(--acc)"/>
            <text :x="deltaApex.cx" :y="deltaApex.botY + 18" text-anchor="middle" font-size="10" font-weight="bold" fill="var(--acc)">50Ω (Apex)</text>
            <text :x="deltaApex.cx" :y="deltaApex.topY - 14" text-anchor="middle" font-size="10" fill="var(--ts)">
              Basis: {{ fmt(result.basis) }} m (18%)
            </text>
            <text :x="SVG_W / 2" :y="SVG_H - 8" text-anchor="middle" font-size="10" fill="var(--ts)">
              Schenkel: {{ fmt(result.schenkel) }} m (41%)
            </text>
          </template>

          <!-- Quad -->
          <template v-if="quad">
            <rect :x="quad.x0" :y="quad.y0" :width="quad.side" :height="quad.side"
                  fill="none" stroke="#60a5fa" stroke-width="2.5"/>
            <circle :cx="quad.feedX" :cy="quad.feedY" r="5" fill="var(--acc)"/>
            <text :x="quad.feedX" :y="quad.feedY + 18" text-anchor="middle" font-size="10" font-weight="bold" fill="var(--acc)">50Ω via λ/4</text>
            <text :x="SVG_W / 2" :y="SVG_H - 8" text-anchor="middle" font-size="10" fill="var(--ts)">
              Seite: {{ fmt(result.seite) }} m
            </text>
          </template>
        </svg>
      </div>
    </div>

    <div class="card">
      <h2>{{ needsMatch ? 'Anpassleitung' : 'Speisung' }}</h2>
      <template v-if="needsMatch">
        <div class="rr"><span class="lbl">Typ</span><span class="val">λ/4 aus 75Ω Koaxkabel</span></div>
        <div class="rr hi"><span class="lbl">Länge (phys.)</span><span class="val">{{ fmt(result.matchLen) }} m  ({{ (result.matchLen * 100).toFixed(0) }} cm)</span></div>
        <div class="rr"><span class="lbl">Koax VF</span><span class="val">{{ result.coaxVF.toFixed(2) }}</span></div>
        <div class="small mt8">Transformiert ~110Ω → 50Ω. Zwischen Speisepunkt und 50Ω Koaxkabel einschleifen.</div>
      </template>
      <template v-else>
        <div class="small">Direkte 50Ω Einspeisung am Speisepunkt. Kein zusätzlicher Trafo nötig.</div>
      </template>
    </div>
  </template>

  <RechnerBeschreibung name="loop" />
</template>

<style scoped>
.variant-list { display: flex; flex-direction: column; gap: 4px; }
.variant-row {
  display: flex; align-items: center; gap: 10px;
  padding: 8px 10px;
  border: none; background: transparent;
  color: var(--tp); cursor: pointer; text-align: left;
  border-radius: 8px;
  transition: background 0.12s;
}
.variant-row:hover { background: var(--hover); }
.variant-row.active { background: rgba(160,160,160,0.08); }
.variant-row.active .variant-radio { color: var(--acc); }
.variant-radio { font-size: 16px; color: var(--td); width: 16px; flex-shrink: 0; }
.variant-label { flex: 1; font-size: 13px; }
.variant-imp { font-size: 11px; color: var(--ts); white-space: nowrap; }
</style>
