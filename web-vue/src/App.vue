<script setup>
import { ref, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import {
  RadioTower, ArrowUpToLine, Square, Cylinder, Triangle,
  ArrowRightToLine, Spline, CircleDashed, RectangleHorizontal,
  Radio, Hexagon, Star, StarHalf, CircleDotDashed,
  Repeat, Ruler, Loader, SlidersHorizontal, Cable, CableCar,
  AudioWaveform, LineChart, Send, MapPin, Menu, Home,
} from 'lucide-vue-next'

const theme = ref(localStorage.getItem('ht_theme') || 'classic')
const sidebarOpen = ref(false)
const route = useRoute()

function setTheme(t) {
  theme.value = t
  document.body.className = t
  localStorage.setItem('ht_theme', t)
}

function toggleSidebar() { sidebarOpen.value = !sidebarOpen.value }
function closeSidebar() { sidebarOpen.value = false }

// Mobile-Sidebar bei Navigationswechsel automatisch schließen
watch(() => route.path, () => closeSidebar())

onMounted(() => {
  document.body.className = theme.value
})

const navGroups = [
  { cat: 'Drahtantennen', items: [
    { label: 'Dipol',                    to: '/dipol',         icon: RadioTower },
    { label: 'Groundplane / Vertikal',   to: '/groundplane',   icon: ArrowUpToLine },
    { label: 'J-Pole / Slim Jim',        to: '/jpole',         icon: Square },
    { label: 'Sperrtopf',                to: '/sperrtopf',     icon: Cylinder },
    { label: 'Windom (OCFD)',            to: '/windom',        icon: Triangle },
    { label: 'EFHW-Antenne',             to: '/efhw',          icon: ArrowRightToLine },
    { label: 'EFHW-Verkürzung',          to: '/efhwv',         icon: Spline },
    { label: 'Loop-Antenne',             to: '/loop',          icon: CircleDashed },
  ]},
  { cat: 'Richtstrahler', items: [
    { label: 'Moxon Rectangle',          to: '/moxon',         icon: RectangleHorizontal },
    { label: 'HB9CV Beam',               to: '/hb9cv',         icon: Radio },
    { label: 'Hexbeam',                  to: '/hexbeam',       icon: Hexagon },
    { label: 'Yagi-Rechner',             to: '/yagi',          icon: ArrowRightToLine },
    { label: 'Spiderbeam Einzelband',    to: '/spidereinzel',  icon: StarHalf },
    { label: 'Spiderbeam Multi-Band',    to: '/spidermulti',   icon: Star },
  ]},
  { cat: 'Spezialantennen', items: [
    { label: 'Magnetic Loop',            to: '/magloop',       icon: CircleDotDashed },
  ]},
  { cat: 'Spulen & Trafos', items: [
    { label: 'Balun / Unun',             to: '/balun',         icon: Repeat },
    { label: 'Strahler-Verlängerung',    to: '/strahlerverl',  icon: Ruler },
    { label: 'Spulen-Wickler',           to: '/spulenwickler', icon: Loader },
  ]},
  { cat: 'Anpassung & Leitungen', items: [
    { label: 'Anpassnetzwerk (L-Netz)',  to: '/anpassnetz',    icon: SlidersHorizontal },
    { label: 'Koax-Stub',                to: '/koaxstub',      icon: Cable },
    { label: 'Kabeldämpfung',            to: '/kabeldaempfung',icon: CableCar },
  ]},
  { cat: 'Signale & Tools', items: [
    { label: 'Pegel-Umrechner',          to: '/pegelrechner',  icon: AudioWaveform },
    { label: 'SWR-Simulator',            to: '/swr',           icon: LineChart },
    { label: 'Linkbudget / Reichweite',  to: '/linkbudget',    icon: Send },
    { label: 'QTH-Locator',              to: '/qthlocator',    icon: MapPin },
  ]},
]
</script>

<template>
  <div class="mobile-header">
    <button class="hamburger" @click="toggleSidebar" aria-label="Menü öffnen">
      <Menu :size="22" :stroke-width="2" />
    </button>
    <div class="mh-title">
      <h1>HAM-Tools</h1>
      <p>HB9HJI · Funkwelt</p>
    </div>
  </div>
  <div class="backdrop" :class="{ open: sidebarOpen }" @click="closeSidebar"></div>
  <div id="sidebar" :class="{ open: sidebarOpen }">
    <div class="sb-head">
      <h1>HAM-Tools</h1>
      <p>HB9HJI · Funkwelt</p>
    </div>
    <nav>
      <div class="nav-group" style="margin-top:4px">
        <RouterLink to="/" class="nav-item" active-class="active" exact-active-class="active">
          <Home class="nav-icon" :size="14" :stroke-width="1.75" />
          <span>Startseite</span>
        </RouterLink>
      </div>
      <div v-for="group in navGroups" :key="group.cat" class="nav-group">
        <div class="nav-cat">{{ group.cat }}</div>
        <RouterLink
          v-for="item in group.items"
          :key="item.to"
          :to="item.to"
          class="nav-item"
          active-class="active"
        >
          <component :is="item.icon" class="nav-icon" :size="14" :stroke-width="1.75" />
          <span>{{ item.label }}</span>
        </RouterLink>
      </div>
    </nav>
    <div class="sb-footer">
      <p>Theme</p>
      <div class="theme-row">
        <button class="theme-btn" :class="{ active: theme === 'classic' }" @click="setTheme('classic')">Classic</button>
        <button class="theme-btn" :class="{ active: theme === 'dark' }"    @click="setTheme('dark')">Dark</button>
        <button class="theme-btn" :class="{ active: theme === 'light' }"   @click="setTheme('light')">Light</button>
      </div>
    </div>
  </div>
  <main id="main">
    <RouterView />
  </main>
</template>
