import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  // Vite 8's default target is Safari/iOS 16.4+. Broaden support to older
  // iPhones; the app entry itself avoids top-level await for Safari module-loader compatibility.
  build: { target: 'safari14' },
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) }
  },
  server: {
    host: '0.0.0.0',
    port: 3000,
    strictPort: true,
    allowedHosts: true,
    hmr: { clientPort: 443 }
  }
})
