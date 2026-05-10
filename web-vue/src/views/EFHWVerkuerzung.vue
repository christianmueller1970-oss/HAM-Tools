<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const v = reactive({
  freq: '7.1', len: '15.0', coilD: '50.0', wireD: '1.5', posMitte: true,
})

const efhwBands = [
  ['80m',3.65],['40m',7.1],['30m',10.125],['20m',14.175],
  ['17m',18.118],['15m',21.225],['12m',24.94],['10m',28.5],
]

function selectBand(freq) {
  v.freq = String(freq)
  v.len = ((142.5 / freq) * 0.7).toFixed(1)
}

const fullLen = computed(() => {
  const f = pf(v.freq)
  return f > 0 ? 142.5 / f : 0
})

const result = computed(() => {
  const f = pf(v.freq), h = pf(v.len), D = pf(v.coilD), dw = pf(v.wireD)
  if (!f || !h || !D || !dw) return null
  const fl = 142.5 / f
  if (h >= fl) return { ok: true, h, fullLen: fl }
  const diff = fl - h
  const L_uH = diff * 2.5
  const r_inch = (D / 2) / 25.4
  // Wheeler iterative
  const pitch = dw / 25.4
  let n = 10, np = 0
  for (let i = 0; i < 80; i++) {
    const l_inch = n * pitch
    n = Math.sqrt(L_uH * (9 * r_inch + 10 * l_inch)) / r_inch
    if (Math.abs(n - np) < 0.0001) break
    np = n
  }
  if (n <= 0) return null
  const nInt = Math.ceil(n)
  const coilLen = nInt * dw
  const meanCirc = Math.PI * D
  const wireLen = nInt * Math.sqrt(meanCirc * meanCirc + dw * dw) / 1000
  return {
    ok: false, fullLen: fl, h, diff, L_uH,
    windungen: nInt, windungenRoh: n,
    coilLen_mm: coilLen, wireLen_m: wireLen, outerD_mm: D + 2 * dw,
  }
})

// SVG Skizze
const SVG_W = 600, SVG_H = 220
const cy = SVG_H / 2
const marginL = 30, marginR = 30

const svgScale = computed(() => result.value && !result.value.ok
  ? (SVG_W - marginL - marginR) / result.value.fullLen : 1)
const hPx = computed(() => result.value ? pf(v.len) * svgScale.value : 0)
const coilWpx = computed(() => result.value && !result.value.ok
  ? Math.max(48, Math.min(100, result.value.windungen * 5)) : 48)
const coilX = computed(() => v.posMitte
  ? marginL + hPx.value / 2 - coilWpx.value / 2
  : marginL + hPx.value - coilWpx.value)
const wireStartX = marginL
const antennaEndX = computed(() => marginL + hPx.value)
const afterCoilX = computed(() => coilX.value + coilWpx.value)
const coilCenterX = computed(() => coilX.value + coilWpx.value / 2)
const amp = 20

// Spulen-Bogen-Pfad
const spulenPath = computed(() => {
  if (!result.value || result.value.ok) return ''
  const nVis = Math.min(result.value.windungen, 16)
  const step = coilWpx.value / nVis
  let path = `M ${coilX.value} ${cy}`
  for (let i = 0; i < nVis; i++) {
    const x1 = coilX.value + i * step
    const x3 = coilX.value + (i + 1) * step
    path += ` C ${x1} ${cy - amp}, ${x3} ${cy - amp}, ${x3} ${cy}`
  }
  return path
})
</script>

<template>
  <div class="calc-title">EFHW-Verkürzung</div>

  <div class="card">
    <h2>Eingabe</h2>
    <div class="band-grid" style="grid-template-columns:repeat(4,1fr);margin-bottom:10px">
      <button v-for="[name, f] in efhwBands" :key="name"
              class="bb" :class="{ on: Math.abs(pf(v.freq) - f) < 0.5 }"
              @click="selectBand(f)">{{ name }}</button>
    </div>
    <div class="inp-grid">
      <div class="inp-g"><label>Frequenz</label><div class="inp-row"><input type="text" v-model="v.freq"><span>MHz</span></div></div>
      <div class="inp-g">
        <label>Antennenlänge h</label>
        <div class="inp-row"><input type="text" v-model="v.len"><span>m</span></div>
        <div class="small c-orn" style="font-size:10px">Muss kürzer als λ/2 sein</div>
      </div>
    </div>
    <div class="inp-grid" style="margin-top:10px">
      <div class="inp-g"><label>Spulen-Ø D</label><div class="inp-row"><input type="text" v-model="v.coilD"><span>mm</span></div></div>
      <div class="inp-g"><label>Draht-Ø dw</label><div class="inp-row"><input type="text" v-model="v.wireD"><span>mm</span></div></div>
    </div>
    <div v-if="fullLen > 0" class="small mt8">
      λ/2 Referenz: {{ fmt(fullLen) }} m
    </div>
    <hr class="div">
    <div class="inp-g">
      <label>Spulenposition</label>
      <div class="seg">
        <button class="sb" :class="{ on: v.posMitte }" @click="v.posMitte = true">Mitte des Strahlers</button>
        <button class="sb" :class="{ on: !v.posMitte }" @click="v.posMitte = false">Ende des Strahlers</button>
      </div>
      <div class="small" style="font-size:10px;margin-top:4px">
        {{ v.posMitte ? 'Spule teilt den Strahler in zwei gleiche Hälften' : 'Spule am freien Ende des Strahlers' }}
      </div>
    </div>
  </div>

  <template v-if="result">
    <div v-if="result.ok" class="card">
      <div class="ok-box" style="display:flex;gap:12px;align-items:center">
        <span style="background:var(--grn);color:#fff;width:28px;height:28px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;font-weight:bold">✓</span>
        <div>
          <div style="font-weight:600;color:var(--tp)">Keine Spule nötig</div>
          <div class="small">Die Antenne ({{ fmt(result.h, 2) }} m) ist bereits lang genug für λ/2 ({{ fmt(result.fullLen) }} m).</div>
        </div>
      </div>
    </div>

    <template v-else>
      <div class="card">
        <h2>Ergebnis</h2>
        <div class="ken-grid">
          <div class="ken hi"><div class="ken-val">{{ result.windungen }}</div><div class="ken-lbl">Windungen</div></div>
          <div class="ken"><div class="ken-val">{{ fmt(result.L_uH, 1) }} µH</div><div class="ken-lbl">Induktivität</div></div>
          <div class="ken"><div class="ken-val">{{ fmt(result.coilLen_mm, 1) }} mm</div><div class="ken-lbl">Wickellänge</div></div>
          <div class="ken"><div class="ken-val">{{ fmt(result.wireLen_m, 2) }} m</div><div class="ken-lbl">Drahtlänge</div></div>
          <div class="ken"><div class="ken-val">{{ fmt(result.outerD_mm, 1) }} mm</div><div class="ken-lbl">Außen-Ø</div></div>
          <div class="ken"><div class="ken-val">{{ fmt(result.diff) }} m</div><div class="ken-lbl">Fehlende Länge</div></div>
        </div>
      </div>

      <div class="card">
        <h2>Details</h2>
        <div class="rr"><span class="lbl">Volle λ/2 Länge</span><span class="val">{{ fmt(result.fullLen) }} m</span></div>
        <div class="rr"><span class="lbl">Antennenlänge h</span><span class="val">{{ fmt(result.h) }} m</span></div>
        <div class="rr"><span class="lbl">Fehlende Länge</span><span class="val">{{ fmt(result.diff) }} m</span></div>
        <div class="rr"><span class="lbl">Benötigte Induktivität</span><span class="val">{{ fmt(result.L_uH, 2) }} µH</span></div>
        <div class="rr"><span class="lbl">Windungen (roh)</span><span class="val">{{ fmt(result.windungenRoh, 2) }}</span></div>
        <div class="rr hi"><span class="lbl">Windungen (aufgerundet)</span><span class="val">{{ result.windungen }}</span></div>
        <div class="rr"><span class="lbl">Wickellänge</span><span class="val">{{ fmt(result.coilLen_mm, 1) }} mm</span></div>
        <div class="rr"><span class="lbl">Drahtlänge gesamt</span><span class="val">{{ fmt(result.wireLen_m, 2) }} m</span></div>
        <div class="rr"><span class="lbl">Spulen-Außen-Ø</span><span class="val">{{ fmt(result.outerD_mm, 1) }} mm</span></div>
      </div>

      <div class="card">
        <h2>Skizze</h2>
        <div class="skz-bg">
          <svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet">
            <!-- Bemaßung weit oben -->
            <line :x1="wireStartX" :y1="cy - amp - 46" :x2="antennaEndX" :y2="cy - amp - 46"
                  stroke="rgba(140,140,140,0.45)" stroke-width="1"/>
            <line :x1="wireStartX" :y1="cy - amp - 50" :x2="wireStartX" :y2="cy - amp - 42"
                  stroke="rgba(140,140,140,0.45)" stroke-width="1"/>
            <line :x1="antennaEndX" :y1="cy - amp - 50" :x2="antennaEndX" :y2="cy - amp - 42"
                  stroke="rgba(140,140,140,0.45)" stroke-width="1"/>
            <text :x="(wireStartX + antennaEndX) / 2" :y="cy - amp - 56" text-anchor="middle" font-size="11" fill="var(--ts)">
              h = {{ fmt(result.h) }} m
            </text>

            <!-- Segment 1: Anfang → Spule -->
            <line :x1="wireStartX" :y1="cy" :x2="coilX" :y2="cy"
                  stroke="#a78bfa" stroke-width="3"/>

            <!-- Spulen-Box (orange, leicht transparent) -->
            <rect :x="coilX - 2" :y="cy - amp - 4" :width="coilWpx + 4" :height="amp + 8" rx="4"
                  fill="none" stroke="rgba(251,146,60,0.3)" stroke-width="1"/>
            <!-- Spulen-Bögen -->
            <path :d="spulenPath" fill="none" stroke="#fb923c" stroke-width="2.5"/>

            <!-- Segment 2: Spule → Ende -->
            <line v-if="afterCoilX < SVG_W - marginR" :x1="afterCoilX" :y1="cy" :x2="antennaEndX" :y2="cy"
                  stroke="#a78bfa" stroke-width="3"/>

            <!-- Speisepunkt -->
            <circle :cx="wireStartX" :cy="cy" r="5" fill="var(--acc)"/>
            <text :x="wireStartX" :y="cy + 24" text-anchor="middle" font-size="11" font-weight="bold" fill="var(--acc)">50Ω</text>

            <!-- Windungen + L-Wert über Spule -->
            <text :x="coilCenterX" :y="cy - amp - 22" text-anchor="middle" font-size="11" font-weight="bold" fill="#fb923c">
              {{ result.windungen }} Wdg.  {{ fmt(result.L_uH, 2) }} µH
            </text>

            <!-- λ/2 Referenz unten -->
            <text :x="SVG_W / 2" :y="SVG_H - 6" text-anchor="middle" font-size="10" fill="var(--ts)">
              λ/2 = {{ fmt(result.fullLen) }} m
            </text>
          </svg>
        </div>
      </div>
    </template>
  </template>

  <RechnerBeschreibung name="efhwv" />
</template>

<style scoped>
.ken-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
.ken {
  background: var(--card2);
  border: 1px solid var(--sep);
  border-radius: 8px;
  padding: 14px 12px;
  text-align: center;
}
.ken.hi { border-color: var(--acc); }
.ken-val { font-size: 18px; font-weight: 700; color: var(--tp); font-family: 'SF Mono', 'Cascadia Mono', monospace; }
.ken.hi .ken-val { color: var(--acc); }
.ken-lbl { font-size: 10px; color: var(--ts); margin-top: 4px; text-transform: uppercase; letter-spacing: 0.5px; }
@media(max-width:560px){ .ken-grid { grid-template-columns: 1fr 1fr; } }
</style>
