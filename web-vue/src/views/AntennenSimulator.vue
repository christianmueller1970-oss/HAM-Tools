<script setup>
import { reactive, ref, onMounted, onBeforeUnmount, computed } from 'vue'
import { useRoute } from 'vue-router'
import Pattern3D from '../components/Pattern3D.vue'
import { decodeModel } from '../composables/openInSim.js'

const route = useRoute()

// ─── Templates ────────────────────────────────────────────────────────────────

function dipolTemplate(fMHz = 14.2, h = 10) {
  const halfLen = (300 / fMHz) * 0.475 / 2  // halbe halbe Wellenlänge
  return {
    name: `Dipol ${(halfLen*2).toFixed(2)}m @ ${fMHz} MHz`,
    freq: fMHz,
    ground: 'free_space',
    height: h,
    wires: [
      { tag: 1, segments: 21, x1: -halfLen, y1: 0, z1: h, x2: halfLen, y2: 0, z2: h, radius_mm: 1.0 },
    ],
    excitation: { wire_tag: 1, segment: 11 },
  }
}
function invertedVTemplate(fMHz = 14.2, h = 12) {
  const halfLen = (300 / fMHz) * 0.475 / 2
  // Apex bei (0,0,h), Endpunkte runter auf 30° Winkel
  const drop = halfLen * Math.sin(30 * Math.PI / 180)
  const horiz = halfLen * Math.cos(30 * Math.PI / 180)
  return {
    name: `Inverted-V ${(halfLen*2).toFixed(2)}m @ ${fMHz} MHz`,
    freq: fMHz,
    ground: 'average',
    height: h,
    wires: [
      { tag: 1, segments: 11, x1: -horiz, y1: 0, z1: h - drop, x2: 0, y2: 0, z2: h, radius_mm: 1.0 },
      { tag: 2, segments: 11, x1: 0, y1: 0, z1: h, x2: horiz, y2: 0, z2: h - drop, radius_mm: 1.0 },
    ],
    excitation: { wire_tag: 1, segment: 11 },  // letztes Segment vor Apex
  }
}
function yagi2Template(fMHz = 14.2, h = 12) {
  const lambda = 300 / fMHz
  const refLen = lambda * 0.5 * 1.05 / 2
  const drvLen = lambda * 0.5 * 0.93 / 2
  const spacing = lambda * 0.15
  return {
    name: `2-Element Yagi @ ${fMHz} MHz`,
    freq: fMHz,
    ground: 'average',
    height: h,
    wires: [
      { tag: 1, segments: 21, x1: -refLen, y1: -spacing/2, z1: h, x2: refLen, y2: -spacing/2, z2: h, radius_mm: 5.0 },  // Reflektor
      { tag: 2, segments: 21, x1: -drvLen, y1:  spacing/2, z1: h, x2: drvLen, y2:  spacing/2, z2: h, radius_mm: 5.0 },  // Driver
    ],
    excitation: { wire_tag: 2, segment: 11 },
  }
}
function yagi3Template(fMHz = 14.2, h = 12) {
  const lambda = 300 / fMHz
  const refLen = lambda * 0.5 * 1.06 / 2
  const drvLen = lambda * 0.5 * 0.94 / 2
  const dirLen = lambda * 0.5 * 0.86 / 2
  return {
    name: `3-Element Yagi @ ${fMHz} MHz`,
    freq: fMHz,
    ground: 'average',
    height: h,
    wires: [
      { tag: 1, segments: 21, x1: -refLen, y1: -2.0, z1: h, x2: refLen, y2: -2.0, z2: h, radius_mm: 5.0 },
      { tag: 2, segments: 21, x1: -drvLen, y1:  0.0, z1: h, x2: drvLen, y2:  0.0, z2: h, radius_mm: 5.0 },
      { tag: 3, segments: 21, x1: -dirLen, y1:  1.5, z1: h, x2: dirLen, y2:  1.5, z2: h, radius_mm: 5.0 },
    ],
    excitation: { wire_tag: 2, segment: 11 },
  }
}
function quadTemplate(fMHz = 28.5, h = 8) {
  // Square Loop, eine Wellenlänge Umfang
  const side = (300 / fMHz) * 1.018 / 4  // Side length
  return {
    name: `Quad-Loop (1λ Umfang) @ ${fMHz} MHz`,
    freq: fMHz,
    ground: 'average',
    height: h,
    wires: [
      { tag: 1, segments: 11, x1: -side/2, y1: 0, z1: h - side/2, x2:  side/2, y2: 0, z2: h - side/2, radius_mm: 2.0 },  // unten
      { tag: 2, segments: 11, x1:  side/2, y1: 0, z1: h - side/2, x2:  side/2, y2: 0, z2: h + side/2, radius_mm: 2.0 },  // rechts
      { tag: 3, segments: 11, x1:  side/2, y1: 0, z1: h + side/2, x2: -side/2, y2: 0, z2: h + side/2, radius_mm: 2.0 },  // oben
      { tag: 4, segments: 11, x1: -side/2, y1: 0, z1: h + side/2, x2: -side/2, y2: 0, z2: h - side/2, radius_mm: 2.0 },  // links
    ],
    excitation: { wire_tag: 1, segment: 6 },
  }
}

// ─── Zusätzliche Templates (entsprechend den 14 Antennen-Rechnern) ───────────

function efhwTemplate(fMHz = 7.1) {
  const draht = (150 / fMHz) * 0.96
  const lambda = 300 / fMHz
  const h = Math.max(8, lambda / 2)
  return {
    name: `EFHW ${draht.toFixed(2)}m @ ${fMHz} MHz`,
    freq: fMHz, ground: 'average', height: h,
    wires: [
      { tag: 1, segments: 21, x1: 0, y1: 0, z1: h, x2: draht, y2: 0, z2: h, radius_mm: 1.0 },
      { tag: 2, segments: 5,  x1: 0, y1: 0, z1: h, x2: -lambda * 0.05, y2: 0, z2: h, radius_mm: 1.0 },
    ],
    excitation: { wire_tag: 1, segment: 1 },
  }
}

function windomTemplate(fMHz = 7.1) {
  const gesamt = (150 / fMHz) * 0.95
  const lang = gesamt * 0.64
  const kurz = gesamt * 0.36
  const h = Math.max(8, (300 / fMHz) / 2)
  return {
    name: `Windom (OCFD) ${gesamt.toFixed(2)}m @ ${fMHz} MHz`,
    freq: fMHz, ground: 'average', height: h,
    wires: [
      { tag: 1, segments: 9,  x1: -kurz, y1: 0, z1: h, x2: 0,    y2: 0, z2: h, radius_mm: 1.0 },
      { tag: 2, segments: 17, x1: 0,     y1: 0, z1: h, x2: lang, y2: 0, z2: h, radius_mm: 1.0 },
    ],
    excitation: { wire_tag: 2, segment: 1 },
  }
}

function groundplaneTemplate(fMHz = 14.175) {
  const strahler = (75 / fMHz) * 0.95
  const radial = strahler * 1.02
  const lambda = 300 / fMHz
  const h = Math.max(lambda * 0.1, 3)
  const winkel = 45 * Math.PI / 180
  const radialDz = -Math.sin(winkel) * radial
  const radialDr =  Math.cos(winkel) * radial
  const wires = [
    { tag: 1, segments: 11, x1: 0, y1: 0, z1: h, x2: 0, y2: 0, z2: h + strahler, radius_mm: 2.0 },
  ]
  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * 2 * Math.PI
    wires.push({
      tag: 2 + i, segments: 9,
      x1: 0, y1: 0, z1: h,
      x2: Math.cos(a) * radialDr, y2: Math.sin(a) * radialDr, z2: h + radialDz,
      radius_mm: 1.0,
    })
  }
  return {
    name: `Groundplane ${strahler.toFixed(2)}m @ ${fMHz} MHz (4 Radials)`,
    freq: fMHz, ground: 'average', height: h, wires,
    excitation: { wire_tag: 1, segment: 1 },
  }
}

function moxonTemplate(fMHz = 14.175) {
  const lam = (300 / fMHz) * 0.95
  const A = lam * 0.4750, B = lam * 0.0500, C = lam * 0.0156, D = lam * 0.0624, E = lam * 0.4750
  const depth = B + C + D
  const xD = depth / 2, xR = -depth / 2
  const xDTail = xD - B, xRTail = xR + D
  const halfA = A / 2, halfE = E / 2
  const h = Math.max(8, (300 / fMHz) / 2)
  return {
    name: `Moxon @ ${fMHz} MHz`,
    freq: fMHz, ground: 'average', height: h,
    wires: [
      { tag: 1, segments: 11, x1: xD, y1: -halfA, z1: h, x2: xD, y2: 0,     z2: h, radius_mm: 2.0 },
      { tag: 2, segments: 11, x1: xD, y1: 0,     z1: h, x2: xD, y2: halfA, z2: h, radius_mm: 2.0 },
      { tag: 3, segments: 5,  x1: xD, y1: -halfA, z1: h, x2: xDTail, y2: -halfA, z2: h, radius_mm: 2.0 },
      { tag: 4, segments: 5,  x1: xD, y1:  halfA, z1: h, x2: xDTail, y2:  halfA, z2: h, radius_mm: 2.0 },
      { tag: 5, segments: 21, x1: xR, y1: -halfE, z1: h, x2: xR, y2: halfE, z2: h, radius_mm: 2.0 },
      { tag: 6, segments: 5,  x1: xR, y1: -halfE, z1: h, x2: xRTail, y2: -halfE, z2: h, radius_mm: 2.0 },
      { tag: 7, segments: 5,  x1: xR, y1:  halfE, z1: h, x2: xRTail, y2:  halfE, z2: h, radius_mm: 2.0 },
    ],
    excitation: { wire_tag: 2, segment: 1 },
  }
}

function deltaLoopTemplate(fMHz = 7.1) {
  // Gleichseitig, 110Ω-Variante
  const total = (306.3 / fMHz)
  const side = total / 3
  const half = side / 2
  const triH = side * Math.sqrt(3) / 2
  const lambda = 300 / fMHz
  const h = Math.max(8, lambda * 0.25)
  return {
    name: `Delta-Loop ${total.toFixed(2)}m @ ${fMHz} MHz`,
    freq: fMHz, ground: 'average', height: h,
    wires: [
      { tag: 1, segments: 7,  x1: 0, y1: -half, z1: h,         x2: 0, y2: 0,    z2: h,         radius_mm: 1.5 },
      { tag: 2, segments: 7,  x1: 0, y1: 0,     z1: h,         x2: 0, y2: half, z2: h,         radius_mm: 1.5 },
      { tag: 3, segments: 13, x1: 0, y1: half,  z1: h,         x2: 0, y2: 0,    z2: h + triH,  radius_mm: 1.5 },
      { tag: 4, segments: 13, x1: 0, y1: 0,     z1: h + triH,  x2: 0, y2: -half, z2: h,        radius_mm: 1.5 },
    ],
    excitation: { wire_tag: 2, segment: 1 },
  }
}

function yagi5Template(fMHz = 28.5) {
  const lambda = 300 / fMHz
  const h = Math.max(8, lambda / 2)
  // 5-Element Yagi mit Standard-Faktoren
  const factors = [
    { name: 'Refl', len: 0.500, S: 0 },
    { name: 'Drv',  len: 0.469, S: 0.15 },
    { name: 'D1',   len: 0.442, S: 0.33 },
    { name: 'D2',   len: 0.438, S: 0.55 },
    { name: 'D3',   len: 0.434, S: 0.80 },
  ]
  const wires = factors.map((el, idx) => {
    const halfLen = lambda * el.len * 0.95 / 2
    const x = lambda * el.S
    return {
      tag: idx + 1, segments: 21,
      x1: x, y1: -halfLen, z1: h, x2: x, y2: halfLen, z2: h, radius_mm: 5.0,
    }
  })
  return {
    name: `5-Element Yagi @ ${fMHz} MHz`,
    freq: fMHz, ground: 'average', height: h, wires,
    excitation: { wire_tag: 2, segment: 11 },
  }
}

const TEMPLATES = {
  dipol:        () => dipolTemplate(),
  invV:         () => invertedVTemplate(),
  yagi2:        () => yagi2Template(),
  yagi3:        () => yagi3Template(),
  yagi5:        () => yagi5Template(),
  quad:         () => quadTemplate(),
  efhw:         () => efhwTemplate(),
  windom:       () => windomTemplate(),
  groundplane:  () => groundplaneTemplate(),
  moxon:        () => moxonTemplate(),
  deltaloop:    () => deltaLoopTemplate(),
}

// ─── Reactive State ───────────────────────────────────────────────────────────

const cfg = reactive(dipolTemplate())
const sweep = reactive({
  enabled: false,
  f_start: 13.8,
  f_stop: 14.6,
  steps: 21,
})
const status = ref('Worker noch nicht initialisiert')
const running = ref(false)
const result = ref(null)
const errorMsg = ref(null)
const showAntennaIn3D = ref(true)

let worker = null
let pendingId = 0

onMounted(() => {
  worker = new Worker('/antenna-worker.js')
  worker.onmessage = (e) => {
    const m = e.data
    if (m.type === 'success') {
      result.value = m.result
      errorMsg.value = null
      status.value = `OK · ${m.result.computed_in_ms} ms`
    } else if (m.type === 'error') {
      errorMsg.value = m.message
      result.value = null
      status.value = 'Fehler'
    }
    running.value = false
  }
  worker.onerror = (err) => {
    errorMsg.value = err.message
    running.value = false
  }
  status.value = 'Bereit'

  // ?model=<base64-JSON> → Antennen-Modell aus anderem Rechner importieren
  // (gesetzt vom "Im Sim öffnen"-Button in Hexbeam/Yagi/Dipol-Views)
  if (route.query.model) {
    const m = decodeModel(String(route.query.model))
    if (m && m.wires && Array.isArray(m.wires) && m.wires.length > 0) {
      cfg.name = m.name || 'Importiertes Modell'
      cfg.freq = m.freq
      cfg.ground = m.ground || 'average'
      cfg.height = m.height || 10
      cfg.wires = m.wires
      cfg.excitation = m.excitation || { wire_tag: m.wires[0].tag, segment: Math.ceil(m.wires[0].segments / 2) }
      status.value = `Modell aus Rechner importiert: ${cfg.name}`
    } else {
      status.value = 'Bereit · (URL-Modell ungültig, Default geladen)'
    }
  }
})
onBeforeUnmount(() => { if (worker) worker.terminate() })

// ─── Template-Wechsel ────────────────────────────────────────────────────────

function loadTemplate(key) {
  const t = TEMPLATES[key]?.()
  if (!t) return
  cfg.name = t.name
  cfg.freq = t.freq
  cfg.ground = t.ground
  cfg.height = t.height
  cfg.wires = t.wires
  cfg.excitation = t.excitation
  result.value = null
  errorMsg.value = null
}

function addWire() {
  const newTag = (cfg.wires.length ? Math.max(...cfg.wires.map(w => w.tag)) : 0) + 1
  cfg.wires.push({
    tag: newTag, segments: 11,
    x1: 0, y1: 0, z1: cfg.height,
    x2: 1, y2: 0, z2: cfg.height,
    radius_mm: 1.0,
  })
}
function removeWire(idx) {
  if (cfg.wires.length <= 1) return
  cfg.wires.splice(idx, 1)
}

// ─── Modell um 90° drehen (H ↔ V Polarisation, Pole-Orientierung ändern) ────
// Rotation um die jeweilige Achse durch (0, 0, h_center).
// Nach der Rotation wird der niedrigste Z-Wert geprüft — wenn < 0.5m,
// wird das Modell entsprechend nach oben verschoben (damit nichts unter dem Boden landet).
function rotateModel(axis) {
  const h = cfg.height || 10
  function rot(x, y, z) {
    if (axis === 'X') {
      // Rotation 90° um X-Achse durch (0, 0, h): elements-entlang-Y → vertikal
      return { x, y: h - z, z: y + h }
    }
    if (axis === 'Y') {
      // Rotation 90° um Y-Achse durch (0, 0, h): elements-entlang-X → vertikal
      return { x: z - h, y, z: -x + h }
    }
    // Z-Achse: dreht horizontal, ändert Polarisation nicht (nur Beam-Richtung)
    return { x: -y, y: x, z }
  }
  const newWires = cfg.wires.map(w => {
    const p1 = rot(w.x1, w.y1, w.z1)
    const p2 = rot(w.x2, w.y2, w.z2)
    return { ...w, x1: p1.x, y1: p1.y, z1: p1.z, x2: p2.x, y2: p2.y, z2: p2.z }
  })
  // Min-Z prüfen, ggf. Modell hochheben damit nichts unter dem Boden ist
  let minZ = Infinity
  for (const w of newWires) {
    if (w.z1 < minZ) minZ = w.z1
    if (w.z2 < minZ) minZ = w.z2
  }
  if (minZ < 0.5) {
    const offset = 0.5 - minZ
    for (const w of newWires) {
      w.z1 += offset
      w.z2 += offset
    }
  }
  cfg.wires = newWires
  const hadResult = result.value !== null
  result.value = null
  errorMsg.value = null
  status.value = `Modell um 90° gedreht (${axis}-Achse)…`
  // Wenn vorher schon eine Simulation lief, automatisch neu rechnen
  // damit Pattern + 3D unmittelbar das gedrehte Modell zeigen.
  if (hadResult && !running.value) {
    simulate()
  }
}

// ─── Simulation ──────────────────────────────────────────────────────────────

function simulate() {
  if (!worker) return
  errorMsg.value = null
  running.value = true
  status.value = 'Simuliere…'

  const wires = cfg.wires.map(w => ({
    tag: w.tag, segments: Math.max(3, Math.min(101, parseInt(w.segments) || 11)),
    x1: parseFloat(w.x1), y1: parseFloat(w.y1), z1: parseFloat(w.z1),
    x2: parseFloat(w.x2), y2: parseFloat(w.y2), z2: parseFloat(w.z2),
    radius: (parseFloat(w.radius_mm) || 1) / 1000,
  }))
  const request = {
    comment: cfg.name || 'HAM-Tools Antennen-Simulator',
    wires,
    excitations: [{
      wire_tag: cfg.excitation.wire_tag,
      segment: cfg.excitation.segment,
      voltage_real: 1.0, voltage_imag: 0,
    }],
    ground: cfg.ground,
    frequency_mhz: parseFloat(cfg.freq),
  }
  if (sweep.enabled) {
    request.sweep = {
      f_start: parseFloat(sweep.f_start),
      f_stop:  parseFloat(sweep.f_stop),
      steps:   Math.max(2, Math.min(101, parseInt(sweep.steps) || 21)),
    }
  }
  pendingId++
  worker.postMessage({ type: 'simulate', id: pendingId, request })
}

// ─── 2D-Vorschau ─────────────────────────────────────────────────────────────

const VIEW_SIZE = 320

const bounds = computed(() => {
  const xs = cfg.wires.flatMap(w => [w.x1, w.x2])
  const ys = cfg.wires.flatMap(w => [w.y1, w.y2])
  const zs = cfg.wires.flatMap(w => [w.z1, w.z2])
  const fmt = arr => ({ min: Math.min(...arr), max: Math.max(...arr) })
  return { x: fmt(xs), y: fmt(ys), z: fmt(zs) }
})

function projectXY(x, y) {
  const b = bounds.value
  const rangeX = Math.max(b.x.max - b.x.min, b.y.max - b.y.min, 1) * 1.2
  const cx = (b.x.max + b.x.min) / 2
  const cy = (b.y.max + b.y.min) / 2
  const px = VIEW_SIZE / 2 + (x - cx) / rangeX * VIEW_SIZE
  const py = VIEW_SIZE / 2 - (y - cy) / rangeX * VIEW_SIZE
  return { x: px, y: py }
}
function projectXZ(x, z) {
  const b = bounds.value
  const rangeX = Math.max(b.x.max - b.x.min, 1) * 1.2
  const rangeZ = Math.max(b.z.max - b.z.min, 1) * 1.2
  const range = Math.max(rangeX, rangeZ)
  const cx = (b.x.max + b.x.min) / 2
  const cz = (b.z.max + b.z.min) / 2
  const px = VIEW_SIZE / 2 + (x - cx) / range * VIEW_SIZE
  const py = VIEW_SIZE / 2 - (z - cz) / range * VIEW_SIZE
  return { x: px, y: py }
}

const wirePathsXY = computed(() => cfg.wires.map(w => {
  const a = projectXY(w.x1, w.y1)
  const b = projectXY(w.x2, w.y2)
  const isExcited = w.tag === cfg.excitation.wire_tag
  return { a, b, tag: w.tag, isExcited }
}))
const wirePathsXZ = computed(() => cfg.wires.map(w => {
  const a = projectXZ(w.x1, w.z1)
  const b = projectXZ(w.x2, w.z2)
  const isExcited = w.tag === cfg.excitation.wire_tag
  return { a, b, tag: w.tag, isExcited }
}))

// ─── Helpers für Result-Zugriff ──────────────────────────────────────────────

const primary = computed(() => result.value?.primary || null)
const sweepBlocks = computed(() => result.value?.blocks || [])
const isSweep = computed(() => result.value?.is_sweep || false)

// ─── Pattern-Plots (nur Single-Freq) ─────────────────────────────────────────

const PLOT_SIZE = 280

const polarPoints = computed(() => {
  if (!primary.value || !primary.value.pattern) return []
  const isFree = cfg.ground === 'free_space'
  const targetTheta = isFree ? 90 : 80
  const tol = 5
  return primary.value.pattern
    .filter(p => Math.abs(p.theta - targetTheta) < tol)
    .sort((a, b) => a.phi - b.phi)
})
const elevationPoints = computed(() => {
  if (!primary.value || !primary.value.pattern) return []
  return primary.value.pattern
    .filter(p => Math.abs(p.phi) < 5)
    .sort((a, b) => a.theta - b.theta)
})

// ─── Sweep-Charts (SWR + Z über Frequenz) ────────────────────────────────────

const SWEEP_W = 640, SWEEP_H = 200

function sweepChart(blocks, key, color, yMin, yMax, label) {
  if (blocks.length < 2) return { path: '', ticks: [] }
  const fMin = blocks[0].frequency_mhz
  const fMax = blocks[blocks.length - 1].frequency_mhz
  const margin = { l: 50, r: 16, t: 12, b: 28 }
  const W = SWEEP_W - margin.l - margin.r
  const H = SWEEP_H - margin.t - margin.b
  const xOf = f => margin.l + (f - fMin) / (fMax - fMin) * W
  const yOf = v => margin.t + H - Math.max(0, Math.min(1, (v - yMin) / (yMax - yMin))) * H
  let d = ''
  for (let i = 0; i < blocks.length; i++) {
    const v = key(blocks[i])
    const x = xOf(blocks[i].frequency_mhz)
    const y = yOf(v)
    d += (i === 0 ? `M ${x.toFixed(1)} ${y.toFixed(1)}` : ` L ${x.toFixed(1)} ${y.toFixed(1)}`)
  }
  return { path: d, color, fMin, fMax, yMin, yMax, label, margin, W, H }
}
const swrChart = computed(() => sweepChart(
  sweepBlocks.value,
  b => Math.min(5, b.swr_50),
  '#3b82f6', 1, 5, 'SWR (50 Ω)'
))
const zChart = computed(() => {
  // R und X auf gleichem Chart; auto-scale
  const blocks = sweepBlocks.value
  if (blocks.length < 2) return null
  let yMin = -300, yMax = 300
  for (const b of blocks) {
    if (b.impedance.real > yMax) yMax = b.impedance.real
    if (b.impedance.real < yMin) yMin = b.impedance.real
    if (b.impedance.imag > yMax) yMax = b.impedance.imag
    if (b.impedance.imag < yMin) yMin = b.impedance.imag
  }
  yMin = Math.floor(yMin / 50) * 50
  yMax = Math.ceil(yMax / 50) * 50
  const r = sweepChart(blocks, b => b.impedance.real, '#22c55e', yMin, yMax, '')
  const x = sweepChart(blocks, b => b.impedance.imag, '#f97316', yMin, yMax, '')
  return { ...r, rPath: r.path, xPath: x.path, yMin, yMax }
})

// Bandbreite (SWR < 2)
const bandwidth = computed(() => {
  const blocks = sweepBlocks.value
  if (blocks.length < 3) return null
  let lo = null, hi = null
  for (const b of blocks) {
    if (b.swr_50 <= 2) {
      if (lo === null) lo = b.frequency_mhz
      hi = b.frequency_mhz
    }
  }
  if (lo === null || hi === null) return null
  return { lo, hi, bw: hi - lo }
})
// Resonanz (Z_imag = 0 — linear interpoliert)
const resonance = computed(() => {
  const blocks = sweepBlocks.value
  if (blocks.length < 2) return null
  let best = null
  for (let i = 0; i < blocks.length - 1; i++) {
    const a = blocks[i], b = blocks[i + 1]
    if ((a.impedance.imag <= 0 && b.impedance.imag >= 0) ||
        (a.impedance.imag >= 0 && b.impedance.imag <= 0)) {
      const ratio = Math.abs(a.impedance.imag) / (Math.abs(a.impedance.imag) + Math.abs(b.impedance.imag))
      const f = a.frequency_mhz + ratio * (b.frequency_mhz - a.frequency_mhz)
      const r = a.impedance.real + ratio * (b.impedance.real - a.impedance.real)
      best = { f, r }
      break
    }
  }
  return best
})

function polarPath(points, kind) {
  if (points.length < 3) return ''
  const cx = PLOT_SIZE / 2, cy = PLOT_SIZE / 2
  const R = PLOT_SIZE / 2 - 24
  let maxG = -999
  for (const p of points) if (p.gain > maxG) maxG = p.gain
  if (maxG < -30) maxG = -30
  const minG = maxG - 40
  const range = maxG - minG
  let d = ''
  for (let i = 0; i < points.length; i++) {
    const p = points[i]
    const norm = Math.max(0, (p.gain - minG) / range)
    const r = norm * R
    const angle = (kind === 'azimuth' ? p.phi : p.theta) * Math.PI / 180
    const x = cx + r * Math.sin(angle)
    const y = cy - r * Math.cos(angle)
    d += (i === 0 ? `M ${x.toFixed(2)} ${y.toFixed(2)}` : ` L ${x.toFixed(2)} ${y.toFixed(2)}`)
  }
  return d + ' Z'
}
const azimuthPath  = computed(() => polarPath(polarPoints.value, 'azimuth'))
const elevationPath = computed(() => polarPath(elevationPoints.value, 'elevation'))
const PLOT_R = PLOT_SIZE / 2 - 24
const PLOT_C = PLOT_SIZE / 2
</script>

<template>
  <div class="calc-title">Antennen-Simulator (Phase 2) — Mehrelement-Editor</div>

  <div class="card" style="border-color:#3b82f6">
    <h2>📡 NEC2-Engine im Browser</h2>
    <p style="margin:0; opacity:0.85; font-size:13px">
      Drahtmodell-basierte Antennen-Simulation mit nec2c (Public Domain) als WASM. Definiere deine
      Antenne als Liste von Drahtsegmenten oder lade ein Template, wähle Speisepunkt und Boden,
      drücke Simulieren — du bekommst Impedanz, SWR, Gewinn und Strahlungsdiagramme.
    </p>
  </div>

  <div class="card">
    <h2>Templates</h2>
    <div style="font-size:11px; opacity:0.7; margin-bottom:6px; text-transform:uppercase; letter-spacing:0.5px">Dipol-Familie</div>
    <div class="seg" style="flex-wrap: wrap; gap:6px; margin-bottom:10px">
      <button class="sb" @click="loadTemplate('dipol')">Dipol</button>
      <button class="sb" @click="loadTemplate('invV')">Inverted-V</button>
      <button class="sb" @click="loadTemplate('efhw')">EFHW</button>
      <button class="sb" @click="loadTemplate('windom')">Windom (OCFD)</button>
    </div>
    <div style="font-size:11px; opacity:0.7; margin-bottom:6px; text-transform:uppercase; letter-spacing:0.5px">Yagi / Beam</div>
    <div class="seg" style="flex-wrap: wrap; gap:6px; margin-bottom:10px">
      <button class="sb" @click="loadTemplate('yagi2')">2-El Yagi</button>
      <button class="sb" @click="loadTemplate('yagi3')">3-El Yagi</button>
      <button class="sb" @click="loadTemplate('yagi5')">5-El Yagi</button>
      <button class="sb" @click="loadTemplate('moxon')">Moxon</button>
    </div>
    <div style="font-size:11px; opacity:0.7; margin-bottom:6px; text-transform:uppercase; letter-spacing:0.5px">Loop / Vertikal</div>
    <div class="seg" style="flex-wrap: wrap; gap:6px">
      <button class="sb" @click="loadTemplate('quad')">Quad-Loop</button>
      <button class="sb" @click="loadTemplate('deltaloop')">Delta-Loop</button>
      <button class="sb" @click="loadTemplate('groundplane')">Groundplane</button>
    </div>
    <p style="font-size:11px; opacity:0.65; margin-top:10px; line-height:1.5">
      Templates setzen Drahtmodell, Speisepunkt, Boden + Frequenz auf sinnvolle Defaults — du kannst danach alles editieren.
      Für komplexere Antennen (Hexbeam, Spiderbeam, HB9CV, J-Pole, Magnetic Loop) öffnest du am besten den entsprechenden
      Rechner und nutzt dort den <strong>📡 Im Sim öffnen</strong>-Button.
    </p>
  </div>

  <div class="card">
    <h2>Globale Konfiguration</h2>
    <div class="inp-grid" style="grid-template-columns: 2fr 1fr 1fr; gap: 12px">
      <div class="inp-g">
        <label>Bezeichnung</label>
        <input type="text" v-model="cfg.name">
      </div>
      <div class="inp-g">
        <label>Frequenz</label>
        <div class="inp-row"><input type="text" v-model="cfg.freq"><span>MHz</span></div>
      </div>
      <div class="inp-g">
        <label>Boden</label>
        <select v-model="cfg.ground">
          <option value="free_space">Free Space</option>
          <option value="average">Realer Boden</option>
          <option value="perfect">Perfekter Reflektor</option>
        </select>
      </div>
    </div>
  </div>

  <div class="card">
    <h2>Drahtsegmente ({{ cfg.wires.length }} Element{{ cfg.wires.length === 1 ? '' : 'e' }})</h2>
    <div style="overflow-x: auto">
      <table class="tbl wire-tbl">
        <thead>
          <tr>
            <th>Tag</th>
            <th>Seg</th>
            <th>X1</th><th>Y1</th><th>Z1</th>
            <th>X2</th><th>Y2</th><th>Z2</th>
            <th>R<br>mm</th>
            <th>SP</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(w, idx) in cfg.wires" :key="idx" :class="{ excited: w.tag === cfg.excitation.wire_tag }">
            <td><input type="number" v-model.number="w.tag" class="cell xs"></td>
            <td><input type="number" v-model.number="w.segments" min="3" max="101" class="cell xs"></td>
            <td><input type="number" step="0.01" v-model.number="w.x1" class="cell"></td>
            <td><input type="number" step="0.01" v-model.number="w.y1" class="cell"></td>
            <td><input type="number" step="0.01" v-model.number="w.z1" class="cell"></td>
            <td><input type="number" step="0.01" v-model.number="w.x2" class="cell"></td>
            <td><input type="number" step="0.01" v-model.number="w.y2" class="cell"></td>
            <td><input type="number" step="0.01" v-model.number="w.z2" class="cell"></td>
            <td><input type="number" step="0.1" v-model.number="w.radius_mm" class="cell xs"></td>
            <td>
              <input type="radio" :name="'sp'" :value="w.tag" v-model.number="cfg.excitation.wire_tag"
                     :title="`Tag ${w.tag} als Speisepunkt`">
            </td>
            <td>
              <button class="btn-x" @click="removeWire(idx)" :disabled="cfg.wires.length <= 1" title="Drahtsegment entfernen">×</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <div style="display:flex; align-items:center; gap:12px; margin-top:8px; flex-wrap: wrap">
      <button class="btn" @click="addWire">+ Draht hinzufügen</button>
      <div class="inp-g" style="flex-direction: row; align-items:center; gap:6px">
        <label style="margin:0">SP-Segment:</label>
        <input type="number" v-model.number="cfg.excitation.segment" min="1" class="cell xs">
        <span style="font-size:11px; opacity:0.7">(an Tag {{ cfg.excitation.wire_tag }})</span>
      </div>
      <div style="display:flex; align-items:center; gap:6px; margin-left:auto">
        <span style="font-size:11px; opacity:0.7">90° drehen:</span>
        <button class="btn" @click="rotateModel('X')" title="Rotiert um X-Achse — passend wenn Elemente entlang Y liegen (z.B. 5-El Yagi)">↻ X</button>
        <button class="btn" @click="rotateModel('Y')" title="Rotiert um Y-Achse — passend wenn Elemente entlang X liegen (z.B. 2-El/3-El Yagi, Dipol)">↻ Y</button>
        <button class="btn" @click="rotateModel('Z')" title="Rotiert um Z-Achse (vertikal) — ändert Beam-Richtung, nicht Polarisation">↻ Z</button>
      </div>
    </div>
    <p style="font-size:11px; opacity:0.6; margin-top:6px">
      <strong>SP</strong> = Speisepunkt (Excitation). Pro Modell ein Speisepunkt: Wähle den Draht (Radio) und das Segment (Nummer, mittig ist üblich).
      <strong>↻ X/Y</strong> kippen horizontal/vertikal-Polarisation — die richtige Achse hängt von der Element-Richtung im Modell ab; einfach ausprobieren, Min-Z wird automatisch über Boden gehalten.
    </p>
  </div>

  <div class="card">
    <h2>Modell-Vorschau</h2>
    <div style="display:flex; gap:24px; flex-wrap:wrap; justify-content:center">
      <div style="text-align:center">
        <div style="font-size:12px; opacity:0.7; margin-bottom:6px">Top-Down (X-Y, Blick von oben)</div>
        <svg :viewBox="`0 0 ${VIEW_SIZE} ${VIEW_SIZE}`" :width="VIEW_SIZE" :height="VIEW_SIZE" style="background: rgba(0,0,0,0.15); border-radius: 4px">
          <line x1="0" :y1="VIEW_SIZE/2" :x2="VIEW_SIZE" :y2="VIEW_SIZE/2" stroke="#444" stroke-width="0.5"/>
          <line :x1="VIEW_SIZE/2" y1="0" :x2="VIEW_SIZE/2" :y2="VIEW_SIZE" stroke="#444" stroke-width="0.5"/>
          <g v-for="(p, i) in wirePathsXY" :key="i">
            <line :x1="p.a.x" :y1="p.a.y" :x2="p.b.x" :y2="p.b.y"
                  :stroke="p.isExcited ? '#ef4444' : '#3b82f6'"
                  :stroke-width="p.isExcited ? 3 : 2"/>
            <circle :cx="(p.a.x + p.b.x)/2" :cy="(p.a.y + p.b.y)/2" r="3"
                    :fill="p.isExcited ? '#ef4444' : '#3b82f6'" opacity="0.7"/>
            <text :x="(p.a.x + p.b.x)/2 + 8" :y="(p.a.y + p.b.y)/2"
                  font-size="10" :fill="p.isExcited ? '#ef4444' : '#aaa'">T{{ p.tag }}</text>
          </g>
          <text x="6" y="14" font-size="10" fill="#666">Y ↑</text>
          <text :x="VIEW_SIZE-30" :y="VIEW_SIZE/2 - 4" font-size="10" fill="#666">→ X</text>
        </svg>
      </div>
      <div style="text-align:center">
        <div style="font-size:12px; opacity:0.7; margin-bottom:6px">Side (X-Z, Blick von Seite)</div>
        <svg :viewBox="`0 0 ${VIEW_SIZE} ${VIEW_SIZE}`" :width="VIEW_SIZE" :height="VIEW_SIZE" style="background: rgba(0,0,0,0.15); border-radius: 4px">
          <line x1="0" :y1="VIEW_SIZE/2" :x2="VIEW_SIZE" :y2="VIEW_SIZE/2" stroke="#444" stroke-width="0.5"/>
          <line :x1="VIEW_SIZE/2" y1="0" :x2="VIEW_SIZE/2" :y2="VIEW_SIZE" stroke="#444" stroke-width="0.5"/>
          <g v-for="(p, i) in wirePathsXZ" :key="i">
            <line :x1="p.a.x" :y1="p.a.y" :x2="p.b.x" :y2="p.b.y"
                  :stroke="p.isExcited ? '#ef4444' : '#3b82f6'"
                  :stroke-width="p.isExcited ? 3 : 2"/>
            <text :x="(p.a.x + p.b.x)/2 + 8" :y="(p.a.y + p.b.y)/2 - 4"
                  font-size="10" :fill="p.isExcited ? '#ef4444' : '#aaa'">T{{ p.tag }}</text>
          </g>
          <text x="6" y="14" font-size="10" fill="#666">Z ↑</text>
          <text :x="VIEW_SIZE-30" :y="VIEW_SIZE/2 - 4" font-size="10" fill="#666">→ X</text>
        </svg>
      </div>
    </div>
  </div>

  <div class="card">
    <h2>Simulation</h2>
    <div style="margin-bottom: 10px">
      <label style="display:flex; align-items:center; gap:6px; font-weight:600">
        <input type="checkbox" v-model="sweep.enabled">
        Frequenz-Sweep aktivieren (über mehrere Frequenzen rechnen)
      </label>
    </div>
    <div v-if="sweep.enabled" class="inp-grid" style="grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 10px">
      <div class="inp-g">
        <label>f_start</label>
        <div class="inp-row"><input type="text" v-model="sweep.f_start"><span>MHz</span></div>
      </div>
      <div class="inp-g">
        <label>f_stop</label>
        <div class="inp-row"><input type="text" v-model="sweep.f_stop"><span>MHz</span></div>
      </div>
      <div class="inp-g">
        <label>Schritte</label>
        <input type="number" v-model.number="sweep.steps" min="2" max="101" class="cell">
      </div>
    </div>
    <p v-if="sweep.enabled" style="font-size:11px; opacity:0.65; margin: 0 0 10px">
      Bei aktiviertem Sweep wird kein Strahlungsdiagramm berechnet (nur Z + SWR pro Frequenz).
      Für Pattern den Sweep abschalten und auf Mitten-Frequenz simulieren.
    </p>
    <div style="display:flex; gap:8px; align-items:center">
      <button class="btn primary" @click="simulate" :disabled="running">
        {{ running ? 'Simuliere…' : 'Simulieren ▶' }}
      </button>
      <span style="opacity:0.7; font-size:12px">{{ status }}</span>
    </div>
    <div v-if="errorMsg" style="color:#ef4444; margin-top:10px; font-size:13px">⚠ {{ errorMsg }}</div>
  </div>

  <div v-if="primary && !isSweep" class="card">
    <h2>Ergebnisse bei {{ primary.frequency_mhz.toFixed(3) }} MHz</h2>
    <div class="rr"><span class="lbl">Impedanz Z</span>
      <span class="val mono">{{ primary.impedance.real.toFixed(2) }} {{ primary.impedance.imag >= 0 ? '+' : '−' }} {{ Math.abs(primary.impedance.imag).toFixed(2) }}j  Ω</span>
    </div>
    <div class="rr hi"><span class="lbl">SWR (50 Ω)</span>
      <span class="val mono">{{ primary.swr_50 < 99 ? primary.swr_50.toFixed(2) : '∞' }} : 1</span>
    </div>
    <div class="rr hi"><span class="lbl">Max. Gewinn</span>
      <span class="val mono">{{ primary.gain_max_dbi.toFixed(2) }} dBi @ θ={{ primary.gain_max_theta.toFixed(0) }}° / φ={{ primary.gain_max_phi.toFixed(0) }}°</span>
    </div>
    <div class="rr"><span class="lbl">Berechnungszeit</span>
      <span class="val mono">{{ result.computed_in_ms }} ms</span>
    </div>
  </div>

  <!-- ── Sweep-Charts ── -->
  <div v-if="isSweep" class="card">
    <h2>Frequenz-Sweep ({{ sweepBlocks.length }} Punkte, {{ result.computed_in_ms }} ms)</h2>
    <div v-if="resonance" class="rr hi"><span class="lbl">Resonanz (X = 0)</span>
      <span class="val mono">{{ resonance.f.toFixed(3) }} MHz, R = {{ resonance.r.toFixed(1) }} Ω</span>
    </div>
    <div v-if="bandwidth" class="rr hi"><span class="lbl">Bandbreite SWR ≤ 2</span>
      <span class="val mono">{{ bandwidth.lo.toFixed(3) }} – {{ bandwidth.hi.toFixed(3) }} MHz ({{ (bandwidth.bw * 1000).toFixed(0) }} kHz)</span>
    </div>
    <div v-else class="rr"><span class="lbl">Bandbreite SWR ≤ 2</span>
      <span class="val">— (im gewählten Bereich nirgends ≤ 2)</span>
    </div>

    <!-- SWR Chart -->
    <h3 style="margin-top:18px">SWR über Frequenz</h3>
    <svg :viewBox="`0 0 ${SWEEP_W} ${SWEEP_H}`" :width="SWEEP_W" :height="SWEEP_H" style="background: rgba(0,0,0,0.15); border-radius: 4px; max-width: 100%; height: auto">
      <!-- Grid -->
      <g v-for="v in [1.5, 2, 3, 4, 5]" :key="`gy${v}`">
        <line :x1="swrChart.margin.l" :y1="swrChart.margin.t + swrChart.H * (1 - (v-1)/4)"
              :x2="swrChart.margin.l + swrChart.W" :y2="swrChart.margin.t + swrChart.H * (1 - (v-1)/4)"
              :stroke="v === 2 ? '#22c55e' : '#444'" :stroke-width="v === 2 ? 1 : 0.5" :stroke-dasharray="v === 2 ? '4,4' : '0'"/>
        <text :x="swrChart.margin.l - 6" :y="swrChart.margin.t + swrChart.H * (1 - (v-1)/4) + 3"
              text-anchor="end" font-size="10" fill="#888">{{ v }}</text>
      </g>
      <!-- Frequenz-Achse -->
      <text v-for="(f, i) in [swrChart.fMin, (swrChart.fMin + swrChart.fMax)/2, swrChart.fMax]" :key="`fx${i}`"
            :x="swrChart.margin.l + swrChart.W * i/2" :y="SWEEP_H - 8"
            text-anchor="middle" font-size="10" fill="#888">{{ f.toFixed(3) }}</text>
      <!-- SWR-Kurve -->
      <path :d="swrChart.path" fill="none" :stroke="swrChart.color" stroke-width="2"/>
      <text :x="swrChart.margin.l + 8" :y="swrChart.margin.t + 14" font-size="10" fill="#3b82f6" font-weight="600">SWR (50 Ω)</text>
      <text :x="swrChart.margin.l + 8" :y="swrChart.margin.t + 26" font-size="9" fill="#22c55e">— SWR=2 Schwelle</text>
    </svg>

    <!-- Z Chart -->
    <h3 style="margin-top:18px">Impedanz R + jX über Frequenz</h3>
    <svg v-if="zChart" :viewBox="`0 0 ${SWEEP_W} ${SWEEP_H}`" :width="SWEEP_W" :height="SWEEP_H" style="background: rgba(0,0,0,0.15); border-radius: 4px; max-width: 100%; height: auto">
      <!-- Grid: 50, 0, -50 etc. -->
      <g v-for="v in [zChart.yMin, zChart.yMin + (zChart.yMax-zChart.yMin)*0.25, (zChart.yMin + zChart.yMax)/2, zChart.yMin + (zChart.yMax-zChart.yMin)*0.75, zChart.yMax]" :key="`zy${v}`">
        <line :x1="zChart.margin.l" :y1="zChart.margin.t + zChart.H * (1 - (v - zChart.yMin)/(zChart.yMax - zChart.yMin))"
              :x2="zChart.margin.l + zChart.W" :y2="zChart.margin.t + zChart.H * (1 - (v - zChart.yMin)/(zChart.yMax - zChart.yMin))"
              :stroke="v === 0 ? '#888' : '#444'" :stroke-width="v === 0 ? 1 : 0.5"/>
        <text :x="zChart.margin.l - 6" :y="zChart.margin.t + zChart.H * (1 - (v - zChart.yMin)/(zChart.yMax - zChart.yMin)) + 3"
              text-anchor="end" font-size="10" fill="#888">{{ v.toFixed(0) }}</text>
      </g>
      <text v-for="(f, i) in [zChart.fMin, (zChart.fMin + zChart.fMax)/2, zChart.fMax]" :key="`zfx${i}`"
            :x="zChart.margin.l + zChart.W * i/2" :y="SWEEP_H - 8"
            text-anchor="middle" font-size="10" fill="#888">{{ f.toFixed(3) }}</text>
      <path :d="zChart.rPath" fill="none" stroke="#22c55e" stroke-width="2"/>
      <path :d="zChart.xPath" fill="none" stroke="#f97316" stroke-width="2"/>
      <text :x="zChart.margin.l + 8" :y="zChart.margin.t + 14" font-size="10" fill="#22c55e" font-weight="600">— R (Realteil)</text>
      <text :x="zChart.margin.l + 8" :y="zChart.margin.t + 26" font-size="10" fill="#f97316" font-weight="600">— X (Imag, ind/kap)</text>
    </svg>
  </div>

  <div v-if="primary && !isSweep" class="card">
    <h2>Strahlungsdiagramm</h2>
    <div style="display:flex; gap:24px; flex-wrap:wrap; justify-content:center">
      <div style="text-align:center">
        <div style="font-size:12px; opacity:0.7; margin-bottom:6px">Azimuth (Horizontal)</div>
        <svg :viewBox="`0 0 ${PLOT_SIZE} ${PLOT_SIZE}`" :width="PLOT_SIZE" :height="PLOT_SIZE">
          <circle :cx="PLOT_C" :cy="PLOT_C" :r="PLOT_R"      fill="none" stroke="#666" stroke-width="0.5"/>
          <circle :cx="PLOT_C" :cy="PLOT_C" :r="PLOT_R*0.75" fill="none" stroke="#444" stroke-width="0.5"/>
          <circle :cx="PLOT_C" :cy="PLOT_C" :r="PLOT_R*0.5"  fill="none" stroke="#444" stroke-width="0.5"/>
          <circle :cx="PLOT_C" :cy="PLOT_C" :r="PLOT_R*0.25" fill="none" stroke="#444" stroke-width="0.5"/>
          <line :x1="PLOT_C" y1="14" :x2="PLOT_C" :y2="PLOT_SIZE-14" stroke="#555" stroke-width="0.5"/>
          <line x1="14" :y1="PLOT_C" :x2="PLOT_SIZE-14" :y2="PLOT_C" stroke="#555" stroke-width="0.5"/>
          <path :d="azimuthPath" fill="rgba(59,130,246,0.25)" stroke="#3b82f6" stroke-width="2"/>
          <text :x="PLOT_C" y="11" text-anchor="middle" font-size="9" fill="#888">N (φ=0°)</text>
          <text :x="PLOT_SIZE-10" :y="PLOT_C+4" text-anchor="end" font-size="9" fill="#888">E</text>
          <text :x="PLOT_C" :y="PLOT_SIZE-4" text-anchor="middle" font-size="9" fill="#888">S</text>
          <text x="10" :y="PLOT_C+4" font-size="9" fill="#888">W</text>
        </svg>
      </div>
      <div style="text-align:center">
        <div style="font-size:12px; opacity:0.7; margin-bottom:6px">Elevation (Vertikal, φ=0°)</div>
        <svg :viewBox="`0 0 ${PLOT_SIZE} ${PLOT_SIZE}`" :width="PLOT_SIZE" :height="PLOT_SIZE">
          <circle :cx="PLOT_C" :cy="PLOT_C" :r="PLOT_R"      fill="none" stroke="#666" stroke-width="0.5"/>
          <circle :cx="PLOT_C" :cy="PLOT_C" :r="PLOT_R*0.75" fill="none" stroke="#444" stroke-width="0.5"/>
          <circle :cx="PLOT_C" :cy="PLOT_C" :r="PLOT_R*0.5"  fill="none" stroke="#444" stroke-width="0.5"/>
          <circle :cx="PLOT_C" :cy="PLOT_C" :r="PLOT_R*0.25" fill="none" stroke="#444" stroke-width="0.5"/>
          <line :x1="PLOT_C" y1="14" :x2="PLOT_C" :y2="PLOT_SIZE-14" stroke="#555" stroke-width="0.5"/>
          <line x1="14" :y1="PLOT_C" :x2="PLOT_SIZE-14" :y2="PLOT_C" stroke="#555" stroke-width="0.5"/>
          <path :d="elevationPath" fill="rgba(34,197,94,0.25)" stroke="#22c55e" stroke-width="2"/>
          <text :x="PLOT_C" y="11" text-anchor="middle" font-size="9" fill="#888">Zenith (θ=0°)</text>
          <text :x="PLOT_SIZE-10" :y="PLOT_C+4" text-anchor="end" font-size="9" fill="#888">Horizon</text>
        </svg>
      </div>
    </div>
  </div>

  <div v-if="primary && primary.pattern && primary.pattern.length > 0 && !isSweep" class="card">
    <div style="display:flex; justify-content:space-between; align-items:center; gap:10px; flex-wrap:wrap">
      <h2 style="margin:0">3D-Strahlungsdiagramm</h2>
      <label style="display:flex; align-items:center; gap:6px; font-size:12px; cursor:pointer">
        <input type="checkbox" v-model="showAntennaIn3D">
        <span>Antenne im 3D einblenden</span>
      </label>
    </div>
    <Pattern3D
      :key="`p3d-${primary.gain_max_dbi.toFixed(3)}-${primary.gain_max_theta}-${primary.gain_max_phi}`"
      :pattern="primary.pattern"
      :is-free-space="cfg.ground === 'free_space'"
      :height="480"
      :wires="cfg.wires"
      :excitation-wire-tag="cfg.excitation?.wire_tag ?? null"
      :show-antenna="showAntennaIn3D"
    />
  </div>

  <div v-if="result && result.deck" class="card" style="opacity:0.85">
    <h2>NEC2-Deck (Eingabe an Engine)</h2>
    <pre style="font-size:11px; line-height:1.4; white-space:pre-wrap; word-break:break-all">{{ result.deck }}</pre>
  </div>

  <div class="card" style="opacity:0.7; font-size:11px">
    <h2>Engine & Lizenz</h2>
    Engine: <strong>nec2c</strong> (Public Domain) als WebAssembly. WASM-Files aus dem AntennaSim-Build (EA1FUO) bezogen.
    Architektur (Worker + buildDeck + Output-Parser) eigene Implementation, inspiriert von AntennaSim.
  </div>
</template>

<style scoped>
select { padding: 6px 8px; border-radius: 6px; border: 1px solid var(--border, #333); background: var(--bg-input, #1a1a1a); color: inherit; width: 100% }
.btn.primary { background: #3b82f6; color: white; border-color: #3b82f6; padding: 8px 18px; font-weight: 600 }
.btn.primary:disabled { opacity: 0.5; cursor: not-allowed }

.wire-tbl { width: 100%; font-size: 11px; min-width: 720px }
.wire-tbl th { font-size: 10px; opacity: 0.7; padding: 6px 4px; text-align: center }
.wire-tbl td { padding: 3px 4px }
.wire-tbl tr.excited { background: rgba(239,68,68,0.05) }

.cell {
  width: 70px; padding: 6px 8px; border-radius: 4px;
  border: 1px solid var(--border, #333); background: var(--bg-input, #1a1a1a);
  color: inherit; font-family: monospace; font-size: 12px; text-align: right;
  -moz-appearance: textfield;
}
.cell.xs { width: 50px }
/* Native Spinner-Buttons komplett verstecken — Pfeiltasten/Tippen reicht */
.cell::-webkit-outer-spin-button,
.cell::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}
.btn-x {
  width: 24px; height: 24px; border-radius: 4px; border: 1px solid #ef4444;
  background: transparent; color: #ef4444; cursor: pointer; font-size: 14px; line-height: 1;
}
.btn-x:disabled { opacity: 0.3; cursor: not-allowed }

pre { background: rgba(0,0,0,0.25); padding: 10px; border-radius: 4px; overflow-x: auto }
.mono { font-family: monospace }
</style>
