<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import BandGrid from '../components/BandGrid.vue'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const spt = reactive({ freq: '14.175', coaxVF: 0.82 })

const result = computed(() => {
  const f = pf(spt.freq)
  if (!f) return null
  return {
    f, coaxVF: spt.coaxVF,
    strahler: 75 / f * 0.95,
    huelle: 75 / f * spt.coaxVF,
  }
})

// SVG: Skizze (Sperrtopf, Innenleiter + Koaxhülle)
const SVG_W = 240, SVG_H = 280
const cx = SVG_W / 2
const topY = 16, botY = SVG_H - 28
const innerH = botY - topY
const sleeveH = computed(() => innerH * (spt.coaxVF / 0.95))
const sleeveTop = computed(() => botY - sleeveH.value)
</script>

<template>
  <div class="calc-title">Sperrtopf</div>

  <BandGrid v-model:freq="spt.freq" />

  <div class="card">
    <h2>Eingabe</h2>
    <div class="inp-grid">
      <div class="inp-g">
        <label>Frequenz</label>
        <div class="inp-row"><input type="text" v-model="spt.freq"><span>MHz</span></div>
      </div>
      <div class="inp-g">
        <label>Koax-Verkürzungsfaktor (Hülle)</label>
        <div class="seg">
          <button class="sb" :class="{ on: spt.coaxVF === 0.66 }" @click="spt.coaxVF = 0.66">0.66 (Schaum)</button>
          <button class="sb" :class="{ on: spt.coaxVF === 0.82 }" @click="spt.coaxVF = 0.82">0.82 (PVC)</button>
          <button class="sb" :class="{ on: spt.coaxVF === 0.85 }" @click="spt.coaxVF = 0.85">0.85 (PE)</button>
        </div>
      </div>
    </div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Maße</h2>
      <div class="rr hi"><span class="lbl">Strahler / Innenleiter (λ/4)</span><span class="val">{{ fmt(result.strahler) }} m</span></div>
      <div class="rr"><span class="lbl">Koax-Hülle (λ/4 × VF)</span><span class="val">{{ fmt(result.huelle) }} m</span></div>
      <div class="rr"><span class="lbl">Koax-Verkürzungsfaktor</span><span class="val">{{ result.coaxVF.toFixed(2) }}</span></div>
      <div class="rr"><span class="lbl">Speisepunkt-Impedanz</span><span class="val">≈ 50 Ω (kein Gegengewicht nötig)</span></div>
      <div class="rr"><span class="lbl">Frequenz</span><span class="val">{{ fmt(result.f) }} MHz</span></div>
    </div>

    <div class="card">
      <h2>Skizze</h2>
      <div class="skz-bg" style="display:flex;justify-content:center">
        <svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet" style="max-height:280px">
          <!-- Innenleiter (Strahler) -->
          <line :x1="cx" :y1="botY" :x2="cx" :y2="topY"
                stroke="#60a5fa" stroke-width="4" stroke-linecap="round"/>
          <!-- Koax-Hülle links und rechts -->
          <line :x1="cx - 12" :y1="botY" :x2="cx - 12" :y2="sleeveTop"
                stroke="rgba(140,140,140,0.7)" stroke-width="2.5"/>
          <line :x1="cx + 12" :y1="botY" :x2="cx + 12" :y2="sleeveTop"
                stroke="rgba(140,140,140,0.7)" stroke-width="2.5"/>
          <!-- Hülle oben und unten -->
          <line :x1="cx - 12" :y1="sleeveTop" :x2="cx + 12" :y2="sleeveTop"
                stroke="rgba(140,140,140,0.7)" stroke-width="2"/>
          <line :x1="cx - 12" :y1="botY" :x2="cx + 12" :y2="botY"
                stroke="rgba(140,140,140,0.7)" stroke-width="2"/>
          <!-- Speisepunkt -->
          <circle :cx="cx" :cy="botY" r="5" fill="var(--acc)"/>
          <text :x="cx" :y="botY + 22" text-anchor="middle" font-size="11" font-weight="bold" fill="var(--acc)">50Ω</text>
          <!-- Labels -->
          <text :x="cx + 18" :y="(topY + botY) / 2" text-anchor="start" font-size="11" fill="var(--ts)">
            λ/4 = {{ fmt(result.strahler) }} m
          </text>
          <text :x="cx - 18" :y="(sleeveTop + botY) / 2" text-anchor="end" font-size="10" fill="var(--ts)">
            Hülle {{ fmt(result.huelle) }} m
          </text>
        </svg>
      </div>
    </div>

  </template>

  <RechnerBeschreibung name="sperrtopf" />
</template>
