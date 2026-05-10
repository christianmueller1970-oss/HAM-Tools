<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import BandGrid from '../components/BandGrid.vue'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const mox = reactive({ freq: '14.175', vf: '0.95' })

const result = computed(() => {
  const f = pf(mox.freq), vf = pf(mox.vf)
  if (!f || !vf) return null
  const lam = 300 / f * vf
  const A = lam * 0.4750
  const B = lam * 0.0500
  const C = lam * 0.0156
  const D = lam * 0.0624
  const E = lam * 0.4750
  return {
    f, vf, A, B, C, D, E,
    gesamttiefe: B + C + D,
    drahtTreiber: A + 2 * B,
    drahtReflektor: E + 2 * D,
  }
})

// SVG (Draufsicht)
const SVG_W = 600, SVG_H = 280
const margin = 44
const labelH = 40

const svgGeom = computed(() => {
  if (!result.value) return null
  const r = result.value
  const availW = SVG_W - 2 * margin
  const availH = SVG_H - 2 * margin - labelH
  const scale = Math.min(availW / r.A, availH / r.gesamttiefe) * 0.9
  const bPx = r.A * scale
  const bRueT = r.B * scale
  const gapPx = r.C * scale
  const dRueR = r.D * scale
  const cx = SVG_W / 2
  const topY = margin + (availH - r.gesamttiefe * scale) / 2
  return {
    cx,
    tLeft: cx - bPx / 2,
    tRight: cx + bPx / 2,
    tY: topY,
    bY: topY + bRueT + gapPx + dRueR,
    bRueT, gapPx, dRueR,
  }
})
</script>

<template>
  <div class="calc-title">Moxon Rectangle</div>

  <BandGrid v-model:freq="mox.freq" />

  <div class="card">
    <h2>Eingabe</h2>
    <div class="inp-grid">
      <div class="inp-g"><label>Frequenz</label><div class="inp-row"><input type="text" v-model="mox.freq"><span>MHz</span></div></div>
      <div class="inp-g"><label>Verkürzungsfaktor VF</label><div class="inp-row"><input type="text" v-model="mox.vf"></div></div>
    </div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Maße</h2>
      <div class="rr hi"><span class="lbl">A – Treiber horizontal</span><span class="val">{{ fmt(result.A) }} m</span></div>
      <div class="rr"><span class="lbl">B – Treiber Rücklauf (je)</span><span class="val">{{ fmt(result.B) }} m</span></div>
      <div class="rr"><span class="lbl">C – Lücke</span><span class="val">{{ fmt(result.C) }} m</span></div>
      <div class="rr"><span class="lbl">D – Reflektor Rücklauf (je)</span><span class="val">{{ fmt(result.D) }} m</span></div>
      <div class="rr"><span class="lbl">E – Reflektor horizontal</span><span class="val">{{ fmt(result.E) }} m</span></div>
      <hr class="div">
      <div class="rr"><span class="lbl">Gesamttiefe (B+C+D)</span><span class="val">{{ fmt(result.gesamttiefe) }} m</span></div>
      <div class="rr"><span class="lbl">Breite (= A = E)</span><span class="val">{{ fmt(result.A) }} m</span></div>
      <div class="rr"><span class="lbl">Drahtlänge Treiber</span><span class="val">{{ fmt(result.drahtTreiber) }} m</span></div>
      <div class="rr"><span class="lbl">Drahtlänge Reflektor</span><span class="val">{{ fmt(result.drahtReflektor) }} m</span></div>
      <div class="rr"><span class="lbl">Speisepunkt-Impedanz</span><span class="val">≈ 50 Ω</span></div>
    </div>

    <div class="card">
      <h2>Skizze (Draufsicht)</h2>
      <div class="skz-bg">
        <svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet" v-if="svgGeom">
          <!-- Treiber (blau): obere horizontale + zwei vertikale Rückläufe -->
          <polyline :points="`${svgGeom.tLeft},${svgGeom.tY + svgGeom.bRueT} ${svgGeom.tLeft},${svgGeom.tY} ${svgGeom.tRight},${svgGeom.tY} ${svgGeom.tRight},${svgGeom.tY + svgGeom.bRueT}`"
                    fill="none" stroke="#60a5fa" stroke-width="2.5" stroke-linejoin="round"/>

          <!-- Reflektor (grau): untere horizontale + Rückläufe -->
          <polyline :points="`${svgGeom.tLeft},${svgGeom.bY - svgGeom.dRueR} ${svgGeom.tLeft},${svgGeom.bY} ${svgGeom.tRight},${svgGeom.bY} ${svgGeom.tRight},${svgGeom.bY - svgGeom.dRueR}`"
                    fill="none" stroke="rgba(140,140,140,0.85)" stroke-width="2.5" stroke-linejoin="round"/>

          <!-- Lücke (gestrichelte Hilfslinien) -->
          <line :x1="svgGeom.tLeft" :y1="svgGeom.tY + svgGeom.bRueT"
                :x2="svgGeom.tLeft" :y2="svgGeom.tY + svgGeom.bRueT + svgGeom.gapPx"
                stroke="rgba(140,140,140,0.4)" stroke-width="1.5" stroke-dasharray="4,3"/>
          <line :x1="svgGeom.tRight" :y1="svgGeom.tY + svgGeom.bRueT"
                :x2="svgGeom.tRight" :y2="svgGeom.tY + svgGeom.bRueT + svgGeom.gapPx"
                stroke="rgba(140,140,140,0.4)" stroke-width="1.5" stroke-dasharray="4,3"/>

          <!-- Speisepunkt -->
          <circle :cx="svgGeom.cx" :cy="svgGeom.tY" r="5" fill="var(--acc)"/>
          <text :x="svgGeom.cx" :y="svgGeom.tY - 12" text-anchor="middle" font-size="10" font-weight="bold" fill="var(--acc)">50Ω</text>

          <!-- Bemaßungs-Labels -->
          <text :x="svgGeom.cx" :y="svgGeom.tY - 28" text-anchor="middle" font-size="10" fill="var(--ts)">
            A = {{ fmt(result.A) }} m
          </text>
          <text :x="SVG_W / 2" :y="SVG_H - 8" text-anchor="middle" font-size="10" fill="var(--ts)">
            B={{ fmt(result.B) }}  C={{ fmt(result.C) }}  D={{ fmt(result.D) }}
          </text>

          <!-- Richtungsanzeige -->
          <text :x="SVG_W - margin + 4" :y="svgGeom.tY + (svgGeom.bY - svgGeom.tY) / 2"
                text-anchor="start" font-size="9" fill="rgba(96,165,250,0.7)">▶ Hauptrichtung</text>
        </svg>
      </div>
    </div>

  </template>

  <RechnerBeschreibung name="moxon" />
</template>
