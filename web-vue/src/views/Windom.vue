<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const wd = reactive({ freq: '7.1', vf: '0.95' })

const wdBands = [['160m',1.85],['80m',3.65],['60m',5.36],['40m',7.1],['30m',10.125]]

const allBands = [
  ['160m', 1.8, 2.0],['80m', 3.5, 3.8],['60m', 5.3, 5.4],
  ['40m', 7.0, 7.3],['30m', 10.1, 10.15],['20m', 14.0, 14.35],
  ['17m', 18.068, 18.168],['15m', 21.0, 21.45],
  ['12m', 24.89, 24.99],['10m', 28.0, 29.7],
]
const bandOrder = ['160m','80m','60m','40m','30m','20m','17m','15m','12m','10m']

const result = computed(() => {
  const f = pf(wd.freq), vf = pf(wd.vf)
  if (!f || !vf) return null
  const gesamt = 150 / f * vf
  const bands = []
  for (const n of [1, 2, 3, 5, 7]) {
    const fCheck = f * n
    for (const [b, lo, hi] of allBands) {
      if (fCheck >= lo && fCheck <= hi && !bands.includes(b)) bands.push(b)
    }
  }
  bands.sort((a, b) => bandOrder.indexOf(a) - bandOrder.indexOf(b))
  return {
    f, vf, gesamt,
    lang: gesamt * 0.64,
    kurz: gesamt * 0.36,
    baender: bands,
  }
})

// SVG Skizze
const SVG_W = 600, SVG_H = 150
const margin = 30
const cy = SVG_H / 2
const availW = SVG_W - 2 * margin
const feedX = margin + availW * 0.36
const leftX = margin
const rightX = SVG_W - margin
</script>

<template>
  <div class="calc-title">Windom (OCFD)</div>

  <div class="card">
    <h2>Eingabe</h2>
    <div class="band-grid" style="grid-template-columns:repeat(5,1fr);margin-bottom:10px">
      <button v-for="[name, f] in wdBands" :key="name"
              class="bb" :class="{ on: Math.abs(pf(wd.freq) - f) < 0.5 }"
              @click="wd.freq = String(f)">{{ name }}</button>
    </div>
    <div class="inp-grid">
      <div class="inp-g"><label>Frequenz (Grundwelle)</label><div class="inp-row"><input type="text" v-model="wd.freq"><span>MHz</span></div></div>
      <div class="inp-g"><label>Verkürzungsfaktor VF</label><div class="inp-row"><input type="text" v-model="wd.vf"></div></div>
    </div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Maße</h2>
      <div class="rr hi"><span class="lbl">Gesamtlänge (λ/2)</span><span class="val">{{ fmt(result.gesamt) }} m</span></div>
      <div class="rr"><span class="lbl">Langer Schenkel (64%)</span><span class="val">{{ fmt(result.lang) }} m</span></div>
      <div class="rr"><span class="lbl">Kurzer Schenkel (36%)</span><span class="val">{{ fmt(result.kurz) }} m</span></div>
      <div class="rr"><span class="lbl">Speisepunkt-Impedanz</span><span class="val">≈ 200–300 Ω</span></div>
      <div class="rr"><span class="lbl">Balun</span><span class="val">4:1 Current Balun (empfohlen) oder 6:1</span></div>
      <div class="rr"><span class="lbl">Frequenz (Grundwelle)</span><span class="val">{{ fmt(result.f) }} MHz</span></div>
    </div>

    <div class="card">
      <h2>Skizze</h2>
      <div class="skz-bg">
        <svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet">
          <!-- Kurzer Schenkel links 36% -->
          <line :x1="leftX" :y1="cy" :x2="feedX" :y2="cy" stroke="#60a5fa" stroke-width="4" stroke-linecap="round"/>
          <!-- Langer Schenkel rechts 64% -->
          <line :x1="feedX" :y1="cy" :x2="rightX" :y2="cy" stroke="#60a5fa" stroke-width="4" stroke-linecap="round"/>

          <!-- Balun-Box -->
          <rect :x="feedX - 17" :y="cy - 29" width="34" height="22" rx="4" fill="none" stroke="#fb923c" stroke-width="2"/>
          <text :x="feedX" :y="cy - 14" text-anchor="middle" font-size="10" font-weight="bold" fill="#fb923c">4:1</text>

          <!-- Koax nach unten -->
          <line :x1="feedX" :y1="cy + 5" :x2="feedX" :y2="cy + 28" stroke="var(--acc)" stroke-width="2.5"/>
          <circle :cx="feedX" :cy="cy" r="4" fill="var(--acc)"/>
          <text :x="feedX" :y="cy + 42" text-anchor="middle" font-size="10" font-weight="bold" fill="var(--acc)">50Ω</text>

          <!-- Bemaßung -->
          <text :x="(leftX + feedX) / 2" :y="cy - 38" text-anchor="middle" font-size="10" fill="var(--ts)">
            ← {{ fmt(result.kurz) }} m (36%) →
          </text>
          <text :x="(feedX + rightX) / 2" :y="cy - 38" text-anchor="middle" font-size="10" fill="var(--ts)">
            ← {{ fmt(result.lang) }} m (64%) →
          </text>
          <text :x="SVG_W / 2" :y="SVG_H - 6" text-anchor="middle" font-size="11" fill="var(--ts)">
            Gesamt: {{ fmt(result.gesamt) }} m
          </text>
        </svg>
      </div>
    </div>

    <div class="card">
      <h2>Einsetzbare Bänder</h2>
      <div v-if="result.baender.length === 0" class="small">Keine zusätzlichen Bänder ermittelt.</div>
      <div v-else class="tag-grid" style="grid-template-columns:repeat(5,1fr)">
        <div v-for="b in result.baender" :key="b" class="tag">{{ b }}</div>
      </div>
    </div>

  </template>

  <RechnerBeschreibung name="windom" />
</template>
