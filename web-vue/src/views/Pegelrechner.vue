<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const peg = reactive({ mode: 'watt', value: '100', Z: 50 })

const modes = [
  { id: 'watt', label: 'W' },
  { id: 'mw',   label: 'mW' },
  { id: 'dbm',  label: 'dBm' },
  { id: 'dbw',  label: 'dBW' },
  { id: 'volt', label: 'V' },
]

const result = computed(() => {
  const v = pf(peg.value)
  if (!v || v <= 0) return null
  let P_W
  switch (peg.mode) {
    case 'watt': P_W = v; break
    case 'mw':   P_W = v / 1000; break
    case 'dbm':  P_W = Math.pow(10, (v - 30) / 10); break
    case 'dbw':  P_W = Math.pow(10, v / 10); break
    case 'volt': P_W = v * v / peg.Z; break
    default: return null
  }
  return {
    W: P_W, mW: P_W * 1000,
    dBm: 10 * Math.log10(P_W * 1000),
    dBW: 10 * Math.log10(P_W),
    V50: Math.sqrt(P_W * 50),
  }
})

const unitLabel = computed(() => modes.find(m => m.id === peg.mode)?.label || '')

const refs = [
  ['QRP (5 W)', 5], ['10 W', 10], ['100 W', 100], ['1 kW', 1000],
]

function fmtWatt(w) {
  if (w >= 1000) return (w / 1000).toFixed(2) + ' k'
  if (w >= 1) return w.toFixed(3)
  if (w >= 0.001) return (w * 1000).toFixed(3) + ' m'
  return (w * 1e6).toFixed(3) + ' µ'
}
</script>

<template>
  <div class="calc-title">Pegel-Umrechner</div>

  <div class="card">
    <h2>Eingabe</h2>
    <div class="seg" style="margin-bottom:10px">
      <button v-for="m in modes" :key="m.id" class="sb" :class="{ on: peg.mode === m.id }" @click="peg.mode = m.id">
        {{ m.label }}
      </button>
    </div>
    <div class="inp-grid">
      <div class="inp-g">
        <label>Wert</label>
        <div class="inp-row"><input type="text" v-model="peg.value"><span>{{ unitLabel }}</span></div>
      </div>
      <div v-if="peg.mode === 'volt'" class="inp-g">
        <label>Impedanz</label>
        <div class="seg">
          <button class="sb" :class="{ on: peg.Z === 50 }" @click="peg.Z = 50">50 Ω</button>
          <button class="sb" :class="{ on: peg.Z === 75 }" @click="peg.Z = 75">75 Ω</button>
          <button class="sb" :class="{ on: peg.Z === 600 }" @click="peg.Z = 600">600 Ω</button>
        </div>
      </div>
    </div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Ergebnisse</h2>
      <div class="rr" :class="{ hi: peg.mode === 'watt' }">
        <span class="lbl">Leistung</span><span class="val">{{ fmtWatt(result.W) }} W</span>
      </div>
      <div class="rr" :class="{ hi: peg.mode === 'mw' }">
        <span class="lbl">Leistung</span><span class="val">{{ fmt(result.mW, 3) }} mW</span>
      </div>
      <div class="rr" :class="{ hi: peg.mode === 'dbm' }">
        <span class="lbl">Pegel</span><span class="val">{{ fmt(result.dBm, 2) }} dBm</span>
      </div>
      <div class="rr" :class="{ hi: peg.mode === 'dbw' }">
        <span class="lbl">Pegel</span><span class="val">{{ fmt(result.dBW, 2) }} dBW</span>
      </div>
      <div class="rr" :class="{ hi: peg.mode === 'volt' }">
        <span class="lbl">Spannung (50 Ω)</span><span class="val">{{ fmt(result.V50, 3) }} V</span>
      </div>
    </div>

    <div class="card">
      <h2>Referenzpegel Amateurfunk</h2>
      <div v-for="[name, refW] in refs" :key="name" class="rr">
        <span class="lbl">{{ name }}</span>
        <span class="val">
          <template v-if="(10 * Math.log10(result.W / refW)) >= 0">+</template>{{ fmt(10 * Math.log10(result.W / refW), 1) }} dB
        </span>
      </div>
    </div>
  </template>

  <RechnerBeschreibung name="pegelrechner" />
</template>
