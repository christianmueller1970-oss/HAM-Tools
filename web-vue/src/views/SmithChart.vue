<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const sc = reactive({
  freq: '14.200',
  R: '75',
  X: '25',
  Z0: 50,
  showVSWR: true,
  showAdmittance: false,
  selectedSolution: 0,
})

const rVal = computed(() => pf(sc.R) || 0)
const xVal = computed(() => pf(sc.X) || 0)
const fVal = computed(() => pf(sc.freq) || 0)

const zN = computed(() => ({ re: rVal.value / sc.Z0, im: xVal.value / sc.Z0 }))

const gamma = computed(() => {
  const num_re = rVal.value - sc.Z0
  const num_im = xVal.value
  const den_re = rVal.value + sc.Z0
  const den_im = xVal.value
  const mag2 = den_re * den_re + den_im * den_im
  if (mag2 <= 0) return { re: 0, im: 0 }
  return {
    re: (num_re * den_re + num_im * den_im) / mag2,
    im: (num_im * den_re - num_re * den_im) / mag2,
  }
})

const gammaMag = computed(() => Math.sqrt(gamma.value.re ** 2 + gamma.value.im ** 2))
const gammaDeg = computed(() => Math.atan2(gamma.value.im, gamma.value.re) * 180 / Math.PI)
const swr = computed(() => {
  const g = gammaMag.value
  if (g >= 0.999) return Infinity
  return (1 + g) / (1 - g)
})
const returnLossDB = computed(() => gammaMag.value <= 0 ? Infinity : -20 * Math.log10(gammaMag.value))
const mismatchLossDB = computed(() => {
  const g2 = gammaMag.value ** 2
  return g2 >= 0.999 ? Infinity : -10 * Math.log10(1 - g2)
})

const admittance = computed(() => {
  const mag2 = rVal.value ** 2 + xVal.value ** 2
  if (mag2 <= 0) return { g: 0, b: 0 }
  return { g: rVal.value / mag2 * 1000, b: -xVal.value / mag2 * 1000 }
})

// SVG-Geometrie
const SIZE = 480
const CX = SIZE / 2, CY = SIZE / 2
const RADIUS = SIZE / 2 - 24
const pt = (gx, gy) => ({ x: CX + gx * RADIUS, y: CY - gy * RADIUS })

// Konstante-r-Kreise (Z-Karte)
const rCircles = [0.2, 0.5, 1.0, 2.0, 5.0].map(r => {
  const cx = r / (r + 1)
  const rad = 1 / (r + 1)
  const c = pt(cx, 0)
  return { cx: c.x, cy: c.y, r: rad * RADIUS, hi: r === 1.0, val: r }
})

// Konstante-x-Bögen
const xCircles = [0.2, 0.5, 1.0, 2.0, 5.0].flatMap(x =>
  [+1, -1].map(sign => {
    const xs = x * sign
    const cy = 1 / xs
    const rad = Math.abs(1 / xs)
    const c = pt(1, cy)
    return { cx: c.x, cy: c.y, r: rad * RADIUS, hi: x === 1.0, val: xs }
  })
)

// Admittanz (gespiegelt)
const yCircles = computed(() =>
  sc.showAdmittance ? rCircles.map(c => ({
    cx: pt(-c.val / (c.val + 1), 0).x,
    cy: CY,
    r: c.r,
    hi: c.hi,
  })) : []
)
const yArcs = computed(() =>
  sc.showAdmittance
    ? [0.2, 0.5, 1.0, 2.0, 5.0].flatMap(b =>
        [+1, -1].map(sign => {
          const bs = b * sign
          const cy = -1 / bs
          const rad = Math.abs(1 / bs)
          const c = pt(-1, cy)
          return { cx: c.x, cy: c.y, r: rad * RADIUS, hi: b === 1.0 }
        })
      )
    : []
)

const loadPt = computed(() => {
  const g = gamma.value
  if (Math.abs(g.re) > 1.05 || Math.abs(g.im) > 1.05) return null
  return pt(g.re, g.im)
})
const swrCircleR = computed(() => gammaMag.value > 0 && gammaMag.value < 1 ? gammaMag.value * RADIUS : 0)

// L-Network Berechnung — bis zu 4 Lösungen
function fmtComponent(comp) {
  if (comp.type === 'L') {
    const nH = comp.value * 1e9
    if (nH >= 1000) return `L = ${(nH / 1000).toFixed(3)} µH`
    if (nH >= 1)    return `L = ${nH.toFixed(1)} nH`
    return `L = ${nH.toFixed(2)} nH`
  }
  const pF = comp.value * 1e12
  if (pF >= 1000) return `C = ${(pF / 1000).toFixed(3)} nF`
  if (pF >= 1)    return `C = ${pF.toFixed(1)} pF`
  return `C = ${pF.toFixed(2)} pF`
}

const lMatchSolutions = computed(() => {
  if (fVal.value <= 0 || rVal.value <= 0) return []
  const omega = 2 * Math.PI * fVal.value * 1e6
  const R_L = rVal.value, X_L = xVal.value, R_S = sc.Z0
  const R_L_eq = (R_L * R_L + X_L * X_L) / R_L
  const sols = []

  // Fall A: Shunt am Last-Ende (R_L_eq > R_S)
  if (R_L_eq > R_S) {
    const Q = Math.sqrt(R_L_eq / R_S - 1)
    const G_L = R_L / (R_L * R_L + X_L * X_L)
    const B_L = -X_L / (R_L * R_L + X_L * X_L)
    for (const sign of [+1, -1]) {
      const Bp_target = sign * G_L * Q
      const B_p = Bp_target - B_L
      const denom = G_L * G_L + Bp_target * Bp_target
      const X_int = -Bp_target / denom
      const X_s = -X_int

      const shunt = B_p > 0 ? { type: 'C', value: B_p / omega } : { type: 'L', value: 1 / (omega * Math.abs(B_p)) }
      const series = X_s > 0 ? { type: 'L', value: X_s / omega } : { type: 'C', value: 1 / (omega * Math.abs(X_s)) }
      const isLP = shunt.type === 'C' && series.type === 'L'
      const kind = isLP ? 'Tiefpass' : (shunt.type === 'L' && series.type === 'C' ? 'Hochpass' : 'gemischt')
      sols.push({
        name: `Shunt-zuerst (${kind})`,
        topology: `Shunt-${shunt.type} ‖ Last  →  Series-${series.type}  →  Quelle`,
        shuntFirst: true, shunt, series,
        intermediateR: R_S, intermediateX: X_int,
      })
    }
  }
  // Fall B: Series am Last-Ende (R_L < R_S)
  if (R_L < R_S) {
    const Q = Math.sqrt(R_S / R_L - 1)
    for (const sign of [+1, -1]) {
      const X_s = -X_L + sign * R_L * Q
      const X_after = X_L + X_s
      const B_int = -X_after / (R_L * R_L + X_after * X_after)
      const B_p = -B_int
      const shunt = B_p > 0 ? { type: 'C', value: B_p / omega } : { type: 'L', value: 1 / (omega * Math.abs(B_p)) }
      const series = X_s > 0 ? { type: 'L', value: X_s / omega } : { type: 'C', value: 1 / (omega * Math.abs(X_s)) }
      const isLP = series.type === 'L' && shunt.type === 'C'
      const kind = isLP ? 'Tiefpass' : (series.type === 'C' && shunt.type === 'L' ? 'Hochpass' : 'gemischt')
      sols.push({
        name: `Series-zuerst (${kind})`,
        topology: `Last  →  Series-${series.type}  →  Shunt-${shunt.type} ‖  →  Quelle`,
        shuntFirst: false, shunt, series,
        intermediateR: R_L, intermediateX: X_after,
      })
    }
  }
  return sols
})

// Z → Γ Helper für Pfad
function zToGamma(r, x) {
  const num_re = r - sc.Z0, num_im = x
  const den_re = r + sc.Z0, den_im = x
  const mag2 = den_re * den_re + den_im * den_im
  if (mag2 === 0) return { re: 0, im: 0 }
  return {
    re: (num_re * den_re + num_im * den_im) / mag2,
    im: (num_im * den_re - num_re * den_im) / mag2,
  }
}

// Pfad-SVG-String für Bogen von `from` zu `to` auf Smith-Karte
function arcPathString(from, to, isShunt) {
  const num_re = 1 + from.re, num_im =  from.im
  const den_re = 1 - from.re, den_im = -from.im
  const mag2 = den_re * den_re + den_im * den_im
  if (mag2 <= 0) return ''
  const z_re = (num_re * den_re + num_im * den_im) / mag2 * sc.Z0
  const z_im = (num_im * den_re - num_re * den_im) / mag2 * sc.Z0

  let centerGx, radius
  if (isShunt) {
    const denom = z_re * z_re + z_im * z_im
    if (denom <= 0) return ''
    const g_norm = (z_re / denom) * sc.Z0
    centerGx = -g_norm / (g_norm + 1)
    radius   =  1.0 / (g_norm + 1)
  } else {
    const r_norm = z_re / sc.Z0
    if (r_norm < 0) return ''
    centerGx = r_norm / (r_norm + 1)
    radius   = 1.0 / (r_norm + 1)
  }

  const a1 = Math.atan2(from.im, from.re - centerGx)
  const a2 = Math.atan2(to.im,   to.re   - centerGx)
  let diff = a2 - a1
  while (diff >  Math.PI) diff -= 2 * Math.PI
  while (diff < -Math.PI) diff += 2 * Math.PI

  const steps = 64
  let d = ''
  for (let i = 0; i <= steps; i++) {
    const t = i / steps
    const angle = a1 + diff * t
    const gx = centerGx + radius * Math.cos(angle)
    const gy = radius * Math.sin(angle)
    const px = CX + gx * RADIUS
    const py = CY - gy * RADIUS
    d += (i === 0 ? `M ${px} ${py}` : ` L ${px} ${py}`)
  }
  return d
}

const matchPath = computed(() => {
  if (lMatchSolutions.value.length === 0 || sc.selectedSolution >= lMatchSolutions.value.length) return null
  const sol = lMatchSolutions.value[sc.selectedSolution]
  if (!loadPt.value) return null
  const loadG = gamma.value
  const intG  = zToGamma(sol.intermediateR, sol.intermediateX)
  const matchG = { re: 0, im: 0 }
  return {
    leg1: arcPathString(loadG, intG, sol.shuntFirst),
    leg2: arcPathString(intG, matchG, !sol.shuntFirst),
    intPx: { x: CX + intG.re * RADIUS, y: CY - intG.im * RADIUS },
  }
})

const seriesEquiv = computed(() => {
  if (fVal.value <= 0) return null
  const omega = 2 * Math.PI * fVal.value * 1e6
  if (xVal.value > 0) {
    return { type: 'L', value: xVal.value / omega * 1e6, unit: 'µH', kind: 'induktiv' }
  } else if (xVal.value < 0) {
    return { type: 'C', value: -1 / (omega * xVal.value) * 1e12, unit: 'pF', kind: 'kapazitiv' }
  } else {
    return { type: 'R', value: 0, unit: '', kind: 'rein resistiv' }
  }
})

function fmtSign(v, dec = 2) {
  return (v >= 0 ? '+' : '−') + Math.abs(v).toFixed(dec)
}
</script>

<template>
  <div class="calc-title">Smith-Chart</div>

  <div class="card">
    <h2>Last-Impedanz</h2>
    <div class="inp-grid" style="grid-template-columns:repeat(4, 1fr); gap:12px">
      <div class="inp-g">
        <label>Frequenz</label>
        <div class="inp-row"><input type="text" v-model="sc.freq"><span>MHz</span></div>
      </div>
      <div class="inp-g">
        <label>R (Resistanz)</label>
        <div class="inp-row"><input type="text" v-model="sc.R"><span>Ω</span></div>
      </div>
      <div class="inp-g">
        <label>X (Reaktanz)</label>
        <div class="inp-row"><input type="text" v-model="sc.X"><span>Ω</span></div>
      </div>
      <div class="inp-g">
        <label>Z₀ (System)</label>
        <select v-model.number="sc.Z0" class="z0-select">
          <option :value="50">50 Ω</option>
          <option :value="75">75 Ω</option>
          <option :value="300">300 Ω</option>
          <option :value="450">450 Ω</option>
          <option :value="600">600 Ω</option>
        </select>
      </div>
    </div>
    <div style="display:flex; gap:16px; margin-top:8px; flex-wrap:wrap">
      <label style="display:flex; align-items:center; gap:5px"><input type="checkbox" v-model="sc.showVSWR"> VSWR-Kreis</label>
      <label style="display:flex; align-items:center; gap:5px"><input type="checkbox" v-model="sc.showAdmittance"> Admittanz-Karte (Y)</label>
    </div>
    <p style="font-size:11px; opacity:0.7; margin-top:6px">
      Hinweis: positives X = induktiv, negatives X = kapazitiv. Beispiel Dipol-Resonanz: R≈73, X≈0. Kapazitive Last: X negativ.
    </p>
  </div>

  <div class="card">
    <h2>Smith-Karte (Z-Karte, normiert auf {{ sc.Z0 }} Ω)</h2>
    <div class="skz-bg">
      <svg :viewBox="`0 0 ${SIZE} ${SIZE + 30}`" preserveAspectRatio="xMidYMid meet">
        <defs>
          <clipPath id="smith-clip">
            <circle :cx="CX" :cy="CY" :r="RADIUS"/>
          </clipPath>
        </defs>
        <!-- Hintergrund -->
        <circle :cx="CX" :cy="CY" :r="RADIUS" fill="#f7f7f7" stroke="#999" stroke-width="1.5"/>

        <g clip-path="url(#smith-clip)">
          <!-- R-Kreise (blau) -->
          <circle v-for="(c, i) in rCircles" :key="`r${i}`"
                  :cx="c.cx" :cy="c.cy" :r="c.r"
                  fill="none"
                  :stroke="c.hi ? 'rgba(59,130,246,0.9)' : 'rgba(59,130,246,0.35)'"
                  :stroke-width="c.hi ? 1.3 : 0.8"/>
          <!-- X-Bögen (lila) -->
          <circle v-for="(c, i) in xCircles" :key="`x${i}`"
                  :cx="c.cx" :cy="c.cy" :r="c.r"
                  fill="none"
                  :stroke="c.hi ? 'rgba(168,85,247,0.85)' : 'rgba(168,85,247,0.30)'"
                  :stroke-width="c.hi ? 1.3 : 0.8"/>
          <!-- Admittanz (orange, gestrichelt) -->
          <circle v-for="(c, i) in yCircles" :key="`yc${i}`"
                  :cx="c.cx" :cy="c.cy" :r="c.r"
                  fill="none"
                  :stroke="c.hi ? 'rgba(249,115,22,0.9)' : 'rgba(249,115,22,0.35)'"
                  :stroke-width="c.hi ? 1.3 : 0.8"
                  stroke-dasharray="3,3"/>
          <circle v-for="(c, i) in yArcs" :key="`ya${i}`"
                  :cx="c.cx" :cy="c.cy" :r="c.r"
                  fill="none"
                  :stroke="c.hi ? 'rgba(249,115,22,0.85)' : 'rgba(249,115,22,0.30)'"
                  :stroke-width="c.hi ? 1.3 : 0.8"
                  stroke-dasharray="3,3"/>
          <!-- Hauptachse (x=0) -->
          <line :x1="CX - RADIUS" :y1="CY" :x2="CX + RADIUS" :y2="CY" stroke="rgba(140,140,140,0.6)" stroke-width="1"/>
        </g>

        <!-- Mittelpunkt (Z₀) -->
        <circle :cx="CX" :cy="CY" r="4" fill="#22c55e"/>
        <text :x="CX + 6" :y="CY - 10" font-size="9" font-weight="bold" fill="#22c55e">{{ sc.Z0 }} Ω</text>

        <!-- Open / Short Labels -->
        <text :x="CX + RADIUS + 4" :y="CY + 8" font-size="8" fill="#666">OPEN (∞)</text>
        <text :x="CX - RADIUS - 4" :y="CY + 8" font-size="8" fill="#666" text-anchor="end">SHORT (0 Ω)</text>

        <!-- VSWR-Kreis -->
        <g v-if="sc.showVSWR && swrCircleR > 0">
          <circle :cx="CX" :cy="CY" :r="swrCircleR" fill="none" stroke="rgba(239,68,68,0.8)" stroke-width="1.5" stroke-dasharray="4,3"/>
          <text :x="CX" :y="CY - swrCircleR - 6" text-anchor="middle" font-size="9" font-weight="bold" fill="#ef4444">
            {{ Number.isFinite(swr) ? `VSWR ${swr.toFixed(2)}` : 'VSWR ∞' }}
          </text>
        </g>

        <!-- L-Network Pfad -->
        <g v-if="matchPath">
          <path :d="matchPath.leg1" fill="none" stroke="rgba(34,197,94,0.9)" stroke-width="3" stroke-linecap="round"/>
          <path :d="matchPath.leg2" fill="none" stroke="rgba(249,115,22,0.95)" stroke-width="3" stroke-linecap="round"/>
          <circle :cx="matchPath.intPx.x" :cy="matchPath.intPx.y" r="4" fill="#3b82f6" stroke="white" stroke-width="1"/>
        </g>

        <!-- Eingabepunkt -->
        <g v-if="loadPt">
          <circle :cx="loadPt.x" :cy="loadPt.y" r="6" fill="#ef4444" stroke="white" stroke-width="1.5"/>
          <text :x="loadPt.x + 9" :y="loadPt.y - 8" font-size="10" font-weight="bold" fill="#ef4444">
            {{ rVal.toFixed(0) }}{{ fmtSign(xVal, 0) }}j Ω
          </text>
        </g>

        <!-- Legende -->
        <text :x="CX" :y="SIZE + 18" text-anchor="middle" font-size="9" fill="#888">
          ─── R/Z₀ konstant   ─── X/Z₀ konstant   ● Last
        </text>
      </svg>
    </div>
  </div>

  <div v-if="lMatchSolutions.length > 0" class="card">
    <h2>L-Network Anpassung auf {{ sc.Z0 }} Ω bei {{ Number(sc.freq).toFixed(3) }} MHz</h2>
    <div class="seg" style="margin-bottom: 12px; flex-wrap: wrap">
      <button v-for="(sol, i) in lMatchSolutions" :key="i"
              class="sb" :class="{ on: sc.selectedSolution === i }"
              @click="sc.selectedSolution = i">
        Lösung {{ i + 1 }}: {{ sol.name }}
      </button>
    </div>
    <template v-if="sc.selectedSolution < lMatchSolutions.length">
      <div class="rr"><span class="lbl">Topologie</span><span class="val mono">{{ lMatchSolutions[sc.selectedSolution].topology }}</span></div>
      <div class="rr hi"><span class="lbl">Shunt-Komponente</span><span class="val mono">{{ fmtComponent(lMatchSolutions[sc.selectedSolution].shunt) }}</span></div>
      <div class="rr hi"><span class="lbl">Series-Komponente</span><span class="val mono">{{ fmtComponent(lMatchSolutions[sc.selectedSolution].series) }}</span></div>
      <div class="rr"><span class="lbl">Zwischen-Impedanz</span>
        <span class="val mono">
          {{ lMatchSolutions[sc.selectedSolution].intermediateR.toFixed(2) }}
          {{ fmtSign(lMatchSolutions[sc.selectedSolution].intermediateX, 2) }}j Ω
        </span>
      </div>
      <p style="font-size:11px; opacity:0.7; margin-top:8px">
        Pfad auf der Smith-Karte: <span style="color:#22c55e">grüner Bogen</span> = erste Komponente vom Last-Punkt,
        <span style="color:#f97316">oranger Bogen</span> = zweite Komponente bis zum Match.
      </p>
    </template>
  </div>

  <div class="card">
    <h2>Berechnete Werte</h2>
    <div class="rr"><span class="lbl">Z (Last)</span><span class="val mono">{{ rVal.toFixed(2) }} {{ fmtSign(xVal, 2) }}j Ω</span></div>
    <div class="rr"><span class="lbl">z (normiert)</span><span class="val mono">{{ zN.re.toFixed(3) }} {{ fmtSign(zN.im, 3) }}j</span></div>
    <div class="rr"><span class="lbl">Γ (Reflexionsfaktor)</span><span class="val mono">{{ gamma.re.toFixed(3) }} {{ fmtSign(gamma.im, 3) }}j</span></div>
    <div class="rr hi"><span class="lbl">|Γ|</span><span class="val mono">{{ gammaMag.toFixed(4) }}</span></div>
    <div class="rr"><span class="lbl">∠Γ</span><span class="val mono">{{ gammaDeg.toFixed(1) }} °</span></div>
    <div class="rr hi"><span class="lbl">VSWR</span><span class="val mono">{{ Number.isFinite(swr) ? swr.toFixed(3) + ' : 1' : '∞ : 1' }}</span></div>
    <div class="rr"><span class="lbl">Return Loss</span><span class="val mono">{{ Number.isFinite(returnLossDB) ? returnLossDB.toFixed(2) + ' dB' : '∞ dB' }}</span></div>
    <div class="rr"><span class="lbl">Mismatch Loss</span><span class="val mono">{{ Number.isFinite(mismatchLossDB) ? mismatchLossDB.toFixed(3) + ' dB' : '∞ dB' }}</span></div>
    <div class="rr"><span class="lbl">Y (Admittanz)</span><span class="val mono">{{ admittance.g.toFixed(2) }} {{ fmtSign(admittance.b, 2) }}j mS</span></div>
    <div v-if="seriesEquiv" class="rr"><span class="lbl">Äquivalent (Serie)</span>
      <span class="val mono">
        <template v-if="seriesEquiv.type === 'R'">0 (rein resistiv → Resonanz)</template>
        <template v-else>{{ seriesEquiv.type }} = {{ seriesEquiv.value.toFixed(seriesEquiv.type === 'L' ? 3 : 2) }} {{ seriesEquiv.unit }} ({{ seriesEquiv.kind }})</template>
      </span>
    </div>
  </div>

  <div class="card">
    <h2>Lese-Hilfe</h2>
    <ul style="margin:0; padding-left:18px; line-height:1.6; font-size:13px; opacity:0.85">
      <li><strong>Mitte (grüner Punkt)</strong> = Z₀ Match, perfekt angepasst (VSWR 1:1).</li>
      <li><strong>Rechter Rand (1, 0)</strong> = Open (Leerlauf, ∞ Ω).</li>
      <li><strong>Linker Rand (−1, 0)</strong> = Short (Kurzschluss, 0 Ω).</li>
      <li><strong>Obere Halbebene</strong> = induktive Last (X &gt; 0).</li>
      <li><strong>Untere Halbebene</strong> = kapazitive Last (X &lt; 0).</li>
      <li><strong>Roter VSWR-Kreis</strong> = alle Impedanzen mit gleichem VSWR wie die Last.</li>
      <li><strong>R-Kreise (blau)</strong> = konstanter Real-Anteil. <strong>X-Bögen (lila)</strong> = konstanter Imaginär-Anteil.</li>
      <li><strong>Admittanz-Karte (orange, gestrichelt)</strong> = gespiegelte Y-Karte für Parallel-Komponenten.</li>
    </ul>
  </div>

  <RechnerBeschreibung name="smithchart" />
</template>

<style scoped>
.z0-select { padding: 6px 8px; border-radius: 6px; border: 1px solid var(--border, #333); background: var(--bg-input, #1a1a1a); color: inherit; width: 100% }
.mono { font-family: monospace }
</style>
