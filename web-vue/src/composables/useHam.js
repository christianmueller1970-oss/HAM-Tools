export const bands = [
  ['160m', 1.85], ['80m', 3.65], ['60m', 5.36], ['40m', 7.1],
  ['30m', 10.125], ['20m', 14.175], ['17m', 18.118], ['15m', 21.225],
  ['12m', 24.94], ['10m', 28.5], ['6m', 50.15], ['2m', 145.0],
]

export function pf(s) {
  return parseFloat(String(s).replace(',', '.')) || 0
}

export function fmt(n, d = 3) {
  return (!isFinite(n) || isNaN(n)) ? '—' : n.toFixed(d)
}

export function isBandActive(freq, bandFreq) {
  return Math.abs(pf(freq) - bandFreq) < 0.5
}
