<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import BandGrid from '../components/BandGrid.vue'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const dip = reactive({ freq: '14.175', vf: '0.95', typ: 'klassisch' })

const result = computed(() => {
  const f = pf(dip.freq), vf = pf(dip.vf)
  if (!f || !vf || vf > 1) return null
  const g = 150 / f * vf
  return {
    f, vf, gesamt: g, arm: g / 2, lambda: 300 / f,
    imp: dip.typ === 'klassisch' ? '≈ 50–75 Ω' : '≈ 240–300 Ω (4:1 Balun → 50 Ω)',
  }
})

// SVG: Skizze (Dipol horizontal)
const SVG_W = 600, SVG_H = 130
const margin = 40
const cx = SVG_W / 2
const cy = SVG_H / 2
const armLen = (SVG_W - 2 * margin) / 2
</script>

<template>
  <div class="calc-title">Dipol</div>

  <div class="card">
    <h2>Dipol-Variante</h2>
    <div class="opt-grid">
      <button class="opt-btn" :class="{ active: dip.typ === 'klassisch' }" @click="dip.typ = 'klassisch'">
        <div class="opt-label">λ/2 Dipol (klassisch)</div>
        <div class="opt-sub">1 Draht, 50–75 Ω, 1:1 Balun</div>
      </button>
      <button class="opt-btn" :class="{ active: dip.typ === 'falter' }" @click="dip.typ = 'falter'">
        <div class="opt-label">Faltdipol (λ/2)</div>
        <div class="opt-sub">2 parallele Drähte, ~300 Ω, 4:1 Balun</div>
      </button>
    </div>
  </div>

  <BandGrid v-model:freq="dip.freq" />

  <div class="card">
    <h2>Eingabe</h2>
    <div class="inp-grid">
      <div class="inp-g"><label>Frequenz</label><div class="inp-row"><input type="text" v-model="dip.freq"><span>MHz</span></div></div>
      <div class="inp-g"><label>Verkürzungsfaktor VF</label><div class="inp-row"><input type="text" v-model="dip.vf"><span>0.90–1.00</span></div></div>
    </div>
    <div v-if="result" class="small mt8">
      λ = {{ fmt(result.lambda) }} m  ·  λ/2 = {{ fmt(150 / result.f) }} m (ohne VF)
    </div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Maße</h2>
      <div class="rr hi"><span class="lbl">Gesamtlänge (λ/2)</span><span class="val">{{ fmt(result.gesamt) }} m</span></div>
      <div class="rr"><span class="lbl">Arm-Länge (λ/4, je Seite)</span><span class="val">{{ fmt(result.arm) }} m</span></div>
      <div class="rr"><span class="lbl">Speisepunkt-Impedanz</span><span class="val">{{ result.imp }}</span></div>
      <div class="rr"><span class="lbl">Frequenz</span><span class="val">{{ fmt(result.f) }} MHz</span></div>
      <div class="rr"><span class="lbl">Verkürzungsfaktor</span><span class="val">{{ fmt(result.vf) }}</span></div>
    </div>

    <div class="card">
      <h2>Skizze</h2>
      <div class="skz-bg">
        <svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet">
          <!-- Bemaßungslinie oben -->
          <line :x1="cx - armLen" :y1="cy - 36" :x2="cx + armLen" :y2="cy - 36"
                stroke="rgba(140,140,140,0.5)" stroke-width="1"/>
          <line :x1="cx - armLen" :y1="cy - 40" :x2="cx - armLen" :y2="cy - 32"
                stroke="rgba(140,140,140,0.5)" stroke-width="1"/>
          <line :x1="cx + armLen" :y1="cy - 40" :x2="cx + armLen" :y2="cy - 32"
                stroke="rgba(140,140,140,0.5)" stroke-width="1"/>
          <text :x="cx" :y="cy - 44" text-anchor="middle" font-size="11" fill="var(--ts)">
            {{ fmt(result.gesamt) }} m
          </text>

          <!-- Dipol-Hauptarm -->
          <line :x1="cx - armLen" :y1="cy" :x2="cx + armLen" :y2="cy"
                stroke="var(--acc)" :stroke-width="dip.typ === 'falter' ? 2 : 4" stroke-linecap="round"/>

          <!-- Faltdipol: paralleler Draht + Verbindungen -->
          <template v-if="dip.typ === 'falter'">
            <line :x1="cx - armLen" :y1="cy - 14" :x2="cx + armLen" :y2="cy - 14"
                  stroke="var(--acc)" stroke-width="2" stroke-linecap="round"/>
            <line :x1="cx - armLen" :y1="cy - 14" :x2="cx - armLen" :y2="cy"
                  stroke="var(--acc)" stroke-width="2"/>
            <line :x1="cx + armLen" :y1="cy - 14" :x2="cx + armLen" :y2="cy"
                  stroke="var(--acc)" stroke-width="2"/>
          </template>

          <!-- Speisepunkt -->
          <circle :cx="cx" :cy="cy" r="5" fill="var(--acc)"/>
          <text :x="cx" :y="cy + 22" text-anchor="middle" font-size="11" font-weight="bold" fill="var(--acc)">50Ω</text>

          <!-- Arm-Beschriftung unten -->
          <text :x="cx - armLen / 2" :y="cy + 38" text-anchor="middle" font-size="10" fill="var(--ts)">
            ← {{ fmt(result.arm) }} m →
          </text>
          <text :x="cx + armLen / 2" :y="cy + 38" text-anchor="middle" font-size="10" fill="var(--ts)">
            ← {{ fmt(result.arm) }} m →
          </text>
        </svg>
      </div>
    </div>

  </template>

  <RechnerBeschreibung name="dipol" />
</template>
