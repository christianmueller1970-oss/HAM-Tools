// Helper für "Im Sim öffnen"-Buttons in den Antennen-Rechnern.
// Serialisiert das AntennenSim-Modell als URL-Param (Base64-JSON) und ruft
// AntennenSimulator.vue mit diesem Param auf.

function toUrlBase64(str) {
  // btoa kann mit UTF-8 nicht direkt umgehen — über encodeURIComponent gehen.
  const utf8 = unescape(encodeURIComponent(str))
  return btoa(utf8).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

export function encodeModel(model) {
  return toUrlBase64(JSON.stringify(model))
}

export function decodeModel(b64) {
  try {
    const padded = b64.replace(/-/g, '+').replace(/_/g, '/')
    const utf8 = atob(padded)
    const json = decodeURIComponent(escape(utf8))
    return JSON.parse(json)
  } catch {
    return null
  }
}

export function openInSim(router, model) {
  const param = encodeModel(model)
  return router.push({ path: '/antennensim', query: { model: param } })
}
