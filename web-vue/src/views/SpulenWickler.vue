<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const sp = reactive({ L: '10', D: '30', dw: '1.0', s: '0', C: '100' })

const result = computed(() => {
  const L = pf(sp.L), D = pf(sp.D), dw = pf(sp.dw), s = pf(sp.s), C = pf(sp.C)
  if (!L || !D || !dw || s < 0) return null
  const r_inch = (D / 2) / 25.4
  const pitch_inch = (dw + s) / 25.4
  let n = 10, np = 0
  for (let i = 0; i < 80; i++) {
    const l_inch = n * pitch_inch
    n = Math.sqrt(L * (9 * r_inch + 10 * l_inch)) / r_inch
    if (Math.abs(n - np) < 0.0001) break
    np = n
  }
  if (n <= 0) return null
  const pitch = dw + s
  const laenge = n * pitch
  const aussenD = D + 2 * dw
  const wireLen = n * Math.sqrt(Math.pow(Math.PI * D, 2) + Math.pow(pitch, 2)) / 1000
  let freq = null
  if (C > 0) {
    const f_hz = 1 / (2 * Math.PI * Math.sqrt(L * 1e-6 * C * 1e-12))
    freq = f_hz / 1e6
  }
  let q = null
  if (freq && freq > 0) {
    const rho = 1.72e-8
    const A = Math.PI * Math.pow(dw * 0.5e-3, 2)
    const Rdc = rho * wireLen / A
    const qVal = (2 * Math.PI * freq * 1e6 * L * 1e-6) / Rdc
    if (qVal >= 1) q = qVal
  }
  return {
    L, D, dw, s, C, windungen: n, pitch, laenge, aussenD,
    wireLen, freq, q,
    induktProWindung: L / n,
    schlankheit: laenge / D,
  }
})

// SVG Skizze (Helix-Ansicht)
const SVG_W = 600, SVG_H = 220

const sketchGeom = computed(() => {
  if (!result.value) return null
  const r = result.value
  const maxTurnsVis = 30
  const n = r.windungen
  const nVis = Math.min(Math.ceil(n), maxTurnsVis)
  const D = r.D, dw = r.dw, s = r.s, pitch = dw + s
  const leadLen = 32, marginL = leadLen + 10, marginR = 88, marginT = 20, marginB = 34
  const availW = SVG_W - marginL - marginR
  const availH = SVG_H - marginT - marginB
  const bodyH = Math.min(availH * 0.5, 70)
  const aspect = (n * pitch) / D
  const idealBodyW = bodyH * aspect
  const bodyW = Math.max(80, Math.min(idealBodyW, availW))
  const bodyX = marginL + (availW - bodyW) / 2
  const cy = marginT + availH * 0.5
  const bTop = cy - bodyH / 2
  const bBot = cy + bodyH / 2
  const pitchPx = bodyW / nVis
  const dw_over_pitch = dw / pitch
  const wireThick = Math.max(1.5, Math.min(pitchPx * dw_over_pitch, 10))
  const ey = bodyH / 2
  // Helix-Pfade (Vorder-/Rückseite)
  const stepsPerTurn = 80
  const totalSteps = nVis * stepsPerTurn
  const frontSegments = []
  const backSegments = []
  let currentSeg = []
  let prevFront = null
  for (let step = 0; step <= totalSteps; step++) {
    const tNorm = step / totalSteps
    const t = tNorm * nVis * 2 * Math.PI
    const px = bodyX + tNorm * bodyW
    const py = cy - ey * Math.cos(t)
    const isFront = Math.sin(t) >= 0
    if (prevFront !== null && prevFront !== isFront) {
      // Wechsel
      if (prevFront) frontSegments.push(currentSeg)
      else backSegments.push(currentSeg)
      currentSeg = []
    }
    currentSeg.push({ x: px, y: py })
    prevFront = isFront
  }
  if (currentSeg.length > 0) {
    if (prevFront) frontSegments.push(currentSeg)
    else backSegments.push(currentSeg)
  }
  const segToPath = seg => seg.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(' ')
  return {
    bodyX, bodyW, bTop, bBot, cy, ey, bodyH,
    leadLen, wireThick,
    frontPath: frontSegments.map(segToPath).join(' '),
    backPath: backSegments.map(segToPath).join(' '),
    nVis, n, pitch,
    capRx: ey * 0.22,
    yLead: cy - ey,
    arrY: bBot + 16,
    dax: bodyX + bodyW + leadLen + 14,
  }
})
</script>

<template>
  <div class="calc-title">Spulen-Wickler</div>

  <div class="card">
    <h2>Spulenparameter</h2>
    <div class="inp-grid">
      <div class="inp-g">
        <label>Induktivität L</label>
        <div class="inp-row"><input type="text" v-model="sp.L"><span>µH</span></div>
        <div class="small" style="font-size:10px;color:var(--td)">Gewünschter Wert</div>
      </div>
      <div class="inp-g">
        <label>Körper-Ø D</label>
        <div class="inp-row"><input type="text" v-model="sp.D"><span>mm</span></div>
        <div class="small" style="font-size:10px;color:var(--td)">Wickelkörper</div>
      </div>
    </div>
    <div class="inp-grid" style="margin-top:10px">
      <div class="inp-g">
        <label>Draht-Ø d</label>
        <div class="inp-row"><input type="text" v-model="sp.dw"><span>mm</span></div>
        <div class="small" style="font-size:10px;color:var(--td)">inkl. Isolierung</div>
      </div>
      <div class="inp-g">
        <label>Windungsabstand</label>
        <div class="inp-row"><input type="text" v-model="sp.s"><span>mm</span></div>
        <div class="small" style="font-size:10px;color:var(--td)">0 = dicht gewickelt</div>
      </div>
    </div>
    <div class="inp-grid" style="margin-top:10px">
      <div class="inp-g">
        <label>Kapazität C</label>
        <div class="inp-row"><input type="text" v-model="sp.C"><span>pF</span></div>
        <div class="small" style="font-size:10px;color:var(--td)">Für LC-Resonanz</div>
      </div>
      <div></div>
    </div>
    <div class="small mt8" style="font-size:11px">Berechnung nach Wheeler-Formel für einlagige Luftspulen</div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Skizze</h2>
      <div class="skz-bg">
        <svg v-if="sketchGeom" :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet">
          <defs>
            <linearGradient id="bodyGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stop-color="#eaf0f8"/>
              <stop offset="50%" stop-color="#c7d8ec"/>
              <stop offset="100%" stop-color="#eaf0f8"/>
            </linearGradient>
          </defs>
          <!-- Spulenkörper -->
          <rect :x="sketchGeom.bodyX" :y="sketchGeom.bTop" :width="sketchGeom.bodyW" :height="sketchGeom.bodyH"
                fill="url(#bodyGrad)" stroke="#9bb0c8" stroke-width="1.5"/>
          <!-- Linke Endkappe -->
          <ellipse :cx="sketchGeom.bodyX" :cy="sketchGeom.cy" :rx="sketchGeom.capRx" :ry="sketchGeom.bodyH / 2"
                   fill="#bfd2e7" stroke="#9bb0c8" stroke-width="1.5"/>
          <!-- Rechte Endkappe -->
          <ellipse :cx="sketchGeom.bodyX + sketchGeom.bodyW" :cy="sketchGeom.cy" :rx="sketchGeom.capRx" :ry="sketchGeom.bodyH / 2"
                   fill="#c7d8ec" stroke="#9bb0c8" stroke-width="1.5"/>

          <!-- Helix-Wicklung: Rückseite zuerst (dunkler) -->
          <path :d="sketchGeom.backPath" fill="none" stroke="rgba(140,46,0,0.4)" :stroke-width="sketchGeom.wireThick * 0.7" stroke-linecap="round"/>
          <!-- Vorderseite -->
          <path :d="sketchGeom.frontPath" fill="none" stroke="#d35400" :stroke-width="sketchGeom.wireThick" stroke-linecap="round"/>

          <!-- Zuleitungen -->
          <line :x1="sketchGeom.bodyX - sketchGeom.leadLen" :y1="sketchGeom.yLead"
                :x2="sketchGeom.bodyX" :y2="sketchGeom.yLead"
                stroke="#d35400" :stroke-width="sketchGeom.wireThick" stroke-linecap="round"/>
          <line :x1="sketchGeom.bodyX + sketchGeom.bodyW" :y1="sketchGeom.yLead"
                :x2="sketchGeom.bodyX + sketchGeom.bodyW + sketchGeom.leadLen" :y2="sketchGeom.yLead"
                stroke="#d35400" :stroke-width="sketchGeom.wireThick" stroke-linecap="round"/>

          <!-- Bemaßung Länge unten -->
          <line :x1="sketchGeom.bodyX" :y1="sketchGeom.bBot + 4" :x2="sketchGeom.bodyX" :y2="sketchGeom.arrY + 2"
                stroke="rgba(140,140,140,0.5)" stroke-width="1" stroke-dasharray="3,2"/>
          <line :x1="sketchGeom.bodyX + sketchGeom.bodyW" :y1="sketchGeom.bBot + 4" :x2="sketchGeom.bodyX + sketchGeom.bodyW" :y2="sketchGeom.arrY + 2"
                stroke="rgba(140,140,140,0.5)" stroke-width="1" stroke-dasharray="3,2"/>
          <line :x1="sketchGeom.bodyX" :y1="sketchGeom.arrY" :x2="sketchGeom.bodyX + sketchGeom.bodyW" :y2="sketchGeom.arrY"
                stroke="rgba(140,140,140,0.85)" stroke-width="1.5"/>
          <text :x="sketchGeom.bodyX + sketchGeom.bodyW / 2" :y="sketchGeom.arrY + 14"
                text-anchor="middle" font-size="10" fill="var(--ts)">
            {{ result.laenge.toFixed(1) }} mm
          </text>

          <!-- Bemaßung Durchmesser rechts -->
          <line :x1="sketchGeom.bodyX + sketchGeom.bodyW + 4" :y1="sketchGeom.bTop"
                :x2="sketchGeom.dax - 2" :y2="sketchGeom.bTop"
                stroke="rgba(140,140,140,0.5)" stroke-width="1" stroke-dasharray="3,2"/>
          <line :x1="sketchGeom.bodyX + sketchGeom.bodyW + 4" :y1="sketchGeom.bBot"
                :x2="sketchGeom.dax - 2" :y2="sketchGeom.bBot"
                stroke="rgba(140,140,140,0.5)" stroke-width="1" stroke-dasharray="3,2"/>
          <line :x1="sketchGeom.dax" :y1="sketchGeom.bTop" :x2="sketchGeom.dax" :y2="sketchGeom.bBot"
                stroke="rgba(140,140,140,0.85)" stroke-width="1.5"/>
          <text :x="sketchGeom.dax + 8" :y="(sketchGeom.bTop + sketchGeom.bBot) / 2 + 4"
                text-anchor="start" font-size="10" fill="var(--ts)">
            Ø {{ result.D.toFixed(0) }} mm
          </text>

          <!-- Label oben -->
          <text :x="sketchGeom.bodyX + sketchGeom.bodyW / 2" :y="sketchGeom.bTop - 8"
                text-anchor="middle" font-size="10" fill="var(--ts)">
            {{ Math.ceil(result.windungen) }} Windungen · Pitch {{ result.pitch.toFixed(1) }} mm
          </text>

          <text v-if="Math.ceil(result.windungen) > 30" :x="SVG_W / 2" :y="SVG_H - 6"
                text-anchor="middle" font-size="9" fill="var(--td)">
            Skizze: 30 von {{ Math.ceil(result.windungen) }} Windungen
          </text>
        </svg>
      </div>
    </div>

    <div class="card">
      <h2>Ergebnisse</h2>
      <div class="ken-grid">
        <div class="ken hi"><div class="ken-val">{{ result.windungen.toFixed(1) }}</div><div class="ken-lbl">Windungen</div></div>
        <div class="ken"><div class="ken-val">{{ result.laenge.toFixed(1) }} mm</div><div class="ken-lbl">Spulenlänge</div></div>
        <div class="ken"><div class="ken-val">{{ result.wireLen.toFixed(2) }} m</div><div class="ken-lbl">Drahtlänge</div></div>
        <div v-if="result.freq" class="ken">
          <div class="ken-val">{{ result.freq >= 1 ? result.freq.toFixed(3) + ' MHz' : (result.freq * 1000).toFixed(1) + ' kHz' }}</div>
          <div class="ken-lbl">Resonanzfreq.</div>
        </div>
        <div v-if="result.q" class="ken"><div class="ken-val">{{ result.q.toFixed(0) }}</div><div class="ken-lbl">Güte Q</div></div>
      </div>
    </div>

    <div class="card">
      <h2>Wickeldetails</h2>
      <div class="rr"><span class="lbl">Wickelschritt (Pitch)</span><span class="val">{{ result.pitch.toFixed(2) }} mm</span></div>
      <div class="rr"><span class="lbl">Außendurchmesser</span><span class="val">{{ result.aussenD.toFixed(1) }} mm</span></div>
      <div class="rr"><span class="lbl">Induktivität / Windung</span><span class="val">{{ result.induktProWindung.toFixed(3) }} µH/Wdg.</span></div>
      <div class="rr"><span class="lbl">Schlankheit (L/D)</span><span class="val">{{ result.schlankheit.toFixed(2) }}</span></div>
      <div class="rr"><span class="lbl">Körperdurchmesser</span><span class="val">{{ result.D.toFixed(0) }} mm</span></div>
    </div>
  </template>

  <RechnerBeschreibung name="spulenwickler" />
</template>

<style scoped>
.ken-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }
.ken {
  background: var(--card2); border: 1px solid var(--sep);
  border-radius: 8px; padding: 12px 10px; text-align: center;
}
.ken.hi { border-color: var(--acc); }
.ken-val { font-size: 16px; font-weight: 700; color: var(--tp); font-family: 'SF Mono', 'Cascadia Mono', monospace; }
.ken.hi .ken-val { color: var(--acc); }
.ken-lbl { font-size: 10px; color: var(--ts); margin-top: 4px; text-transform: uppercase; letter-spacing: 0.5px; }
@media(max-width:640px){ .ken-grid { grid-template-columns: 1fr 1fr; } }
</style>
