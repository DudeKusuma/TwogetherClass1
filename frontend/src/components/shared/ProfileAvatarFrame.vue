<script setup>
import { computed } from 'vue'

const props = defineProps({
  frame: { type: String, default: '' },
  size: { type: String, default: 'md' },
  label: { type: String, default: '' }
})

const frameClass = computed(() => props.frame ? `profile-frame--${props.frame}` : '')
const frameLabel = computed(() => ({
  'blueberry-jam': 'Blueberry jam',
  'strawberry-swirl': 'Strawberry swirl',
  'lemon-glaze': 'Lemon glaze'
}[props.frame] || ''))
</script>

<template>
  <span class="profile-frame" :class="[`profile-frame--${size}`, frameClass]" :aria-label="label || (frameLabel ? `${frameLabel} profile border` : undefined)">
    <span class="profile-frame__content"><slot /></span>
    <img v-if="frame" class="profile-frame__art" src="/assets/profile-frames/blueberry-jam.svg?v=2" alt="" aria-hidden="true" />
  </span>
</template>

<style scoped>
.profile-frame{position:relative;isolation:isolate;display:inline-grid;place-items:center;flex:none;aspect-ratio:1;overflow:visible}
.profile-frame--sm{width:42px}.profile-frame--md{width:62px}.profile-frame--lg{width:72px}.profile-frame--discover{width:43px}
.profile-frame__content{position:relative;z-index:0;width:100%;height:100%;display:grid;place-items:center;border-radius:50%;overflow:hidden}
.profile-frame__art{position:absolute;z-index:1;inset:0;width:100%;height:100%;object-fit:contain;transform:scale(1.5);transform-origin:center;pointer-events:none;user-select:none;animation:frame-in 240ms ease-out both}
.profile-frame--sm .profile-frame__art{transform:scale(1.05)}
.profile-frame--strawberry-swirl .profile-frame__art{filter:hue-rotate(82deg) saturate(1.15)}
.profile-frame--lemon-glaze .profile-frame__art{filter:hue-rotate(135deg) saturate(1.25) brightness(1.05)}
@keyframes frame-in{from{opacity:.5}to{opacity:1}}
@media(prefers-reduced-motion:reduce){.profile-frame__art{animation:none}}
</style>
