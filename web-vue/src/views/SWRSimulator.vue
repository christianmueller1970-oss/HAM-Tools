<script setup>
import { reactive, computed, watch } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const sw = reactive({ swr: 1.5, leistung: '100', z0: 50, swrMax: 5.0 })

watch(() => sw.swrMax, (newMax) => {
  if (sw.swr > newMax) sw.swr = newMax
})

const result = computed(() => {
  const s = sw.swr
  const p = Math.max(pf(sw.leistung), 0.001)
  const gamma = (s - 1) / (s + 1)
  const gamma2 = gamma * gamma
  const ruecklauf = gamma2 * p
  const ausgang = p - ruecklauf
  const verlustProzent = gamma2 * 100
  const rl = gamma > 0 ? -20 * Math.log10(gamma) : Infinity
  const mismatch = -10 * Math.log10(1 - gamma2)
  const zLast = sw.z0 * s
  let bewertung, farbe
  if (s <= 1.5) { bewertung = 'gut'; farbe = '#22c55e' }
  else if (s <= 2.5) { bewertung = 'mittel'; farbe = '#f0c000' }
  else if (s <= 4.0) { bewertung = 'hoch'; farbe = '#fb923c' }
  else { bewertung = 'gefahr'; farbe = '#ef4444' }
  return { gamma, gamma2, ruecklauf, ausgang, verlustProzent, rl, mismatch, zLast, bewertung, farbe }
})

const bewertungInfo = computed(() => {
  const m = {
    gut:    { icon: '✓', label: 'Sehr gut',          title: '',                          text: '' },
    mittel: { icon: '!', label: 'Akzeptabel',        title: 'Leichte Fehlanpassung',     text: 'Für die meisten Betriebsarten noch akzeptabel. Ein Tuner verbessert die Effizienz.' },
    hoch:   { icon: '⚠', label: 'Tuner empfohlen',   title: 'Hoher SWR – Tuner empfohlen', text: 'Die Fehlanpassung verursacht messbare Leistungsverluste und belastet den PA.' },
    gefahr: { icon: '✗', label: 'Gefahr für Endstufe', title: 'Gefahr für die Endstufe!', text: 'Viele Transceiver schalten bei SWR > 4 die Leistung automatisch zurück. Sofortige Anpassung erforderlich.' },
  }
  return m[result.value.bewertung]
})

// Chart: Effizienz vs. SWR
const chartW = 600, chartH = 200
const chartPadL = 36, chartPadR = 16, chartPadT = 16, chartPadB = 28
const chartInnerW = chartW - chartPadL - chartPadR
const chartInnerH = chartH - chartPadT - chartPadB

const chartCurve = computed(() => {
  const points = []
  for (let i = 0; i <= 100; i++) {
    const s = 1.0 + i / 100 * (sw.swrMax - 1.0)
    const g = (s - 1) / (s + 1)
    const eff = (1 - g * g) * 100
    const x = chartPadL + (s - 1) / (sw.swrMax - 1) * chartInnerW
    const y = chartPadT + (1 - eff / 100) * chartInnerH
    points.push({ x, y, s, eff })
  }
  return points
})

const chartLinePath = computed(() => {
  return chartCurve.value.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(' ')
})

const chartAreaPath = computed(() => {
  const baseY = chartPadT + chartInnerH
  const line = chartCurve.value.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(' ')
  const lastX = chartCurve.value[chartCurve.value.length - 1].x
  const firstX = chartCurve.value[0].x
  return `${line} L ${lastX} ${baseY} L ${firstX} ${baseY} Z`
})

const aktX = computed(() => chartPadL + (sw.swr - 1) / (sw.swrMax - 1) * chartInnerW)
const aktEff = computed(() => (1 - result.value.gamma2) * 100)
const aktY = computed(() => chartPadT + (1 - aktEff.value / 100) * chartInnerH)

const presetMarks = [1.5, 2.0, 3.0, 4.0]
</script>

<template>
  <div class="calc-title">SWR-Simulator</div>

  <div class="card">
    <h2>Parameter</h2>
    <div class="inp-grid3">
      <div class="inp-g"><label>Sendeleistung</label><div class="inp-row"><input type="text" v-model="sw.leistung"><span>W</span></div></div>
      <div class="inp-g">
        <label>Systemimpedanz Z₀</label>
        <div class="seg">
          <button class="sb" :class="{ on: sw.z0 === 50 }" @click="sw.z0 = 50">50 Ω</button>
          <button class="sb" :class="{ on: sw.z0 === 75 }" @click="sw.z0 = 75">75 Ω</button>
        </div>
      </div>
      <div class="inp-g">
        <label>Slider-Maximum</label>
        <div class="seg">
          <button class="sb" :class="{ on: sw.swrMax === 5.0 }" @click="sw.swrMax = 5.0">SWR 5</button>
          <button class="sb" :class="{ on: sw.swrMax === 10.0 }" @click="sw.swrMax = 10.0">SWR 10</button>
        </div>
      </div>
    </div>
    <div style="margin-top:14px">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px">
        <span class="small">SWR</span>
        <span class="mono fw7" :style="{ color: result.farbe, fontSize: '14px' }">1 : {{ sw.swr.toFixed(2) }}</span>
      </div>
      <input type="range" :min="1.0" :max="sw.swrMax" :step="0.05" v-model.number="sw.swr"
             :style="{ '--slider-color': result.farbe }" class="swr-slider">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-top:6px;gap:8px">
        <span class="small" style="font-size:10px">1:1</span>
        <button v-for="m in presetMarks.filter(x => x <= sw.swrMax)" :key="m"
                class="sb" :class="{ on: Math.abs(sw.swr - m) < 0.03 }" @click="sw.swr = m"
                style="padding:3px 8px;font-size:10px">
          1:{{ m.toFixed(1) }}
        </button>
        <span class="small" style="font-size:10px">1:{{ sw.swrMax.toFixed(0) }}</span>
      </div>
    </div>
  </div>

  <!-- Große SWR-Anzeige -->
  <div class="swr-display" :style="{ borderColor: result.farbe + '66' }">
    <div class="small">Aktuelles SWR</div>
    <div class="swr-big mono" :style="{ color: result.farbe }">1 : {{ sw.swr.toFixed(2) }}</div>
    <div :style="{ color: result.farbe }" style="font-size:14px;font-weight:600">
      {{ bewertungInfo.icon }} {{ bewertungInfo.label }}
    </div>
    <div class="swr-bar" :style="{ background: result.farbe }"></div>
  </div>

  <div class="card">
    <h2>Leistungsverteilung</h2>
    <div class="balken-row">
      <span class="balken-lbl">Vorlauf</span>
      <div class="balken-bg"><div class="balken-fill" style="background:#60a5fa;width:100%"></div></div>
      <span class="balken-val">{{ pf(sw.leistung).toFixed(1) }} W</span>
    </div>
    <div class="balken-row">
      <span class="balken-lbl">Rücklauf</span>
      <div class="balken-bg"><div class="balken-fill" :style="{ background: '#ef4444', width: Math.min(result.gamma2 * 100, 100) + '%' }"></div></div>
      <span class="balken-val">{{ result.ruecklauf.toFixed(2) }} W</span>
    </div>
    <div class="balken-row">
      <span class="balken-lbl">Verlust</span>
      <div class="balken-bg"><div class="balken-fill" :style="{ background: '#fb923c', width: Math.min(result.gamma2 * 100, 100) + '%' }"></div></div>
      <span class="balken-val">{{ result.verlustProzent.toFixed(1) }} %</span>
    </div>
  </div>

  <div class="card">
    <h2>Kenngrößen</h2>
    <div class="ken-grid">
      <div class="ken hi" :style="{ borderColor: result.farbe + '66' }">
        <div class="ken-val" :style="{ color: result.farbe }">{{ result.ausgang.toFixed(2) }} W</div>
        <div class="ken-lbl">An der Antenne</div>
      </div>
      <div class="ken"><div class="ken-val">{{ result.gamma.toFixed(4) }}</div><div class="ken-lbl">Reflexionsfaktor Γ</div></div>
      <div class="ken"><div class="ken-val">{{ isFinite(result.rl) ? result.rl.toFixed(1) + ' dB' : '∞' }}</div><div class="ken-lbl">Rückflussdämpfung</div></div>
      <div class="ken"><div class="ken-val">{{ result.mismatch.toFixed(2) }} dB</div><div class="ken-lbl">Mismatch-Verlust</div></div>
      <div class="ken"><div class="ken-val">{{ result.zLast.toFixed(0) }} Ω</div><div class="ken-lbl">Z-Last ({{ sw.z0 }} Ω)</div></div>
      <div class="ken"><div class="ken-val">{{ (100 - result.verlustProzent).toFixed(1) }} %</div><div class="ken-lbl">Effizienz</div></div>
    </div>
  </div>

  <div v-if="result.bewertung !== 'gut'" class="card warn-box" :style="{ background: result.farbe + '14', borderLeftColor: result.farbe }">
    <div style="display:flex;gap:12px;align-items:flex-start">
      <span :style="{ color: result.farbe, fontSize: '18px' }">{{ bewertungInfo.icon }}</span>
      <div>
        <div style="font-weight:600;color:var(--tp);margin-bottom:4px">{{ bewertungInfo.title }}</div>
        <div class="small">{{ bewertungInfo.text }}</div>
      </div>
    </div>
  </div>

  <div class="card">
    <h2>Effizienz vs. SWR</h2>
    <div class="skz-bg">
      <svg :viewBox="`0 0 ${chartW} ${chartH}`" preserveAspectRatio="xMidYMid meet">
        <!-- Y-Achse Beschriftung -->
        <line :x1="chartPadL" :y1="chartPadT" :x2="chartPadL" :y2="chartPadT + chartInnerH"
              stroke="rgba(140,140,140,0.4)" stroke-width="1"/>
        <line :x1="chartPadL" :y1="chartPadT + chartInnerH" :x2="chartPadL + chartInnerW" :y2="chartPadT + chartInnerH"
              stroke="rgba(140,140,140,0.4)" stroke-width="1"/>

        <!-- Y-Achsen-Werte -->
        <text v-for="y in [0, 25, 50, 75, 100]" :key="y"
              :x="chartPadL - 6" :y="chartPadT + (1 - y / 100) * chartInnerH + 3"
              text-anchor="end" font-size="9" fill="var(--ts)">{{ y }}%</text>

        <!-- X-Achsen-Werte -->
        <text v-for="i in [1, 2, 3, 4, 5].filter(n => n <= sw.swrMax)" :key="i"
              :x="chartPadL + (i - 1) / (sw.swrMax - 1) * chartInnerW" :y="chartPadT + chartInnerH + 16"
              text-anchor="middle" font-size="9" fill="var(--ts)">1:{{ i }}</text>

        <!-- Area unter Kurve mit Gradient -->
        <defs>
          <linearGradient id="effGrad" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#22c55e" stop-opacity="0.3"/>
            <stop offset="100%" stop-color="#ef4444" stop-opacity="0.3"/>
          </linearGradient>
        </defs>
        <path :d="chartAreaPath" fill="url(#effGrad)"/>

        <!-- Kurve -->
        <path :d="chartLinePath" fill="none" stroke="var(--acc)" stroke-width="2"/>

        <!-- Aktueller SWR Marker -->
        <line :x1="aktX" :y1="chartPadT" :x2="aktX" :y2="chartPadT + chartInnerH"
              :stroke="result.farbe" stroke-width="1.2" stroke-dasharray="4,3" opacity="0.6"/>
        <circle :cx="aktX" :cy="aktY" r="6" :fill="result.farbe"/>
        <text :x="aktX + 10" :y="aktY - 4" font-size="11" font-weight="bold" :fill="result.farbe">
          {{ aktEff.toFixed(0) }}%
        </text>
      </svg>
    </div>
  </div>

  <RechnerBeschreibung name="swr" />
</template>

<style scoped>
.swr-slider { width: 100%; height: 6px; appearance: none; background: var(--sub); border-radius: 3px; outline: none; cursor: pointer; }
.swr-slider::-webkit-slider-thumb { appearance: none; width: 18px; height: 18px; border-radius: 50%; background: var(--slider-color, var(--acc)); cursor: pointer; border: 2px solid var(--bg); }
.swr-slider::-moz-range-thumb { width: 18px; height: 18px; border-radius: 50%; background: var(--slider-color, var(--acc)); cursor: pointer; border: 2px solid var(--bg); }

.swr-display {
  background: var(--card2); border: 2px solid;
  border-radius: 14px; padding: 24px; margin-bottom: 14px; text-align: center;
}
.swr-big { font-size: 52px; font-weight: 900; line-height: 1; margin: 8px 0; font-family: 'SF Mono', 'Cascadia Mono', monospace; }
.swr-bar { height: 4px; border-radius: 2px; margin: 12px 40px 0; }

.balken-row { display: flex; align-items: center; gap: 10px; padding: 6px 0; }
.balken-lbl { width: 70px; text-align: right; font-size: 12px; color: var(--ts); }
.balken-bg { flex: 1; height: 22px; background: var(--sub); border-radius: 5px; overflow: hidden; }
.balken-fill { height: 100%; transition: width 0.25s; opacity: 0.85; border-radius: 5px; }
.balken-val { width: 90px; text-align: right; font-family: 'SF Mono', 'Cascadia Mono', monospace; font-size: 13px; font-weight: 700; color: var(--tp); }

.ken-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
.ken {
  background: var(--card2); border: 1px solid var(--sep);
  border-radius: 8px; padding: 12px 10px; text-align: center;
}
.ken.hi { border-width: 1.5px; }
.ken-val { font-size: 16px; font-weight: 700; color: var(--tp); font-family: 'SF Mono', 'Cascadia Mono', monospace; }
.ken-lbl { font-size: 10px; color: var(--ts); margin-top: 4px; text-transform: uppercase; letter-spacing: 0.5px; }

.warn-box { border-left: 4px solid; padding: 14px; }
@media(max-width:560px){ .ken-grid { grid-template-columns: 1fr 1fr; } }
</style>
