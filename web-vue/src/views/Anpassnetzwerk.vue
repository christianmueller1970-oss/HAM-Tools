<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const an = reactive({ rs: '50.0', rl: '200.0', freq: '14.175' })

const anpBands = [
  ['160m',1.85],['80m',3.65],['40m',7.1],['30m',10.125],
  ['20m',14.175],['17m',18.118],['15m',21.225],['10m',28.5],
]

const result = computed(() => {
  const rs = pf(an.rs), rl = pf(an.rl), f = pf(an.freq)
  if (!rs || !rl || !f || rs === rl) return null
  const rHigh = Math.max(rs, rl)
  const rLow = Math.min(rs, rl)
  const q = Math.sqrt(rHigh / rLow - 1)
  const w = 2 * Math.PI * f * 1e6
  // Tiefpass
  const xl1 = rLow * q
  const xc1 = rHigh / q
  const l1 = xl1 / w * 1e6
  const c1 = 1 / (w * xc1) * 1e12
  // Hochpass
  const xc2 = rLow * q
  const xl2 = rHigh / q
  const c2 = 1 / (w * xc2) * 1e12
  const l2 = xl2 / w * 1e6
  return { rs, rl, f, q, xl1, xc1, l1, c1, xc2, xl2, c2, l2 }
})

const isEqual = computed(() => {
  const rs = pf(an.rs), rl = pf(an.rl)
  return rs > 0 && rl > 0 && rs === rl
})

// SVG Schema (Tiefpass: L Serie + C parallel)
const SVG_W = 600, SVG_H = 200
const cy = SVG_H / 2
const margin = 30
const nodeX = SVG_W * 0.42

// Spulen-Pfad
const coilPath = computed(() => {
  if (!result.value) return ''
  const coilX = nodeX - 30, coilW = 40, nCoil = 5, amp = 8
  let path = `M ${coilX} ${cy}`
  for (let i = 0; i < nCoil; i++) {
    const x1 = coilX + i * coilW / nCoil
    const x2 = coilX + (i + 1) * coilW / nCoil
    path += ` C ${x1} ${cy - amp}, ${x2} ${cy - amp}, ${x2} ${cy}`
  }
  return path
})
</script>

<template>
  <div class="calc-title">Anpassnetzwerk (L-Netz)</div>

  <div class="card">
    <h2>Eingabe</h2>
    <div class="band-grid" style="grid-template-columns:repeat(4,1fr);margin-bottom:10px">
      <button v-for="[name, f] in anpBands" :key="name"
              class="bb" :class="{ on: Math.abs(pf(an.freq) - f) < 0.5 }"
              @click="an.freq = String(f)">{{ name }}</button>
    </div>
    <div class="inp-grid3">
      <div class="inp-g"><label>Quellimpedanz Rs</label><div class="inp-row"><input type="text" v-model="an.rs"><span>Ω</span></div></div>
      <div class="inp-g"><label>Lastimpedanz Rl</label><div class="inp-row"><input type="text" v-model="an.rl"><span>Ω</span></div></div>
      <div class="inp-g"><label>Frequenz</label><div class="inp-row"><input type="text" v-model="an.freq"><span>MHz</span></div></div>
    </div>
    <div class="small mt8" style="font-size:10px">Typisch: Rs=50Ω (Koax) → Rl=200Ω (Antenne) oder umgekehrt</div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Tiefpass L-Netz (L + C parallel)</h2>
      <div class="rr"><span class="lbl">Güte Q</span><span class="val">{{ result.q.toFixed(2) }}</span></div>
      <div class="rr hi"><span class="lbl">Spule (Serie)</span><span class="val">{{ fmt(result.l1, 3) }} µH  (XL = {{ fmt(result.xl1, 1) }} Ω)</span></div>
      <div class="rr hi"><span class="lbl">Kondensator (Parallel)</span><span class="val">{{ fmt(result.c1, 1) }} pF  (XC = {{ fmt(result.xc1, 1) }} Ω)</span></div>
      <div class="rr"><span class="lbl">Konfiguration</span><span class="val">{{ result.rs < result.rl ? 'Rs→[L]→[C∥]→Rl' : 'Rl→[L]→[C∥]→Rs' }}</span></div>
    </div>

    <div class="card">
      <h2>Hochpass L-Netz (C + L parallel)</h2>
      <div class="rr"><span class="lbl">Güte Q</span><span class="val">{{ result.q.toFixed(2) }}</span></div>
      <div class="rr hi"><span class="lbl">Kondensator (Serie)</span><span class="val">{{ fmt(result.c2, 1) }} pF  (XC = {{ fmt(result.xc2, 1) }} Ω)</span></div>
      <div class="rr hi"><span class="lbl">Spule (Parallel)</span><span class="val">{{ fmt(result.l2, 3) }} µH  (XL = {{ fmt(result.xl2, 1) }} Ω)</span></div>
      <div class="rr"><span class="lbl">Konfiguration</span><span class="val">{{ result.rs < result.rl ? 'Rs→[C]→[L∥]→Rl' : 'Rl→[C]→[L∥]→Rs' }}</span></div>
    </div>

    <div class="card">
      <h2>Schema Tiefpass L-Netz</h2>
      <div class="skz-bg">
        <svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet">
          <!-- Leitung links -->
          <line :x1="margin" :y1="cy" :x2="nodeX - 30" :y2="cy" stroke="#60a5fa" stroke-width="2"/>
          <!-- Leitung rechts -->
          <line :x1="nodeX + 10" :y1="cy" :x2="SVG_W - margin" :y2="cy" stroke="#60a5fa" stroke-width="2"/>
          <!-- Spulen-Bögen -->
          <path :d="coilPath" fill="none" stroke="#60a5fa" stroke-width="2"/>
          <text :x="nodeX - 10" :y="cy - 18" text-anchor="middle" font-size="10" fill="#60a5fa">{{ fmt(result.l1, 3) }} µH</text>

          <!-- Kondensator (parallel nach unten) -->
          <line :x1="nodeX + 10" :y1="cy" :x2="nodeX + 10" :y2="cy + 17" stroke="#fb923c" stroke-width="2"/>
          <line :x1="nodeX + 10" :y1="cy + 27" :x2="nodeX + 10" :y2="cy + 44" stroke="#fb923c" stroke-width="2"/>
          <!-- Platten -->
          <line :x1="nodeX - 2" :y1="cy + 17" :x2="nodeX + 22" :y2="cy + 17" stroke="#fb923c" stroke-width="2.5"/>
          <line :x1="nodeX - 2" :y1="cy + 27" :x2="nodeX + 22" :y2="cy + 27" stroke="#fb923c" stroke-width="2.5"/>
          <!-- GND -->
          <line :x1="nodeX" :y1="cy + 44" :x2="nodeX + 20" :y2="cy + 44" stroke="rgba(140,140,140,0.85)" stroke-width="2"/>
          <line :x1="nodeX + 3" :y1="cy + 49" :x2="nodeX + 17" :y2="cy + 49" stroke="rgba(140,140,140,0.6)" stroke-width="1"/>
          <line :x1="nodeX + 6" :y1="cy + 54" :x2="nodeX + 14" :y2="cy + 54" stroke="rgba(140,140,140,0.6)" stroke-width="1"/>
          <text :x="nodeX + 28" :y="cy + 26" font-size="10" fill="#fb923c">{{ fmt(result.c1, 0) }} pF</text>

          <!-- Labels Rs/Rl -->
          <text :x="margin" :y="cy - 14" text-anchor="start" font-size="10" fill="var(--ts)">
            Rs = {{ result.rs.toFixed(0) }} Ω
          </text>
          <text :x="SVG_W - margin" :y="cy - 14" text-anchor="end" font-size="10" fill="var(--ts)">
            Rl = {{ result.rl.toFixed(0) }} Ω
          </text>
        </svg>
      </div>
    </div>
  </template>

  <div v-if="isEqual" class="card">
    <h2>Kein Netzwerk nötig</h2>
    <div class="small">Quell- und Lastimpedanz sind identisch – kein Anpassnetzwerk erforderlich.</div>
  </div>

  <RechnerBeschreibung name="anpassnetz" />
</template>
