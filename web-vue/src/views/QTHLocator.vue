<script setup>
import { reactive, computed } from 'vue'
import RechnerBeschreibung from '../components/RechnerBeschreibung.vue'

const qth = reactive({ locator: 'JN47PN', lat: '', lon: '', mode: 'loc2coord' })

function loc2coord(loc) {
  if (!loc || loc.length < 4) return null
  loc = loc.toUpperCase()
  const lon = (loc.charCodeAt(0) - 65) * 20 - 180
             + (parseInt(loc[2]) * 2)
             + (loc.length >= 6 ? (loc.charCodeAt(4) - 65) / 12 : 1)
  const lat = (loc.charCodeAt(1) - 65) * 10 - 90
             + parseInt(loc[3])
             + (loc.length >= 6 ? (loc.charCodeAt(5) - 65) / 24 : 0.5)
  return { mode: 'loc2coord', loc, lat: lat.toFixed(5), lon: lon.toFixed(5) }
}

function coord2loc(lat, lon) {
  lon += 180; lat += 90
  const A = String.fromCharCode(65 + Math.floor(lon / 20))
  const B = String.fromCharCode(65 + Math.floor(lat / 10))
  const C = String(Math.floor((lon % 20) / 2))
  const D = String(Math.floor(lat % 10))
  const E = String.fromCharCode(65 + Math.floor((lon % 2) * 12))
  const F = String.fromCharCode(65 + Math.floor((lat % 1) * 24))
  return { mode: 'coord2loc', loc: A+B+C+D+E+F, lat: lat-90, lon: lon-180 }
}

const result = computed(() => {
  if (qth.mode === 'loc2coord') {
    return loc2coord(qth.locator.toUpperCase().trim())
  } else {
    const lat = parseFloat(qth.lat), lon = parseFloat(qth.lon)
    if (isNaN(lat) || isNaN(lon)) return null
    return coord2loc(lat, lon)
  }
})
</script>

<template>
  <div class="calc-title">QTH-Locator</div>
  <div class="card">
    <h2>Modus</h2>
    <div class="seg">
      <button class="sb" :class="{ on: qth.mode === 'loc2coord' }" @click="qth.mode = 'loc2coord'">Locator → Koordinaten</button>
      <button class="sb" :class="{ on: qth.mode === 'coord2loc' }" @click="qth.mode = 'coord2loc'">Koordinaten → Locator</button>
    </div>
  </div>
  <div class="card">
    <h2>Eingabe</h2>
    <template v-if="qth.mode === 'loc2coord'">
      <div class="inp-g" style="max-width:240px">
        <label>Maidenhead Locator</label>
        <input type="text" v-model="qth.locator" placeholder="z.B. JN47PN" style="text-transform:uppercase">
      </div>
    </template>
    <template v-else>
      <div class="inp-grid">
        <div class="inp-g"><label>Breitengrad (Latitude)</label><div class="inp-row"><input type="text" v-model="qth.lat"><span>°N</span></div></div>
        <div class="inp-g"><label>Längengrad (Longitude)</label><div class="inp-row"><input type="text" v-model="qth.lon"><span>°E</span></div></div>
      </div>
    </template>
  </div>
  <template v-if="result">
    <div class="card">
      <h2>Ergebnis</h2>
      <template v-if="result.mode === 'loc2coord'">
        <div class="rr hi"><span class="lbl">Locator</span><span class="val">{{ result.loc }}</span></div>
        <div class="rr"><span class="lbl">Breitengrad</span><span class="val">{{ result.lat }}° N</span></div>
        <div class="rr"><span class="lbl">Längengrad</span><span class="val">{{ result.lon }}° E</span></div>
      </template>
      <template v-else>
        <div class="rr hi"><span class="lbl">Maidenhead Locator (6-stellig)</span><span class="val">{{ result.loc }}</span></div>
        <div class="rr"><span class="lbl">Breitengrad</span><span class="val">{{ Number(result.lat).toFixed(5) }}° N</span></div>
        <div class="rr"><span class="lbl">Längengrad</span><span class="val">{{ Number(result.lon).toFixed(5) }}° E</span></div>
      </template>
    </div>
  </template>
  <RechnerBeschreibung name="qthlocator" />
</template>
