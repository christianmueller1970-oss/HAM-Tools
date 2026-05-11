<script setup>
import { reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { pf, fmt } from '../composables/useHam.js'
import BandGrid from '../components/BandGrid.vue'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'
import { openInSim } from '../composables/openInSim.js'

const router = useRouter()
const ml = reactive({ freq: '14.2', d: '1.0', wire_mm: '22.0', power: '10', shape: 'kreis' })

const result = computed(() => {
  const f = pf(ml.freq), d = pf(ml.d), wire = pf(ml.wire_mm), p = pf(ml.power)
  if (!f || !d || !wire || !p) return null
  const mu0 = 4 * Math.PI * 1e-7
  const rho_cu = 1.72e-8
  const f_hz = f * 1e6
  const r = d / 2
  const a = wire / 2 / 1000
  let L_h, perim
  switch (ml.shape) {
    case 'kreis':
      L_h = mu0 * r * (Math.log(8 * r / a) - 2)
      perim = 2 * Math.PI * r
      break
    case 'achteck':
      perim = 8 * d * Math.tan(Math.PI / 8)
      L_h = mu0 * perim / (2 * Math.PI) * (Math.log(perim / (Math.PI * a)) - 0.2235 * 7 + 0.726)
      break
    case 'quadrat':
      perim = 4 * d
      L_h = mu0 * perim / (2 * Math.PI) * (Math.log(perim / (Math.PI * a)) - 0.2235 * 3 + 0.726)
      break
  }
  if (L_h <= 0) return null
  const L_uH = L_h * 1e6
  const XL = 2 * Math.PI * f_hz * L_h
  const C_f = 1 / ((2 * Math.PI * f_hz) ** 2 * L_h)
  const C_pF = C_f * 1e12
  const V_rms = Math.sqrt(p * XL)
  const lambda = 300 / f
  const R_rad = 31200 * Math.pow(perim / lambda, 4)
  const Rs = Math.sqrt(Math.PI * f_hz * mu0 * rho_cu)
  const R_loss = Rs * perim / (2 * Math.PI * a)
  const R_total = R_rad + R_loss
  const Q = XL / R_total
  const BW_hz = f_hz / Q
  const eta = R_rad / R_total * 100
  let bewertung = 'ok', warnFarbe = '#22c55e'
  if (V_rms > 2000) { bewertung = 'gefahr'; warnFarbe = '#ef4444' }
  else if (V_rms > 1000) { bewertung = 'warnung'; warnFarbe = '#fb923c' }
  return {
    f, d, wire_mm: wire, power: p,
    L_uH, XL, C_pF, V_rms,
    R_rad, R_loss, R_total, Q, BW_hz, eta,
    couplingD: d / 5,
    bewertung, warnFarbe,
  }
})

function voltString(v) {
  return v >= 1000 ? (v / 1000).toFixed(1) + ' kV' : v.toFixed(0) + ' V'
}

// ─── Im Sim öffnen ───────────────────────────────────────────────────────────
// Magnetic Loop: geschlossene Stromschleife mit Vakuum-Kondensator zur Abstimmung.
// NEC2 modelliert keinen konzentrierten Kondensator direkt — wir exportieren die
// Loop-Geometrie OHNE Kondensator. Im NEC2-Sim ist die Loop dann nicht resonant
// (wäre als reine Drahtschleife ein Full-Wave-Loop), die Strahlungsverteilung
// (Doughnut-Pattern) bleibt aber sichtbar. Echter Magloop-Sim braucht eine
// LD-Karte (Loading mit Kapazität) — kommt in einer späteren AntennenSim-Phase.
function imSimOeffnen() {
  if (!result.value) return
  const r = result.value
  const lambda = 300 / r.f
  const h = Math.max(2, lambda * 0.1)
  const radius_mm = r.wire_mm / 2
  const D = r.d                 // Loop-Durchmesser
  const radius = D / 2
  const wires = []
  if (ml.shape === 'kreis') {
    // Kreis-Loop als 12-Eck approximieren, in Y-Z-Ebene (Antenne broadside auf X)
    const N = 12
    for (let i = 0; i < N; i++) {
      const a1 = (i / N) * 2 * Math.PI
      const a2 = ((i + 1) / N) * 2 * Math.PI
      wires.push({
        tag: i + 1, segments: 5,
        x1: 0, y1: radius * Math.cos(a1), z1: h + radius * Math.sin(a1),
        x2: 0, y2: radius * Math.cos(a2), z2: h + radius * Math.sin(a2),
        radius_mm,
      })
    }
  } else if (ml.shape === 'quadrat') {
    const corners = [
      { y:  radius, z: h - radius }, { y:  radius, z: h + radius },
      { y: -radius, z: h + radius }, { y: -radius, z: h - radius },
    ]
    for (let i = 0; i < 4; i++) {
      const a = corners[i], b = corners[(i + 1) % 4]
      wires.push({
        tag: i + 1, segments: 7,
        x1: 0, y1: a.y, z1: a.z, x2: 0, y2: b.y, z2: b.z, radius_mm,
      })
    }
  } else {
    // Achteck
    const N = 8
    const rPoly = radius
    for (let i = 0; i < N; i++) {
      const a1 = (i / N) * 2 * Math.PI + Math.PI / N
      const a2 = ((i + 1) / N) * 2 * Math.PI + Math.PI / N
      wires.push({
        tag: i + 1, segments: 5,
        x1: 0, y1: rPoly * Math.cos(a1), z1: h + rPoly * Math.sin(a1),
        x2: 0, y2: rPoly * Math.cos(a2), z2: h + rPoly * Math.sin(a2),
        radius_mm,
      })
    }
  }
  openInSim(router, {
    name: `Magnetic Loop ${D.toFixed(2)}m (${ml.shape}, ohne C) @ ${r.f} MHz`,
    freq: r.f,
    ground: 'average',
    height: h,
    wires,
    // Speisung am ersten Wire-Segment (Loop-Spitze)
    excitation: { wire_tag: 1, segment: 3 },
  })
}
function bwString(hz) {
  return hz >= 1000 ? (hz / 1000).toFixed(1) + ' kHz' : hz.toFixed(0) + ' Hz'
}

// SVG Skizze
const SVG_W = 360, SVG_H = 320

const sketchGeom = computed(() => {
  if (!result.value) return null
  const cx = SVG_W / 2, cy = SVG_H / 2 - 10
  const rad = Math.min(SVG_W, SVG_H) * 0.32
  const coupRad = rad / 5
  const capY = cy - rad
  const coupCy = cy + rad - coupRad - 8
  // Polygon points für Achteck/Quadrat
  let polyPts = null
  if (ml.shape === 'achteck' || ml.shape === 'quadrat') {
    const sides = ml.shape === 'achteck' ? 8 : 4
    const pts = []
    for (let i = 0; i < sides; i++) {
      const ang = -Math.PI / 2 + (i + 0.5) * (2 * Math.PI / sides)
      pts.push(`${cx + rad * Math.cos(ang)},${cy + rad * Math.sin(ang)}`)
    }
    polyPts = pts.join(' ')
  }
  return { cx, cy, rad, coupRad, capY, coupCy, polyPts }
})
</script>

<template>
  <div class="calc-title">Magnetic Loop</div>

  <BandGrid v-model:freq="ml.freq" />

  <div class="card">
    <h2>Parameter</h2>
    <div class="inp-grid">
      <div class="inp-g"><label>Frequenz</label><div class="inp-row"><input type="text" v-model="ml.freq"><span>MHz</span></div></div>
      <div class="inp-g"><label>Loop-Durchmesser</label><div class="inp-row"><input type="text" v-model="ml.d"><span>m</span></div></div>
    </div>
    <div class="inp-grid" style="margin-top:10px">
      <div class="inp-g"><label>Leiter-Ø (Rohr/Draht)</label><div class="inp-row"><input type="text" v-model="ml.wire_mm"><span>mm</span></div></div>
      <div class="inp-g"><label>Sendeleistung</label><div class="inp-row"><input type="text" v-model="ml.power"><span>W</span></div></div>
    </div>
    <div class="inp-g" style="margin-top:10px">
      <label>Loop-Form</label>
      <div class="seg">
        <button class="sb" :class="{ on: ml.shape === 'kreis' }" @click="ml.shape = 'kreis'">Kreis</button>
        <button class="sb" :class="{ on: ml.shape === 'achteck' }" @click="ml.shape = 'achteck'">Achteck</button>
        <button class="sb" :class="{ on: ml.shape === 'quadrat' }" @click="ml.shape = 'quadrat'">Quadrat</button>
      </div>
    </div>
  </div>

  <template v-if="result">
    <div v-if="result.bewertung !== 'ok'" class="card warn-box"
         :style="{ background: result.warnFarbe + '14', borderLeft: '4px solid ' + result.warnFarbe }">
      <div style="display:flex;gap:12px;align-items:flex-start">
        <span :style="{ color: result.warnFarbe, fontSize: '20px' }">{{ result.bewertung === 'gefahr' ? '⚠' : '!' }}</span>
        <div>
          <div :style="{ color: result.warnFarbe, fontWeight: 600 }">
            {{ result.bewertung === 'gefahr' ? 'Hohe Kondensatorspannung – Lebensgefahr!' : 'Kondensatorspannung erhöht' }}
          </div>
          <div class="small" style="margin-top:4px">
            <template v-if="result.bewertung === 'gefahr'">
              Spannung von {{ result.V_rms.toFixed(0) }} V RMS! Hochspannungs-Luftdrehkondensator oder Vakuumkondensator erforderlich. Niemals während Betrieb berühren.
            </template>
            <template v-else>
              Spannung von {{ result.V_rms.toFixed(0) }} V RMS am Drehko. Spezial-Kondensator mit ausreichend Spannungsfestigkeit nötig.
            </template>
          </div>
        </div>
      </div>
    </div>

    <div class="card">
      <h2>Kenngrößen</h2>
      <div class="ken-grid">
        <div class="ken hi"><div class="ken-val">{{ fmt(result.L_uH, 2) }} µH</div><div class="ken-lbl">Induktivität</div></div>
        <div class="ken"><div class="ken-val">{{ fmt(result.C_pF, 1) }} pF</div><div class="ken-lbl">Resonanzkapazität</div></div>
        <div class="ken" :class="{ hi: result.V_rms > 1000 }" :style="result.V_rms > 1000 ? { borderColor: result.warnFarbe } : {}">
          <div class="ken-val" :style="result.V_rms > 1000 ? { color: result.warnFarbe } : {}">{{ voltString(result.V_rms) }}</div>
          <div class="ken-lbl">Spannung Drehko</div>
        </div>
        <div class="ken"><div class="ken-val">{{ result.Q.toFixed(0) }}</div><div class="ken-lbl">Güte Q</div></div>
        <div class="ken"><div class="ken-val">{{ bwString(result.BW_hz) }}</div><div class="ken-lbl">Bandbreite BW</div></div>
        <div class="ken"><div class="ken-val">{{ fmt(result.eta, 1) }} %</div><div class="ken-lbl">Wirkungsgrad η</div></div>
      </div>
      <div style="margin-top:12px; text-align:right">
        <button class="btn-sim" @click="imSimOeffnen"
                title="Exportiert nur die Loop-Geometrie. NEC2 modelliert den Abstimmkondensator nicht — Sim ist nicht resonant, aber Strahlungspattern wird sichtbar">
          📡 Im Sim öffnen (ohne C)
        </button>
      </div>
    </div>

    <div class="card">
      <h2>Skizze</h2>
      <div class="skz-bg" style="display:flex;justify-content:center">
        <svg v-if="sketchGeom" :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet" style="max-height:320px">
          <!-- Hauptschleife -->
          <circle v-if="ml.shape === 'kreis'" :cx="sketchGeom.cx" :cy="sketchGeom.cy" :r="sketchGeom.rad"
                  fill="none" stroke="#60a5fa" stroke-width="4"/>
          <polygon v-else-if="sketchGeom.polyPts" :points="sketchGeom.polyPts"
                   fill="none" stroke="#60a5fa" stroke-width="4"/>

          <!-- Kondensator oben (zwei parallele Platten) -->
          <line :x1="sketchGeom.cx - 12" :y1="sketchGeom.capY" :x2="sketchGeom.cx + 12" :y2="sketchGeom.capY"
                stroke="#fb923c" stroke-width="3"/>
          <line :x1="sketchGeom.cx - 12" :y1="sketchGeom.capY - 6" :x2="sketchGeom.cx + 12" :y2="sketchGeom.capY - 6"
                stroke="#fb923c" stroke-width="3"/>

          <!-- Kopplungsschleife unten -->
          <circle :cx="sketchGeom.cx" :cy="sketchGeom.coupCy" :r="sketchGeom.coupRad"
                  fill="none" stroke="#4ade80" stroke-width="2"/>

          <!-- Beschriftungen -->
          <text :x="sketchGeom.cx" :y="sketchGeom.capY - 14" text-anchor="middle" font-size="10" fill="#fb923c">Drehko</text>
          <text :x="sketchGeom.cx + sketchGeom.rad + 4" :y="sketchGeom.capY + 4"
                text-anchor="start" font-size="11" font-weight="bold" :fill="result.warnFarbe">
            {{ result.V_rms.toFixed(0) }} V
          </text>
          <text :x="sketchGeom.cx" :y="sketchGeom.coupCy + sketchGeom.coupRad + 14"
                text-anchor="middle" font-size="10" fill="#4ade80">
            Ø {{ (result.couplingD * 100).toFixed(0) }} cm
          </text>
          <text :x="sketchGeom.cx" :y="sketchGeom.coupCy + sketchGeom.coupRad + 26"
                text-anchor="middle" font-size="10" fill="#4ade80">Kopplung</text>
          <text :x="sketchGeom.cx" :y="sketchGeom.cy + sketchGeom.rad + 16"
                text-anchor="middle" font-size="11" fill="var(--ts)">
            Ø {{ result.d.toFixed(2) }} m
          </text>
        </svg>
      </div>
    </div>

    <div class="card">
      <h2>Technische Details</h2>
      <div class="rr"><span class="lbl">Induktivität L</span><span class="val">{{ fmt(result.L_uH, 3) }} µH</span></div>
      <div class="rr"><span class="lbl">Induktiver Blindwiderstand XL</span><span class="val">{{ fmt(result.XL, 1) }} Ω</span></div>
      <div class="rr"><span class="lbl">Resonanzkapazität C</span><span class="val">{{ fmt(result.C_pF, 2) }} pF</span></div>
      <div class="rr hi"><span class="lbl">Spannung am Drehko</span><span class="val">{{ voltString(result.V_rms) }}</span></div>
      <hr class="div">
      <div class="rr"><span class="lbl">Strahlungswiderstand R_rad</span><span class="val">{{ fmt(result.R_rad, 4) }} Ω</span></div>
      <div class="rr"><span class="lbl">Verlustwiderstand R_loss</span><span class="val">{{ fmt(result.R_loss, 3) }} Ω</span></div>
      <div class="rr"><span class="lbl">Güte Q</span><span class="val">{{ result.Q.toFixed(0) }}</span></div>
      <div class="rr"><span class="lbl">Bandbreite BW</span><span class="val">{{ bwString(result.BW_hz) }}</span></div>
      <div class="rr"><span class="lbl">Wirkungsgrad η</span><span class="val">{{ fmt(result.eta, 2) }} %</span></div>
      <hr class="div">
      <div class="rr"><span class="lbl">Kopplungsschleife Ø</span><span class="val">{{ fmt(result.couplingD) }} m  ({{ (result.couplingD * 100).toFixed(0) }} cm)</span></div>
    </div>
  </template>

  <RechnerBeschreibung name="magloop" />
</template>

<style scoped>
.ken-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
.ken {
  background: var(--card2); border: 1px solid var(--sep);
  border-radius: 8px; padding: 12px 10px; text-align: center;
}
.ken.hi { border-width: 1.5px; border-color: var(--acc); }
.ken-val { font-size: 16px; font-weight: 700; color: var(--tp); font-family: 'SF Mono', 'Cascadia Mono', monospace; }
.ken.hi .ken-val { color: var(--acc); }
.ken-lbl { font-size: 10px; color: var(--ts); margin-top: 4px; text-transform: uppercase; letter-spacing: 0.5px; }
.warn-box { padding: 14px; }
@media(max-width:560px){ .ken-grid { grid-template-columns: 1fr 1fr; } }
</style>
