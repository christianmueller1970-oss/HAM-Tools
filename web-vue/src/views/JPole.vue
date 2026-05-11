<script setup>
import { reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { pf, fmt, isBandActive } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'
import { openInSim } from '../composables/openInSim.js'

const router = useRouter()
const jp = reactive({ freq: '145.0', vf: '0.95', typ: 'jpole' })

const jpBands = [
  ['10m', 28.5], ['6m', 50.15], ['4m', 70.0],
  ['2m', 145.0], ['70cm', 432.0], ['23cm', 1296.0],
]

const result = computed(() => {
  const f = pf(jp.freq), vf = pf(jp.vf)
  if (!f || !vf) return null
  const strahler = 150 / f * vf
  const stub = 75 / f * vf
  const pct = jp.typ === 'jpole' ? 0.05 : 0.04
  const feed = stub * pct
  return { f, vf, strahler, stub, gesamt: strahler + stub, feed, feedProzent: pct * 100 }
})

// SVG: Skizze (J-Pole vertikal)
const SVG_W = 360, SVG_H = 320
const cx = SVG_W / 2
const topY = 16, botY = SVG_H - 24
const totalPx = botY - topY

const stubTop = computed(() => result.value
  ? botY - totalPx * (result.value.strahler / result.value.gesamt) : 0)
const feedY = computed(() => result.value
  ? botY - totalPx * (result.value.feed / result.value.gesamt) : 0)

// ─── Im Sim öffnen ───────────────────────────────────────────────────────────
// J-Pole = λ/4 Stub + λ/2 Strahler, parallele Leiter mit ~25-50mm Abstand
// am Boden kurzgeschlossen. Einspeisepunkt ~5% vom Boden auf dem Stub-Bein.
function imSimOeffnen() {
  if (!result.value) return
  const r = result.value
  const lambda = 300 / r.f
  const zBase = Math.max(3, lambda * 0.5)   // J-Pole-Basis über Boden
  const d = 0.03                            // 30mm Leiterabstand
  // Strahler-Leiter: vom Stub-Top hoch auf gesamte Höhe (Strahler λ/2)
  // Stub-Leiter:    vom Stub-Top runter um λ/4
  // Kurzschluss am Boden + Einspeisung bei feed-Höhe
  const zStubBottom = zBase
  const zStubTop    = zBase + r.stub
  const zRadTop     = zStubTop + r.strahler
  const zFeed       = zBase + r.feed
  const wires = [
    // Rechter Leiter (Strahler-Seite): vom Stub-Bottom durch Stub-Top bis Strahler-Top
    { tag: 1, segments: 9,  x1: d/2, y1: 0, z1: zStubBottom, x2: d/2, y2: 0, z2: zStubTop, radius_mm: 2.0 },
    { tag: 2, segments: 17, x1: d/2, y1: 0, z1: zStubTop,    x2: d/2, y2: 0, z2: zRadTop,  radius_mm: 2.0 },
    // Linker Leiter (Stub-Seite, parallel, kürzer — endet am Stub-Top)
    { tag: 3, segments: 9,  x1: -d/2, y1: 0, z1: zStubBottom, x2: -d/2, y2: 0, z2: zStubTop, radius_mm: 2.0 },
    // Kurzschluss am Boden (horizontaler Verbinder)
    { tag: 4, segments: 3,  x1: -d/2, y1: 0, z1: zStubBottom, x2: d/2,  y2: 0, z2: zStubBottom, radius_mm: 2.0 },
  ]
  // Slim Jim: Strahler-Top hat noch einen offenen Ablauf — approximieren wir nicht (würde NEC2-Tuning brauchen)
  openInSim(router, {
    name: `${jp.typ === 'slimjim' ? 'Slim Jim' : 'J-Pole'} ${r.gesamt.toFixed(2)}m @ ${r.f} MHz`,
    freq: r.f,
    ground: 'average',
    height: zBase,
    wires,
    // Speisung am rechten Leiter, am Feed-Punkt (~5% des Stubs vom Boden)
    excitation: { wire_tag: 1, segment: Math.max(1, Math.round(9 * (zFeed - zStubBottom) / (zStubTop - zStubBottom))) },
  })
}
</script>

<template>
  <div class="calc-title">J-Pole / Slim Jim</div>

  <div class="card">
    <h2>Variante</h2>
    <div class="opt-grid">
      <button class="opt-btn" :class="{ active: jp.typ === 'jpole' }" @click="jp.typ = 'jpole'">
        <div class="opt-label">J-Pole</div>
        <div class="opt-sub">λ/2 + λ/4 Anpass-Stub, Feed ~5%</div>
      </button>
      <button class="opt-btn" :class="{ active: jp.typ === 'slimjim' }" @click="jp.typ = 'slimjim'">
        <div class="opt-label">Slim Jim / J-Zepp</div>
        <div class="opt-sub">Strahler einseitig offen, +3 dB</div>
      </button>
    </div>
  </div>

  <div class="card">
    <h2>Eingabe</h2>
    <div class="band-grid" style="margin-bottom:10px">
      <button v-for="[name, f] in jpBands" :key="name"
              class="bb" :class="{ on: Math.abs(pf(jp.freq) - f) < 1.0 }"
              @click="jp.freq = String(f)">{{ name }}</button>
    </div>
    <div class="inp-grid">
      <div class="inp-g"><label>Frequenz</label><div class="inp-row"><input type="text" v-model="jp.freq"><span>MHz</span></div></div>
      <div class="inp-g"><label>Verkürzungsfaktor VF</label><div class="inp-row"><input type="text" v-model="jp.vf"></div></div>
    </div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Maße</h2>
      <div class="rr hi"><span class="lbl">Gesamtlänge (3/4 λ)</span><span class="val">{{ fmt(result.gesamt) }} m</span></div>
      <div class="rr"><span class="lbl">Strahler (λ/2)</span><span class="val">{{ fmt(result.strahler) }} m</span></div>
      <div class="rr"><span class="lbl">Anpass-Stub (λ/4)</span><span class="val">{{ fmt(result.stub) }} m</span></div>
      <div class="rr"><span class="lbl">Einspeisepunkt ab unten</span><span class="val">{{ fmt(result.feed) }} m  ({{ result.feedProzent.toFixed(0) }}% des Stubs)</span></div>
      <div class="rr"><span class="lbl">Speisepunkt-Impedanz</span><span class="val">≈ 50 Ω am Einspeisepunkt</span></div>
      <div class="rr"><span class="lbl">Frequenz</span><span class="val">{{ fmt(result.f) }} MHz</span></div>
      <div style="margin-top:12px; text-align:right">
        <button class="btn-sim" @click="imSimOeffnen">📡 Im Sim öffnen</button>
      </div>
    </div>

    <div class="card">
      <h2>Skizze</h2>
      <div class="skz-bg" style="display:flex;justify-content:center">
        <svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet" style="max-height:320px">
          <!-- Strahler (rechter Leiter, blau/accent) -->
          <line :x1="cx + 22" :y1="botY" :x2="cx + 22" :y2="topY"
                stroke="#60a5fa" stroke-width="4" stroke-linecap="round"/>

          <!-- Stub (linker Leiter) -->
          <line :x1="cx - 22" :y1="botY" :x2="cx - 22" :y2="stubTop"
                :stroke="jp.typ === 'slimjim' ? '#fb923c' : 'rgba(140,140,140,0.7)'"
                stroke-width="3" stroke-linecap="round"/>

          <!-- Verbindung unten -->
          <line :x1="cx - 22" :y1="botY" :x2="cx + 22" :y2="botY"
                stroke="rgba(140,140,140,0.7)" stroke-width="2"/>

          <!-- Offenes Ende des Stubs -->
          <line :x1="cx - 30" :y1="stubTop" :x2="cx - 14" :y2="stubTop"
                stroke="rgba(140,140,140,0.7)" stroke-width="2"/>

          <!-- Einspeisepunkt -->
          <circle :cx="cx - 22" :cy="feedY" r="5" fill="var(--acc)"/>
          <text :x="cx - 30" :y="feedY + 3" text-anchor="end" font-size="10" font-weight="bold" fill="var(--acc)">50Ω</text>

          <!-- Labels rechts -->
          <text :x="cx + 30" :y="(topY + botY) / 2" text-anchor="start" font-size="10" fill="var(--ts)">
            λ/2  {{ fmt(result.strahler) }} m
          </text>
          <text :x="cx + 30" :y="(stubTop + botY) / 2" text-anchor="start" font-size="10" fill="var(--ts)">
            λ/4  {{ fmt(result.stub) }} m
          </text>
          <text :x="cx - 30" :y="feedY - 8" text-anchor="end" font-size="10" fill="var(--acc)">
            {{ result.feedProzent.toFixed(0) }}%  {{ fmt(result.feed) }} m
          </text>
        </svg>
      </div>
    </div>

  </template>

  <RechnerBeschreibung name="jpole" />
</template>
