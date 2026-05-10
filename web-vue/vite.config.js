import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  base: './',
  server: {
    fs: {
      // Erlaubt Vite-Zugriff auf ../Sources/HAMRechner/Content/*.md
      // (Single Source of Truth für Native + Web Beschreibungen)
      allow: ['..'],
    },
  },
})
