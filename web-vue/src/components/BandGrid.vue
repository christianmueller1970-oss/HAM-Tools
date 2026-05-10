<script setup>
import { bands, isBandActive } from '../composables/useHam.js'
const props = defineProps({ freq: String })
const emit = defineEmits(['update:freq'])
</script>

<template>
  <div class="card">
    <h2>Band-Schnellwahl</h2>
    <div class="band-grid">
      <button
        v-for="[name, f] in bands"
        :key="name"
        class="bb"
        :class="{ on: isBandActive(props.freq, f) }"
        @click="emit('update:freq', String(f))"
      >{{ name }}</button>
    </div>
  </div>
</template>
