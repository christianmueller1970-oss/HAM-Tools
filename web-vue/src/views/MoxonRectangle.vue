<script setup>
import { reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { pf, fmt } from '../composables/useHam.js'
import BandGrid from '../components/BandGrid.vue'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'
import { openInSim } from '../composables/openInSim.js'

const router = useRouter()
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

// ─── Im Sim öffnen ───────────────────────────────────────────────────────────
// Moxon: 2 horizontale Hauptdrähte (Driver vorne, Reflektor hinten) + je 2 Tails
// die aufeinander zu zeigen. Total 6 Wires. Driver in Strahlungsrichtung (X-Achse Vorderseite).
function imSimOeffnen() {
  if (!result.value) return
  const r = result.value
  const lambda = 300 / r.f
  const h = Math.max(8, lambda / 2)
  // Driver vorne (X = +halfDepth/2), Reflektor hinten (X = -halfDepth/2)
  const depth = r.gesamttiefe   // B + C + D
  const xDriver = depth / 2
  const xReflLevel = -depth / 2
  const xDriverTailEnd = xDriver - r.B
  const xReflTailEnd = xReflLevel + r.D
  const halfA = r.A / 2
  const halfE = r.E / 2
  openInSim(router, {
    name: `Moxon ${r.A.toFixed(2)}×${depth.toFixed(2)}m @ ${r.f} MHz`,
    freq: r.f,
    ground: 'average',
    height: h,
    wires: [
      // Driver-Hauptteil entlang Y bei x=xDriver, gespeist in der Mitte
      { tag: 1, segments: 11, x1: xDriver, y1: -halfA, z1: h, x2: xDriver, y2: 0,     z2: h, radius_mm: 2.0 },
      { tag: 2, segments: 11, x1: xDriver, y1: 0,     z1: h, x2: xDriver, y2: halfA, z2: h, radius_mm: 2.0 },
      // Driver-Tails (auf jeder Seite, zeigen nach hinten Richtung Reflektor)
      { tag: 3, segments: 5,  x1: xDriver, y1: -halfA, z1: h, x2: xDriverTailEnd, y2: -halfA, z2: h, radius_mm: 2.0 },
      { tag: 4, segments: 5,  x1: xDriver, y1:  halfA, z1: h, x2: xDriverTailEnd, y2:  halfA, z2: h, radius_mm: 2.0 },
      // Reflektor-Hauptteil entlang Y bei x=xReflLevel
      { tag: 5, segments: 21, x1: xReflLevel, y1: -halfE, z1: h, x2: xReflLevel, y2: halfE, z2: h, radius_mm: 2.0 },
      // Reflektor-Tails (zeigen nach vorne Richtung Driver)
      { tag: 6, segments: 5,  x1: xReflLevel, y1: -halfE, z1: h, x2: xReflTailEnd, y2: -halfE, z2: h, radius_mm: 2.0 },
      { tag: 7, segments: 5,  x1: xReflLevel, y1:  halfE, z1: h, x2: xReflTailEnd, y2:  halfE, z2: h, radius_mm: 2.0 },
    ],
    // Speisung am Übergang Wire 1 → Wire 2 (Driver-Mitte): erstes Segment von Wire 2
    excitation: { wire_tag: 2, segment: 1 },
  })
}
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
      <div style="margin-top:12px; text-align:right">
        <button class="btn-sim" @click="imSimOeffnen">📡 Im Sim öffnen</button>
      </div>
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
