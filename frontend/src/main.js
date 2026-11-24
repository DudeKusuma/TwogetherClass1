import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { useAuthStore } from './stores/useAuthStore'
import './assets/styles/tokens.css'
import './assets/styles/base.css'

const app = createApp(App)
const pinia = createPinia()
app.use(pinia)

// Avoid top-level await in the app entry module. Safari's module loader has had
// bugs with top-level await in split module graphs; initialize auth before the
// router starts, but do it inside a normal async function instead.
const auth = useAuthStore(pinia)

async function bootstrap() {
  try {
    await auth.initialize()
  } catch (error) {
    console.error('Could not initialize the app:', error)
    auth.authError = error?.message || 'Twogether Class gagal dimuat.'
  }

  app.use(router)
  await router.isReady()
  app.mount('#app')

  if ('serviceWorker' in navigator && import.meta.env.PROD) {
    window.addEventListener('load', () => navigator.serviceWorker.register('/sw.js').catch((error) => console.warn('Service worker registration failed:', error)))
  }
}

void bootstrap().catch((error) => {
  console.error('Could not start Twogether Class:', error)
  const root = document.getElementById('app')
  if (root) root.textContent = 'Twogether Class belum dapat dibuka. Periksa koneksi lalu muat ulang halaman.'
})
