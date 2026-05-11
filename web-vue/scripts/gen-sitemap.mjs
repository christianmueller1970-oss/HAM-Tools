// Generiert public/sitemap.xml aus seo.js — alle Routen, mit Last-Modified
// auf "heute" und Priority/ChangeFreq.
import { SEO_ROUTES, SITE_URL } from '../src/seo.js'
import fs from 'node:fs'
import path from 'node:path'

const today = new Date().toISOString().slice(0, 10)
const urls = Object.keys(SEO_ROUTES).map(p => {
  const isHome = p === '/'
  return `  <url>
    <loc>${SITE_URL}${p === '/' ? '' : p}</loc>
    <lastmod>${today}</lastmod>
    <changefreq>${isHome ? 'weekly' : 'monthly'}</changefreq>
    <priority>${isHome ? '1.0' : '0.8'}</priority>
  </url>`
}).join('\n')

const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls}
</urlset>
`

const out = path.join(process.cwd(), 'public', 'sitemap.xml')
fs.writeFileSync(out, xml, 'utf8')
console.log(`✓ sitemap.xml mit ${Object.keys(SEO_ROUTES).length} URLs geschrieben → ${out}`)
