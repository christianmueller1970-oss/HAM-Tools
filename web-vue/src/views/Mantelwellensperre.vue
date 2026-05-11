<script setup>
import { reactive, computed, watch } from 'vue'
import { pf, fmt } from '../composables/useHam.js'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

// Ringkern-DB (1:1 zur Native-Version aus BalunRechnerModel.swift)
const alleKerne = [
  { id:'ft50_43',  gruppe:'Amidon Ferrit Mix 43',   name:'FT-50-43',  al:523, idMM:7.15 },
  { id:'ft82_43',  gruppe:'Amidon Ferrit Mix 43',   name:'FT-82-43',  al:557, idMM:13.1 },
  { id:'ft114_43', gruppe:'Amidon Ferrit Mix 43',   name:'FT-114-43', al:603, idMM:19.0 },
  { id:'ft140_43', gruppe:'Amidon Ferrit Mix 43',   name:'FT-140-43', al:885, idMM:23.0 },
  { id:'ft240_43', gruppe:'Amidon Ferrit Mix 43',   name:'FT-240-43', al:1075,idMM:35.55 },
  { id:'ft114_61', gruppe:'Amidon Ferrit Mix 61',   name:'FT-114-61', al:173, idMM:19.0 },
  { id:'ft240_61', gruppe:'Amidon Ferrit Mix 61',   name:'FT-240-61', al:173, idMM:35.55 },
  { id:'ft114_31', gruppe:'Amidon Ferrit Mix 31',   name:'FT-114-31', al:1180,idMM:19.0 },
  { id:'ft140_31', gruppe:'Amidon Ferrit Mix 31',   name:'FT-140-31', al:1400,idMM:23.0 },
  { id:'ft240_31', gruppe:'Amidon Ferrit Mix 31',   name:'FT-240-31', al:1400,idMM:35.55 },
  { id:'ft240_77', gruppe:'Amidon Ferrit Mix 77',   name:'FT-240-77', al:3700,idMM:35.55 },
  { id:'t50_2',    gruppe:'Amidon Eisenpulver Mix 2',name:'T-50-2',   al:49,  idMM:7.7 },
  { id:'t68_2',    gruppe:'Amidon Eisenpulver Mix 2',name:'T-68-2',   al:57,  idMM:9.4 },
  { id:'t94_2',    gruppe:'Amidon Eisenpulver Mix 2',name:'T-94-2',   al:84,  idMM:14.0 },
  { id:'t106_2',   gruppe:'Amidon Eisenpulver Mix 2',name:'T-106-2',  al:135, idMM:14.35 },
  { id:'t130_2',   gruppe:'Amidon Eisenpulver Mix 2',name:'T-130-2',  al:110, idMM:19.5 },
  { id:'t200_2',   gruppe:'Amidon Eisenpulver Mix 2',name:'T-200-2',  al:120, idMM:31.75 },
  { id:'t300_2',   gruppe:'Amidon Eisenpulver Mix 2',name:'T-300-2',  al:228, idMM:49.0 },
  { id:'t130_6',   gruppe:'Amidon Eisenpulver Mix 6',name:'T-130-6',  al:96,  idMM:19.5 },
  { id:'t200_6',   gruppe:'Amidon Eisenpulver Mix 6',name:'T-200-6',  al:105, idMM:31.75 },
  { id:'fr_2643',  gruppe:'Fair-Rite Mix 43',       name:'2643625002',al:1075,idMM:35.55 },
  { id:'fr_5943',  gruppe:'Fair-Rite Mix 31',       name:'5943003801',al:4900,idMM:13.0 },
  { id:'fr_5961',  gruppe:'Fair-Rite Mix 61',       name:'5961003801',al:68,  idMM:13.0 },
]

const kernGruppen = [...new Set(alleKerne.map(k => k.gruppe))]

const m = reactive({
  gruppe: 'Amidon Ferrit Mix 43',
  kernID: 'ft240_43',
  windungen: 12,
  freq: '14.2',
  koaxD: '5.0',
})

const gewaehlteKerne = computed(() => alleKerne.filter(k => k.gruppe === m.gruppe))
const kern = computed(() => alleKerne.find(k => k.id === m.kernID))
const fVal = computed(() => pf(m.freq) || 0)
const koaxD = computed(() => pf(m.koaxD) || 5.0)

watch(() => m.gruppe, () => {
  const first = gewaehlteKerne.value[0]
  if (first) m.kernID = first.id
})

const isFerrite = computed(() => m.gruppe.includes('Ferrit') || m.gruppe.includes('Fair-Rite'))

function lUH(N, k) { return (N * N * k.al) / 1000 }
function zCM(N, fMHz, k) { return 2 * Math.PI * fMHz * lUH(N, k) }

const L_uH = computed(() => kern.value ? lUH(m.windungen, kern.value) : 0)
const X_L  = computed(() => kern.value ? zCM(m.windungen, fVal.value, kern.value) : 0)

function bewertung(X) {
  if (X >= 5000) return '✓ ausgezeichnet (≥ 5 kΩ)'
  if (X >= 1000) return '✓ gut (≥ 1 kΩ)'
  if (X >= 500)  return '~ akzeptabel'
  return '✗ ungenügend (< 500 Ω)'
}

const bandList = [
  { name: '160m', fMHz: 1.85 }, { name: '80m',  fMHz: 3.65 }, { name: '60m', fMHz: 5.36 },
  { name: '40m',  fMHz: 7.10 }, { name: '30m',  fMHz: 10.12 }, { name: '20m', fMHz: 14.20 },
  { name: '17m',  fMHz: 18.10 },{ name: '15m',  fMHz: 21.20 }, { name: '12m', fMHz: 24.94 },
  { name: '10m',  fMHz: 28.50 },{ name: '6m',   fMHz: 50.10 },
]

function statusIcon(X) {
  if (X >= 5000) return '✓ top'
  if (X >= 1000) return '✓ ok'
  if (X >= 500)  return '~'
  return '✗'
}
function statusColor(X) {
  if (X >= 5000) return '#22c55e'
  if (X >= 1000) return '#84cc16'
  if (X >= 500)  return '#eab308'
  return '#ef4444'
}

const wickel = computed(() => {
  if (!kern.value) return null
  const innenUmfang = Math.PI * kern.value.idMM
  const maxN = Math.floor(innenUmfang / koaxD.value)
  const auslastung = (m.windungen * koaxD.value / innenUmfang) * 100
  return { innenUmfang, maxN, auslastung }
})
</script>

<template>
  <div class="calc-title">Mantelwellensperre</div>

  <div class="card">
    <h2>Ringkern + Wicklung</h2>
    <div class="inp-grid" style="grid-template-columns: 2fr 1fr; gap: 12px">
      <div class="inp-g">
        <label>Material / Mix</label>
        <select v-model="m.gruppe">
          <option v-for="g in kernGruppen" :key="g" :value="g">{{ g }}</option>
        </select>
      </div>
      <div class="inp-g">
        <label>Kern</label>
        <select v-model="m.kernID">
          <option v-for="k in gewaehlteKerne" :key="k.id" :value="k.id">{{ k.name }}</option>
        </select>
      </div>
    </div>
    <div class="inp-grid" style="grid-template-columns: repeat(3, 1fr); gap: 12px; margin-top: 8px">
      <div class="inp-g">
        <label>Windungen N</label>
        <div class="inp-row" style="gap:8px">
          <button class="btn-step" @click="m.windungen = Math.max(1, m.windungen - 1)">−</button>
          <input type="number" v-model.number="m.windungen" min="1" max="30" style="text-align:center; width:60px">
          <button class="btn-step" @click="m.windungen = Math.min(30, m.windungen + 1)">+</button>
        </div>
      </div>
      <div class="inp-g">
        <label>Test-Frequenz</label>
        <div class="inp-row"><input type="text" v-model="m.freq"><span>MHz</span></div>
      </div>
      <div class="inp-g">
        <label>Koax-⌀ (für Wickel-Check)</label>
        <div class="inp-row"><input type="text" v-model="m.koaxD"><span>mm</span></div>
      </div>
    </div>
    <p style="font-size:11px;opacity:0.7;margin-top:8px">
      Eine Mantelwellensperre wird typisch durch Wickeln des <strong>Koaxialkabels selbst</strong>
      durch oder um einen Ringkern hergestellt — die Anzahl Windungen entspricht der Anzahl
      Durchführungen durch das Kernloch.
    </p>
  </div>

  <template v-if="kern">
    <div v-if="!isFerrite" class="card warn-card">
      <h2>⚠ Material-Warnung</h2>
      <p style="color:#f97316; margin:0">
        <strong>Eisenpulver-Kerne (Mix 2, Mix 6) sind für Mantelwellensperren UNGEEIGNET!</strong>
        Sie haben hohes Q (geringe Verluste), wirken nur als reine Induktivität und sperren
        Common-Mode-Ströme nur über einen schmalen Frequenzbereich. Für Chokes immer
        <strong>Ferrit-Mix verwenden</strong> (Mix 43 für KW, Mix 31 für 1-10 MHz EFHW,
        Mix 61 für VHF/UHF, Mix 77 für NF).
      </p>
    </div>

    <div class="card">
      <h2>Sperrwirkung bei {{ Number(m.freq).toFixed(3) }} MHz</h2>
      <div class="rr"><span class="lbl">Induktivität L</span><span class="val mono">{{ L_uH.toFixed(2) }} µH</span></div>
      <div class="rr"><span class="lbl">Reaktanz X_L = 2πfL</span><span class="val mono">{{ X_L.toFixed(0) }} Ω</span></div>
      <div class="rr hi"><span class="lbl">Common-Mode Z</span><span class="val mono">{{ X_L.toFixed(0) }} Ω ≈ {{ (X_L/1000).toFixed(2) }} kΩ</span></div>
      <div class="rr"><span class="lbl">Bewertung</span><span class="val">{{ bewertung(X_L) }}</span></div>
    </div>

    <div class="card">
      <h2>Sperrwirkung über alle Bänder</h2>
      <table class="tbl mws-tbl">
        <thead>
          <tr><th>Band</th><th>Frequenz</th><th>X_L</th><th>kΩ</th><th>Status</th></tr>
        </thead>
        <tbody>
          <tr v-for="b in bandList" :key="b.name">
            <td class="fw7">{{ b.name }}</td>
            <td class="mono">{{ b.fMHz.toFixed(2) }} MHz</td>
            <td class="mono">{{ zCM(m.windungen, b.fMHz, kern).toFixed(0) }} Ω</td>
            <td class="mono fw7">{{ (zCM(m.windungen, b.fMHz, kern) / 1000).toFixed(2) }}</td>
            <td :style="{ color: statusColor(zCM(m.windungen, b.fMHz, kern)), fontWeight:600 }">
              {{ statusIcon(zCM(m.windungen, b.fMHz, kern)) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="wickel" class="card">
      <h2>Wickel-Check</h2>
      <div class="rr"><span class="lbl">Kern-Innenumfang</span><span class="val mono">{{ wickel.innenUmfang.toFixed(1) }} mm</span></div>
      <div class="rr"><span class="lbl">Maximal mögliche Windungen</span><span class="val mono">≈ {{ wickel.maxN }}</span></div>
      <div class="rr" :class="{ hi: wickel.auslastung > 90 }">
        <span class="lbl">Aktuelle Auslastung</span>
        <span class="val mono">{{ wickel.auslastung.toFixed(0) }} %  ({{ m.windungen }} von {{ wickel.maxN }})</span>
      </div>
      <p v-if="m.windungen > wickel.maxN" style="color:#ef4444; margin:6px 0 0">
        ⚠ Mehr Windungen geplant als auf den Kern passen!
      </p>
      <p v-else-if="wickel.auslastung > 90" style="color:#f97316; margin:6px 0 0">
        ⚠ Wickelfenster fast voll — eng zu wickeln, ggf. größeren Kern wählen.
      </p>
      <p v-else-if="wickel.auslastung > 60" style="opacity:0.75; margin:6px 0 0">
        Wickelfenster gut belegt, sollte sauber zu wickeln sein.
      </p>
      <p v-else style="opacity:0.75; margin:6px 0 0">
        Viel Platz — alternativ größere Windungszahl möglich für mehr Sperrwirkung.
      </p>
    </div>
  </template>

  <div class="card">
    <h2>Praxis-Empfehlung</h2>
    <ul style="margin:0; padding-left:18px; line-height:1.6; font-size:13px; opacity:0.85">
      <li><strong>Ziel: Z_CM ≥ 1 kΩ</strong> auf den genutzten Bändern. <strong>≥ 5 kΩ</strong> ist optimal.</li>
      <li><strong>Mix 31</strong> ist typisch beste Wahl für KW-Choke (1–10 MHz top, brauchbar bis 30 MHz). <strong>Mix 43</strong> für 5–50 MHz universell. <strong>Mix 61</strong> für VHF/UHF. <strong>Mix 77</strong> für NF (&lt;2 MHz).</li>
      <li><strong>Konservative Berechnung:</strong> Z_CM = X_L (rein induktiv). Bei Ferrit liegen die realen Werte im Verlust-Resonanz-Fenster oft 2–3× höher dank des Material-Imaginärteils μ".</li>
      <li><strong>Standard-Empfehlung 100 W KW-Station:</strong> FT-240-43 mit 10–14 Windungen Aircell-5 / RG-58 — deckt 80–10m sauber ab.</li>
      <li><strong>EFHW-Choke:</strong> FT-240-31 mit 7–10 Windungen — speziell für die Common-Mode-Probleme an EFHW-Antennen.</li>
      <li><strong>Wickel-Trick:</strong> Windungen gleichmäßig um den Kern verteilen (nicht alle nebeneinander) — weniger Eigenkapazität, breiteres Sperrband.</li>
    </ul>
  </div>

  <RechnerBeschreibung name="mantelwellensperre" />
</template>

<style scoped>
.warn-card { border-color: #f97316 }
select { padding: 6px 8px; border-radius: 6px; border: 1px solid var(--border, #333); background: var(--bg-input, #1a1a1a); color: inherit; width: 100% }
.btn-step { padding: 4px 10px; border-radius: 4px; border: 1px solid var(--border, #333); background: var(--bg-sub, #222); color: inherit; cursor: pointer; font-size: 16px; line-height: 1 }
.mws-tbl th, .mws-tbl td { font-size: 12px }
.mws-tbl th:nth-child(n+2), .mws-tbl td:nth-child(n+2) { text-align: right }
.mws-tbl td:last-child, .mws-tbl th:last-child { text-align: center }
.mono { font-family: monospace }
</style>
