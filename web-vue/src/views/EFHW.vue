<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import BandGrid from '../components/BandGrid.vue'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const efhw = reactive({ freq: '7.1', vf: '0.96' })

const bRanges = [
  ['160m',1.8,2.0],['80m',3.5,3.8],['60m',5.35,5.37],['40m',7.0,7.2],
  ['30m',10.1,10.15],['20m',14.0,14.35],['17m',18.068,18.168],
  ['15m',21.0,21.45],['12m',24.89,24.99],['10m',28.0,29.7],
  ['6m',50.0,52.0],['2m',144.0,146.0],
]

const result = computed(() => {
  const f = pf(efhw.freq), vf = pf(efhw.vf)
  if (!f || !vf || vf > 1) return null
  const lambda = 300 / f
  const draht = 150 / f * vf
  const gegengew = lambda * 0.05 * vf
  const harmonics = []
  for (let n = 1; n <= 8; n++) {
    const h = f * n
    for (const [band, lo, hi] of bRanges) {
      if (h >= lo && h <= hi) {
        const label = n === 1 ? band : `${band} (${n}. Harm.)`
        if (!harmonics.includes(label)) harmonics.push(label)
      }
    }
  }
  return { f, vf, draht, gegengew, lambda, bauds: harmonics }
})

// SVG Skizze (Unun-Box + Draht horizontal + Gegengewicht diagonal)
const SVG_W = 600, SVG_H = 180
const cy = SVG_H / 2
const boxX = 40, boxW = 56, boxH = 32
const wireStart = boxX + boxW
const wireEnd = SVG_W - 24
</script>

<template>
  <div class="calc-title">EFHW-Antenne</div>

  <BandGrid v-model:freq="efhw.freq" />

  <div class="card">
    <h2>Parameter</h2>
    <div class="inp-grid">
      <div class="inp-g"><label>Frequenz</label><div class="inp-row"><input type="text" v-model="efhw.freq"><span>MHz</span></div></div>
      <div class="inp-g"><label>Verkürzungsfaktor VF</label><div class="inp-row"><input type="text" v-model="efhw.vf"><span>0.90–1.00</span></div></div>
    </div>
    <div v-if="result" class="small mt8">
      λ = {{ fmt(result.lambda) }} m  ·  λ/2 = {{ fmt(150 / result.f) }} m (ohne VF)
    </div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Maße</h2>
      <div class="rr hi"><span class="lbl">Drahtlänge (λ/2)</span><span class="val">{{ fmt(result.draht) }} m</span></div>
      <div class="rr"><span class="lbl">Gegengewicht (≈5% λ)</span><span class="val">{{ fmt(result.gegengew) }} m</span></div>
      <div class="rr"><span class="lbl">Eingangsimpedanz</span><span class="val">≈ 2450 Ω</span></div>
      <div class="rr"><span class="lbl">Anpass-Transformator</span><span class="val">49:1 Unun</span></div>
      <hr class="div">
      <div class="rr"><span class="lbl">Wellenlänge λ</span><span class="val">{{ fmt(result.lambda) }} m</span></div>
      <div class="rr"><span class="lbl">Frequenz</span><span class="val">{{ result.f.toFixed(4) }} MHz</span></div>
      <div class="rr"><span class="lbl">Verkürzungsfaktor</span><span class="val">{{ result.vf.toFixed(3) }}</span></div>
    </div>

    <div class="card">
      <h2>Aufbau-Skizze</h2>
      <div class="skz-bg">
        <svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet">
          <!-- Bemaßung oben -->
          <line :x1="wireStart" :y1="cy - 28" :x2="wireEnd" :y2="cy - 28"
                stroke="rgba(140,140,140,0.5)" stroke-width="1"/>
          <line :x1="wireStart" :y1="cy - 32" :x2="wireStart" :y2="cy - 24"
                stroke="rgba(140,140,140,0.5)" stroke-width="1"/>
          <line :x1="wireEnd" :y1="cy - 32" :x2="wireEnd" :y2="cy - 24"
                stroke="rgba(140,140,140,0.5)" stroke-width="1"/>
          <text :x="(wireStart + wireEnd) / 2" :y="cy - 36" text-anchor="middle" font-size="11" fill="var(--ts)">
            λ/2 = {{ fmt(result.draht) }} m
          </text>

          <!-- 49:1 Unun-Box -->
          <rect :x="boxX" :y="cy - boxH/2" :width="boxW" :height="boxH" rx="6"
                fill="none" stroke="#fb923c" stroke-width="2"/>
          <text :x="boxX + boxW/2" :y="cy - 3" text-anchor="middle" font-size="12" font-weight="bold" fill="#fb923c">49:1</text>
          <text :x="boxX + boxW/2" :y="cy + 11" text-anchor="middle" font-size="10" fill="#fb923c" opacity="0.8">Unun</text>

          <!-- Draht -->
          <line :x1="wireStart" :y1="cy" :x2="wireEnd" :y2="cy"
                stroke="#60a5fa" stroke-width="4" stroke-linecap="round"/>

          <!-- Speisepunkt -->
          <circle :cx="boxX" :cy="cy" r="6" fill="var(--acc)"/>
          <text :x="boxX - 10" :y="cy + 3" text-anchor="end" font-size="10" font-weight="bold" fill="var(--acc)">50Ω</text>

          <!-- Gegengewicht nach unten-links -->
          <line :x1="boxX" :y1="cy" :x2="boxX - 36" :y2="cy + 40"
                stroke="rgba(150,150,150,0.7)" stroke-width="2"/>
          <text :x="boxX - 42" :y="cy + 44" text-anchor="end" font-size="10" fill="var(--ts)">
            GGW {{ fmt(result.gegengew, 2) }} m
          </text>

          <!-- Trafo-Hinweis unten -->
          <text :x="boxX + boxW/2" :y="cy + boxH/2 + 18" text-anchor="middle" font-size="10" fill="#fb923c" opacity="0.7">
            FT240-43 · 2:14 Wdg.
          </text>
        </svg>
      </div>
    </div>

    <div v-if="result.bauds.length > 0" class="card">
      <h2>Multiband-Nutzung (Harmonische)</h2>
      <div class="small" style="margin-bottom:6px">Diese Drahtlänge ist resonant auf folgenden Bändern:</div>
      <div class="tag-grid">
        <div v-for="b in result.bauds" :key="b" class="tag">{{ b }}</div>
      </div>
    </div>

  </template>

  <RechnerBeschreibung name="efhw" />
</template>

<style scoped>
.info-row {
  display: flex;
  gap: 10px;
  align-items: flex-start;
  padding: 6px 0;
  font-size: 12px;
  color: var(--ts);
  line-height: 1.5;
}
.bullet {
  flex-shrink: 0;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 10px;
  font-weight: bold;
}
</style>
