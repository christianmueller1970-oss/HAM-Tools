// HAM-Tools Antennen-Simulator — Web Worker
// Engine: nec2c (Public Domain) kompiliert zu WebAssembly
// Architektur inspiriert vom Worker in AntennaSim (EA1FUO, GPL-3.0)
// Unsere Implementation ist eigenständig — nur die nec2c-Engine selbst stammt aus dem Public-Domain-Original.
//
// Phase 1 (PoC): Single-Frequency Simulation mit einem oder mehreren Drähten,
// Free-Space oder Real-Ground. Output: Impedance, SWR, Gain (max), Pattern (Az/El).

let nec2cFactory = null

async function loadEngine() {
  if (nec2cFactory) return
  const r = await fetch('/wasm/nec2c.js')
  if (!r.ok) throw new Error(`Konnte nec2c.js nicht laden (${r.status})`)
  const code = await r.text()
  // eval im Worker-Scope, setzt self.createNec2c
  ;(0, eval)(code)
  nec2cFactory = self.createNec2c
  if (!nec2cFactory) throw new Error('createNec2c nicht gefunden nach Laden von nec2c.js')
}

async function newInstance() {
  await loadEngine()
  return nec2cFactory({
    locateFile: (p) => p.endsWith('.wasm') ? '/wasm/nec2c.wasm' : p,
    print: () => {},
    printErr: () => {},
  })
}

// ─── NEC-Deck Generator ───────────────────────────────────────────────────────

function buildDeck(req) {
  const lines = []
  lines.push(`CM ${req.comment || 'HAM-Tools Antennen-Simulator'}`)
  lines.push('CE')
  for (const w of req.wires) {
    lines.push(`GW ${w.tag} ${w.segments} ${w.x1.toFixed(6)} ${w.y1.toFixed(6)} ${w.z1.toFixed(6)} ${w.x2.toFixed(6)} ${w.y2.toFixed(6)} ${w.z2.toFixed(6)} ${w.radius.toFixed(6)}`)
  }
  const isFree = req.ground === 'free_space'
  lines.push(isFree ? 'GE -1' : 'GE 0')
  if (isFree) {
    lines.push('GN -1')
  } else if (req.ground === 'perfect') {
    lines.push('GN 1 0 0 0 0 0')
  } else {
    lines.push(`GN 2 0 0 0 13.0000 0.005000`)
  }
  for (const e of req.excitations) {
    lines.push(`EX 0 ${e.wire_tag} ${e.segment} 0 ${(e.voltage_real ?? 1).toFixed(4)} ${(e.voltage_imag ?? 0).toFixed(4)}`)
  }
  // Multi-Frequenz Sweep oder Single
  const sweep = req.sweep
  if (sweep && sweep.steps > 1) {
    const df = (sweep.f_stop - sweep.f_start) / (sweep.steps - 1)
    lines.push(`FR 0 ${sweep.steps} 0 0 ${sweep.f_start.toFixed(6)} ${df.toFixed(6)}`)
  } else {
    lines.push(`FR 0 1 0 0 ${req.frequency_mhz.toFixed(6)} 0`)
  }
  // Pattern: nur wenn nicht Sweep (sonst riesig)
  if (!sweep || sweep.steps <= 1) {
    const step = 5
    const thetaStart = isFree ? -180 : -90
    const nTheta = Math.floor((isFree ? 360 : 180) / step) + 1
    const nPhi = Math.floor(360 / step)
    lines.push(`RP 0 ${nTheta} ${nPhi} 1000 ${thetaStart.toFixed(1)} 0.0 ${step.toFixed(1)} ${step.toFixed(1)}`)
  }
  lines.push('EN')
  return lines.join('\n') + '\n'
}

// ─── Output-Parser ───────────────────────────────────────────────────────────

function calcSWR(Zr, Zi) {
  const num_re = Zr - 50, num_im = Zi
  const den_re = Zr + 50, den_im = Zi
  const den_mag2 = den_re * den_re + den_im * den_im
  if (den_mag2 <= 0) return 999
  const g_re = (num_re * den_re + num_im * den_im) / den_mag2
  const g_im = (num_im * den_re - num_re * den_im) / den_mag2
  const g_mag = Math.sqrt(g_re * g_re + g_im * g_im)
  return g_mag >= 1 ? 999 : (1 + g_mag) / (1 - g_mag)
}

// Parse alle Frequenz-Blöcke; gibt Array zurück mit pro Block: f, Z, SWR, Pattern, MaxGain
function parseOutput(text) {
  const lines = text.split('\n')
  const blocks = []
  let cur = null

  function pushCur() {
    if (cur) {
      cur.swr_50 = calcSWR(cur.impedance.real, cur.impedance.imag)
      blocks.push(cur)
    }
  }

  let i = 0
  while (i < lines.length) {
    const line = lines[i]
    const fmatch = line.match(/FREQUENCY\s*:\s*([0-9.E+-]+)\s*MHZ/i)
    if (fmatch) {
      pushCur()
      cur = {
        frequency_mhz: parseFloat(fmatch[1]),
        impedance: { real: 0, imag: 0 },
        swr_50: 0,
        gain_max_dbi: -999, gain_max_theta: 0, gain_max_phi: 0,
        pattern: [],
      }
      i++; continue
    }
    if (cur && /ANTENNA INPUT PARAMETERS/.test(line)) {
      i += 3
      const dl = lines[i] || ''
      const m = dl.trim().split(/\s+/)
      if (m.length >= 11) {
        cur.impedance.real = parseFloat(m[6])
        cur.impedance.imag = parseFloat(m[7])
      }
      i++; continue
    }
    if (cur && /RADIATION PATTERNS/.test(line)) {
      i += 4
      while (i < lines.length) {
        const rl = lines[i]
        if (/^\s*$/.test(rl)) { i++; if (cur.pattern.length > 0) break; continue }
        const parts = rl.trim().split(/\s+/)
        if (parts.length >= 7) {
          const theta = parseFloat(parts[0])
          const phi   = parseFloat(parts[1])
          const gain  = parseFloat(parts[4])
          if (!isNaN(theta) && !isNaN(phi) && !isNaN(gain)) {
            cur.pattern.push({ theta, phi, gain })
            if (gain > cur.gain_max_dbi) {
              cur.gain_max_dbi = gain
              cur.gain_max_theta = theta
              cur.gain_max_phi = phi
            }
          }
        }
        i++
      }
      continue
    }
    i++
  }
  pushCur()
  return blocks
}

// ─── Simulation ──────────────────────────────────────────────────────────────

async function simulate(req) {
  const t0 = performance.now()
  const deck = buildDeck(req)
  const eng = await newInstance()
  eng.FS.writeFile('/input.nec', deck)
  try {
    eng.callMain(['-i', '/input.nec', '-o', '/output.out'])
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e)
    if (!msg.includes('exit(0)') && !msg.includes('status = 0')) {
      throw new Error(`nec2c-Fehler: ${msg}`)
    }
  }
  let output
  try {
    output = eng.FS.readFile('/output.out', { encoding: 'utf8' })
  } catch {
    throw new Error('nec2c hat keinen Output erzeugt — Antennen-Geometrie ungültig?')
  }
  const blocks = parseOutput(output)
  if (blocks.length === 0) {
    throw new Error('nec2c-Output enthält keine Frequenz-Daten')
  }
  return {
    blocks,                                // alle Frequenz-Blöcke
    primary: blocks[0],                    // erster Block (für Single-Freq-Anzeige)
    is_sweep: blocks.length > 1,
    computed_in_ms: Math.round(performance.now() - t0),
    deck,
    raw_output: output.length > 8000 ? output.slice(0, 8000) + '\n...(gekürzt)' : output,
  }
}

// ─── Worker-Message-Loop ─────────────────────────────────────────────────────

self.onmessage = async (e) => {
  const msg = e.data
  if (msg.type === 'simulate') {
    try {
      const result = await simulate(msg.request)
      self.postMessage({ type: 'success', id: msg.id, result })
    } catch (err) {
      self.postMessage({
        type: 'error',
        id: msg.id,
        message: err instanceof Error ? err.message : String(err),
      })
    }
  }
}
