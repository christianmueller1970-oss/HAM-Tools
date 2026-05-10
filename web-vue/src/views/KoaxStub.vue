<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const ks = reactive({ freq: '14.175', vf: 0.66, typ: 'offen' })

const ksBands = [
  ['160m',1.85],['80m',3.65],['40m',7.1],['30m',10.125],
  ['20m',14.175],['17m',18.118],['15m',21.225],['10m',28.5],
]

const result = computed(() => {
  const f = pf(ks.freq)
  if (!f) return null
  return {
    f, vf: ks.vf,
    viertel: 75 / f * ks.vf,
    halb: 150 / f * ks.vf,
  }
})

const SVG_W = 480, SVG_H = 220
const cy = SVG_H * 0.4
const margin = 30
const stubY1 = cy
const stubY2 = cy + SVG_H * 0.38
const stubX = SVG_W * 0.5
</script>

<template>
  <div class="calc-title">Koax-Stub</div>

  <div class="card">
    <h2>Eingabe</h2>
    <div class="band-grid" style="grid-template-columns:repeat(4,1fr);margin-bottom:10px">
      <button v-for="[name, f] in ksBands" :key="name"
              class="bb" :class="{ on: Math.abs(pf(ks.freq) - f) < 0.5 }"
              @click="ks.freq = String(f)">{{ name }}</button>
    </div>
    <div class="inp-grid">
      <div class="inp-g">
        <label>Frequenz</label>
        <div class="inp-row"><input type="text" v-model="ks.freq"><span>MHz</span></div>
      </div>
      <div class="inp-g">
        <label>Koax Verkürzungsfaktor VF</label>
        <div class="seg">
          <button class="sb" :class="{ on: ks.vf === 0.66 }" @click="ks.vf = 0.66">0.66 (Schaum)</button>
          <button class="sb" :class="{ on: ks.vf === 0.82 }" @click="ks.vf = 0.82">0.82 (PVC)</button>
          <button class="sb" :class="{ on: ks.vf === 0.85 }" @click="ks.vf = 0.85">0.85 (PE)</button>
        </div>
      </div>
    </div>
    <div class="inp-g" style="margin-top:10px">
      <label>Stub-Abschluss</label>
      <div class="seg">
        <button class="sb" :class="{ on: ks.typ === 'offen' }" @click="ks.typ = 'offen'">Offen (open stub)</button>
        <button class="sb" :class="{ on: ks.typ === 'kurz' }" @click="ks.typ = 'kurz'">Kurzschluss (shorted stub)</button>
      </div>
    </div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Längen</h2>
      <div class="rr hi"><span class="lbl">λ/4 Stub-Länge</span>
        <span class="val">{{ fmt(result.viertel) }} m  ({{ (result.viertel * 100).toFixed(1) }} cm)</span>
      </div>
      <div class="rr"><span class="lbl">λ/2 Stub-Länge</span>
        <span class="val">{{ fmt(result.halb) }} m  ({{ (result.halb * 100).toFixed(1) }} cm)</span>
      </div>
      <div class="rr"><span class="lbl">VF</span><span class="val">{{ result.vf.toFixed(2) }}</span></div>
      <div class="rr"><span class="lbl">Frequenz</span><span class="val">{{ fmt(result.f) }} MHz</span></div>
    </div>

    <div class="card">
      <h2>Wirkung</h2>
      <template v-if="ks.typ === 'offen'">
        <div class="rr"><span class="lbl">λ/4 offen</span><span class="val">Wirkt wie Kurzschluss → Bandsperre (Seriensperrer)</span></div>
        <div class="rr"><span class="lbl">λ/2 offen</span><span class="val">Wirkt wie Leerlauf → transparent (kein Einfluss)</span></div>
        <div class="rr"><span class="lbl">Anwendung</span><span class="val">Oberwellen-Unterdrückung, Bandsperre</span></div>
      </template>
      <template v-else>
        <div class="rr"><span class="lbl">λ/4 kurz</span><span class="val">Wirkt wie Leerlauf → transparent (kein Einfluss)</span></div>
        <div class="rr"><span class="lbl">λ/2 kurz</span><span class="val">Wirkt wie Kurzschluss → Bandsperre</span></div>
        <div class="rr"><span class="lbl">Anwendung</span><span class="val">Mantelwellensperre, Potentialtrennung</span></div>
      </template>
    </div>

    <div class="card">
      <h2>Schema</h2>
      <div class="skz-bg">
        <svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet">
          <!-- Hauptleitung -->
          <line :x1="margin" :y1="cy" :x2="SVG_W - margin" :y2="cy"
                stroke="#60a5fa" stroke-width="3"/>

          <!-- Stub senkrecht -->
          <line :x1="stubX" :y1="stubY1" :x2="stubX" :y2="stubY2"
                stroke="#fb923c" stroke-width="2.5"/>

          <!-- Abschluss: offen oder Kurzschluss (GND) -->
          <template v-if="ks.typ === 'offen'">
            <circle :cx="stubX" :cy="stubY2" r="5" fill="none" stroke="#fb923c" stroke-width="2"/>
            <text :x="stubX" :y="stubY2 + 18" text-anchor="middle" font-size="10" fill="#fb923c">offen</text>
          </template>
          <template v-else>
            <line :x1="stubX - 12" :y1="stubY2" :x2="stubX + 12" :y2="stubY2" stroke="#fb923c" stroke-width="2"/>
            <line :x1="stubX - 8" :y1="stubY2 + 5" :x2="stubX + 8" :y2="stubY2 + 5" stroke="#fb923c" stroke-width="1"/>
            <line :x1="stubX - 4" :y1="stubY2 + 10" :x2="stubX + 4" :y2="stubY2 + 10" stroke="#fb923c" stroke-width="1"/>
            <text :x="stubX" :y="stubY2 + 24" text-anchor="middle" font-size="10" fill="#fb923c">GND</text>
          </template>

          <!-- Speisepunkt -->
          <circle :cx="stubX" :cy="stubY1" r="4" fill="var(--acc)"/>

          <!-- Labels -->
          <text :x="margin" :y="cy - 14" text-anchor="start" font-size="10" fill="var(--ts)">Einspeisung →</text>
          <text :x="SVG_W - margin" :y="cy - 14" text-anchor="end" font-size="10" fill="var(--ts)">→ Last</text>
          <text :x="stubX + 14" :y="(stubY1 + stubY2) / 2" text-anchor="start" font-size="10" font-weight="bold" fill="#fb923c">
            λ/4 = {{ fmt(result.viertel) }} m
          </text>
        </svg>
      </div>
    </div>
  </template>

  <RechnerBeschreibung name="koaxstub" />
</template>
