<script setup>
import { reactive, computed, watch } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const balunTypen = [
  { id: '1_1',  label: '1:1 Balun (Strombalun / Mantelwellensperre)',   zielL: 25.0, hinweis: 'Ziel ca. 25–30 µH für 80–10m. Monofilar mit Koaxkabel oder bifilar.', wicklung: 'monofilar' },
  { id: '4_1',  label: '4:1 Balun (200 Ω zu 50 Ω)',                     zielL: 12.5, hinweis: 'Ziel ca. 10–15 µH. Bifilar auf 2 Kernen (Guanella-Bauweise).',          wicklung: 'bifilar' },
  { id: '9_1',  label: '9:1 Unun (450 Ω zu 50 Ω)',                      zielL: 8.0,  hinweis: 'Ziel ca. 7–10 µH. Trifilar gewickelt (3 Drähte gleichzeitig). Für Langdraht.', wicklung: 'trifilar' },
  { id: '49_1', label: '49:1 Unun (EFHW, 2450 Ω zu 50 Ω)',              zielL: 55.0, hinweis: 'Für EFHW-Antenne. 2 Primär- + 14 Sekundär-Windungen. FT-140-43 empfohlen.', wicklung: 'efhw49' },
  { id: '64_1', label: '64:1 Unun (Langdraht, 3200 Ω zu 50 Ω)',         zielL: 65.0, hinweis: 'Für Random-Wire. 1+7 Windungen (8:1 Verhältnis). FT-240-43 empfohlen.', wicklung: 'langdraht64' },
  { id: 'man',  label: 'Mantelwellensperre (1:1 Choke)',                zielL: 30.0, hinweis: 'Ziel > 25 µH für effektive Sperrwirkung auf 80–10m.',                  wicklung: 'monofilar' },
  { id: 'free', label: 'Freie L-Eingabe',                                zielL: 10.0, hinweis: 'Eigene Induktivität eingeben. Windungen werden berechnet.',          wicklung: 'monofilar' },
]

const alleKerne = [
  { id:'ft50_43',  gruppe:'Amidon Ferrit Mix 43',   name:'FT-50-43',  beschreibung:'Kleiner Ferritkern, 80–10m Balun/Choke',              al:523, od:12.7, idMM:7.15, hoehe:4.85 },
  { id:'ft82_43',  gruppe:'Amidon Ferrit Mix 43',   name:'FT-82-43',  beschreibung:'Mittlerer Kern, gut für 1:1 Strombalun',               al:557, od:21.0, idMM:13.1, hoehe:6.35 },
  { id:'ft114_43', gruppe:'Amidon Ferrit Mix 43',   name:'FT-114-43', beschreibung:'Großer Kern, höhere Leistung',                         al:603, od:29.0, idMM:19.0, hoehe:7.55 },
  { id:'ft140_43', gruppe:'Amidon Ferrit Mix 43',   name:'FT-140-43', beschreibung:'Beliebt für 100W Stationsbalun',                       al:885, od:35.55,idMM:23.0, hoehe:12.7 },
  { id:'ft240_43', gruppe:'Amidon Ferrit Mix 43',   name:'FT-240-43', beschreibung:'Großer Kern, 100–200W, empfohlen für 1:1 Strombalun',  al:1075,od:61.0, idMM:35.55,hoehe:12.7 },
  { id:'ft114_61', gruppe:'Amidon Ferrit Mix 61',   name:'FT-114-61', beschreibung:'Mix 61, gut für 6–40m, niedriger Verlust',             al:173, od:29.0, idMM:19.0, hoehe:7.55 },
  { id:'ft240_61', gruppe:'Amidon Ferrit Mix 61',   name:'FT-240-61', beschreibung:'Mix 61, breitbandig 1–30 MHz, guter Wirkungsgrad',     al:173, od:61.0, idMM:35.55,hoehe:12.7 },
  { id:'ft114_31', gruppe:'Amidon Ferrit Mix 31',   name:'FT-114-31', beschreibung:'Mix 31, sehr gut für 1–10 MHz, hohe Permeabilität',    al:1180,od:29.0, idMM:19.0, hoehe:7.55 },
  { id:'ft140_31', gruppe:'Amidon Ferrit Mix 31',   name:'FT-140-31', beschreibung:'Mix 31, ideal für EFHW 80–10m, 100W',                  al:1400,od:35.55,idMM:23.0, hoehe:12.7 },
  { id:'ft240_31', gruppe:'Amidon Ferrit Mix 31',   name:'FT-240-31', beschreibung:'Mix 31, hervorragend als Mantelwellensperre KW',       al:1400,od:61.0, idMM:35.55,hoehe:12.7 },
  { id:'ft240_77', gruppe:'Amidon Ferrit Mix 77',   name:'FT-240-77', beschreibung:'Mix 77, sehr hohe Permeabilität, MF/LW <2 MHz',        al:3700,od:61.0, idMM:35.55,hoehe:12.7 },
  { id:'t50_2',    gruppe:'Amidon Eisenpulver Mix 2',name:'T-50-2',   beschreibung:'Klein, QRP-Tuner, schmalbandige LC-Kreise',            al:49,  od:12.7, idMM:7.7,  hoehe:4.83 },
  { id:'t68_2',    gruppe:'Amidon Eisenpulver Mix 2',name:'T-68-2',   beschreibung:'Klein-mittel, QRP-Filter, Vorkreise',                  al:57,  od:17.5, idMM:9.4,  hoehe:4.83 },
  { id:'t94_2',    gruppe:'Amidon Eisenpulver Mix 2',name:'T-94-2',   beschreibung:'Mittel, Tiefpass-Filter, 25–50W',                      al:84,  od:23.9, idMM:14.0, hoehe:7.92 },
  { id:'t106_2',   gruppe:'Amidon Eisenpulver Mix 2',name:'T-106-2',  beschreibung:'Mittelgroß, PA-Ausgangsfilter, Anpassnetzwerke',        al:135, od:26.9, idMM:14.35,hoehe:11.1 },
  { id:'t130_2',   gruppe:'Amidon Eisenpulver Mix 2',name:'T-130-2',  beschreibung:'Eisenpulver, HF/KW LC-Kreise, Koppelspulen',           al:110, od:33.0, idMM:19.5, hoehe:11.1 },
  { id:'t200_2',   gruppe:'Amidon Eisenpulver Mix 2',name:'T-200-2',  beschreibung:'Großer Eisenpulverkern, Antennentuner, LPF',            al:120, od:50.8, idMM:31.75,hoehe:14.3 },
  { id:'t300_2',   gruppe:'Amidon Eisenpulver Mix 2',name:'T-300-2',  beschreibung:'Sehr groß, PA-Ausgangsfilter >500W, robuste LPF',      al:228, od:76.2, idMM:49.0, hoehe:12.7 },
  { id:'t130_6',   gruppe:'Amidon Eisenpulver Mix 6',name:'T-130-6',  beschreibung:'Mix 6, gut für 10–160m, hohe Güte',                    al:96,  od:33.0, idMM:19.5, hoehe:11.1 },
  { id:'t200_6',   gruppe:'Amidon Eisenpulver Mix 6',name:'T-200-6',  beschreibung:'Großer Mix-6 Kern, hohe Leistung möglich',              al:105, od:50.8, idMM:31.75,hoehe:14.3 },
  { id:'fr_2643',  gruppe:'Fair-Rite Mix 43',       name:'2643625002',beschreibung:'Fair-Rite Äquivalent zum FT-240-43, Mix 43',           al:1075,od:61.0, idMM:35.55,hoehe:12.7 },
  { id:'fr_5943',  gruppe:'Fair-Rite Mix 31',       name:'5943003801',beschreibung:'Fair-Rite Mix 31, sehr gut für 1–10 MHz, MF/LW',       al:4900,od:23.0, idMM:13.0, hoehe:7.5 },
  { id:'fr_5961',  gruppe:'Fair-Rite Mix 61',       name:'5961003801',beschreibung:'Fair-Rite Mix 61, 10–200 MHz, niedriger Verlust',       al:68,  od:23.0, idMM:13.0, hoehe:7.5 },
]

const kernGruppen = [...new Set(alleKerne.map(k => k.gruppe))]

const ba = reactive({ gruppe: 'Amidon Ferrit Mix 43', kernID: 'ft240_43', typID: '1_1', lUH: '25.0', dw: '1.5' })

const gewaehlteKerne = computed(() => alleKerne.filter(k => k.gruppe === ba.gruppe))
const kern = computed(() => alleKerne.find(k => k.id === ba.kernID))
const typ = computed(() => balunTypen.find(t => t.id === ba.typID))

watch(() => ba.typID, () => { if (typ.value) ba.lUH = String(typ.value.zielL) })
watch(() => ba.gruppe, () => {
  const erster = gewaehlteKerne.value[0]
  if (erster) ba.kernID = erster.id
})

const result = computed(() => {
  const k = kern.value, t = typ.value
  const L = pf(ba.lUH), d = pf(ba.dw)
  if (!k || !t || !L || !d) return null
  const L_nH = L * 1000
  const nRoh = Math.sqrt(L_nH / k.al)
  const n = Math.ceil(nRoh)
  const lTats = n * n * k.al / 1000
  const innenUmfang = Math.PI * k.idMM
  const mittlD = (k.od + k.idMM) / 2
  const mittlCirc = Math.PI * mittlD
  const drahtLen_m = (n * mittlCirc + 100) / 1000
  const maxN = Math.floor(innenUmfang / d)
  const fill = (n * d) / innenUmfang * 100
  let bewertung = 'ok'
  if (fill > 100) bewertung = 'zuKlein'
  else if (fill > 80) bewertung = 'eng'
  return {
    kern: k, typ: t, windungen: n, windungenRoh: nRoh, lTatsaechlich: lTats,
    drahtlaenge_m: drahtLen_m, maxWindungen: maxN, auslastungProzent: fill,
    innenumfang_mm: innenUmfang, bewertung,
  }
})

const isSpecial = computed(() => result.value && (result.value.typ.id === '49_1' || result.value.typ.id === '64_1'))

// SVG Skizze - Standard (1 Kern, monofilar)
const SVG_W = 600, SVG_H = 240

const standardSketch = computed(() => {
  if (!result.value || !['monofilar', 'efhw49', 'langdraht64'].includes(result.value.typ.wicklung)) return null
  const r = result.value
  const cx = 200, cy = SVG_H / 2
  const scale = Math.min(130 / r.kern.od, 80 / r.kern.idMM)
  const rO = r.kern.od / 2 * scale
  const rI = r.kern.idMM / 2 * scale
  const wireR = Math.max(3, Math.min(6.5, r.windungen > 0 ? rI * 0.15 : 5))
  const N = r.windungen
  const maxVis = Math.min(N, r.maxWindungen, 60)
  const fill = r.auslastungProzent / 100
  const angleStep = (2 * Math.PI) / Math.max(maxVis, 1)
  const filledN = Math.round(maxVis * fill)
  const windungen = []
  for (let i = 0; i < maxVis; i++) {
    const angle = -Math.PI / 2 + i * angleStep
    const ox = cx + (rO + wireR * 0.6) * Math.cos(angle)
    const oy = cy + (rO + wireR * 0.6) * Math.sin(angle)
    const ix = cx + (rI - wireR * 0.6) * Math.cos(angle)
    const iy = cy + (rI - wireR * 0.6) * Math.sin(angle)
    windungen.push({ ox, oy, ix, iy, gewickelt: i < filledN })
  }
  return { cx, cy, rO, rI, wireR, windungen }
})

// 4:1 Guanella - 2 Kerne bifilar
const guanellaSketch = computed(() => {
  if (!result.value || result.value.typ.wicklung !== 'bifilar') return null
  const r = result.value
  const rO = 58, rI = 32
  const centers = [{ x: SVG_W * 0.28, y: SVG_H * 0.5 }, { x: SVG_W * 0.60, y: SVG_H * 0.5 }]
  const nVis = Math.min(r.windungen, 14)
  const wR = 4.5
  const aStep = (2 * Math.PI) / Math.max(nVis, 1)
  const drahtPaare = [{ mult: -wR * 0.9, color: '#212121' }, { mult: wR * 0.9, color: '#1976D2' }]
  const allWindungen = centers.map(c => {
    const wnds = []
    for (let i = 0; i < nVis; i++) {
      const ang = -Math.PI / 2 + i * aStep
      const offAng = ang + Math.PI / 2
      drahtPaare.forEach(({ mult, color }) => {
        const ox = c.x + (rO + wR * 0.55) * Math.cos(ang) + Math.cos(offAng) * mult
        const oy = c.y + (rO + wR * 0.55) * Math.sin(ang) + Math.sin(offAng) * mult
        const ix = c.x + (rI - wR * 0.55) * Math.cos(ang) + Math.cos(offAng) * mult
        const iy = c.y + (rI - wR * 0.55) * Math.sin(ang) + Math.sin(offAng) * mult
        wnds.push({ ox, oy, ix, iy, color, wR })
      })
    }
    return { center: c, windungen: wnds }
  })
  return { centers, rO, rI, allWindungen, drahtPaare }
})

// 9:1 Trifilar
const trifilarSketch = computed(() => {
  if (!result.value || result.value.typ.wicklung !== 'trifilar') return null
  const r = result.value
  const cx = SVG_W * 0.38, cy = SVG_H / 2
  const rO = 75, rI = 42
  const nVis = Math.min(r.windungen, 9)
  const farben = ['#bf3a0c', '#d94714', '#ff8a66']
  const aStep = (2 * Math.PI) / Math.max(nVis, 1)
  const wR = 4.5
  const wnds = []
  for (let i = 0; i < nVis; i++) {
    const ang = -Math.PI / 2 + i * aStep
    const offAng = ang + Math.PI / 2
    for (let d = 0; d < 3; d++) {
      const mult = (d - 1) * 2.0
      const ox = cx + (rO + wR * 0.45) * Math.cos(ang) + Math.cos(offAng) * mult
      const oy = cy + (rO + wR * 0.45) * Math.sin(ang) + Math.sin(offAng) * mult
      const ix = cx + (rI - wR * 0.45) * Math.cos(ang) + Math.cos(offAng) * mult
      const iy = cy + (rI - wR * 0.45) * Math.sin(ang) + Math.sin(offAng) * mult
      wnds.push({ ox, oy, ix, iy, color: farben[d], wR })
    }
  }
  return { cx, cy, rO, rI, windungen: wnds, farben }
})
</script>

<template>
  <div class="calc-title">Balun / Unun Wicklungsrechner</div>

  <div class="card">
    <h2>Balun / Unun Typ</h2>
    <select v-model="ba.typID" style="width:100%">
      <option v-for="t in balunTypen" :key="t.id" :value="t.id">{{ t.label }}</option>
    </select>
    <div v-if="typ" class="small mt8" style="display:flex;gap:8px;align-items:flex-start">
      <span style="color:var(--ts);flex-shrink:0">ⓘ</span>
      <span>{{ typ.hinweis }}</span>
    </div>
  </div>

  <div class="card">
    <h2>Ringkern</h2>
    <div class="inp-grid">
      <div class="inp-g">
        <label>Material / Gruppe</label>
        <select v-model="ba.gruppe">
          <option v-for="g in kernGruppen" :key="g">{{ g }}</option>
        </select>
      </div>
      <div class="inp-g">
        <label>Kern</label>
        <select v-model="ba.kernID">
          <option v-for="k in gewaehlteKerne" :key="k.id" :value="k.id">{{ k.name }}  (Al = {{ k.al }})</option>
        </select>
      </div>
    </div>
    <div v-if="kern" class="small mt8" style="display:flex;gap:12px;flex-wrap:wrap;justify-content:space-between">
      <span style="color:var(--ts);flex:1">ⓘ {{ kern.beschreibung }}</span>
      <span class="mono" style="color:var(--td);font-size:11px">
        OD {{ kern.od.toFixed(1) }} · ID {{ kern.idMM.toFixed(1) }} · H {{ kern.hoehe.toFixed(1) }} mm
      </span>
    </div>
  </div>

  <div class="card">
    <h2>Parameter</h2>
    <div class="inp-grid">
      <div class="inp-g"><label>Ziel-Induktivität L</label><div class="inp-row"><input type="text" v-model="ba.lUH"><span>µH</span></div></div>
      <div class="inp-g"><label>Drahtdurchmesser</label><div class="inp-row"><input type="text" v-model="ba.dw"><span>mm</span></div></div>
    </div>
    <div class="small mt8" style="font-size:11px">
      Formel: <span class="mono">N = √(L[nH] / Al[nH/N²])</span>
    </div>
  </div>

  <template v-if="result">
    <!-- Skizze -->
    <div class="card">
      <h2>Wicklungs-Skizze</h2>
      <div class="skz-bg" style="display:flex;justify-content:center">
        <!-- Standard (1 Kern, monofilar) -->
        <svg v-if="standardSketch" :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet" style="max-height:240px">
          <defs>
            <radialGradient id="kernGrad" cx="40%" cy="35%">
              <stop offset="0%" stop-color="#d6ccc7"/>
              <stop offset="100%" stop-color="#7a5448"/>
            </radialGradient>
          </defs>
          <!-- Kern außen -->
          <circle :cx="standardSketch.cx" :cy="standardSketch.cy" :r="standardSketch.rO" fill="url(#kernGrad)" stroke="#8c6d5f" stroke-width="1.5"/>
          <!-- Innenloch -->
          <circle :cx="standardSketch.cx" :cy="standardSketch.cy" :r="standardSketch.rI" fill="var(--card2)" stroke="#8c6d5f" stroke-width="1"/>
          <!-- Windungen -->
          <g v-for="(w, i) in standardSketch.windungen" :key="i">
            <line :x1="w.ox" :y1="w.oy" :x2="w.ix" :y2="w.iy"
                  :stroke="w.gewickelt ? 'rgba(194,59,43,0.7)' : 'rgba(140,140,140,0.3)'"
                  :stroke-width="standardSketch.wireR * 1.2"/>
            <circle :cx="w.ox" :cy="w.oy" :r="standardSketch.wireR"
                    :fill="w.gewickelt ? '#c23b2b' : 'rgba(140,140,140,0.4)'"/>
            <circle :cx="w.ix" :cy="w.iy" :r="standardSketch.wireR * 0.75"
                    :fill="w.gewickelt ? '#9b2e22' : 'rgba(140,140,140,0.4)'"/>
          </g>
          <!-- Bemaßung OD -->
          <line :x1="standardSketch.cx - standardSketch.rO" :y1="standardSketch.cy - standardSketch.rO - 18"
                :x2="standardSketch.cx + standardSketch.rO" :y2="standardSketch.cy - standardSketch.rO - 18"
                stroke="rgba(140,140,140,0.6)" stroke-width="1.5"/>
          <text :x="standardSketch.cx" :y="standardSketch.cy - standardSketch.rO - 23"
                text-anchor="middle" font-size="10" fill="var(--ts)">
            OD {{ result.kern.od.toFixed(0) }} mm
          </text>
          <!-- Infos rechts -->
          <text :x="standardSketch.cx + standardSketch.rO + 30" :y="standardSketch.cy - 35" font-size="11" fill="var(--ts)">Kern:</text>
          <text :x="standardSketch.cx + standardSketch.rO + 115" :y="standardSketch.cy - 35" font-size="11" font-weight="bold" fill="var(--tp)">{{ result.kern.name }}</text>
          <text :x="standardSketch.cx + standardSketch.rO + 30" :y="standardSketch.cy - 15" font-size="11" fill="var(--ts)">Windungen:</text>
          <text :x="standardSketch.cx + standardSketch.rO + 115" :y="standardSketch.cy - 15" font-size="11" font-weight="bold" fill="var(--tp)">{{ result.windungen }} Wdg.</text>
          <text :x="standardSketch.cx + standardSketch.rO + 30" :y="standardSketch.cy + 5" font-size="11" fill="var(--ts)">Auslastung:</text>
          <text :x="standardSketch.cx + standardSketch.rO + 115" :y="standardSketch.cy + 5" font-size="11" font-weight="bold" fill="var(--tp)">{{ result.auslastungProzent.toFixed(0) }} %</text>
          <text :x="standardSketch.cx + standardSketch.rO + 30" :y="standardSketch.cy + 25" font-size="11" fill="var(--ts)">Al-Wert:</text>
          <text :x="standardSketch.cx + standardSketch.rO + 115" :y="standardSketch.cy + 25" font-size="11" font-weight="bold" fill="var(--tp)">{{ result.kern.al.toFixed(0) }} nH/N²</text>
          <!-- Legende -->
          <circle :cx="standardSketch.cx + standardSketch.rO + 35" :cy="standardSketch.cy + 60" r="5" fill="#c23b2b"/>
          <text :x="standardSketch.cx + standardSketch.rO + 50" :y="standardSketch.cy + 64" font-size="10" fill="var(--ts)">= gewickelt</text>
          <circle :cx="standardSketch.cx + standardSketch.rO + 35" :cy="standardSketch.cy + 78" r="5" fill="rgba(140,140,140,0.4)"/>
          <text :x="standardSketch.cx + standardSketch.rO + 50" :y="standardSketch.cy + 82" font-size="10" fill="var(--ts)">= frei</text>
        </svg>

        <!-- 4:1 Guanella (2 Kerne) -->
        <svg v-if="guanellaSketch" :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet" style="max-height:240px">
          <defs>
            <radialGradient id="kernGradG" cx="40%" cy="35%">
              <stop offset="0%" stop-color="#d6ccc7"/>
              <stop offset="100%" stop-color="#7a5448"/>
            </radialGradient>
          </defs>
          <text :x="SVG_W / 2" y="14" text-anchor="middle" font-size="11" fill="var(--ts)">
            4:1 Guanella Strombalun – 2 Kerne bifilar
          </text>
          <g v-for="(kdata, ki) in guanellaSketch.allWindungen" :key="ki">
            <circle :cx="kdata.center.x" :cy="kdata.center.y" :r="guanellaSketch.rO" fill="url(#kernGradG)" stroke="#8c6d5f" stroke-width="1.5"/>
            <circle :cx="kdata.center.x" :cy="kdata.center.y" :r="guanellaSketch.rI" fill="var(--card2)" stroke="#8c6d5f" stroke-width="1"/>
            <text :x="kdata.center.x" :y="kdata.center.y + 4" text-anchor="middle" font-size="11" font-weight="bold" fill="rgba(255,255,255,0.7)">Kern {{ ki + 1 }}</text>
            <g v-for="(w, j) in kdata.windungen" :key="j">
              <line :x1="w.ox" :y1="w.oy" :x2="w.ix" :y2="w.iy" :stroke="w.color" stroke-width="3.5" opacity="0.9"/>
              <circle :cx="w.ox" :cy="w.oy" :r="w.wR" :fill="w.color"/>
            </g>
          </g>
          <!-- Verbindungsdrähte -->
          <line v-for="(p, i) in guanellaSketch.drahtPaare" :key="`v${i}`"
                :x1="guanellaSketch.centers[0].x + guanellaSketch.rO + 5" :y1="guanellaSketch.centers[0].y + (i === 0 ? -12 : 12)"
                :x2="guanellaSketch.centers[1].x - guanellaSketch.rO - 5" :y2="guanellaSketch.centers[1].y + (i === 0 ? -12 : 12)"
                :stroke="p.color" stroke-width="2" stroke-dasharray="5,3"/>
          <text :x="guanellaSketch.centers[0].x - guanellaSketch.rO - 20" :y="guanellaSketch.centers[0].y + 5" text-anchor="middle" font-size="10" fill="var(--ts)">50 Ω</text>
          <text :x="guanellaSketch.centers[1].x + guanellaSketch.rO + 24" :y="guanellaSketch.centers[1].y + 5" text-anchor="middle" font-size="10" fill="var(--ts)">200 Ω</text>
          <!-- Legende -->
          <circle :cx="SVG_W * 0.80" :cy="SVG_H * 0.15" r="5" fill="#212121"/>
          <text :x="SVG_W * 0.80 + 10" :y="SVG_H * 0.15 + 4" font-size="10" fill="var(--ts)">Draht 1</text>
          <circle :cx="SVG_W * 0.80" :cy="SVG_H * 0.15 + 18" r="5" fill="#1976D2"/>
          <text :x="SVG_W * 0.80 + 10" :y="SVG_H * 0.15 + 22" font-size="10" fill="var(--ts)">Draht 2</text>
        </svg>

        <!-- 9:1 Trifilar -->
        <svg v-if="trifilarSketch" :viewBox="`0 0 ${SVG_W} ${SVG_H}`" preserveAspectRatio="xMidYMid meet" style="max-height:240px">
          <defs>
            <radialGradient id="kernGradT" cx="40%" cy="35%">
              <stop offset="0%" stop-color="#d6ccc7"/>
              <stop offset="100%" stop-color="#7a5448"/>
            </radialGradient>
          </defs>
          <text :x="SVG_W / 2" y="14" text-anchor="middle" font-size="11" fill="var(--ts)">
            9:1 Unun – trifilar (3 Drähte, {{ Math.min(result.windungen, 9) }} Windungen)
          </text>
          <circle :cx="trifilarSketch.cx" :cy="trifilarSketch.cy" :r="trifilarSketch.rO" fill="url(#kernGradT)" stroke="#8c6d5f" stroke-width="1.5"/>
          <circle :cx="trifilarSketch.cx" :cy="trifilarSketch.cy" :r="trifilarSketch.rI" fill="var(--card2)" stroke="#8c6d5f" stroke-width="1"/>
          <g v-for="(w, j) in trifilarSketch.windungen" :key="j">
            <line :x1="w.ox" :y1="w.oy" :x2="w.ix" :y2="w.iy" :stroke="w.color" stroke-width="3.2" opacity="0.9"/>
            <circle :cx="w.ox" :cy="w.oy" :r="w.wR" :fill="w.color"/>
          </g>
          <text v-for="(c, i) in trifilarSketch.farben" :key="i"
                :x="trifilarSketch.cx + trifilarSketch.rO + 50" :y="trifilarSketch.cy - 16 + i * 20"
                font-size="11" fill="var(--ts)">Draht {{ i + 1 }}</text>
          <circle v-for="(c, i) in trifilarSketch.farben" :key="`d${i}`"
                  :cx="trifilarSketch.cx + trifilarSketch.rO + 35" :cy="trifilarSketch.cy - 20 + i * 20"
                  r="5" :fill="c"/>
          <text :x="trifilarSketch.cx - trifilarSketch.rO - 22" :y="trifilarSketch.cy + 5" text-anchor="middle" font-size="10" fill="var(--ts)">450 Ω</text>
          <text :x="trifilarSketch.cx + trifilarSketch.rO + 110" :y="trifilarSketch.cy + 5" text-anchor="middle" font-size="10" fill="var(--ts)">50 Ω</text>
        </svg>
      </div>
    </div>

    <div class="card">
      <h2>Ergebnisse</h2>
      <div class="ken-grid">
        <div class="ken hi">
          <div class="ken-val">{{ isSpecial ? (result.typ.id === '49_1' ? '2 + 14' : '1 + 7') : result.windungen + ' Wdg.' }}</div>
          <div class="ken-lbl">{{ isSpecial ? 'Windungen (Prim + Sek)' : 'Windungen' }}</div>
        </div>
        <div class="ken">
          <div class="ken-val">{{ isSpecial ? 'Prim / Sek' : fmt(result.lTatsaechlich, 2) + ' µH' }}</div>
          <div class="ken-lbl">{{ isSpecial ? 'Wicklung' : 'Erzielte Induktivität' }}</div>
        </div>
        <div class="ken"><div class="ken-val">{{ fmt(result.drahtlaenge_m, 2) }} m</div><div class="ken-lbl">Drahtlänge (ca.)</div></div>
        <div class="ken" :class="{ hi: result.bewertung !== 'ok' }" :style="{ borderColor: result.bewertung === 'zuKlein' ? '#ef4444' : (result.bewertung === 'eng' ? '#fb923c' : '') }">
          <div class="ken-val" :style="{ color: result.bewertung === 'zuKlein' ? '#ef4444' : (result.bewertung === 'eng' ? '#fb923c' : '') }">
            {{ result.auslastungProzent.toFixed(0) }} %
          </div>
          <div class="ken-lbl">Kernauslastung</div>
        </div>
      </div>
    </div>

    <div v-if="result.bewertung === 'zuKlein'" class="card warn-box" style="background:rgba(239,68,68,0.1);border-left:4px solid #ef4444">
      <div style="display:flex;gap:12px;align-items:flex-start">
        <span style="color:#ef4444;font-size:18px">✗</span>
        <div>
          <div style="font-weight:600;color:var(--tp);margin-bottom:4px">Kern zu klein!</div>
          <div class="small">{{ result.windungen }} Wdg. × {{ ba.dw }} mm passen nicht in den Innenumfang ({{ result.innenumfang_mm.toFixed(0) }} mm). Größeren Kern wählen.</div>
        </div>
      </div>
    </div>
    <div v-else-if="result.bewertung === 'eng'" class="card warn-box" style="background:rgba(251,146,60,0.1);border-left:4px solid #fb923c">
      <div style="display:flex;gap:12px;align-items:flex-start">
        <span style="color:#fb923c;font-size:18px">⚠</span>
        <div>
          <div style="font-weight:600;color:var(--tp);margin-bottom:4px">Kern eng belegt ({{ result.auslastungProzent.toFixed(0) }} %)</div>
          <div class="small">Wickeln ist möglich, aber kein Platz für Korrekturen. Nächstgrößeren Kern erwägen.</div>
        </div>
      </div>
    </div>

    <div class="card">
      <h2>Kerndaten</h2>
      <div class="rr"><span class="lbl">Al-Wert</span><span class="val">{{ result.kern.al.toFixed(0) }} nH/N²</span></div>
      <div class="rr"><span class="lbl">Außendurchmesser</span><span class="val">{{ result.kern.od.toFixed(1) }} mm</span></div>
      <div class="rr"><span class="lbl">Innendurchmesser</span><span class="val">{{ result.kern.idMM.toFixed(1) }} mm</span></div>
      <div class="rr"><span class="lbl">Höhe</span><span class="val">{{ result.kern.hoehe.toFixed(2) }} mm</span></div>
      <div class="rr"><span class="lbl">Innenumfang</span><span class="val">{{ result.innenumfang_mm.toFixed(1) }} mm</span></div>
      <div class="rr"><span class="lbl">Max. Windungen</span><span class="val">{{ result.maxWindungen }} Wdg.</span></div>
    </div>
  </template>

  <RechnerBeschreibung name="balun" />
</template>

<style scoped>
.ken-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }
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
