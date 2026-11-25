<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import AppHeader from '@/components/layout/AppHeader.vue'
import AppFooter from '@/components/layout/AppFooter.vue'
import CalendarPendingAlert from '@/components/calendar/CalendarPendingAlert.vue'
import WebsiteGuideModal from '@/components/shared/WebsiteGuideModal.vue'
import { useAuthStore } from '@/stores/useAuthStore'

const route = useRoute()
const auth = useAuthStore()
const showShell = computed(() => auth.isAuthenticated && route.meta.layout !== 'blank' && !route.meta.fullscreen)
const guideOpen = ref(false)
const guideKey = (id) => `twogether-guide-seen:${id}`

function openGuide() { guideOpen.value = true }
function closeGuide() {
  guideOpen.value = false
  if (auth.user?.id) {
    try { localStorage.setItem(guideKey(auth.user.id), '1') } catch { /* Storage may be unavailable in private browsing. */ }
  }
}

watch(() => auth.user?.id, (id) => {
  if (!id) { guideOpen.value = false; return }
  try { guideOpen.value = localStorage.getItem(guideKey(id)) !== '1' }
  catch { guideOpen.value = false }
}, { immediate: true })

onMounted(() => window.addEventListener('twogether:open-guide', openGuide))
onBeforeUnmount(() => window.removeEventListener('twogether:open-guide', openGuide))
</script>

<template>
  <div v-if="showShell" class="app-shell">
    <AppHeader />
    <AppFooter />
    <main class="app-main" data-testid="app-main">
      <RouterView />
    </main>
    <CalendarPendingAlert />
    <WebsiteGuideModal :open="guideOpen" @close="closeGuide" />
  </div>
  <RouterView v-else />
</template>

<style scoped>
.app-shell {
  min-height: 100vh;
}

.app-main {
  width: 100%;
  max-width: var(--content-max);
  margin: 0 auto;
  padding: var(--space-5) var(--space-4) calc(var(--nav-h) + var(--space-8) + env(safe-area-inset-bottom));
}

@media (min-width: 768px) {
  .app-main {
    padding-left: var(--space-6);
    padding-right: var(--space-6);
  }
}

@media (min-width: 1024px) {
  .app-shell {
    padding-left: var(--rail-w);
  }
  .app-main {
    padding: var(--space-6) var(--space-7) var(--space-8);
  }
}
</style>
