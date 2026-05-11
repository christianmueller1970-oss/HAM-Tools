<script setup>
import { ref, computed } from 'vue'
import bandplanData from '../../../Sources/HAMRechner/Content/bandplan.json'

const data = bandplanData
const categories = data.categories

const filterType = ref('alle')
const filterContest = ref(false)
const filterWarc = ref(false)
const filterDigi = ref(false)
const lookupFreq = ref('')
const expandedBand = ref(null)

const typeFilters = [
  { id: 'alle', label: 'Alle Bänder' },
  { id: 'lf',   label: 'LF / MF' },
  { id: 'hf',   label: 'KW (HF)' },
  { id: 'vhf',  label: 'UKW (VHF)' },
  { id: 'uhf',  label: 'UHF' },
  { id: 'shf',  label: 'SHF (Mikro)' },
]

const filteredBands = computed(() => {
  return data.bands.filter(b => {
    if (filterType.value !== 'alle') {
      if (filterType.value === 'lf') {
        if (b.type !== 'lf' && b.type !== 'mf') return false
      } else if (b.type !== filterType.value) return false
    }
    if (filterContest.value && !b.contest) return false
    if (filterWarc.value) {
      const isWarc = b.iaru.includes('WARC') || b.iaru.includes('WRC')
      if (!isWarc) return false
    }
    if (filterDigi.value && !b.digi) return false
    return true
  })
})

function toggleBand(id) {
  expandedBand.value = expandedBand.value === id ? null : id
}

function fmtFreq(kHz) {
  if (kHz >= 1_000_000) return (kHz / 1_000_000).toFixed(3) + ' GHz'
  if (kHz >= 1000) return (kHz / 1000).toFixed(3) + ' MHz'
  return (kHz % 1 === 0 ? kHz.toFixed(0) : kHz.toFixed(1)) + ' kHz'
}

function fmtBW(bw) {
  if (bw === 0) return '—'
  if (bw < 1000) return `${bw} Hz`
  const k = bw / 1000
  return (k % 1 === 0 ? k.toFixed(0) : k.toFixed(1)) + ' kHz'
}

function lookup() {
  const raw = lookupFreq.value.trim().replace(',', '.')
  const f = parseFloat(raw)
  if (isNaN(f)) return
  for (const band of data.bands) {
    if (f < band.fMin * 1000 || f > band.fMax * 1000) continue
    expandedBand.value = band.id
    return
  }
}
</script>

<template>
  <div class="calc-title">IARU R1 Bandplan</div>

  <div class="card">
    <h2>Frequenz-Lookup</h2>
    <div class="lookup-row">
      <input type="text" v-model="lookupFreq" placeholder="Frequenz in kHz (z.B. 14074)"
             @keyup.enter="lookup">
      <button class="btn" @click="lookup">Lookup</button>
    </div>
  </div>

  <div class="card">
    <h2>Filter</h2>
    <div class="seg" style="margin-bottom: 8px; flex-wrap: wrap">
      <button v-for="f in typeFilters" :key="f.id"
              class="sb" :class="{ on: filterType === f.id }"
              @click="filterType = f.id">{{ f.label }}</button>
    </div>
    <div class="seg" style="flex-wrap: wrap">
      <button class="sb" :class="{ on: filterContest }" @click="filterContest = !filterContest" style="border-color: #f97316">Contest</button>
      <button class="sb" :class="{ on: filterWarc }"   @click="filterWarc = !filterWarc"     style="border-color: #22c55e">WARC</button>
      <button class="sb" :class="{ on: filterDigi }"   @click="filterDigi = !filterDigi"     style="border-color: #a855f7">Digi</button>
      <span style="margin-left:auto; opacity:0.7; font-size:12px">{{ filteredBands.length }} Bänder</span>
    </div>
  </div>

  <div v-for="band in filteredBands" :key="band.id"
       class="card band-card" :class="{ open: expandedBand === band.id }">
    <div class="band-bar-row" @click="toggleBand(band.id)">
      <span class="band-name">{{ band.name }}</span>
      <div class="band-bar">
        <div v-for="(seg, i) in band.segments" :key="i"
             class="bar-seg"
             :style="{ flexBasis: seg.pct + '%', backgroundColor: seg.color }">
          <span>{{ seg.label }}</span>
        </div>
      </div>
      <div class="band-meta">
        <span class="band-range">{{ band.freq }}</span>
        <span class="band-power">{{ band.leistung }}</span>
      </div>
      <span class="caret">{{ expandedBand === band.id ? '▲' : '▼' }}</span>
    </div>

    <div v-if="expandedBand === band.id" class="band-detail">
      <div class="detail-head">
        <strong>{{ band.name }} Band</strong>
        <span class="band-range">{{ band.freq }}</span>
        <span class="badge" :class="band.zuweisung.includes('Sekundär') ? 'b-yellow' : 'b-blue'">{{ band.zuweisung }}</span>
        <span class="badge b-grey">Max. {{ band.leistung }}</span>
      </div>
      <div class="chips">
        <span v-for="m in band.modes" :key="m" class="badge b-blue">{{ m }}</span>
        <span v-if="band.contest" class="badge b-orange">Contest ✓</span>
      </div>
      <p class="lbl">Typische Nutzung:</p>
      <p class="bold">{{ band.typUse }}</p>
      <p class="info">{{ band.info }}</p>
      <p class="src">Quelle: {{ band.iaru }}</p>

      <table class="sub-table">
        <thead>
          <tr>
            <th>VON – BIS</th>
            <th>BANDBREITE</th>
            <th>MODUS</th>
            <th>HINWEIS</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(sub, i) in band.subsegments" :key="i" :class="{ even: i % 2 === 0 }">
            <td>
              <div class="from" :style="{ color: categories[sub.cat]?.color || '#aaa' }">{{ fmtFreq(sub.von) }}</div>
              <div class="to">– {{ fmtFreq(sub.bis) }}</div>
            </td>
            <td class="mono">{{ fmtBW(sub.bw) }}</td>
            <td>{{ sub.mode }}</td>
            <td class="note">{{ sub.info }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>

  <div class="card">
    <h2>Legende</h2>
    <div class="legend">
      <div v-for="(cat, key) in categories" :key="key" class="legend-item">
        <span class="legend-color" :style="{ backgroundColor: cat.color }"></span>
        <span>{{ cat.label }}</span>
      </div>
    </div>
    <p style="margin-top:12px; font-size:11px; opacity:0.65">
      Quelle: funkwelt-bandguide · IARU R1 Band Plans + BAKOM/NaFV (Schweiz). Visualisierung schematisch — verbindlich ist immer der offizielle Bandplan.
    </p>
  </div>
</template>

<style scoped>
.lookup-row { display: flex; gap: 8px; align-items: center }
.lookup-row input { flex: 1; padding: 8px 10px; border-radius: 6px; border: 1px solid var(--border, #333); background: var(--bg-input, #1a1a1a); color: inherit }

.band-card { padding: 0; overflow: hidden }
.band-card.open { border-color: #3b82f6 }

.band-bar-row {
  display: flex; align-items: center; gap: 12px;
  padding: 12px; cursor: pointer;
}
.band-name { font-weight: 700; font-size: 16px; min-width: 60px }
.band-bar { flex: 1; display: flex; height: 28px; border-radius: 4px; overflow: hidden }
.bar-seg {
  display: flex; align-items: center; justify-content: center;
  color: white; font-size: 9px; font-weight: 600;
  white-space: nowrap; overflow: hidden;
}
.band-meta { display: flex; flex-direction: column; align-items: flex-end; gap: 2px }
.band-range { font-family: monospace; font-size: 11px; opacity: 0.8 }
.band-power { font-family: monospace; font-size: 10px; opacity: 0.6 }
.caret { opacity: 0.5; font-size: 11px }

.band-detail { padding: 14px; background: rgba(0,0,0,0.15); border-top: 1px solid rgba(255,255,255,0.05) }
.detail-head { display: flex; align-items: center; gap: 10px; margin-bottom: 8px; flex-wrap: wrap }
.chips { display: flex; gap: 6px; margin-bottom: 12px; flex-wrap: wrap }
.badge { font-size: 10px; font-weight: 600; padding: 3px 7px; border-radius: 4px }
.badge.b-blue   { background: #3b82f626; color: #3b82f6 }
.badge.b-yellow { background: #eab30833; color: #eab308 }
.badge.b-orange { background: #f9731633; color: #f97316 }
.badge.b-grey   { background: #6b728033; color: #9ca3af }

.lbl { font-size: 11px; font-weight: 600; opacity: 0.75; margin: 6px 0 2px }
.bold { font-weight: 600; margin: 0 0 6px }
.info { font-size: 13px; opacity: 0.85; margin: 0 0 8px }
.src { font-size: 10px; opacity: 0.55; margin: 0 0 12px }

.sub-table { width: 100%; border-collapse: collapse; font-size: 12px }
.sub-table th { text-align: left; font-size: 10px; font-weight: 700; padding: 8px 10px; opacity: 0.7; background: rgba(255,255,255,0.04) }
.sub-table td { padding: 6px 10px; vertical-align: top }
.sub-table tr.even td { background: rgba(255,255,255,0.025) }
.sub-table .from { font-weight: 600; font-size: 12px }
.sub-table .to { font-size: 11px; opacity: 0.7 }
.sub-table .mono { font-family: monospace }
.sub-table .note { opacity: 0.85 }

.legend { display: flex; flex-wrap: wrap; gap: 8px }
.legend-item { display: flex; align-items: center; gap: 4px; padding: 3px 8px; background: var(--bg-sub, #222); border-radius: 4px; font-size: 12px }
.legend-color { display: inline-block; width: 14px; height: 14px; border-radius: 2px }
</style>
