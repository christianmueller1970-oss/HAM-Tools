import App from './App.vue'
import { routes } from './router.js'
import { ViteSSG } from 'vite-ssg'
import './style.css'

// vite-ssg übernimmt sowohl SPA-Boot (Production + Dev) als auch
// Pre-Rendering pro Route beim Build (statische HTML-Dateien für SEO).
// @unhead/vue ist von vite-ssg automatisch integriert — useHead() in
// App.vue setzt die Head-Tags reaktiv abhängig von der aktuellen Route.
export const createApp = ViteSSG(App, { routes })
