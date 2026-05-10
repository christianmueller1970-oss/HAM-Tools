<script setup>
import { reactive, computed, watch } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const allKabel = [
  { id:'rg174',     gruppe:'RG-Typen', name:'RG-174',         beschreibung:'Dünn, flexibel, für kurze Verbindungen',           impedanz:50, db:[8.0,14.0,26.0,32.0,48.0,59.0,100.0,120.0] },
  { id:'rg316',     gruppe:'RG-Typen', name:'RG-316',         beschreibung:'Dünn, PTFE-Dielektrikum, hitzebeständig',          impedanz:50, db:[6.5,11.5,22.0,27.0,41.0,50.0,85.0,102.0] },
  { id:'rg58',      gruppe:'RG-Typen', name:'RG-58',          beschreibung:'Klassisch, günstig, mittlere Dämpfung',            impedanz:50, db:[4.5,7.5,14.0,19.0,28.0,35.0,59.0,70.0] },
  { id:'rg8x',      gruppe:'RG-Typen', name:'RG-8X (Mini-8)', beschreibung:'Kompromiss zwischen RG-58 und RG-213',             impedanz:50, db:[3.0,5.2,9.8,12.5,18.5,22.5,37.0,44.0] },
  { id:'rg8',       gruppe:'RG-Typen', name:'RG-8 / RG-8A',   beschreibung:'Klassisch gross, ähnlich RG-213',                 impedanz:50, db:[2.1,3.7,6.9,8.8,13.0,15.8,26.5,31.5] },
  { id:'rg213',     gruppe:'RG-Typen', name:'RG-213',         beschreibung:'Standard Stationsverkabelung, 10 mm',              impedanz:50, db:[2.0,3.5,6.5,8.5,12.5,15.5,26.0,30.0] },
  { id:'rg214',     gruppe:'RG-Typen', name:'RG-214',         beschreibung:'Mil-Spec, doppelt versilbert',                     impedanz:50, db:[1.9,3.3,6.2,7.8,11.8,14.8,24.5,28.5] },
  { id:'rg393',     gruppe:'RG-Typen', name:'RG-393',         beschreibung:'Mil-Spec, PTFE, sehr robust',                      impedanz:50, db:[1.6,2.8,5.2,6.6,9.8,11.9,19.8,23.5] },
  { id:'ecoflex6',  gruppe:'Ecoflex',  name:'Ecoflex 6',      beschreibung:'Kompakt, flexibel, guter Low-Loss Einstieg',       impedanz:50, db:[2.3,3.9,7.2,9.1,13.4,16.2,27.0,32.0] },
  { id:'ecoflex10', gruppe:'Ecoflex',  name:'Ecoflex 10',     beschreibung:'Beliebt für UKW/UHF Stationsanlagen',              impedanz:50, db:[1.2,2.1,3.9,4.9,7.2,8.7,14.5,17.2] },
  { id:'ecoflex15', gruppe:'Ecoflex',  name:'Ecoflex 15',     beschreibung:'Sehr geringe Dämpfung, 15 mm Durchmesser',         impedanz:50, db:[0.8,1.4,2.6,3.3,4.8,5.8,9.7,11.5] },
  { id:'ecoflex15p',gruppe:'Ecoflex',  name:'Ecoflex 15 Plus',beschreibung:'Verbesserte Version, noch geringere Dämpfung',     impedanz:50, db:[0.75,1.3,2.4,3.0,4.4,5.3,8.9,10.5] },
  { id:'aircell5',  gruppe:'Aircell',  name:'Aircell 5',      beschreibung:'Flexibel, 5 mm, für kurze Zuleitungen',            impedanz:50, db:[2.6,4.5,8.3,10.5,15.5,18.8,31.0,37.0] },
  { id:'aircell7',  gruppe:'Aircell',  name:'Aircell 7',      beschreibung:'Sehr flexibel, geringer Verlust, 7 mm',            impedanz:50, db:[2.2,3.8,7.0,8.9,13.1,15.8,26.2,31.0] },
  { id:'lmr200',    gruppe:'LMR',      name:'LMR-200',        beschreibung:'Flexibel, halbsteif, 5 mm',                        impedanz:50, db:[3.1,5.3,9.9,12.6,18.6,22.5,37.5,44.5] },
  { id:'lmr400',    gruppe:'LMR',      name:'LMR-400',        beschreibung:'Beliebtes Low-Loss Kabel, 10 mm',                  impedanz:50, db:[1.3,2.3,4.3,5.4,8.0,9.7,16.2,19.2] },
  { id:'lmr600',    gruppe:'LMR',      name:'LMR-600',        beschreibung:'Sehr geringe Dämpfung, halbsteif, 15 mm',          impedanz:50, db:[0.85,1.5,2.8,3.5,5.2,6.3,10.5,12.4] },
  { id:'lmr900',    gruppe:'LMR',      name:'LMR-900',        beschreibung:'Profi-Backbone, sehr steif, 23 mm',                impedanz:50, db:[0.55,0.97,1.8,2.3,3.4,4.1,6.9,8.2] },
  { id:'sucofl104', gruppe:'Huber+Suhner', name:'Sucoflex 104', beschreibung:'Flexibles PTFE-Kabel',                           impedanz:50, db:[2.8,4.8,9.0,11.4,16.8,20.3,33.8,40.0] },
  { id:'sucofeed12',gruppe:'Huber+Suhner', name:'Sucofeed 1/2"', beschreibung:'Halbsteifes Feeder-Kabel',                       impedanz:50, db:[0.7,1.2,2.2,2.8,4.1,5.0,8.3,9.8] },
  { id:'suhnersc12',gruppe:'Huber+Suhner', name:'S_FLEX-C 1/2"', beschreibung:'Flexibler 1/2" Feeder',                          impedanz:50, db:[0.72,1.25,2.3,2.9,4.3,5.2,8.7,10.3] },
  { id:'h100',      gruppe:'H-Typen',  name:'H-100',          beschreibung:'Preiswertes Allroundkabel, 6 mm',                  impedanz:50, db:[3.2,5.5,10.2,13.0,19.2,23.2,38.5,45.5] },
  { id:'h155',      gruppe:'H-Typen',  name:'H-155',          beschreibung:'Flexibel, Low Loss, 5 mm',                          impedanz:50, db:[2.9,4.9,9.2,11.6,17.1,20.7,34.3,40.6] },
  { id:'hypflex10', gruppe:'H-Typen',  name:'Hyperflex 10',   beschreibung:'Sehr flexibel, 10 mm',                              impedanz:50, db:[1.5,2.6,4.8,6.1,9.0,10.9,18.1,21.4] },
]

const messpunkte = [10, 30, 100, 145, 300, 435, 1000, 1296]
const kabelGruppen = [...new Set(allKabel.map(k => k.gruppe))]

const afuBaender = [
  { id:'160m', name:'160m', f:1.85 }, { id:'80m', name:'80m', f:3.65 }, { id:'40m', name:'40m', f:7.1 },
  { id:'30m', name:'30m', f:10.12 }, { id:'20m', name:'20m', f:14.2 }, { id:'17m', name:'17m', f:18.1 },
  { id:'15m', name:'15m', f:21.2 }, { id:'12m', name:'12m', f:24.9 }, { id:'10m', name:'10m', f:28.5 },
  { id:'6m', name:'6m', f:50.1 }, { id:'2m', name:'2m', f:144.3 }, { id:'70cm', name:'70cm', f:432.1 },
  { id:'23cm', name:'23cm', f:1296.0 },
]

const ka = reactive({ gruppe: 'RG-Typen', kabelID: 'rg213', freq: '145', laenge: '20', leistung: '100' })

const gewaehlteKabel = computed(() => allKabel.filter(k => k.gruppe === ka.gruppe))
const aktuellesKabel = computed(() => allKabel.find(k => k.id === ka.kabelID))

watch(() => ka.gruppe, () => {
  const erstes = gewaehlteKabel.value[0]
  if (erstes) ka.kabelID = erstes.id
})

function dampfPro100m(kabel, f) {
  const pts = messpunkte, db = kabel.db
  if (f <= pts[0]) return db[0] * Math.sqrt(f / pts[0])
  if (f >= pts[pts.length - 1]) return db[db.length - 1] * Math.sqrt(f / pts[pts.length - 1])
  for (let i = 0; i < pts.length - 1; i++) {
    if (f >= pts[i] && f <= pts[i + 1]) {
      const ratio = (f - pts[i]) / (pts[i + 1] - pts[i])
      return db[i] + (db[i + 1] - db[i]) * ratio
    }
  }
  return db[0]
}

const result = computed(() => {
  const kabel = aktuellesKabel.value
  const f = pf(ka.freq), l = pf(ka.laenge), p = pf(ka.leistung)
  if (!kabel || !f || !l || !p) return null
  const att100 = dampfPro100m(kabel, f)
  const gesamtDB = (att100 / 100) * l
  const ausgang = p * Math.pow(10, -gesamtDB / 10)
  const verlust = p - ausgang
  const eff = (ausgang / p) * 100
  let bewertung = 'gut', farbe = '#22c55e'
  if (eff < 50) { bewertung = 'schlecht'; farbe = '#ef4444' }
  else if (eff < 80) { bewertung = 'mittel'; farbe = '#fb923c' }
  return { gesamtDB, ausgang, verlust, eff, bewertung, farbe, att100 }
})

// Chart
const chartW = 600, chartH = 220
const chartPadL = 44, chartPadR = 16, chartPadT = 16, chartPadB = 32
const chartInnerW = chartW - chartPadL - chartPadR
const chartInnerH = chartH - chartPadT - chartPadB

const chartFreqs = [1, 5, 10, 20, 30, 50, 100, 145, 200, 300, 435, 600, 1000, 1296, 1400]
const chartFreqLabels = [10, 30, 100, 145, 300, 435, 1000, 1296]

// Log-Skala für X-Achse: 1 → 1400 MHz
const logMin = Math.log10(1)
const logMax = Math.log10(1400)
function xPos(f) {
  return chartPadL + (Math.log10(f) - logMin) / (logMax - logMin) * chartInnerW
}

const chartData = computed(() => {
  if (!aktuellesKabel.value) return null
  const kabel = aktuellesKabel.value
  const points = chartFreqs.map(f => ({ f, db: dampfPro100m(kabel, f) }))
  const maxDB = Math.max(...points.map(p => p.db)) * 1.1
  const yPos = db => chartPadT + (1 - db / maxDB) * chartInnerH
  const linePoints = points.map(p => ({ x: xPos(p.f), y: yPos(p.db) }))
  const linePath = linePoints.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(' ')
  // Aktueller Marker
  const fAktuell = pf(ka.freq) || 145
  const dbAktuell = dampfPro100m(kabel, fAktuell)
  const markerX = xPos(fAktuell)
  const markerY = yPos(dbAktuell)
  // Y-Ticks
  const ySteps = 5
  const yTicks = []
  for (let i = 0; i <= ySteps; i++) {
    const db = (maxDB / ySteps) * i
    yTicks.push({ db: db.toFixed(0), y: chartPadT + (1 - db / maxDB) * chartInnerH })
  }
  return { linePath, markerX, markerY, dbAktuell, yTicks, maxDB }
})
</script>

<template>
  <div class="calc-title">Kabeldämpfung</div>

  <div class="card">
    <h2>Kabelauswahl</h2>
    <div class="inp-grid">
      <div class="inp-g">
        <label>Gruppe</label>
        <select v-model="ka.gruppe">
          <option v-for="g in kabelGruppen" :key="g">{{ g }}</option>
        </select>
      </div>
      <div class="inp-g">
        <label>Kabeltyp</label>
        <select v-model="ka.kabelID">
          <option v-for="k in gewaehlteKabel" :key="k.id" :value="k.id">{{ k.name }}</option>
        </select>
      </div>
    </div>
    <div v-if="aktuellesKabel" class="small mt8" style="display:flex;gap:12px;flex-wrap:wrap;justify-content:space-between">
      <span style="color:var(--ts);flex:1">ⓘ {{ aktuellesKabel.beschreibung }}</span>
      <span class="mono" style="color:var(--td);font-size:11px">Z₀ = {{ aktuellesKabel.impedanz.toFixed(0) }} Ω</span>
    </div>
  </div>

  <div class="card">
    <h2>Parameter</h2>
    <div class="inp-grid3">
      <div class="inp-g"><label>Frequenz</label><div class="inp-row"><input type="text" v-model="ka.freq"><span>MHz</span></div></div>
      <div class="inp-g"><label>Kabellänge</label><div class="inp-row"><input type="text" v-model="ka.laenge"><span>m</span></div></div>
      <div class="inp-g"><label>Eingangsleistung</label><div class="inp-row"><input type="text" v-model="ka.leistung"><span>W</span></div></div>
    </div>
    <div style="margin-top:10px">
      <div class="small" style="margin-bottom:6px">Band-Schnellwahl</div>
      <div class="band-grid" style="grid-template-columns:repeat(7,1fr)">
        <button v-for="b in afuBaender" :key="b.id"
                class="bb" :class="{ on: Math.abs(pf(ka.freq) - b.f) < 0.01 }"
                @click="ka.freq = String(b.f)">{{ b.name }}</button>
      </div>
    </div>
  </div>

  <template v-if="result">
    <div class="card">
      <h2>Ergebnisse</h2>
      <div class="rr hi"><span class="lbl">Dämpfung gesamt</span><span class="val">{{ result.gesamtDB.toFixed(2) }} dB</span></div>
      <div class="rr"><span class="lbl">Ausgangsleistung</span><span class="val">{{ result.ausgang.toFixed(2) }} W</span></div>
      <div class="rr"><span class="lbl">Verlustleistung</span><span class="val">{{ result.verlust.toFixed(2) }} W</span></div>
      <hr class="div">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">
        <span class="small">Effizienz</span>
        <span class="mono fw7" :style="{ color: result.farbe, fontSize: '13px' }">{{ result.eff.toFixed(1) }} %</span>
      </div>
      <div class="balken-bg"><div class="balken-fill" :style="{ background: result.farbe, width: result.eff + '%' }"></div></div>
    </div>

    <div v-if="result.eff < 50" class="card warn-box" style="background:rgba(239,68,68,0.1);border-left:4px solid #ef4444;padding:14px">
      <div style="display:flex;gap:10px;align-items:flex-start">
        <span style="color:#ef4444;font-size:18px">⚠</span>
        <span class="small" style="color:var(--ts)">Mehr als die Hälfte der Sendeleistung geht im Kabel verloren! Kürzeres Kabel oder besseren Kabeltyp wählen.</span>
      </div>
    </div>
    <div v-else-if="result.gesamtDB > 3" class="card warn-box" style="background:rgba(251,146,60,0.1);border-left:4px solid #fb923c;padding:14px">
      <div style="display:flex;gap:10px;align-items:flex-start">
        <span style="color:#fb923c;font-size:18px">!</span>
        <span class="small" style="color:var(--ts)">Dämpfung über 3 dB – weniger als 50 % der Leistung erreicht die Antenne.</span>
      </div>
    </div>

    <div class="card">
      <h2>Dämpfungskurve (dB/100 m über Frequenz, log)</h2>
      <div class="skz-bg">
        <svg v-if="chartData" :viewBox="`0 0 ${chartW} ${chartH}`" preserveAspectRatio="xMidYMid meet">
          <!-- Y-Gridlines -->
          <line v-for="t in chartData.yTicks" :key="t.db"
                :x1="chartPadL" :y1="t.y" :x2="chartPadL + chartInnerW" :y2="t.y"
                stroke="rgba(140,140,140,0.15)" stroke-width="1"/>
          <text v-for="t in chartData.yTicks" :key="`lbl${t.db}`"
                :x="chartPadL - 6" :y="t.y + 3" text-anchor="end" font-size="9" fill="var(--ts)">{{ t.db }}</text>

          <!-- Achsen -->
          <line :x1="chartPadL" :y1="chartPadT" :x2="chartPadL" :y2="chartPadT + chartInnerH"
                stroke="rgba(140,140,140,0.5)" stroke-width="1"/>
          <line :x1="chartPadL" :y1="chartPadT + chartInnerH" :x2="chartPadL + chartInnerW" :y2="chartPadT + chartInnerH"
                stroke="rgba(140,140,140,0.5)" stroke-width="1"/>

          <!-- X-Achsen-Beschriftungen (log) -->
          <g v-for="f in chartFreqLabels" :key="f">
            <line :x1="xPos(f)" :y1="chartPadT + chartInnerH" :x2="xPos(f)" :y2="chartPadT + chartInnerH + 4"
                  stroke="rgba(140,140,140,0.5)" stroke-width="1"/>
            <text :x="xPos(f)" :y="chartPadT + chartInnerH + 16" text-anchor="middle" font-size="9" fill="var(--ts)">
              {{ f >= 1000 ? (f / 1000).toFixed(1) + 'G' : f }}
            </text>
          </g>
          <text :x="chartPadL + chartInnerW / 2" :y="chartH - 4" text-anchor="middle" font-size="9" fill="var(--td)">MHz</text>
          <text :x="6" :y="chartPadT + chartInnerH / 2" text-anchor="middle" font-size="9" fill="var(--td)" :transform="`rotate(-90, 6, ${chartPadT + chartInnerH / 2})`">dB / 100 m</text>

          <!-- Kurve -->
          <path :d="chartData.linePath" fill="none" stroke="var(--acc)" stroke-width="2"/>

          <!-- Aktueller Marker -->
          <line :x1="chartData.markerX" :y1="chartPadT" :x2="chartData.markerX" :y2="chartPadT + chartInnerH"
                stroke="rgba(248,113,113,0.4)" stroke-width="1.2" stroke-dasharray="4,3"/>
          <circle :cx="chartData.markerX" :cy="chartData.markerY" r="6" fill="#f87171"/>
          <text :x="chartData.markerX + 10" :y="chartData.markerY - 4" font-size="10" font-weight="bold" fill="#f87171">
            {{ chartData.dbAktuell.toFixed(1) }} dB
          </text>
        </svg>
      </div>
    </div>
  </template>

  <RechnerBeschreibung name="kabeldaempfung" />
</template>

<style scoped>
.balken-bg { width: 100%; height: 12px; background: var(--sub); border-radius: 4px; overflow: hidden; }
.balken-fill { height: 100%; transition: width 0.3s; border-radius: 4px; }
</style>
