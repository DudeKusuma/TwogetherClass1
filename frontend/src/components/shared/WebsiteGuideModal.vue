<script setup>
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowRight, MousePointer2, MoveDown, X } from 'lucide-vue-next'
import sealStand from '@/assets/mascot/poses/seal-stand.png'
import sealWave from '@/assets/mascot/poses/seal-wave.png'
import sealPoint from '@/assets/mascot/poses/seal-point.png'
import sealFly from '@/assets/mascot/poses/seal-fly.png'

const props = defineProps({ open: { type: Boolean, default: false } })
const emit = defineEmits(['close'])
const route = useRoute()
const router = useRouter()
const started = ref(false)
const index = ref(0)
const target = ref(null)
const box = ref(null)
const viewport = ref({ width: window.innerWidth, height: window.innerHeight })
const hasScrolled = ref(false)
const progressStart = ref(0)
const sealPoses = [sealStand, sealWave, sealPoint, sealFly]
const mascotPose = ref(0)
let refreshTimer
let mascotTimer

const steps = [
  { path: '/', selector: '[data-testid="daily-spotlight"]', title: 'Daily News hari ini', body: 'Di sini ada aktivitas atau kabar harian kelas. Baca pertanyaannya, pilih jawaban atau tulis respons, lalu kirim jika ingin ikut berpartisipasi.', next: 'Lanjut ke jadwal' },
  { path: '/', selector: '[data-testid="home-schedule-section"]', title: 'Jadwal dari beranda', body: 'Bagian ini menampilkan jadwal pelajaran untuk hari ini atau hari sekolah berikutnya. Untuk kalender lengkap dan agenda, klik tombol Jadwal di navigasi.' },
  { path: '/', selector: '[data-testid="nav-schedule"]', title: 'Buka kalender', body: 'Tekan Jadwal untuk melihat kalender kelas, agenda, dan informasi kegiatan.', click: true, pathAfter: '/schedule' },
  { path: '/schedule', selector: '[data-testid="schedule-page"]', title: 'Kalender kelas', body: 'Pilih tanggal untuk melihat agenda. Admin dapat menambahkan agenda; siswa dapat memberi reaksi atau mengajukan perubahan.' },
  { path: '/schedule', selector: '[data-testid="nav-tasks"]', title: 'Buka daftar tugas', body: 'Tekan Tugas untuk melihat pekerjaan berdasarkan mata pelajaran.', click: true, pathAfter: '/tasks' },
  { path: '/tasks', selector: '.subject-task-list', title: 'Tugas per mata pelajaran', body: 'Pilih kartu mata pelajaran untuk membuka tugas dan deadline. Sekarang scroll halaman ke bawah untuk melihat mata pelajaran lainnya.', scroll: true },
  { path: '/tasks', selector: '[data-testid="profile-avatar-button"]', title: 'Menu fitur lainnya', body: 'Tekan avatar profil di kanan atas untuk membuka menu. Dari situ kamu bisa menuju Games, Shop, Uang Kas, Iuran Kelas, dan Profil.', click: true },
  { path: '/tasks', selector: '[data-testid="drawer-games-link"]', title: 'Games kelas', body: 'Tekan Games untuk membuka mini game harian. Permainan tertentu masih dalam proyek dan belum tersedia untuk siswa.', click: true, pathAfter: '/games' },
  { path: '/games', selector: '.games-layout', title: 'Main dan kumpulkan T-Money', body: 'Coba tantangan harian yang tersedia. Jika benar, game tertentu memberi T-Money. Dosman Underground masih belum bisa dimainkan siswa.' },
  { path: '/games', selector: '[data-testid="profile-avatar-button"]', title: 'Buka menu lagi', body: 'Tekan avatar untuk membuka menu fitur dan lanjut ke Reward Shop.', click: true },
  { path: '/games', selector: '[data-testid="drawer-shop-link"]', title: 'Reward Shop', body: 'Tekan Shop untuk melihat warna background profil yang bisa dibuka dengan T-Money.', click: true, pathAfter: '/shop' },
  { path: '/shop', selector: '.shop-layout', title: 'Tukar hadiah', body: 'Beli warna di sini. Setelah terbuka, pilih warnanya lewat Customize Profile; pembelian tidak langsung mengubah warna profil.' },
  { path: '/shop', selector: '[data-testid="profile-avatar-button"]', title: 'Buka menu lagi', body: 'Tekan avatar untuk menuju pembayaran kelas.', click: true },
  { path: '/shop', selector: '[data-testid="drawer-cash-link"]', title: 'Bayar uang kas', body: 'Tekan Uang Kas. Di halaman itu pilih tombol tambah lalu “Bayar uang kas”, isi nominal, pilih QRIS atau tunai, lalu kirim. Pembayaran menunggu persetujuan admin.', click: true, pathAfter: '/cash' },
  { path: '/cash', selector: '.finance-page', title: 'Pantau uang kas', body: 'Cek saldo, riwayat, dan rekap pembayaran per bulan di sini. Admin juga dapat memperbarui status pembayaran.' },
  { path: '/cash', selector: '[data-testid="profile-avatar-button"]', title: 'Buka menu lagi', body: 'Tekan avatar untuk melihat halaman Iuran Kelas.', click: true },
  { path: '/cash', selector: '[data-testid="drawer-contributions-link"]', title: 'Iuran kegiatan', body: 'Tekan Iuran Kelas untuk melihat iuran khusus. Admin dapat membuat iuran dan memperbarui status pembayaran siswa.', click: true, pathAfter: '/contributions' },
  { path: '/contributions', selector: '.contrib-page', title: 'Rekap pembayaran iuran', body: 'Buka detail iuran untuk melihat status tiap siswa. Admin bisa menandai lunas atau belum bayar dan mengedit rincian iuran.' },
  { path: '/contributions', selector: '[data-testid="nav-profile"]', title: 'Edit profil', body: 'Tekan Profil Saya untuk membuka profil. Tekan tombol pensil untuk mengubah nama tampilan, lokasi, deskripsi, dan menyesuaikan tampilannya.', click: true, pathAfter: '/profile' },
  { path: '/profile', selector: '[data-testid="profile-user-card"]', title: 'Profilmu', body: 'Kamu bisa mengedit informasi pribadi lewat tombol pensil dan memilih warna yang sudah dibuka lewat Customize Profile.' }
]

const current = computed(() => steps[index.value])
const tipPosition = computed(() => {
  if (!box.value) return { left: '50%', top: '50%', transform: 'translate(-50%, -50%)' }
  const width = Math.min(390, viewport.value.width - 28)
  const left = Math.max(14, Math.min(box.value.x + box.value.width / 2 - width / 2, viewport.value.width - width - 14))
  const estimatedHeight = 230
  const top = box.value.bottom + estimatedHeight < viewport.value.height - 14
    ? box.value.bottom + 14
    : Math.max(14, box.value.top - estimatedHeight - 14)
  return { left: `${left}px`, top: `${top}px`, width: `${width}px` }
})

function clearTarget() {
  target.value?.classList.remove('guide-focus-target')
  target.value = null
  box.value = null
}

async function refreshTarget() {
  clearTarget()
  if (!props.open || !started.value || !current.value || route.path !== current.value.path) return
  await nextTick()
  const found = document.querySelector(current.value.selector)
  if (!found) return
  target.value = found
  found.classList.add('guide-focus-target')
  const rect = found.getBoundingClientRect()
  const pad = 7
  box.value = { x: rect.left - pad, y: rect.top - pad, top: rect.top - pad, bottom: rect.bottom + pad, width: rect.width + pad * 2, height: rect.height + pad * 2 }
  if (!current.value.scroll && (rect.top < 20 || rect.bottom > window.innerHeight - 24)) {
    found.scrollIntoView({ behavior: 'smooth', block: 'center' })
    setTimeout(() => updateBox(), 240)
  }
}

function updateBox() {
  if (!target.value?.isConnected) { refreshTarget(); return }
  const rect = target.value.getBoundingClientRect()
  const pad = 7
  box.value = { x: rect.left - pad, y: rect.top - pad, top: rect.top - pad, bottom: rect.bottom + pad, width: rect.width + pad * 2, height: rect.height + pad * 2 }
  viewport.value = { width: window.innerWidth, height: window.innerHeight }
}

function beginTour() {
  started.value = true
  index.value = 0
  hasScrolled.value = false
  document.body.classList.add('guide-tour-active')
  if (route.path !== '/') router.push('/')
  refreshTarget()
}

function finish() {
  clearTarget()
  started.value = false
  document.body.classList.remove('guide-tour-active')
  emit('close')
}

function next() {
  if (current.value?.scroll && !hasScrolled.value) return
  if (index.value >= steps.length - 1) { finish(); return }
  index.value++
  hasScrolled.value = false
  progressStart.value = window.scrollY
  refreshTarget()
}

function clickHighlighted() {
  if (target.value) target.value.click()
}

function onTourClick(event) {
  if (!current.value?.click || !target.value?.contains(event.target)) return
  next()
}

function onScroll() {
  updateBox()
  if (current.value?.scroll && Math.abs(window.scrollY - progressStart.value) > 90) hasScrolled.value = true
}

function onResize() {
  viewport.value = { width: window.innerWidth, height: window.innerHeight }
  updateBox()
}

watch(() => props.open, (open) => {
  clearTimeout(refreshTimer)
  clearInterval(mascotTimer)
  clearTarget()
  if (open) {
    started.value = false
    index.value = 0
    hasScrolled.value = false
    mascotPose.value = 0
    mascotTimer = setInterval(() => { mascotPose.value = (mascotPose.value + 1) % sealPoses.length }, 1500)
  } else {
    started.value = false
    document.body.classList.remove('guide-tour-active')
  }
}, { immediate: true })
watch(() => [route.path, index.value, started.value], () => {
  clearTimeout(refreshTimer)
  clearInterval(mascotTimer)
  clearTarget()
  document.body.classList.remove('guide-tour-active')
  refreshTimer = setTimeout(refreshTarget, 80)
})

document.addEventListener('click', onTourClick, true)
window.addEventListener('scroll', onScroll, { passive: true })
window.addEventListener('resize', onResize)
onBeforeUnmount(() => {
  document.removeEventListener('click', onTourClick, true)
  window.removeEventListener('scroll', onScroll)
  window.removeEventListener('resize', onResize)
  clearTimeout(refreshTimer)
  clearTarget()
})
</script>

<template>
  <Teleport to="body">
    <Transition name="guide-fade">
      <div v-if="open && !started" class="guide-welcome-backdrop" role="presentation" @click.self="finish">
        <section class="guide-welcome" role="dialog" aria-modal="true" aria-labelledby="guide-welcome-title">
          <button class="guide-close" aria-label="Tutup panduan" @click="finish"><X :size="18" /></button>
          <Transition name="seal-pose" mode="out-in">
            <img :key="mascotPose" class="guide-welcome-mascot" :src="sealPoses[mascotPose]" alt="Maskot seal Twogether Class" />
          </Transition>
          <span class="guide-eyebrow">KENALAN DENGAN TWogether CLASS</span>
          <h2 id="guide-welcome-title">Ikuti seal, jelajahi fitur kelas!</h2>
          <p>Tur ini akan menyorot tombol dan bagian penting website. Kamu akan diajak klik menu dan mencoba scroll halaman.</p>
          <button class="guide-primary" @click="beginTour">Mulai tur interaktif <ArrowRight :size="17" /></button>
          <button class="guide-skip" @click="finish">Nanti saja</button>
        </section>
      </div>
    </Transition>
    <div v-if="open && started" class="guide-tour-layer">
      <svg class="guide-shade" :viewBox="`0 0 ${viewport.width} ${viewport.height}`" preserveAspectRatio="none" aria-hidden="true">
        <defs><mask id="guide-spotlight-mask"><rect width="100%" height="100%" fill="white"/><rect v-if="box" :x="box.x" :y="box.y" :width="box.width" :height="box.height" rx="16" fill="black"/></mask></defs>
        <rect width="100%" height="100%" fill="rgba(13, 23, 38, .66)" mask="url(#guide-spotlight-mask)" />
      </svg>
      <section v-if="current" class="guide-tip" :style="tipPosition" role="dialog" aria-live="polite">
        <div class="guide-tip-copy">
          <span class="guide-eyebrow">PANDUAN FITUR · {{ index + 1 }}/{{ steps.length }}</span>
          <h2>{{ current.title }}</h2>
          <p>{{ current.body }}</p>
          <p v-if="current.click" class="guide-hint"><MousePointer2 :size="15" /> Klik bagian yang disorot untuk melanjutkan.</p>
          <p v-if="current.scroll" class="guide-hint" :class="{ complete: hasScrolled }"><MoveDown :size="15" /> {{ hasScrolled ? 'Sip, kamu sudah scroll!' : 'Scroll halaman ke bawah untuk melihat konten lainnya.' }}</p>
          <div class="guide-buttons">
            <button class="guide-skip-inline" @click="finish">Lewati tur</button>
            <button v-if="!current.click" class="guide-primary" :disabled="current.scroll && !hasScrolled" @click="next">{{ index === steps.length - 1 ? 'Selesai' : 'Lanjut' }} <ArrowRight :size="16" /></button>
            <button v-else class="guide-primary guide-primary--small" @click="clickHighlighted">Klik yang disorot <ArrowRight :size="16" /></button>
          </div>
        </div>
        <Transition name="seal-pose" mode="out-in">
          <img :key="mascotPose" class="guide-tip-mascot" :src="sealPoses[mascotPose]" alt="Maskot seal Twogether Class" />
        </Transition>
      </section>
    </div>
  </Teleport>
</template>

<style>
.guide-focus-target{position:relative!important;z-index:9000!important;isolation:isolate;outline:3px solid #ffc95d!important;outline-offset:3px;box-shadow:0 0 0 8px #ffc95d55!important;border-radius:15px;transition:outline-color .15s ease}
.guide-tour-active .nav,.guide-tour-active .app-header,.guide-tour-active .drawer{z-index:9000!important}
</style>
<style scoped>
.guide-welcome-backdrop{position:fixed;inset:0;z-index:9100;background:#0d172c9c;backdrop-filter:blur(5px);display:grid;place-items:center;padding:18px}
.guide-welcome{position:relative;width:min(100%,490px);display:grid;justify-items:center;text-align:center;padding:27px 30px 22px;border-radius:28px;background:linear-gradient(160deg,#eef9ff,#fff 56%);border:1px solid #fff;box-shadow:0 28px 90px #0b182e66;color:var(--c-text)}
.guide-close{position:absolute;right:16px;top:16px;width:36px;height:36px;display:grid;place-items:center;border:0;border-radius:50%;background:#fff;color:#627187;box-shadow:0 3px 12px #20344b12}
.guide-welcome-mascot{width:min(100%,290px);height:185px;object-fit:contain;object-position:center;margin:0 0 6px}
.guide-eyebrow{display:inline-block;font-size:9px;letter-spacing:.12em;font-weight:900;color:#3983a8}
.guide-welcome h2{font-size:24px;line-height:1.2;font-weight:900;margin:8px 0}
.guide-welcome>p{max-width:350px;color:#69778b;font-size:13px;line-height:1.65;margin:0 0 18px}
.guide-primary{min-height:42px;padding:0 16px;display:inline-flex;align-items:center;justify-content:center;gap:8px;border:0;border-radius:12px;background:#287fac;color:white;font-size:12px;font-weight:850;box-shadow:0 6px 16px #287fac30}
.guide-primary:disabled{opacity:.5;cursor:not-allowed}
.guide-skip,.guide-skip-inline{border:0;background:none;color:#718095;font-size:11px;font-weight:750;padding:10px}
.guide-tour-layer{position:fixed;inset:0;z-index:9100;pointer-events:none}
.guide-shade{position:absolute;inset:0;width:100%;height:100%;pointer-events:none}
.guide-tip{position:fixed;pointer-events:auto;z-index:9102;display:flex;align-items:center;gap:5px;padding:17px 14px 15px 17px;border:1px solid #e4ebf3;border-radius:20px;background:linear-gradient(145deg,#fff 65%,#f3faff);box-shadow:0 16px 50px #091a2c3d;color:var(--c-text);animation:tip-pop .2s ease-out}
.guide-tip-copy{flex:1;min-width:0}.guide-tip h2{font-size:16px;line-height:1.25;font-weight:900;margin:5px 0 7px}.guide-tip p{font-size:11px;line-height:1.6;color:#637286;margin:0}.guide-hint{display:flex;align-items:center;gap:6px;margin-top:10px!important;color:#33799d!important;font-weight:800}.guide-hint.complete{color:#15824f!important}
.guide-tip-mascot{width:104px;height:126px;flex:none;object-fit:contain;object-position:center;align-self:flex-end}
.guide-buttons{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:12px}.guide-primary--small{min-height:36px;padding:0 11px;font-size:11px}.guide-skip-inline{padding:8px 4px}
.guide-fade-enter-active,.guide-fade-leave-active{transition:opacity .18s ease}.guide-fade-enter-from,.guide-fade-leave-to{opacity:0}
.seal-pose-enter-active,.seal-pose-leave-active{transition:opacity .22s ease,transform .22s ease}
.seal-pose-enter-from{opacity:0;transform:translateY(5px) scale(.97)}
.seal-pose-leave-to{opacity:0;transform:translateY(-5px) scale(.97)}
@keyframes seal-bob{0%,100%{transform:translateY(0)}50%{transform:translateY(-5px)}}
@keyframes tip-pop{from{opacity:0;transform:translateY(6px) scale(.985)}to{opacity:1;transform:translateY(0) scale(1)}}
@media(max-width:560px){.guide-welcome{padding:24px 20px 18px}.guide-welcome-mascot{height:150px;width:260px}.guide-welcome h2{font-size:21px}.guide-tip{gap:0;padding:14px 12px 12px 14px;border-radius:17px}.guide-tip-mascot{width:76px;height:104px;margin-right:-4px}.guide-tip h2{font-size:14px}.guide-tip p{font-size:10px}.guide-eyebrow{font-size:8px}.guide-buttons{margin-top:8px}.guide-primary--small{min-height:32px;padding:0 8px}}
@media(prefers-reduced-motion:reduce){.seal-pose-enter-active,.seal-pose-leave-active{transition:none}.guide-tip{animation:none}}
</style>
