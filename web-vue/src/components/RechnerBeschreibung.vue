<script setup>
import { computed } from 'vue'
import { marked } from 'marked'

const props = defineProps({
  name: { type: String, required: true },
})

// Lädt alle Markdown-Files aus Sources/HAMRechner/Content/
// (Single Source of Truth — Native und Web teilen denselben Inhalt)
const markdownFiles = import.meta.glob(
  '../../../Sources/HAMRechner/Content/*.md',
  { query: '?raw', import: 'default', eager: true }
)

function findMarkdown(name) {
  for (const [path, content] of Object.entries(markdownFiles)) {
    if (path.endsWith(`/${name}.md`)) return content
  }
  return null
}

// Parsed Markdown in Sections aufgeteilt nach ## Headern
function parseSections(md) {
  if (!md) return []
  const sections = []
  let currentTitle = null
  let currentBody = []

  for (const line of md.split('\n')) {
    if (line.startsWith('## ')) {
      if (currentTitle !== null) {
        sections.push({
          title: currentTitle,
          html: marked.parse(currentBody.join('\n').trim()),
        })
      }
      currentTitle = line.slice(3).trim()
      currentBody = []
    } else if (line.startsWith('# ')) {
      // Top-Level # ist der Antennen-Name → wird im Calc-Title schon angezeigt, hier überspringen
      continue
    } else {
      currentBody.push(line)
    }
  }
  if (currentTitle !== null) {
    sections.push({
      title: currentTitle,
      html: marked.parse(currentBody.join('\n').trim()),
    })
  }
  return sections
}

const sections = computed(() => parseSections(findMarkdown(props.name)))
</script>

<template>
  <template v-if="sections.length > 0">
    <div v-for="section in sections" :key="section.title" class="card">
      <h2>{{ section.title }}</h2>
      <div class="md-body" v-html="section.html"></div>
    </div>
  </template>
</template>

<style scoped>
.md-body {
  font-size: 13px;
  color: var(--ts);
  line-height: 1.65;
}
.md-body :deep(p) { margin-bottom: 10px; }
.md-body :deep(p:last-child) { margin-bottom: 0; }
.md-body :deep(ul) { padding-left: 22px; margin-bottom: 10px; }
.md-body :deep(li) { margin-bottom: 5px; }
.md-body :deep(li:last-child) { margin-bottom: 0; }
.md-body :deep(strong) { color: var(--tp); font-weight: 600; }
.md-body :deep(em) { font-style: italic; }
.md-body :deep(code) {
  background: var(--card2);
  padding: 1px 5px;
  border-radius: 3px;
  font-family: 'SF Mono', 'Cascadia Mono', monospace;
  font-size: 12px;
  color: var(--tp);
}
.md-body :deep(a) { color: var(--acc); text-decoration: none; }
.md-body :deep(a:hover) { text-decoration: underline; }
.md-body :deep(h3) {
  font-size: 13px;
  font-weight: 600;
  color: var(--tp);
  margin-top: 12px;
  margin-bottom: 6px;
}
</style>
