document.addEventListener('alpine:init', () => {
  Alpine.data('app', () => ({

    // ── Navigation & Theme ──────────────────────────────────────────
    page: 'dipol',
    theme: localStorage.getItem('ht_theme') || 'classic',

    init() {
      document.body.className = this.theme;
    },
    nav(p) { this.page = p; },
    setTheme(t) {
      this.theme = t;
      document.body.className = t;
      localStorage.setItem('ht_theme', t);
    },

    // ── Helpers ─────────────────────────────────────────────────────
    pf(s) { return parseFloat(String(s).replace(',', '.')) || 0; },
    fmt(n, d = 3) { return (!isFinite(n) || isNaN(n)) ? '—' : n.toFixed(d); },
    bands: [
      ['160m',1.85],['80m',3.65],['60m',5.36],['40m',7.1],
      ['30m',10.125],['20m',14.175],['17m',18.118],['15m',21.225],
      ['12m',24.94],['10m',28.5],['6m',50.15],['2m',145.0]
    ],
    isBandActive(freq, bandFreq) {
      return Math.abs(this.pf(freq) - bandFreq) < 0.5;
    },

    // ═══════════════════════════════════════════════════════════════
    // 1. DIPOL
    // ═══════════════════════════════════════════════════════════════
    dip: { freq: '14.175', vf: '0.95', typ: 'klassisch' },
    get dipR() {
      const f = this.pf(this.dip.freq), vf = this.pf(this.dip.vf);
      if (!f || !vf || vf > 1) return null;
      const g = 150 / f * vf;
      return {
        gesamt: g, arm: g / 2, lambda: 300 / f,
        imp: this.dip.typ === 'klassisch' ? '≈ 50–75 Ω' : '≈ 240–300 Ω (4:1 Balun → 50 Ω)'
      };
    },

    // ═══════════════════════════════════════════════════════════════
    // 2. GROUNDPLANE
    // ═══════════════════════════════════════════════════════════════
    gp: { freq: '14.175', vf: '0.95', tilt: '0' },
    get gpR() {
      const f = this.pf(this.gp.freq), vf = this.pf(this.gp.vf);
      const tilt = this.pf(this.gp.tilt);
      if (!f || !vf) return null;
      const str = 75 / f * vf;
      const rad = str * 1.02;
      const imp = Math.round(36 + (tilt / 45) * 16);
      return { strahler: str, radial: rad, imp, lambda: 300 / f };
    },

    // ═══════════════════════════════════════════════════════════════
    // 3. J-POLE / SLIM JIM
    // ═══════════════════════════════════════════════════════════════
    jp: { freq: '145.0', vf: '0.95', typ: 'jpole' },
    get jpR() {
      const f = this.pf(this.jp.freq), vf = this.pf(this.jp.vf);
      if (!f || !vf) return null;
      const lh = 150 / f * vf, lq = 75 / f * vf;
      if (this.jp.typ === 'jpole') {
        return { gesamt: lh + lq, strahler: lh, stub: lq, feed: lq * 0.05, lambda: 300 / f };
      } else {
        return { gesamt: lh * 1.5 * vf, strahler: lh * vf, stub: lq * vf, feed: lq * vf * 0.04, lambda: 300 / f };
      }
    },

    // ═══════════════════════════════════════════════════════════════
    // 4. SPERRTOPF
    // ═══════════════════════════════════════════════════════════════
    spt: { freq: '145.0', koax: 'rg213' },
    sptVF: { rg58: 0.66, rg213: 0.66, rg8: 0.66, h155: 0.80, aircell7: 0.83, ecoflex10: 0.83 },
    get sptR() {
      const f = this.pf(this.spt.freq);
      if (!f) return null;
      const vfK = this.sptVF[this.spt.koax] || 0.66;
      return { innen: 75 / f * 0.95, huelle: 75 / f * vfK, lambda: 300 / f };
    },

    // ═══════════════════════════════════════════════════════════════
    // 5. WINDOM (OCFD)
    // ═══════════════════════════════════════════════════════════════
    wd: { freq: '7.1', vf: '0.96' },
    get wdR() {
      const f = this.pf(this.wd.freq), vf = this.pf(this.wd.vf);
      if (!f || !vf) return null;
      const g = 150 / f * vf;
      const harmonics = [];
      this.bands.forEach(([name, bf]) => {
        const n = g / (150 / bf);
        if (Math.abs(n - Math.round(n)) < 0.15 && n >= 0.9) {
          harmonics.push(`${name} (${Math.round(n)}× λ/2)`);
        }
      });
      return { gesamt: g, lang: g * 0.64, kurz: g * 0.36, lambda: 300 / f, harmonics };
    },

    // ═══════════════════════════════════════════════════════════════
    // 6. EFHW-ANTENNE
    // ═══════════════════════════════════════════════════════════════
    efhw: { freq: '7.1', vf: '0.96' },
    get efhwR() {
      const f = this.pf(this.efhw.freq), vf = this.pf(this.efhw.vf);
      if (!f || !vf) return null;
      const draht = 150 / f * vf;
      const gegengew = (300 / f) * 0.05 * vf;
      const bRanges = [
        ['160m',1.8,2.0],['80m',3.5,3.8],['60m',5.35,5.37],['40m',7.0,7.2],
        ['30m',10.1,10.15],['20m',14.0,14.35],['17m',18.068,18.168],
        ['15m',21.0,21.45],['12m',24.89,24.99],['10m',28.0,29.7],
        ['6m',50.0,52.0],['2m',144.0,146.0]
      ];
      const harmonics = [];
      for (let n = 1; n <= 8; n++) {
        const h = f * n;
        bRanges.forEach(([band, lo, hi]) => {
          if (h >= lo && h <= hi) {
            const label = n === 1 ? band : `${band} (${n}. Harm.)`;
            if (!harmonics.includes(label)) harmonics.push(label);
          }
        });
      }
      return { draht, gegengew, lambda: 300 / f, harmonics };
    },

    // ═══════════════════════════════════════════════════════════════
    // 7. EFHW-VERKÜRZUNG
    // ═══════════════════════════════════════════════════════════════
    efhwV: { freq: '7.1', hoehe: '6.0', D: '50', dw: '1.0', spacing: '0.5' },
    get efhwVR() {
      const f = this.pf(this.efhwV.freq), h = this.pf(this.efhwV.hoehe);
      const D = this.pf(this.efhwV.D), dw = this.pf(this.efhwV.dw);
      const s = this.pf(this.efhwV.spacing);
      if (!f || !h || !D || !dw) return null;
      const ziel = 142.5 / f;
      if (h >= ziel) return { ok: true, ziel, aktuell: h };
      const diff = ziel - h;
      const r_inch = (D / 2 / 1000) * 39.3701;
      const pitch_m = (dw + s) / 1000;
      let l_m = dw / 1000;
      let n = 1;
      for (let i = 0; i < 60; i++) {
        const l_inch = l_m * 39.3701;
        const L_uH = (r_inch * r_inch * n * n) / (9 * r_inch + 10 * l_inch);
        const L_target = diff * 2.5;
        n = Math.sqrt(L_target * (9 * r_inch + 10 * l_inch)) / r_inch;
        l_m = n * pitch_m;
      }
      n = Math.ceil(n);
      const l_mm = n * pitch_m * 1000;
      const l_inch = l_mm / 25.4;
      const L_uH = (r_inch * r_inch * n * n) / (9 * r_inch + 10 * l_inch);
      return { ok: false, ziel, aktuell: h, diff, L_uH, n, laenge_mm: l_mm };
    },

    // ═══════════════════════════════════════════════════════════════
    // 8. LOOP-ANTENNE
    // ═══════════════════════════════════════════════════════════════
    loop: { freq: '7.1', vf: '0.98', typ: 'delta', koax: 'rg213' },
    loopCoaxVF: { rg213: 0.66, rg58: 0.66, h155: 0.80, aircell7: 0.83 },
    get loopR() {
      const f = this.pf(this.loop.freq), vf = this.pf(this.loop.vf);
      if (!f || !vf) return null;
      const umfang = (306.3 / f) * (vf / 0.98);
      const matchVF = this.loopCoaxVF[this.loop.koax] || 0.66;
      const matchLen = 75 / f * matchVF;
      if (this.loop.typ === 'delta') {
        return { umfang, seite: umfang / 3, matchLen, lambda: 300 / f };
      } else {
        return { umfang, seite: umfang / 4, matchLen, lambda: 300 / f };
      }
    },

    // ═══════════════════════════════════════════════════════════════
    // 9. MOXON RECTANGLE
    // ═══════════════════════════════════════════════════════════════
    mox: { freq: '14.175', vf: '0.95' },
    get moxR() {
      const f = this.pf(this.mox.freq), vf = this.pf(this.mox.vf);
      if (!f || !vf) return null;
      const lambda = 300 / f;
      // G3TXQ coefficients
      const A = lambda * 0.4750 * vf;
      const B = lambda * 0.0500 * vf;
      const C = lambda * 0.0156 * vf;
      const D = lambda * 0.0624 * vf;
      const E = lambda * 0.4750 * vf;
      return { A, B, C, D, E, tiefe: B + C + D, lambda };
    },

    // ═══════════════════════════════════════════════════════════════
    // 10. HB9CV BEAM
    // ═══════════════════════════════════════════════════════════════
    hb9: { freq: '14.175', d_mm: '4' },
    get hb9R() {
      const f = this.pf(this.hb9.freq), d = this.pf(this.hb9.d_mm);
      if (!f || !d) return null;
      const lambda = 300 / f;
      const lambda_m = lambda;
      const vf = 0.985 - 0.04 * Math.pow((d / 1000 / lambda_m) * 100, 0.4);
      const refl = lambda * 0.500 * vf;
      const dir  = lambda * 0.460 * vf;
      const boom = lambda * 0.200;
      const gamma = refl * 0.08;
      return { refl, dir, boom, gamma, vf, lambda };
    },

    // ═══════════════════════════════════════════════════════════════
    // 11. HEXBEAM
    // ═══════════════════════════════════════════════════════════════
    hex: {
      bands: { '20m': true, '17m': false, '15m': true, '12m': false, '10m': true, '6m': false },
    },
    hexFreqs: { '20m': 14.175, '17m': 18.118, '15m': 21.225, '12m': 24.94, '10m': 28.5, '6m': 50.15 },
    get hexR() {
      const rows = [];
      Object.entries(this.hex.bands).forEach(([band, on]) => {
        if (!on) return;
        const f = this.hexFreqs[band];
        const lambda = 300 / f;
        rows.push({
          band,
          treiber: lambda * 0.440,
          reflektor: lambda * 0.495,
          arm: lambda * 0.260,
          spreizer: lambda * 0.260 * 2,
        });
      });
      return rows;
    },

    // ═══════════════════════════════════════════════════════════════
    // 12. YAGI-RECHNER
    // ═══════════════════════════════════════════════════════════════
    yagi: { freq: '14.175', design: '3el', vf: '0.95', d_mm: '10' },
    yagiDesigns: {
      '3el': { label: '3-Element (Klassisch)', elems: [
        { typ: 'Reflektor', lFak: 0.500, sFak: 0.000 },
        { typ: 'Strahler',  lFak: 0.470, sFak: 0.125 },
        { typ: 'Direktor',  lFak: 0.444, sFak: 0.250 },
      ]},
      '4el': { label: '4-Element', elems: [
        { typ: 'Reflektor', lFak: 0.500, sFak: 0.000 },
        { typ: 'Strahler',  lFak: 0.470, sFak: 0.130 },
        { typ: 'Direktor 1',lFak: 0.444, sFak: 0.250 },
        { typ: 'Direktor 2',lFak: 0.440, sFak: 0.440 },
      ]},
      '5el': { label: '5-Element (OWA)', elems: [
        { typ: 'Reflektor', lFak: 0.510, sFak: 0.000 },
        { typ: 'Strahler',  lFak: 0.470, sFak: 0.086 },
        { typ: 'Direktor 1',lFak: 0.456, sFak: 0.196 },
        { typ: 'Direktor 2',lFak: 0.440, sFak: 0.387 },
        { typ: 'Direktor 3',lFak: 0.435, sFak: 0.590 },
      ]},
    },
    get yagiR() {
      const f = this.pf(this.yagi.freq), vf = this.pf(this.yagi.vf);
      if (!f || !vf) return null;
      const lambda = 299.792458 / f;
      const design = this.yagiDesigns[this.yagi.design];
      const elems = design.elems.map(e => ({
        typ: e.typ,
        laenge: lambda * e.lFak * vf,
        pos: lambda * e.sFak,
      }));
      const boom = elems[elems.length - 1].pos;
      return { lambda, elems, boom };
    },

    // ═══════════════════════════════════════════════════════════════
    // 13. SPIDERBEAM EINZELBAND
    // ═══════════════════════════════════════════════════════════════
    sbe: { freq: '14.175' },
    get sbeR() {
      const f = this.pf(this.sbe.freq);
      if (!f) return null;
      const lambda = 300 / f;
      const str = lambda * 0.466;
      const elems = [
        { typ: 'Strahler',   len: str,          arm: Math.round(str / 2 * 1000), pos:  0.00 },
        { typ: 'Reflektor',  len: lambda * 0.503, arm: Math.round(lambda * 0.503 / 2 * 1000), pos: -5.00 },
        { typ: 'Direktor 1', len: lambda * 0.454, arm: Math.round(lambda * 0.454 / 2 * 1000), pos:  5.00 },
      ];
      const warn = (str / 2) > 5.0;
      return { lambda, elems, warn, spreizer: 5.0 };
    },

    // ═══════════════════════════════════════════════════════════════
    // 14. SPIDERBEAM MULTI-BAND (hardcoded DF4SA data)
    // ═══════════════════════════════════════════════════════════════
    sbm: { version: 'v5band', bands: { '20m':true,'17m':true,'15m':true,'12m':true,'10m':true } },
    sbmVersions: {
      v3band:  { label: '3-Band (20/15/10m)', bands: ['20m','15m','10m'],
        data: {
          '20m': [{ typ:'Strahler',   Lel:9.80, arm:547, S:-0.40 },{ typ:'Reflektor', Lel:10.24,arm:516,S:-5.00 },{ typ:'Direktor 1',Lel:9.51, arm:480,S:+5.00 }],
          '15m': [{ typ:'Strahler',   Lel:6.66, arm:337, S: 0.00 },{ typ:'Reflektor', Lel:6.78, arm:343,S:-2.60 },{ typ:'Direktor 1',Lel:6.29, arm:319,S:+3.30 }],
          '10m': [{ typ:'Strahler',   Lel:4.80, arm:297, S:+0.50 },{ typ:'Reflektor', Lel:5.11, arm:257,S:-1.30 },{ typ:'Direktor 1',Lel:4.70, arm:237,S:+2.00 },{ typ:'Direktor 2',Lel:4.70,arm:237,S:+4.20 }],
        }},
      v5band:  { label: '5-Band (20/17/15/12/10m)', bands: ['20m','17m','15m','12m','10m'],
        data: {
          '20m': [{ typ:'Strahler',   Lel:9.80, arm:547, S:-0.40 },{ typ:'Reflektor', Lel:10.24,arm:516,S:-5.00 },{ typ:'Direktor 1',Lel:9.51, arm:480,S:+5.00 }],
          '17m': [{ typ:'Strahler',   Lel:7.20, arm:450, S:-0.80 },{ typ:'Reflektor', Lel:7.94, arm:399,S:-3.30 }],
          '15m': [{ typ:'Strahler',   Lel:6.66, arm:337, S: 0.00 },{ typ:'Reflektor', Lel:6.79, arm:342,S:-2.60 },{ typ:'Direktor 1',Lel:6.35, arm:320,S:+3.30 }],
          '12m': [{ typ:'Strahler',   Lel:5.46, arm:324, S:+0.40 },{ typ:'Reflektor', Lel:5.75, arm:290,S:-1.50 }],
          '10m': [{ typ:'Strahler',   Lel:4.74, arm:320, S:+0.80 },{ typ:'Reflektor', Lel:5.15, arm:259,S:-1.10 },{ typ:'Direktor 1',Lel:4.74, arm:239,S:+2.00 },{ typ:'Direktor 2',Lel:4.74,arm:239,S:+4.20 }],
        }},
      vsunspot:{ label: 'Low-Sunspot (20/17/15m)', bands: ['20m','17m','15m'],
        data: {
          '20m': [{ typ:'Strahler',   Lel:10.00,arm:500, S: 0.00 },{ typ:'Reflektor', Lel:10.25,arm:517,S:-5.00 },{ typ:'Direktor 1',Lel:9.55, arm:481,S:+5.00 }],
          '17m': [{ typ:'Strahler',   Lel:7.62, arm:438, S:-0.40 },{ typ:'Reflektor', Lel:7.92, arm:399,S:-3.30 },{ typ:'Direktor 1',Lel:7.55, arm:381,S:+4.20 }],
          '15m': [{ typ:'Strahler',   Lel:6.56, arm:385, S:+0.40 },{ typ:'Reflektor', Lel:6.86, arm:346,S:-2.60 },{ typ:'Direktor 1',Lel:6.47, arm:326,S:+3.30 }],
        }},
      vwarc:   { label: 'WARC (30/17/12m)', bands: ['30m','17m','12m'],
        data: {
          '30m': [{ typ:'Strahler',   Lel:13.48,arm:731, S:-0.40 },{ typ:'Reflektor', Lel:14.13,arm:711,S:-6.00 },{ typ:'Direktor 1',Lel:13.66,arm:687,S:+6.00 }],
          '17m': [{ typ:'Strahler',   Lel:7.62, arm:386, S: 0.00 },{ typ:'Reflektor', Lel:7.89, arm:397,S:-3.00 },{ typ:'Direktor 1',Lel:7.58, arm:381,S:+3.90 }],
          '12m': [{ typ:'Strahler',   Lel:5.46, arm:330, S:+0.40 },{ typ:'Reflektor', Lel:5.83, arm:294,S:-1.90 },{ typ:'Direktor 1',Lel:5.47, arm:276,S:+2.30 },{ typ:'Direktor 2',Lel:5.40,arm:273,S:+4.80 }],
        }},
    },
    get sbmRows() {
      const ver = this.sbmVersions[this.sbm.version];
      const rows = [];
      ver.bands.forEach(band => {
        if (!this.sbm.bands[band]) return;
        (ver.data[band] || []).forEach(e => rows.push({ band, ...e }));
      });
      return rows;
    },
    sbmBands(ver) { return this.sbmVersions[ver].bands; },
    sbmSelectVersion(ver) {
      this.sbm.version = ver;
      const allBands = {};
      this.sbmVersions[ver].bands.forEach(b => allBands[b] = true);
      this.sbm.bands = allBands;
    },
    sbmPosStr(s) { return s === 0 ? '0.00' : (s > 0 ? `+${s.toFixed(2)}` : s.toFixed(2)); },

    // ═══════════════════════════════════════════════════════════════
    // 15. MAGNETIC LOOP
    // ═══════════════════════════════════════════════════════════════
    mag: { freq: '7.1', D_m: '1.0', shape: 'kreis', mat: 'cu25', P_W: '100' },
    magMat: {
      cu25: { label: 'Cu-Rohr 25mm', r_ohm_m: 0.0014 },
      cu15: { label: 'Cu-Rohr 15mm', r_ohm_m: 0.0022 },
      cu10: { label: 'Cu-Rohr 10mm', r_ohm_m: 0.0034 },
      al25: { label: 'Al-Rohr 25mm', r_ohm_m: 0.0022 },
    },
    get magR() {
      const f = this.pf(this.mag.freq) * 1e6;
      const D = this.pf(this.mag.D_m);
      const P = this.pf(this.mag.P_W);
      const mat = this.magMat[this.mag.mat];
      if (!f || !D || !P || !mat) return null;
      const r_loop = D / 2; // radius of loop
      const a = 0.0125; // conductor radius (25mm tube)
      const mu0 = 4 * Math.PI * 1e-7;
      // Inductance (Wheeler/Nagaoka for circle)
      let L_H, perim;
      if (this.mag.shape === 'kreis') {
        L_H = mu0 * r_loop * (Math.log(8 * r_loop / a) - 2);
        perim = 2 * Math.PI * r_loop;
      } else {
        // Square
        const side = D / Math.sqrt(2);
        L_H = (2e-7 * 4 * side) * (Math.log(2 * side / a) - 0.774);
        perim = 4 * side;
      }
      const lambda = 3e8 / f;
      const XL = 2 * Math.PI * f * L_H;
      const C_F = 1 / (4 * Math.PI * Math.PI * f * f * L_H);
      const C_pF = C_F * 1e12;
      const V_rms = Math.sqrt(P * XL);
      const R_rad = 31200 * Math.pow(perim / lambda, 4);
      const R_loss = mat.r_ohm_m * perim;
      const R_total = R_rad + R_loss;
      const Q = XL / R_total;
      const eta = (R_rad / R_total) * 100;
      const BW_kHz = (f / Q) / 1000;
      return { L_uH: L_H * 1e6, C_pF, V_rms, Q: Math.round(Q), eta, BW_kHz, R_rad, R_loss };
    },

    // ═══════════════════════════════════════════════════════════════
    // 16. BALUN / UNUN
    // ═══════════════════════════════════════════════════════════════
    bal: { typ: '1_1', kern: 'ft240_43', lUH: '25', dw: '1.5' },
    balTypen: [
      { id:'1_1',  label:'1:1 Balun (Strombalun)',      zielL:25.0 },
      { id:'4_1',  label:'4:1 Balun (Guanella)',        zielL:12.5 },
      { id:'9_1',  label:'9:1 Unun',                    zielL:8.0  },
      { id:'49_1', label:'49:1 Unun (EFHW)',            zielL:55.0 },
      { id:'64_1', label:'64:1 Unun (Langdraht)',       zielL:65.0 },
      { id:'man',  label:'Mantelwellensperre (1:1 Choke)', zielL:30.0 },
      { id:'free', label:'Freie L-Eingabe',             zielL:10.0 },
    ],
    balKerne: [
      { id:'ft50_43',  name:'FT-50-43',  al:523,  od:12.7, id_mm:7.15,  h:4.85  },
      { id:'ft82_43',  name:'FT-82-43',  al:557,  od:21.0, id_mm:13.1,  h:6.35  },
      { id:'ft114_43', name:'FT-114-43', al:603,  od:29.0, id_mm:19.0,  h:7.55  },
      { id:'ft140_43', name:'FT-140-43', al:885,  od:35.55,id_mm:23.0,  h:12.7  },
      { id:'ft240_43', name:'FT-240-43', al:1075, od:61.0, id_mm:35.55, h:12.7  },
      { id:'ft114_61', name:'FT-114-61', al:173,  od:29.0, id_mm:19.0,  h:7.55  },
      { id:'ft240_61', name:'FT-240-61', al:173,  od:61.0, id_mm:35.55, h:12.7  },
      { id:'t130_2',   name:'T-130-2',   al:110,  od:33.0, id_mm:19.5,  h:11.1  },
      { id:'t200_2',   name:'T-200-2',   al:120,  od:50.8, id_mm:31.75, h:14.3  },
      { id:'fr_2643',  name:'FR 2643',   al:1075, od:61.0, id_mm:35.55, h:12.7  },
    ],
    balTypSelect(id) {
      this.bal.typ = id;
      const t = this.balTypen.find(x => x.id === id);
      if (t && id !== 'free') this.bal.lUH = String(t.zielL);
    },
    get balR() {
      const lUH = this.pf(this.bal.lUH), dw = this.pf(this.bal.dw);
      const kern = this.balKerne.find(k => k.id === this.bal.kern);
      if (!lUH || !dw || !kern) return null;
      const L_nH = lUH * 1000;
      const n = Math.ceil(Math.sqrt(L_nH / kern.al));
      const lTats = (n * n * kern.al) / 1000;
      const innenUmfang = Math.PI * kern.id_mm;
      const mittlD = (kern.od + kern.id_mm) / 2;
      const drahtLen = (n * Math.PI * mittlD + 100) / 1000;
      const maxN = Math.floor(innenUmfang / dw);
      const fill = (n * dw / innenUmfang) * 100;
      const status = fill > 100 ? 'zu-klein' : fill > 80 ? 'eng' : 'ok';
      return { n, lTats, drahtLen, maxN, fill, status, kern };
    },

    // ═══════════════════════════════════════════════════════════════
    // 17. STRAHLER-VERLÄNGERUNG
    // ═══════════════════════════════════════════════════════════════
    verl: { freq: '7.1', hoehe: '6.0', D: '50', dw: '1.5', spacing: '0.5' },
    get verlR() {
      const f = this.pf(this.verl.freq), h = this.pf(this.verl.hoehe);
      const D = this.pf(this.verl.D), dw = this.pf(this.verl.dw);
      const s = this.pf(this.verl.spacing);
      if (!f || !h || !D || !dw) return null;
      const lambda = 300 / f;
      const ziel = 71.25 / f;
      if (h >= ziel) return { ok: true, ziel, aktuell: h };
      const d_m = D / 1000, h_m = h;
      const Z0 = 60 * (Math.log(2 * h_m / (d_m / 2)) - 1);
      const G_deg = 360 * h_m / lambda;
      const G_rad = G_deg * Math.PI / 180;
      const Xa = -Z0 / Math.tan(G_rad);
      const L_H = Math.abs(Xa) / (2 * Math.PI * f * 1e6);
      const L_uH = L_H * 1e6;
      const r_inch = (D / 2 / 1000) * 39.3701;
      const pitch_m = (dw + s) / 1000;
      let l_m = dw / 1000, n = 1;
      for (let i = 0; i < 60; i++) {
        const l_inch = l_m * 39.3701;
        n = Math.sqrt(L_uH * (9 * r_inch + 10 * l_inch)) / r_inch;
        l_m = n * pitch_m;
      }
      n = Math.ceil(n);
      const l_mm = n * pitch_m * 1000;
      return { ok: false, ziel, aktuell: h, L_uH, n, laenge_mm: l_mm, Z0: Math.round(Z0), Xa: Math.round(Xa) };
    },

    // ═══════════════════════════════════════════════════════════════
    // 18. SPULEN-WICKLER
    // ═══════════════════════════════════════════════════════════════
    spul: { D_mm: '30', dw: '1.0', spacing: '0.5', n: '20', freq: '7.1' },
    get spulR() {
      const D = this.pf(this.spul.D_mm), dw = this.pf(this.spul.dw);
      const s = this.pf(this.spul.spacing), n = this.pf(this.spul.n);
      const f = this.pf(this.spul.freq);
      if (!D || !dw || !n || !f) return null;
      const r_inch = (D / 2 / 1000) * 39.3701;
      const pitch = dw + s;
      const l_mm = n * pitch;
      const l_inch = l_mm / 25.4;
      const L_uH = (r_inch * r_inch * n * n) / (9 * r_inch + 10 * l_inch);
      const wireLen = n * Math.sqrt(Math.PI * Math.PI * (D / 1000) * (D / 1000) + (pitch / 1000) * (pitch / 1000));
      const C_res_pF = 1 / (4 * Math.PI * Math.PI * f * f * 1e12 * L_uH * 1e-6);
      const Rdc = (wireLen / (Math.PI * (dw / 2000) * (dw / 2000))) * 1.72e-8;
      const XL = 2 * Math.PI * f * 1e6 * L_uH * 1e-6;
      const Q = XL / Rdc;
      return { L_uH, l_mm, wireLen: wireLen * 1000, C_res_pF, Q: Math.round(Q) };
    },

    // ═══════════════════════════════════════════════════════════════
    // 19. ANPASSNETZWERK (L-NETZ)
    // ═══════════════════════════════════════════════════════════════
    anp: { rLow: '50', rHigh: '200', freq: '14.175' },
    get anpR() {
      const rL = this.pf(this.anp.rLow), rH = this.pf(this.anp.rHigh);
      const f = this.pf(this.anp.freq);
      if (!rL || !rH || !f || rL >= rH) return null;
      const Q = Math.sqrt(rH / rL - 1);
      const XL = rL * Q;
      const XC = rH / Q;
      const L_uH = (XL / (2 * Math.PI * f)) * 1e3;
      const C_pF = 1e9 / (2 * Math.PI * f * XC);
      return { Q, XL, XC, L_uH, C_pF };
    },

    // ═══════════════════════════════════════════════════════════════
    // 20. KOAX-STUB
    // ═══════════════════════════════════════════════════════════════
    kstub: { freq: '145.0', koax: 'rg213', typ: 'offen' },
    kstubVF: { rg58: 0.66, rg213: 0.66, rg8: 0.66, h155: 0.80, aircell7: 0.83, ecoflex10: 0.83 },
    get kstubR() {
      const f = this.pf(this.kstub.freq);
      const vf = this.kstubVF[this.kstub.koax] || 0.66;
      if (!f) return null;
      return { lq: 75 / f * vf, lh: 150 / f * vf, lambda: 300 / f, vf };
    },

    // ═══════════════════════════════════════════════════════════════
    // 21. KABELDÄMPFUNG
    // ═══════════════════════════════════════════════════════════════
    kdae: { kabel: 'rg213', freq: '145.0', laenge: '20', pIn: '100' },
    kdaeKabel: [
      { id:'rg174',     name:'RG-174',        db:[8.0,14.0,26.0,32.0,48.0,59.0,100.0,120.0] },
      { id:'rg316',     name:'RG-316',        db:[6.5,11.5,22.0,27.0,41.0,50.0,85.0,102.0]  },
      { id:'rg58',      name:'RG-58',         db:[4.5,7.5,14.0,19.0,28.0,35.0,59.0,70.0]    },
      { id:'rg8x',      name:'RG-8X (Mini-8)',db:[3.0,5.2,9.8,12.5,18.5,22.5,37.0,44.0]     },
      { id:'rg8',       name:'RG-8 / RG-8A',  db:[2.1,3.7,6.9,8.8,13.0,15.8,26.5,31.5]     },
      { id:'rg213',     name:'RG-213',        db:[2.0,3.5,6.5,8.5,12.5,15.5,26.0,30.0]      },
      { id:'rg214',     name:'RG-214',        db:[1.9,3.3,6.2,7.8,11.8,14.8,24.5,28.5]      },
      { id:'ecoflex6',  name:'Ecoflex 6',     db:[2.3,3.9,7.2,9.1,13.4,16.2,27.0,32.0]      },
      { id:'ecoflex10', name:'Ecoflex 10',    db:[1.2,2.1,3.9,4.9,7.2,8.7,14.5,17.2]        },
      { id:'ecoflex15', name:'Ecoflex 15',    db:[0.8,1.4,2.6,3.3,4.8,5.8,9.7,11.5]         },
      { id:'aircell7',  name:'Aircell 7',     db:[2.2,3.8,7.0,8.9,13.1,15.8,26.2,31.0]      },
      { id:'lmr200',    name:'LMR-200',       db:[3.1,5.3,9.9,12.6,18.6,22.5,37.5,44.5]     },
      { id:'lmr400',    name:'LMR-400',       db:[1.3,2.3,4.3,5.4,8.0,9.7,16.2,19.2]        },
      { id:'lmr600',    name:'LMR-600',       db:[0.85,1.5,2.8,3.5,5.2,6.3,10.5,12.4]       },
      { id:'h155',      name:'H-155',         db:[2.9,4.9,9.2,11.6,17.1,20.7,34.3,40.6]     },
      { id:'hypflex10', name:'Hyperflex 10',  db:[1.5,2.6,4.8,6.1,9.0,10.9,18.1,21.4]       },
    ],
    kdaeFreqPts: [10,30,100,145,300,435,1000,1296],
    kdaeInterp(kabel, f) {
      const pts = this.kdaeFreqPts, db = kabel.db;
      if (f <= pts[0]) return db[0] * Math.sqrt(f / pts[0]);
      if (f >= pts[pts.length-1]) return db[db.length-1] * Math.sqrt(f / pts[pts.length-1]);
      for (let i = 0; i < pts.length-1; i++) {
        if (f >= pts[i] && f <= pts[i+1]) {
          const r = (f - pts[i]) / (pts[i+1] - pts[i]);
          return db[i] + (db[i+1] - db[i]) * r;
        }
      }
      return db[0];
    },
    get kdaeR() {
      const f = this.pf(this.kdae.freq), l = this.pf(this.kdae.laenge), pIn = this.pf(this.kdae.pIn);
      const kab = this.kdaeKabel.find(k => k.id === this.kdae.kabel);
      if (!f || !l || !pIn || !kab) return null;
      const att100 = this.kdaeInterp(kab, f);
      const totalDB = (att100 / 100) * l;
      const pOut = pIn * Math.pow(10, -totalDB / 10);
      const eta = (pOut / pIn) * 100;
      const status = eta >= 80 ? 'gut' : eta >= 50 ? 'mittel' : 'schlecht';
      return { att100, totalDB, pOut, verlust: pIn - pOut, eta, status };
    },

    // ═══════════════════════════════════════════════════════════════
    // 22. PEGEL-UMRECHNER
    // ═══════════════════════════════════════════════════════════════
    peg: { mode: 'watt', value: '100', Z: '50' },
    get pegR() {
      const v = this.pf(this.peg.value), Z = this.pf(this.peg.Z) || 50;
      if (!v || v <= 0) return null;
      let P_W, U_V;
      switch (this.peg.mode) {
        case 'watt': P_W = v; U_V = Math.sqrt(P_W * Z); break;
        case 'mw':   P_W = v / 1000; U_V = Math.sqrt(P_W * Z); break;
        case 'dbm':  P_W = Math.pow(10, (v - 30) / 10); U_V = Math.sqrt(P_W * Z); break;
        case 'dbw':  P_W = Math.pow(10, v / 10); U_V = Math.sqrt(P_W * Z); break;
        case 'volt': U_V = v; P_W = v * v / Z; break;
        default: return null;
      }
      return {
        W: P_W, mW: P_W * 1000,
        dBm: 10 * Math.log10(P_W * 1000),
        dBW: 10 * Math.log10(P_W),
        V: U_V, mV: U_V * 1000, uV: U_V * 1e6,
      };
    },

    // ═══════════════════════════════════════════════════════════════
    // 23. SWR-SIMULATOR
    // ═══════════════════════════════════════════════════════════════
    swr: { swr: '2.0', pFwd: '100' },
    get swrR() {
      const swr = this.pf(this.swr.swr), pFwd = this.pf(this.swr.pFwd);
      if (!swr || swr < 1 || !pFwd) return null;
      const gamma = (swr - 1) / (swr + 1);
      const pRef = pFwd * gamma * gamma;
      const pNet = pFwd - pRef;
      const rl = -20 * Math.log10(gamma);
      const mismatch = -10 * Math.log10(1 - gamma * gamma);
      const vswr = swr;
      return { gamma, pRef, pNet, rl, mismatch, vswr };
    },

    // ═══════════════════════════════════════════════════════════════
    // 24. LINKBUDGET
    // ═══════════════════════════════════════════════════════════════
    lnk: { freq: '145.0', dist: '10', ptx: '10', gtx: '0', grx: '0', sens: '-120' },
    get lnkR() {
      const f = this.pf(this.lnk.freq), d = this.pf(this.lnk.dist);
      const ptx = this.pf(this.lnk.ptx), gtx = this.pf(this.lnk.gtx);
      const grx = this.pf(this.lnk.grx), sens = this.pf(this.lnk.sens);
      if (!f || !d || !ptx) return null;
      const ptx_dBm = 10 * Math.log10(ptx * 1000);
      const fspl = 20 * Math.log10(d) + 20 * Math.log10(f) + 32.45;
      const prx_dBm = ptx_dBm + gtx + grx - fspl;
      const prx_W = Math.pow(10, (prx_dBm - 30) / 10);
      const prx_uV = Math.sqrt(prx_W * 50) * 1e6;
      const margin = prx_dBm - sens;
      return { ptx_dBm, fspl, prx_dBm, prx_uV, margin, ok: margin > 0 };
    },

    // ═══════════════════════════════════════════════════════════════
    // 25. QTH-LOCATOR
    // ═══════════════════════════════════════════════════════════════
    qth: { locator: 'JN47PN', lat: '', lon: '', mode: 'loc2coord' },
    get qthR() {
      if (this.qth.mode === 'loc2coord') {
        return this._loc2coord(this.qth.locator.toUpperCase().trim());
      } else {
        const lat = this.pf(this.qth.lat), lon = this.pf(this.qth.lon);
        if (isNaN(lat) || isNaN(lon)) return null;
        return this._coord2loc(lat, lon);
      }
    },
    _loc2coord(loc) {
      if (!loc || loc.length < 4) return null;
      loc = loc.toUpperCase();
      const lon = (loc.charCodeAt(0) - 65) * 20 - 180
                + (parseInt(loc[2]) * 2)
                + (loc.length >= 6 ? (loc.charCodeAt(4) - 65) / 12 : 1);
      const lat = (loc.charCodeAt(1) - 65) * 10 - 90
                + (parseInt(loc[3]))
                + (loc.length >= 6 ? (loc.charCodeAt(5) - 65) / 24 : 0.5);
      return { mode: 'loc2coord', loc, lat: lat.toFixed(5), lon: lon.toFixed(5) };
    },
    _coord2loc(lat, lon) {
      lon += 180; lat += 90;
      const A = String.fromCharCode(65 + Math.floor(lon / 20));
      const B = String.fromCharCode(65 + Math.floor(lat / 10));
      const C = String(Math.floor((lon % 20) / 2));
      const D = String(Math.floor(lat % 10));
      const E = String.fromCharCode(65 + Math.floor((lon % 2) * 12));
      const F = String.fromCharCode(65 + Math.floor((lat % 1) * 24));
      return { mode: 'coord2loc', loc: A+B+C+D+E+F, lat: lat-90, lon: lon-180 };
    },

  })); // end Alpine.data
}); // end alpine:init
