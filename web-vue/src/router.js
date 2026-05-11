import { createRouter, createWebHashHistory } from 'vue-router'

const routes = [
  { path: '/',              component: () => import('./views/Welcome.vue') },
  { path: '/dipol',         component: () => import('./views/Dipol.vue') },
  { path: '/groundplane',   component: () => import('./views/Groundplane.vue') },
  { path: '/jpole',         component: () => import('./views/JPole.vue') },
  { path: '/sperrtopf',     component: () => import('./views/Sperrtopf.vue') },
  { path: '/windom',        component: () => import('./views/Windom.vue') },
  { path: '/efhw',          component: () => import('./views/EFHW.vue') },
  { path: '/efhwv',         component: () => import('./views/EFHWVerkuerzung.vue') },
  { path: '/loop',          component: () => import('./views/LoopAntenne.vue') },
  { path: '/moxon',         component: () => import('./views/MoxonRectangle.vue') },
  { path: '/hb9cv',         component: () => import('./views/HB9CVBeam.vue') },
  { path: '/hexbeam',       component: () => import('./views/Hexbeam.vue') },
  { path: '/yagi',          component: () => import('./views/YagiRechner.vue') },
  { path: '/spidereinzel',  component: () => import('./views/SpiderbeamEinzel.vue') },
  { path: '/spidermulti',   component: () => import('./views/SpiderbeamMulti.vue') },
  { path: '/magloop',       component: () => import('./views/MagneticLoop.vue') },
  { path: '/balun',         component: () => import('./views/BalunUnun.vue') },
  { path: '/mantelwellensperre', component: () => import('./views/Mantelwellensperre.vue') },
  { path: '/strahlerverl',  component: () => import('./views/StrahlerVerl.vue') },
  { path: '/spulenwickler', component: () => import('./views/SpulenWickler.vue') },
  { path: '/anpassnetz',    component: () => import('./views/Anpassnetzwerk.vue') },
  { path: '/koaxstub',      component: () => import('./views/KoaxStub.vue') },
  { path: '/kabeldaempfung',component: () => import('./views/Kabeldaempfung.vue') },
  { path: '/pegelrechner',  component: () => import('./views/Pegelrechner.vue') },
  { path: '/swr',           component: () => import('./views/SWRSimulator.vue') },
  { path: '/linkbudget',    component: () => import('./views/LinkBudget.vue') },
  { path: '/qthlocator',    component: () => import('./views/QTHLocator.vue') },
  { path: '/bandplan',      component: () => import('./views/Bandplan.vue') },
  { path: '/smithchart',    component: () => import('./views/SmithChart.vue') },
  { path: '/antennensim',   component: () => import('./views/AntennenSimulator.vue') },
]

export const router = createRouter({
  history: createWebHashHistory(),
  routes,
})
