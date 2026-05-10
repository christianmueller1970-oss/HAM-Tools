<script setup>
import { reactive, computed } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const lnk = reactive({ ptx: '100', gtx: '0', grx: '0', freq: '14.175', dist: '100', sens: -120 })

const lnkBands = [
  ['160m',1.85],['80m',3.65],['40m',7.1],['20m',14.175],
  ['15m',21.225],['10m',28.5],['2m',145.0],['70cm',432.0],
]

const result = computed(() => {
  const ptx_W = pf(lnk.ptx), gtx = pf(lnk.gtx), grx = pf(lnk.grx)
  const f = pf(lnk.freq), d = pf(lnk.dist)
  if (!ptx_W || !f || !d) return null
  const ptx_dBm = 10 * Math.log10(ptx_W * 1000)
  const fspl = 20 * Math.log10(d) + 20 * Math.log10(f) + 32.45
  const prx_dBm = ptx_dBm + gtx + grx - fspl
  const prx_W = Math.pow(10, prx_dBm / 10) / 1000
  const prx_uV = Math.sqrt(Math.max(prx_W, 1e-30) * 50) * 1e6
  return { ptx_W, ptx_dBm, gtx, grx, fspl, prx_dBm, prx_uV }
})

const margin = computed(() => result.value ? result.value.prx_dBm - lnk.sens : 0)
const linkOK = computed(() => margin.value >= 0)
</script>

<template>
  <div class="calc-title">Linkbudget / Reichweite</div>

  <div class="card">
    <h2>Eingabe</h2>
    <div class="band-grid" style="grid-template-columns:repeat(4,1fr);margin-bottom:10px">
      <button v-for="[name, f] in lnkBands" :key="name"
              class="bb" :class="{ on: Math.abs(pf(lnk.freq) - f) < 1 }"
              @click="lnk.freq = String(f)">{{ name }}</button>
    </div>
    <div class="inp-grid3">
      <div class="inp-g"><label>TX-Leistung</label><div class="inp-row"><input type="text" v-model="lnk.ptx"><span>W</span></div></div>
      <div class="inp-g"><label>TX-Gewinn</label><div class="inp-row"><input type="text" v-model="lnk.gtx"><span>dBi</span></div></div>
      <div class="inp-g"><label>RX-Gewinn</label><div class="inp-row"><input type="text" v-model="lnk.grx"><span>dBi</span></div></div>
      <div class="inp-g"><label>Frequenz</label><div class="inp-row"><input type="text" v-model="lnk.freq"><span>MHz</span></div></div>
      <div class="inp-g"><label>Distanz</label><div class="inp-row"><input type="text" v-model="lnk.dist"><span>km</span></div></div>
      <div class="inp-g">
        <label>RX-Empfindlichkeit</label>
        <div class="seg">
          <button v-for="s in [-100,-110,-120,-130]" :key="s" class="sb" :class="{ on: lnk.sens === s }" @click="lnk.sens = s">
            {{ s }} dBm
          </button>
        </div>
      </div>
    </div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Ergebnis</h2>
      <div class="rr"><span class="lbl">TX-Leistung</span><span class="val">{{ fmt(result.ptx_dBm, 1) }} dBm  ({{ result.ptx_W.toFixed(0) }} W)</span></div>
      <div class="rr"><span class="lbl">TX-Gewinn</span><span class="val">{{ fmt(result.gtx, 1) }} dBi</span></div>
      <div class="rr"><span class="lbl">RX-Gewinn</span><span class="val">{{ fmt(result.grx, 1) }} dBi</span></div>
      <div class="rr"><span class="lbl">Freiraumdämpfung FSPL</span><span class="val">{{ fmt(result.fspl, 1) }} dB</span></div>
      <hr class="div">
      <div class="rr hi"><span class="lbl">Empfangspegel</span><span class="val">{{ fmt(result.prx_dBm, 1) }} dBm</span></div>
      <div class="rr"><span class="lbl">Empfangspegel</span><span class="val">{{ fmt(result.prx_uV, 3) }} µV (an 50 Ω)</span></div>
    </div>

    <div class="card">
      <h2>Link-Margin</h2>
      <div class="margin-row">
        <span class="margin-icon" :class="linkOK ? 'ok' : 'fail'">{{ linkOK ? '✓' : '✗' }}</span>
        <div>
          <div class="margin-title">{{ linkOK ? 'Verbindung möglich' : 'Verbindung nicht sicher' }}</div>
          <div class="small">Margin: {{ margin >= 0 ? '+' : '' }}{{ fmt(margin, 1) }} dB über Empfindlichkeit ({{ lnk.sens }} dBm)</div>
          <div v-if="!linkOK" class="small c-orn" style="margin-top:4px">
            Leistung erhöhen, bessere Antenne oder kürzere Distanz.
          </div>
        </div>
      </div>
    </div>
  </template>

  <RechnerBeschreibung name="linkbudget" />
</template>

<style scoped>
.margin-row { display: flex; gap: 14px; align-items: center; }
.margin-icon {
  width: 32px; height: 32px;
  border-radius: 50%;
  display: inline-flex; align-items: center; justify-content: center;
  font-size: 18px; font-weight: bold;
  flex-shrink: 0;
}
.margin-icon.ok { background: var(--grn); color: #fff; }
.margin-icon.fail { background: var(--red); color: #fff; }
.margin-title { font-size: 14px; font-weight: 600; color: var(--tp); margin-bottom: 4px; }
</style>
