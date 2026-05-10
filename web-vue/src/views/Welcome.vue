<script setup>
import {
  RadioTower, Hexagon, CircleDotDashed, Repeat,
  SlidersHorizontal, LineChart,
} from 'lucide-vue-next'

const kategorien = [
  { icon: RadioTower,        title: 'Drahtantennen',          to: '/dipol',
    desc: 'Dipol, Groundplane, J-Pole, Sperrtopf, Windom, EFHW, Loop',
    count: '8 Rechner' },
  { icon: Hexagon,            title: 'Richtstrahler',          to: '/yagi',
    desc: 'Yagi, Moxon, HB9CV, Hexbeam, Spiderbeam Einzel- und Multi-Band',
    count: '6 Rechner' },
  { icon: CircleDotDashed,    title: 'Spezialantennen',        to: '/magloop',
    desc: 'Magnetic Loop mit Drehko-Berechnung und Wirkungsgrad',
    count: '1 Rechner' },
  { icon: Repeat,              title: 'Spulen & Trafos',        to: '/balun',
    desc: 'Balun / Unun, Strahler-Verlängerung, Spulen-Wickler',
    count: '3 Rechner' },
  { icon: SlidersHorizontal,  title: 'Anpassung & Leitungen',  to: '/anpassnetz',
    desc: 'L-Netz, Koax-Stub, Kabeldämpfung mit Kennlinien',
    count: '3 Rechner' },
  { icon: LineChart,           title: 'Signale & Tools',        to: '/swr',
    desc: 'Pegel-Umrechner, SWR-Simulator, Linkbudget, QTH-Locator',
    count: '4 Rechner' },
]
</script>

<template>
  <div class="welcome">
    <section class="hero">
      <div class="hero-icon">
        <RadioTower :size="56" :stroke-width="1.5" />
      </div>
      <h1>HAM-Tools</h1>
      <p class="lead">
        Werkzeuge für den Amateurfunk &mdash; Berechnungen und Skizzen für
        Antennen, Spulen, Anpassung und Messtechnik
      </p>
      <div class="hero-meta">
        <span>HB9HJI</span>
        <span class="sep">·</span>
        <span>Funkwelt</span>
        <span class="sep">·</span>
        <span>25 Rechner</span>
      </div>
    </section>

    <section>
      <h2 class="section-title">Kategorien</h2>
      <div class="cat-grid">
        <RouterLink v-for="k in kategorien" :key="k.to" :to="k.to" class="cat-card">
          <div class="cat-icon"><component :is="k.icon" :size="28" :stroke-width="1.75" /></div>
          <div class="cat-body">
            <div class="cat-head">
              <h3>{{ k.title }}</h3>
              <span class="cat-count">{{ k.count }}</span>
            </div>
            <p>{{ k.desc }}</p>
          </div>
        </RouterLink>
      </div>
    </section>

    <section class="about">
      <div class="card">
        <h2>Über HAM-Tools</h2>
        <p>
          HAM-Tools ist eine wachsende Sammlung praktischer Berechnungs-Tools
          für den Amateurfunk. Alle Rechner basieren auf etablierten Formeln
          aus der Fachliteratur &mdash; Wheeler-Spule, G3TXQ Moxon,
          DF4SA Spiderbeam, Friis Linkbudget und weitere.
        </p>
        <p>
          Diese Web-Version ist eine 1:1-Portierung der nativen macOS-App.
          Beide Versionen werden parallel gepflegt.
        </p>
      </div>
      <div class="card">
        <h2>funkwelt.net</h2>
        <p>
          <strong>funkwelt.net</strong> ist die persönliche Amateurfunk-Domain
          von HB9HJI. Hier laufen Tools, Notizen und Experimente rund um den
          Funkbetrieb.
        </p>
        <p class="small c-dim">
          <em>Text-Platzhalter &mdash; bei Bedarf in
          <code>web-vue/src/views/Welcome.vue</code> editieren.</em>
        </p>
      </div>
    </section>

    <section>
      <div class="features">
        <div class="feature">
          <div class="feature-num">25</div>
          <div class="feature-lbl">Rechner mit Skizzen</div>
        </div>
        <div class="feature">
          <div class="feature-num">3</div>
          <div class="feature-lbl">Themes (Classic, Light, Dark)</div>
        </div>
        <div class="feature">
          <div class="feature-num">0</div>
          <div class="feature-lbl">Tracking, Cookies, Werbung</div>
        </div>
        <div class="feature">
          <div class="feature-num">100%</div>
          <div class="feature-lbl">offline-fähig nach erstem Laden</div>
        </div>
      </div>
    </section>

    <footer class="welcome-footer">
      <p>HB9HJI · Funkwelt · {{ new Date().getFullYear() }}</p>
      <p class="small">
        Web-Version &mdash; Quellen und Formeln in den jeweiligen Hinweis-Boxen der Rechner
      </p>
    </footer>
  </div>
</template>

<style scoped>
.welcome { max-width: 980px; margin: 0 auto; }

/* Hero */
.hero {
  text-align: center;
  padding: 40px 20px 36px;
  border-bottom: 1px solid var(--sep);
  margin-bottom: 28px;
}
.hero-icon {
  width: 88px; height: 88px;
  margin: 0 auto 16px;
  display: flex; align-items: center; justify-content: center;
  background: var(--card2);
  border: 1px solid var(--sep);
  border-radius: 50%;
  color: var(--acc);
}
.hero h1 {
  font-size: 32px; font-weight: 800;
  color: var(--tp);
  letter-spacing: -0.5px;
  margin-bottom: 10px;
}
.lead {
  font-size: 15px;
  color: var(--ts);
  max-width: 580px;
  margin: 0 auto;
  line-height: 1.6;
}
.hero-meta {
  margin-top: 14px;
  font-size: 12px;
  color: var(--td);
  display: flex; gap: 8px; justify-content: center;
  flex-wrap: wrap;
}
.hero-meta .sep { opacity: 0.5; }

/* Section title */
.section-title {
  font-size: 11px; font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 1px;
  color: var(--ts);
  margin-bottom: 12px;
  padding-left: 4px;
}

/* Kategorien-Grid */
.cat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 12px;
  margin-bottom: 28px;
}
.cat-card {
  display: flex; align-items: flex-start; gap: 14px;
  padding: 16px;
  background: var(--card);
  border: 1px solid var(--sep);
  border-radius: 10px;
  text-decoration: none;
  color: inherit;
  transition: border-color 0.15s, transform 0.15s;
}
.cat-card:hover {
  border-color: var(--acc);
  transform: translateY(-1px);
}
.cat-icon {
  flex-shrink: 0;
  width: 44px; height: 44px;
  display: flex; align-items: center; justify-content: center;
  background: var(--card2);
  border-radius: 8px;
  color: var(--acc);
}
.cat-body { flex: 1; min-width: 0; }
.cat-head {
  display: flex; align-items: baseline; justify-content: space-between;
  gap: 8px; margin-bottom: 4px;
}
.cat-head h3 {
  font-size: 14px; font-weight: 600;
  color: var(--tp);
}
.cat-count {
  font-size: 10px;
  color: var(--td);
  white-space: nowrap;
}
.cat-card p {
  font-size: 12px;
  color: var(--ts);
  line-height: 1.5;
}

/* About-Section: 2 Spalten */
.about {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  margin-bottom: 28px;
}
.about .card p {
  font-size: 13px;
  color: var(--ts);
  line-height: 1.6;
  margin-bottom: 10px;
}
.about .card p:last-child { margin-bottom: 0; }
.about code {
  font-family: 'SF Mono', monospace;
  font-size: 11px;
  background: var(--card2);
  padding: 1px 5px;
  border-radius: 3px;
}

/* Feature-Stats */
.features {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
  margin-bottom: 28px;
}
.feature {
  background: var(--card2);
  border: 1px solid var(--sep);
  border-radius: 10px;
  padding: 18px 12px;
  text-align: center;
}
.feature-num {
  font-size: 26px; font-weight: 800;
  color: var(--acc);
  font-family: 'SF Mono', monospace;
  line-height: 1;
}
.feature-lbl {
  font-size: 11px;
  color: var(--ts);
  margin-top: 6px;
  line-height: 1.4;
}

/* Footer */
.welcome-footer {
  text-align: center;
  padding: 28px 0 16px;
  border-top: 1px solid var(--sep);
  color: var(--td);
}
.welcome-footer p { font-size: 12px; margin-bottom: 4px; }
.welcome-footer .small { font-size: 10px; }

/* Responsive */
@media (max-width: 640px) {
  .hero { padding: 28px 14px 24px; }
  .hero h1 { font-size: 26px; }
  .hero-icon { width: 72px; height: 72px; }
  .about { grid-template-columns: 1fr; }
  .features { grid-template-columns: 1fr 1fr; }
  .cat-grid { grid-template-columns: 1fr; }
}
</style>
