<script setup>
import { ref, onMounted, onBeforeUnmount, watch, computed } from 'vue'
import * as THREE from 'three'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js'

const props = defineProps({
  /**
   * Pattern-Punkte: Array von { theta, phi, gain }
   * - theta: NEC2-Elevation in Grad (-180..180 für Freiraum, -90..90 für Bodenfall)
   * - phi: Azimuth in Grad (0..360)
   * - gain: Gain in dBi
   */
  pattern: { type: Array, required: true },
  isFreeSpace: { type: Boolean, default: false },
  height: { type: Number, default: 480 },
})

const container = ref(null)

let renderer, scene, camera, controls, mesh, axesGroup, groundPlane
let raf = null
let resizeObserver = null

// ─── Geometrie aus Pattern bauen ─────────────────────────────────────────────
//
// NEC2 Konvention:
//   theta = elevation (90° = horizon, 0° = zenith down, etc.)
//   phi   = azimuth, 0° = +X (Front), 90° = +Y, 180° = -X, 270° = -Y
//
// Unsere Welt-Achsen (Three.js):
//   X-Achse = Front (rot)
//   Y-Achse = Hoch/Zenit (blau)
//   Z-Achse = Seite (grün)
//
// Konversion theta/phi → Karthesisch (Unit-Vektor):
//   thetaRad = theta in rad (Elevation von Zenith, 0=Zenith, 90=Horizon)
//   phiRad   = phi in rad
//   x = sin(theta) * cos(phi)
//   z = sin(theta) * sin(phi)
//   y = cos(theta)
//
// Radius pro Punkt = Skalierung der Gain-Werte.
// Da Gain in dBi (negativ möglich), wir mappen [minGain..maxGain] → [0.02..1.0].
//
// Da NEC2-Pattern-Punkte auf einem (theta × phi)-Grid liegen, können wir sie als
// strukturiertes Mesh mit Triangle-Strip-ähnlichen Indices verbinden.

function buildMeshGeometry(pattern, isFreeSpace) {
  if (!pattern || pattern.length === 0) return null

  // Pattern-Punkte nach (theta, phi) gruppieren — wir nehmen alle einzigartigen Werte
  const thetaSet = new Set()
  const phiSet   = new Set()
  for (const p of pattern) {
    thetaSet.add(Math.round(p.theta * 100) / 100)
    phiSet.add(Math.round(p.phi * 100) / 100)
  }
  const thetas = Array.from(thetaSet).sort((a, b) => a - b)
  const phis   = Array.from(phiSet).sort((a, b) => a - b)

  // Pattern-Lookup
  const lookup = new Map()
  for (const p of pattern) {
    const key = `${Math.round(p.theta * 100) / 100}|${Math.round(p.phi * 100) / 100}`
    lookup.set(key, p.gain)
  }

  // Gain-Range bestimmen
  let gMin =  Infinity, gMax = -Infinity
  for (const p of pattern) {
    if (p.gain < gMin) gMin = p.gain
    if (p.gain > gMax) gMax = p.gain
  }
  // Floor bei -30 dB unter Max — niedrigere Werte stauchen wir gleich (sonst dominieren Nulls)
  const floor = Math.max(gMin, gMax - 30)
  const span  = Math.max(1, gMax - floor)

  // Helper: NEC2-Konvention → Three.js-Koordinaten
  function ptFor(theta, phi, r) {
    const thr = THREE.MathUtils.degToRad(theta)
    const phr = THREE.MathUtils.degToRad(phi)
    const x = r * Math.sin(thr) * Math.cos(phr)
    const z = r * Math.sin(thr) * Math.sin(phr)
    const y = r * Math.cos(thr)
    return [x, y, z]
  }

  // Bei Bodenfall (theta 0..90 oder ähnlich) gibt NEC2 nur die obere Halbsphäre.
  // Wir extrudieren die Punkte zu einem Vertex-Grid.

  const positions = []
  const colors    = []
  const indices   = []

  const colA = new THREE.Color(0x0a2a55) // dunkelblau (Min)
  const colB = new THREE.Color(0x16a085) // teal
  const colC = new THREE.Color(0xf1c40f) // gelb
  const colD = new THREE.Color(0xe74c3c) // rot (Max)
  const tmpColor = new THREE.Color()

  function colorForT(t) {
    // t ∈ [0,1] — Viridis-ähnliche 4-Stop-Map
    if (t < 0.333) {
      tmpColor.copy(colA).lerp(colB, t / 0.333)
    } else if (t < 0.667) {
      tmpColor.copy(colB).lerp(colC, (t - 0.333) / 0.334)
    } else {
      tmpColor.copy(colC).lerp(colD, (t - 0.667) / 0.333)
    }
    return tmpColor
  }

  // Vertex-Grid: phi → row, theta → col
  // phi ist zyklisch (0..360 = 0..0), wir duplizieren KEINEN End-Vertex, sondern wrap-around in den Indizes
  const nTheta = thetas.length
  const nPhi   = phis.length

  for (let j = 0; j < nPhi; j++) {
    const phi = phis[j]
    for (let i = 0; i < nTheta; i++) {
      const theta = thetas[i]
      const key = `${Math.round(theta * 100) / 100}|${Math.round(phi * 100) / 100}`
      const g = lookup.has(key) ? lookup.get(key) : floor
      const t = Math.max(0, Math.min(1, (g - floor) / span))
      const r = 0.05 + 0.95 * t   // Min-Radius 5% damit Nullen nicht im Zentrum kollabieren
      const [x, y, z] = ptFor(theta, phi, r)
      positions.push(x, y, z)
      const col = colorForT(t)
      colors.push(col.r, col.g, col.b)
    }
  }

  // Indices: zwei Dreiecke pro Quad (phi[j], theta[i]) → (phi[j+1], theta[i+1])
  for (let j = 0; j < nPhi; j++) {
    const jNext = (j + 1) % nPhi   // wrap-around in phi
    for (let i = 0; i < nTheta - 1; i++) {
      const a = j     * nTheta + i
      const b = jNext * nTheta + i
      const c = jNext * nTheta + (i + 1)
      const d = j     * nTheta + (i + 1)
      // Dreieck 1: a-b-c
      indices.push(a, b, c)
      // Dreieck 2: a-c-d
      indices.push(a, c, d)
    }
  }

  const geom = new THREE.BufferGeometry()
  geom.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3))
  geom.setAttribute('color',    new THREE.Float32BufferAttribute(colors, 3))
  geom.setIndex(indices)
  geom.computeVertexNormals()

  return { geom, gMin, gMax, floor }
}

// ─── Three.js-Setup ──────────────────────────────────────────────────────────

function setupScene() {
  if (!container.value) return

  const w = container.value.clientWidth
  const h = props.height

  scene = new THREE.Scene()
  scene.background = new THREE.Color(0x0d1117)

  camera = new THREE.PerspectiveCamera(45, w / h, 0.01, 100)
  camera.position.set(2.2, 1.5, 2.2)
  camera.lookAt(0, 0, 0)

  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
  renderer.setPixelRatio(window.devicePixelRatio)
  renderer.setSize(w, h)
  container.value.appendChild(renderer.domElement)

  controls = new OrbitControls(camera, renderer.domElement)
  controls.enableDamping = true
  controls.dampingFactor = 0.08
  controls.minDistance = 0.8
  controls.maxDistance = 8

  const ambient = new THREE.AmbientLight(0xffffff, 0.55)
  scene.add(ambient)
  const key = new THREE.DirectionalLight(0xffffff, 0.85)
  key.position.set(3, 4, 2)
  scene.add(key)
  const fill = new THREE.DirectionalLight(0xb0c4de, 0.35)
  fill.position.set(-2, 1, -2)
  scene.add(fill)

  axesGroup = new THREE.Group()
  scene.add(axesGroup)
  addAxes()

  groundPlane = new THREE.GridHelper(3.0, 12, 0x2a3144, 0x1a1f2c)
  scene.add(groundPlane)

  rebuildMesh()
  animate()
}

function addAxes() {
  while (axesGroup.children.length) axesGroup.remove(axesGroup.children[0])
  const len = 1.35

  // X-Achse = Front (rot)
  axesGroup.add(arrow(new THREE.Vector3(1, 0, 0), len, 0xff5a5a, 'Front'))
  // Z-Achse = Seite (grün)
  axesGroup.add(arrow(new THREE.Vector3(0, 0, 1), len, 0x66ff80, 'Seite'))
  // Y-Achse = Zenit (blau)
  axesGroup.add(arrow(new THREE.Vector3(0, 1, 0), len, 0x6ab7ff, 'Zenit'))
}

function arrow(dir, len, color, _label) {
  const arr = new THREE.ArrowHelper(dir.normalize(), new THREE.Vector3(0, 0, 0), len, color, 0.10, 0.06)
  return arr
}

function rebuildMesh() {
  if (mesh) {
    scene.remove(mesh)
    mesh.geometry.dispose()
    mesh.material.dispose()
    mesh = null
  }
  const r = buildMeshGeometry(props.pattern, props.isFreeSpace)
  if (!r) return
  const mat = new THREE.MeshPhongMaterial({
    vertexColors: true,
    side: THREE.DoubleSide,
    shininess: 25,
    flatShading: false,
  })
  mesh = new THREE.Mesh(r.geom, mat)
  scene.add(mesh)
}

function animate() {
  if (!renderer) return
  raf = requestAnimationFrame(animate)
  controls.update()
  renderer.render(scene, camera)
}

function resize() {
  if (!renderer || !container.value) return
  const w = container.value.clientWidth
  const h = props.height
  renderer.setSize(w, h)
  camera.aspect = w / h
  camera.updateProjectionMatrix()
}

// ─── Lifecycle ───────────────────────────────────────────────────────────────

onMounted(() => {
  setupScene()
  if (window.ResizeObserver) {
    resizeObserver = new ResizeObserver(resize)
    resizeObserver.observe(container.value)
  } else {
    window.addEventListener('resize', resize)
  }
})

onBeforeUnmount(() => {
  if (raf) cancelAnimationFrame(raf)
  if (resizeObserver) resizeObserver.disconnect()
  else window.removeEventListener('resize', resize)
  if (mesh) { mesh.geometry.dispose(); mesh.material.dispose() }
  if (renderer) {
    renderer.dispose()
    if (renderer.domElement.parentNode) renderer.domElement.parentNode.removeChild(renderer.domElement)
  }
  renderer = null
})

watch(() => props.pattern, () => {
  if (scene) rebuildMesh()
}, { deep: false })

const meshStats = computed(() => {
  if (!props.pattern || props.pattern.length === 0) return null
  let gMin =  Infinity, gMax = -Infinity
  for (const p of props.pattern) {
    if (p.gain < gMin) gMin = p.gain
    if (p.gain > gMax) gMax = p.gain
  }
  return { gMin, gMax, count: props.pattern.length }
})
</script>

<template>
  <div>
    <div ref="container" :style="{ width: '100%', height: height + 'px', borderRadius: '6px', overflow: 'hidden', background: '#0d1117' }"></div>
    <div v-if="meshStats" class="pattern3d-legend">
      <div class="legend-bar"></div>
      <div class="legend-labels">
        <span>{{ meshStats.gMin.toFixed(1) }} dBi</span>
        <span>Gain</span>
        <span>{{ meshStats.gMax.toFixed(1) }} dBi</span>
      </div>
      <div class="legend-axes">
        <span><span class="dot" style="background:#ff5a5a"></span> X = Front</span>
        <span><span class="dot" style="background:#66ff80"></span> Z = Seite</span>
        <span><span class="dot" style="background:#6ab7ff"></span> Y = Zenit</span>
        <span class="hint">Maus: ziehen = drehen · Scroll = zoomen · Rechtsklick = verschieben</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.pattern3d-legend {
  margin-top: 8px;
  font-size: 11px;
  color: var(--ts);
}
.legend-bar {
  height: 10px;
  border-radius: 4px;
  background: linear-gradient(90deg, #0a2a55 0%, #16a085 33%, #f1c40f 67%, #e74c3c 100%);
}
.legend-labels {
  display: flex;
  justify-content: space-between;
  margin-top: 3px;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}
.legend-labels span:nth-child(2) {
  opacity: 0.6;
}
.legend-axes {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  margin-top: 6px;
  opacity: 0.8;
}
.legend-axes .dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  margin-right: 4px;
  vertical-align: 1px;
}
.legend-axes .hint {
  opacity: 0.6;
  font-style: italic;
}
</style>
