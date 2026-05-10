<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const v = reactive({
  freq: '7.1', len: '8.0', coilD: '50.0', wireD: '1.5', isVertikal: true,
})

const verlBands = [
  ['80m',3.65],['40m',7.1],['30m',10.125],['20m',14.175],
  ['17m',18.118],['15m',21.225],['12m',24.94],['10m',28.5],
]

function selectBand(freq) {
  v.freq = String(freq)
  v.len = ((71.25 / freq) * 0.65).toFixed(1)
}

const target = computed(() => {
  const f = pf(v.freq)
  return f > 0 ? 71.25 / f : 0
})

const result = computed(() => {
  const f = pf(v.freq), h = pf(v.len), D = pf(v.coilD), dw = pf(v.wireD)
  if (!f || !h || !D || !dw) return null
  const lambda = 300 / f
  const tgt = 71.25 / f
  if (h >= tgt * 0.98) return { ok: true, h, target: tgt }
  const wireDiam_m = dw / 1000
  const z0 = 60 * (Math.log(2 * h / wireDiam_m) - 1)
  const G_deg = 360 * h / lambda
  const Xa = -z0 / Math.tan(G_deg * Math.PI / 180)
  const XL = Math.abs(Xa)
  const L_uH = XL / (2 * Math.PI * f)

  const r_inch = (D / 2) / 25.4
  const pitch = dw / 25.4
  let n = 10, np = 0
  for (let i = 0; i < 80; i++) {
    const l_inch = n * pitch
    n = Math.sqrt(L_uH * (9 * r_inch + 10 * l_inch)) / r_inch
    if (Math.abs(n - np) < 0.0001) break
    np = n
  }
  if (n <= 0) return null
  const nInt = Math.ceil(n)
  const coilLen = nInt * dw
  const meanCirc = Math.PI * D
  const wireLen = nInt * Math.sqrt(meanCirc * meanCirc + dw * dw) / 1000
  const diff = tgt - h
  return {
    ok: false, h, target: tgt, diff, z0, G_deg, Xa, L_uH,
    windungen: nInt, windungenRoh: n,
    coilLen_mm: coilLen, wireLen_m: wireLen, outerD_mm: D + 2 * dw,
  }
})

// Vertikal-Skizze
const vertSVG = { W: 360, H: 320 }
const vertGeom = computed(() => {
  if (!result.value || result.value.ok || !v.isVertikal) return null
  const r = result.value
  const cx = vertSVG.W / 2
  const groundY = vertSVG.H - 30
  const coilH = Math.max(60, Math.min(100, r.windungen * 6))
  const spuleBot = groundY
  const spuleTop = spuleBot - coilH
  const availWire = spuleTop - 30
  const hPx = Math.min(availWire - 10, availWire * 0.95)
  const drahtTop = spuleTop - hPx
  const amp = 22
  // Spulen-Sinuspfad
  const nVis = Math.min(r.windungen, 14)
  const stepH = coilH / nVis
  let path = `M ${cx} ${spuleBot}`
  for (let i = 0; i < nVis; i++) {
    const y1 = spuleBot - i * stepH
    const y3 = spuleBot - (i + 1) * stepH
    path += ` C ${cx + amp} ${y1}, ${cx + amp} ${y3}, ${cx} ${y3}`
  }
  return { cx, groundY, spuleBot, spuleTop, drahtTop, amp, path, coilH }
})

// Dipol-Skizze
const dipSVG = { W: 600, H: 160 }
const dipGeom = computed(() => {
  if (!result.value || result.value.ok || v.isVertikal) return null
  const r = result.value
  const cy = dipSVG.H / 2
  const feedX = dipSVG.W / 2
  const availW = (dipSVG.W / 2 - 60)
  const scale = availW / r.target
  const hPx = r.h * scale
  const coilW = Math.max(40, Math.min(70, r.windungen * 4))
  const coilStartX = feedX + hPx
  const amp = 14
  const nVis = Math.min(r.windungen, 12)
  const stepW = coilW / nVis
  let path = `M ${coilStartX} ${cy}`
  for (let i = 0; i < nVis; i++) {
    const x1 = coilStartX + i * stepW
    const x3 = coilStartX + (i + 1) * stepW
    path += ` C ${x1} ${cy - amp * 2}, ${x3} ${cy - amp * 2}, ${x3} ${cy}`
  }
  return { cy, feedX, hPx, coilStartX, coilW, amp, path }
})
</script>

<template>
  <div class="calc-title">Strahler-Verlängerung</div>

  <div class="card">
    <h2>Eingabe</h2>
    <div class="seg" style="margin-bottom:8px">
      <button class="sb" :class="{ on: v.isVertikal }" @click="v.isVertikal = true">λ/4 Vertikal</button>
      <button class="sb" :class="{ on: !v.isVertikal }" @click="v.isVertikal = false">λ/2 Dipol (pro Schenkel)</button>
    </div>
    <div class="small" style="font-size:10px">
      {{ v.isVertikal ? 'Zielgröße λ/4 – Spule am Fuß oder im Strahler' : 'Zielgröße λ/4 pro Schenkel – 2× berechnen für Dipol' }}
    </div>

    <div class="band-grid" style="grid-template-columns:repeat(4,1fr);margin-top:10px;margin-bottom:10px">
      <button v-for="[name, f] in verlBands" :key="name"
              class="bb" :class="{ on: Math.abs(pf(v.freq) - f) < 0.5 }"
              @click="selectBand(f)">{{ name }}</button>
    </div>
    <div class="inp-grid">
      <div class="inp-g"><label>Frequenz</label><div class="inp-row"><input type="text" v-model="v.freq"><span>MHz</span></div></div>
      <div class="inp-g">
        <label>Strahler-Länge h</label>
        <div class="inp-row"><input type="text" v-model="v.len"><span>m</span></div>
        <div class="small c-orn" style="font-size:10px">Muss kürzer als λ/4 sein</div>
      </div>
    </div>
    <div class="inp-grid" style="margin-top:10px">
      <div class="inp-g"><label>Spulen-Ø D</label><div class="inp-row"><input type="text" v-model="v.coilD"><span>mm</span></div></div>
      <div class="inp-g"><label>Draht-Ø dw</label><div class="inp-row"><input type="text" v-model="v.wireD"><span>mm</span></div></div>
    </div>
    <div v-if="target > 0" class="small mt8">
      λ/4 Referenz: {{ fmt(target) }} m
    </div>
  </div>

  <template v-if="result">
    <div v-if="result.ok" class="card">
      <div class="ok-box" style="display:flex;gap:12px;align-items:center">
        <span style="background:var(--grn);color:#fff;width:28px;height:28px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;font-weight:bold">✓</span>
        <div>
          <div style="font-weight:600;color:var(--tp)">Keine Verlängerungsspule nötig</div>
          <div class="small">Die Antenne ({{ fmt(result.h, 2) }} m) ist bereits lang genug für λ/4 ({{ fmt(result.target) }} m).</div>
        </div>
      </div>
    </div>

    <template v-else>
      <div class="card">
        <h2>Ergebnis</h2>
        <div class="ken-grid">
          <div class="ken hi"><div class="ken-val">{{ result.windungen }}</div><div class="ken-lbl">Windungen</div></div>
          <div class="ken"><div class="ken-val">{{ fmt(result.L_uH, 2) }} µH</div><div class="ken-lbl">Induktivität</div></div>
          <div class="ken"><div class="ken-val">{{ fmt(result.coilLen_mm, 1) }} mm</div><div class="ken-lbl">Wickellänge</div></div>
          <div class="ken"><div class="ken-val">{{ fmt(result.wireLen_m, 2) }} m</div><div class="ken-lbl">Drahtlänge</div></div>
          <div class="ken"><div class="ken-val">{{ fmt(result.outerD_mm, 1) }} mm</div><div class="ken-lbl">Außen-Ø</div></div>
          <div class="ken"><div class="ken-val">{{ fmt(result.Xa, 1) }} Ω</div><div class="ken-lbl">Blindwiderstand Xa</div></div>
        </div>
      </div>

      <div class="card">
        <h2>Zwischenwerte</h2>
        <div class="rr"><span class="lbl">Zielgröße λ/4</span><span class="val">{{ fmt(result.target) }} m</span></div>
        <div class="rr"><span class="lbl">Fehlende Länge</span><span class="val">{{ fmt(result.diff) }} m</span></div>
        <div class="rr"><span class="lbl">Wellenwiderstand Z₀</span><span class="val">{{ fmt(result.z0, 1) }} Ω</span></div>
        <div class="rr"><span class="lbl">Elektrische Länge G</span><span class="val">{{ fmt(result.G_deg, 1) }}°</span></div>
        <div class="rr"><span class="lbl">Blindwiderstand Xa</span><span class="val">{{ fmt(result.Xa, 2) }} Ω</span></div>
        <div class="rr"><span class="lbl">Benötigtes XL</span><span class="val">{{ fmt(Math.abs(result.Xa), 2) }} Ω</span></div>
        <div class="rr hi"><span class="lbl">Induktivität L</span><span class="val">{{ fmt(result.L_uH, 3) }} µH</span></div>
        <div class="rr"><span class="lbl">Windungen (roh)</span><span class="val">{{ fmt(result.windungenRoh, 2) }}</span></div>
        <div class="rr hi"><span class="lbl">Windungen N</span><span class="val">{{ result.windungen }}</span></div>
        <div class="rr"><span class="lbl">Wickellänge</span><span class="val">{{ fmt(result.coilLen_mm, 1) }} mm</span></div>
      </div>

      <div class="card">
        <h2>Skizze</h2>
        <div class="skz-bg" style="display:flex;justify-content:center">
          <!-- Vertikale Variante -->
          <svg v-if="vertGeom" :viewBox="`0 0 ${vertSVG.W} ${vertSVG.H}`" preserveAspectRatio="xMidYMid meet" style="max-height:320px">
            <!-- Spulen-Box -->
            <rect :x="vertGeom.cx - vertGeom.amp - 4" :y="vertGeom.spuleTop"
                  :width="vertGeom.amp * 2 + 8" :height="vertGeom.coilH" rx="4"
                  fill="none" stroke="rgba(251,146,60,0.3)" stroke-width="1"/>
            <!-- Spulen-Kurve -->
            <path :d="vertGeom.path" fill="none" stroke="#fb923c" stroke-width="2.5"/>
            <!-- Draht oben -->
            <line :x1="vertGeom.cx" :y1="vertGeom.spuleTop" :x2="vertGeom.cx" :y2="vertGeom.drahtTop"
                  stroke="#a78bfa" stroke-width="4"/>
            <!-- Pfeilspitze -->
            <polygon :points="`${vertGeom.cx},${vertGeom.drahtTop - 8} ${vertGeom.cx - 6},${vertGeom.drahtTop + 4} ${vertGeom.cx + 6},${vertGeom.drahtTop + 4}`"
                     fill="#a78bfa"/>
            <!-- Erde -->
            <line :x1="vertGeom.cx - 20" :y1="vertGeom.groundY" :x2="vertGeom.cx + 20" :y2="vertGeom.groundY"
                  stroke="rgba(140,140,140,0.85)" stroke-width="2.5"/>
            <line :x1="vertGeom.cx - 16" :y1="vertGeom.groundY + 5" :x2="vertGeom.cx + 16" :y2="vertGeom.groundY + 5"
                  stroke="rgba(140,140,140,0.6)" stroke-width="1"/>
            <line :x1="vertGeom.cx - 12" :y1="vertGeom.groundY + 10" :x2="vertGeom.cx + 12" :y2="vertGeom.groundY + 10"
                  stroke="rgba(140,140,140,0.6)" stroke-width="1"/>
            <line :x1="vertGeom.cx - 8" :y1="vertGeom.groundY + 15" :x2="vertGeom.cx + 8" :y2="vertGeom.groundY + 15"
                  stroke="rgba(140,140,140,0.6)" stroke-width="1"/>
            <!-- Speisepunkt -->
            <circle :cx="vertGeom.cx" :cy="vertGeom.spuleBot" r="6" fill="var(--acc)"/>
            <!-- Längen-Pfeil rechts -->
            <line :x1="vertGeom.cx + vertGeom.amp + 20" :y1="vertGeom.spuleTop"
                  :x2="vertGeom.cx + vertGeom.amp + 20" :y2="vertGeom.drahtTop"
                  stroke="rgba(140,140,140,0.5)" stroke-width="1"/>
            <text :x="vertGeom.cx + vertGeom.amp + 26" :y="(vertGeom.spuleTop + vertGeom.drahtTop) / 2"
                  text-anchor="start" font-size="12" font-weight="bold" fill="var(--tp)">
              {{ fmt(result.h, 2) }} m
            </text>
            <!-- Labels -->
            <text :x="vertGeom.cx - vertGeom.amp - 12" :y="(vertGeom.spuleTop + vertGeom.spuleBot) / 2 + 4"
                  text-anchor="end" font-size="12" font-weight="bold" fill="#fb923c">
              {{ result.windungen }} Wdg.
            </text>
            <text :x="vertGeom.cx + 12" :y="vertGeom.spuleBot + 4" font-size="11" fill="var(--acc)">Speisepunkt</text>
            <text :x="vertGeom.cx + 12" :y="vertGeom.groundY + 4" font-size="11" fill="var(--ts)">Erde</text>
            <text :x="vertSVG.W / 2" :y="vertSVG.H - 6" text-anchor="middle" font-size="11" fill="var(--ts)">
              λ/4 Vertikal mit Verlängerungsspule
            </text>
          </svg>

          <!-- Dipol Variante -->
          <svg v-if="dipGeom" :viewBox="`0 0 ${dipSVG.W} ${dipSVG.H}`" preserveAspectRatio="xMidYMid meet" style="max-height:160px">
            <!-- Linker Schenkel -->
            <line :x1="dipGeom.feedX - dipGeom.hPx" :y1="dipGeom.cy" :x2="dipGeom.feedX" :y2="dipGeom.cy"
                  stroke="#a78bfa" stroke-width="4"/>
            <!-- Rechter Schenkel bis Spule -->
            <line :x1="dipGeom.feedX" :y1="dipGeom.cy" :x2="dipGeom.coilStartX" :y2="dipGeom.cy"
                  stroke="#a78bfa" stroke-width="4"/>
            <!-- Spulen-Box -->
            <rect :x="dipGeom.coilStartX - 2" :y="dipGeom.cy - dipGeom.amp * 2 - 4"
                  :width="dipGeom.coilW + 4" :height="dipGeom.amp * 2 + 8" rx="4"
                  fill="none" stroke="rgba(251,146,60,0.3)" stroke-width="1"/>
            <!-- Spulen-Kurve -->
            <path :d="dipGeom.path" fill="none" stroke="#fb923c" stroke-width="2.5"/>
            <!-- Speisepunkt -->
            <circle :cx="dipGeom.feedX" :cy="dipGeom.cy" r="6" fill="var(--acc)"/>
            <text :x="dipGeom.feedX" :y="dipGeom.cy + 22" text-anchor="middle" font-size="11" fill="var(--acc)">50Ω</text>
            <text :x="dipGeom.coilStartX + dipGeom.coilW / 2" :y="dipGeom.cy - dipGeom.amp * 2 - 14"
                  text-anchor="middle" font-size="12" font-weight="bold" fill="#fb923c">
              {{ result.windungen }} Wdg.
            </text>
            <text :x="dipGeom.feedX - dipGeom.hPx / 2" :y="dipGeom.cy - 18" text-anchor="middle" font-size="11" fill="var(--ts)">
              ← {{ fmt(result.h, 2) }} m →
            </text>
            <text :x="dipSVG.W / 2" :y="dipSVG.H - 6" text-anchor="middle" font-size="11" fill="var(--ts)">
              λ/2 Dipol – ein Schenkel
            </text>
          </svg>
        </div>
      </div>
    </template>
  </template>

  <div class="card">
    <h2>Formeln</h2>
    <div class="rr"><span class="lbl">Wellenwiderstand Z₀</span><span class="val">60 × (ln(2h/d) – 1)</span></div>
    <div class="rr"><span class="lbl">Elektr. Länge G</span><span class="val">360 × h / λ</span></div>
    <div class="rr"><span class="lbl">Blindwiderstand Xa</span><span class="val">–Z₀ / tan(G°)</span></div>
    <div class="rr"><span class="lbl">Induktivität L</span><span class="val">Xa / (2π × f)</span></div>
    <div class="rr"><span class="lbl">Windungen N</span><span class="val">Wheeler-Formel (einlagige Luftspule)</span></div>
  </div>

  <RechnerBeschreibung name="strahlerverl" />
</template>

<style scoped>
.ken-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
.ken {
  background: var(--card2); border: 1px solid var(--sep);
  border-radius: 8px; padding: 12px 10px; text-align: center;
}
.ken.hi { border-color: var(--acc); }
.ken-val { font-size: 16px; font-weight: 700; color: var(--tp); font-family: 'SF Mono', 'Cascadia Mono', monospace; }
.ken.hi .ken-val { color: var(--acc); }
.ken-lbl { font-size: 10px; color: var(--ts); margin-top: 4px; text-transform: uppercase; letter-spacing: 0.5px; }
@media(max-width:560px){ .ken-grid { grid-template-columns: 1fr 1fr; } }
</style>
