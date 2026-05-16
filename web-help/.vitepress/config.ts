import { defineConfig } from 'vitepress'

// HAM-Tools — Help & Docs.
// Wird gebaut nach dist/ und per scp nach /var/www/toolbox/help/ hochgeladen.
// Liegt damit unter https://toolbox.funkwelt.net/help/
//
// base: '/help/' ist wichtig — sonst suchen alle Asset-URLs unter /,
// dann sind CSS/JS-Pfade nach dem Upload kaputt.

export default defineConfig({
  base: '/help/',
  lang: 'de-CH',
  title: 'HAM-Tools',
  description: 'Anleitungen, FAQ und Tipps zum HAM-Tools macOS-Logger',
  cleanUrls: true,
  lastUpdated: true,

  // VitePress generiert beim Build automatisch eine sitemap.xml unter
  // /help/sitemap.xml — Google Search Console bekommt diese URL eingetragen.
  sitemap: {
    hostname: 'https://toolbox.funkwelt.net/help/',
  },

  head: [
    ['link', { rel: 'icon', href: '/help/favicon.svg' }],
    ['meta', { name: 'theme-color', content: '#2a8fd6' }],

    // OpenGraph für Social-Sharing (Twitter, Mastodon, Facebook, LinkedIn)
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:site_name', content: 'HAM-Tools Help' }],
    ['meta', { property: 'og:title', content: 'HAM-Tools — Logbuch, Contest, POTA/SOTA/WWFF/BOTA für macOS' }],
    ['meta', { property: 'og:description', content: 'Anleitungen, FAQ und Tipps zum HAM-Tools macOS-Logger. Multi-Log, Contest mit 14 Templates, vier Award-Programme (POTA, SOTA, WWFF, BOTA), CAT für Yaesu/Icom/Kenwood/Elecraft.' }],
    ['meta', { property: 'og:url', content: 'https://toolbox.funkwelt.net/help/' }],
    ['meta', { property: 'og:image', content: 'https://toolbox.funkwelt.net/help/og-image.png' }],
    ['meta', { property: 'og:locale', content: 'de_CH' }],

    // Twitter / X Card
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['meta', { name: 'twitter:title', content: 'HAM-Tools — macOS-Logger für Funkamateure' }],
    ['meta', { name: 'twitter:description', content: 'Logbuch, Contest, POTA/SOTA/WWFF/BOTA, CAT-Steuerung. Native macOS-App.' }],
    ['meta', { name: 'twitter:image', content: 'https://toolbox.funkwelt.net/help/og-image.png' }],

    // Strukturierte Daten (Schema.org) für Google Rich Results
    ['script', { type: 'application/ld+json' }, JSON.stringify({
      '@context': 'https://schema.org',
      '@type': 'SoftwareApplication',
      name: 'HAM-Tools',
      operatingSystem: 'macOS 14+',
      applicationCategory: 'CommunicationApplication',
      description: 'Native macOS-Logger für Funkamateure mit Logbuch, Contest-Modus, vier Award-Programmen (POTA, SOTA, WWFF, BOTA), DX-Cluster, CAT-Steuerung und Antennen-Rechnern.',
      url: 'https://toolbox.funkwelt.net/help/',
      author: {
        '@type': 'Person',
        name: 'Christian Mueller',
        alternateName: 'HB9HJI',
      },
      offers: {
        '@type': 'Offer',
        priceCurrency: 'CHF',
        availability: 'https://schema.org/InStock',
      },
    })],
  ],

  themeConfig: {
    siteTitle: 'HAM-Tools Help',
    logo: { src: '/icon.svg', alt: 'HAM-Tools' },

    nav: [
      { text: 'Erste Schritte', link: '/getting-started' },
      { text: 'Module', link: '/modules/logbuch' },
      { text: 'FAQ', link: '/faq' },
      { text: 'Bekannte Bugs', link: '/known-bugs' },
      { text: 'Download', link: 'https://toolbox.funkwelt.net/app/dmg/latest.dmg' },
    ],

    sidebar: {
      '/': [
        {
          text: 'Einstieg',
          items: [
            { text: 'Übersicht', link: '/' },
            { text: 'Erste Schritte', link: '/getting-started' },
            { text: 'Lizenz aktivieren', link: '/license' },
          ],
        },
        {
          text: 'Module',
          collapsed: false,
          items: [
            { text: 'Logbuch (Standard)', link: '/modules/logbuch' },
            { text: 'Contest', link: '/modules/contest' },
            { text: 'POTA', link: '/modules/pota' },
            { text: 'SOTA', link: '/modules/sota' },
            { text: 'WWFF', link: '/modules/wwff' },
            { text: 'BOTA', link: '/modules/bota' },
            { text: 'DX-Cluster', link: '/modules/dx-cluster' },
            { text: 'CAT / Radio-Steuerung', link: '/modules/cat' },
            { text: 'Rechner', link: '/modules/rechner' },
            { text: 'Bandplan', link: '/modules/bandplan' },
          ],
        },
        {
          text: 'Hilfe',
          items: [
            { text: 'FAQ', link: '/faq' },
            { text: 'Bekannte Bugs', link: '/known-bugs' },
            { text: 'Bug melden', link: '/report-bug' },
            { text: 'Changelog', link: '/changelog' },
          ],
        },
      ],
    },

    footer: {
      message: 'HAM-Tools © HB9HJI · Funkwelt',
      copyright: 'Made with VitePress',
    },

    search: {
      provider: 'local',
      options: {
        locales: {
          root: {
            translations: {
              button: { buttonText: 'Suchen', buttonAriaLabel: 'Suchen' },
              modal: {
                noResultsText: 'Keine Treffer für',
                resetButtonTitle: 'Zurücksetzen',
                footer: {
                  selectText: 'auswählen',
                  navigateText: 'navigieren',
                  closeText: 'schließen',
                },
              },
            },
          },
        },
      },
    },

    editLink: {
      pattern: 'https://github.com/christianmueller1970-oss/HAM-Tools/edit/main/web-help/:path',
      text: 'Seite verbessern auf GitHub',
    },

    outline: {
      label: 'Auf dieser Seite',
      level: [2, 3],
    },

    docFooter: {
      prev: 'Zurück',
      next: 'Weiter',
    },
  },
})
