<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { UserRound, Save, Heart, Sparkles, LockKeyhole, CheckCircle2, Coins, Pencil, Palette, X, Check, Camera } from 'lucide-vue-next'
import BaseCard from '@/components/base/BaseCard.vue'
import PagePlaceholder from '@/components/shared/PagePlaceholder.vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/useAuthStore'
import ProfileAvatarFrame from '@/components/shared/ProfileAvatarFrame.vue'
import { getProfilePhotoUrl } from '@/lib/profilePhotos'

const auth = useAuthStore()
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const success = ref('')
const fullName = ref('')
const studentNumber = ref('')
const attendanceNumber = ref(null)
const adminOnly = ref(false)
const cosmetics = ref({})
const backgroundOptions = ref([])
const ownedBackgrounds = ref([])
const frameOptions = ref([])
const ownedFrames = ref([])
const editorOpen = ref(false)
const customizeOpen = ref(false)
const customizing = ref(false)
const tMoney = ref(null)
const avatarPhotoPath = ref('')
const avatarPhotoUrl = ref('')
const avatarPreview = ref('')
const avatarSourceUrl = ref('')
const avatarCropImage = ref(null)
const avatarCropOpen = ref(false)
const avatarCropZoom = ref(1)
const avatarCropOffset = ref({ x: 0, y: 0 })
const avatarCropDrag = ref(null)
const avatarFile = ref(null)
const avatarFileInput = ref(null)
const avatarUploading = ref(false)
const form = ref({
  short_name: '',
  birth_place: '',
  birth_date: '',
  gender: '',
  address: '',
  description: '',
  hobbies: [],
  about_me: [],
  show_student_number: false,
  discover_opt_in: true
})

const hobbyOptions = [
  '🎧 Music', '🎮 Gaming', '🏀 Basketball', '🎬 Movies', '📚 Comics',
  '📖 Reading', '📷 Photography', '🎨 Drawing', '⚽ Football',
  '🏸 Badminton', '🎤 Singing', '💃 Dancing', '💻 Coding',
  '🧑‍🍳 Cooking', '✈️ Traveling', '🐱 Pets'
]
const aboutOptions = [
  '😆 Funny', '💗 Romantic', '😎 Chill', '🎨 Creative', '🤫 Quiet',
  '⚡ Energetic', '🌻 Cheerful', '🧠 Curious', '🤝 Friendly',
  '🎯 Ambitious', '🥹 Sensitive', '🦉 Introvert', '🎉 Extrovert', '🤍 Caring'
]
const initial = computed(() => (form.value.short_name || auth.user?.displayName || 'S').trim().charAt(0).toUpperCase())
const orderedBackgrounds = computed(() => backgroundOptions.value
  .map(item => ({ ...item, owned: ownedBackgrounds.value.includes(item.id) }))
  .sort((a, b) => Number(b.owned) - Number(a.owned) || a.price - b.price))

function toggleChoice(key, value, limit) {
  const values = form.value[key]
  if (values.includes(value)) form.value[key] = values.filter(item => item !== value)
  else if (values.length < limit) form.value[key] = [...values, value]
}

async function loadProfile() {
  loading.value = true
  error.value = ''
  adminOnly.value = false
  const [cosmeticResult, walletResult, backgroundsResult, purchasesResult, framesResult] = await Promise.all([
    supabase.from('student_cosmetics').select('profile_color,name_color,title_color,profile_frame').eq('profile_id', auth.user.id).maybeSingle(),
    supabase.rpc('get_my_t_money'),
    supabase.from('shop_catalog').select('id,name,description,price,preview_color').eq('active', true).eq('category', 'profile_color'),
    supabase.from('shop_purchases').select('item_id').eq('user_id', auth.user.id),
    supabase.from('shop_catalog').select('id,name,description,price').eq('active', true).eq('category', 'profile_frame').order('price')
  ])
  cosmetics.value = cosmeticResult.data || {}
  auth.user.profileFrame = cosmeticResult.data?.profile_frame || null
  tMoney.value = walletResult.error ? null : (walletResult.data?.balance ?? 0)
  backgroundOptions.value = backgroundsResult.data || []
  ownedBackgrounds.value = (purchasesResult.data || []).map(item => item.item_id)
  frameOptions.value = framesResult.data || []
  ownedFrames.value = ownedBackgrounds.value.filter(id => id.startsWith('frame-')).map(id => id.slice('frame-'.length))
  const { data, error: requestError } = await supabase.rpc('get_student_profile', {
    target_profile_id: auth.user.id
  })
  if (requestError) {
    error.value = 'Profil belum dapat dimuat. Jalankan migration Student Profile di Supabase terlebih dahulu.'
  } else if (!data && auth.isAdmin) {
    adminOnly.value = true
  } else if (!data) {
    error.value = 'Akun ini belum terhubung ke data siswa di roster kelas. Minta admin menghubungkan akun terlebih dahulu.'
  } else {
    fullName.value = data.full_name || ''
    studentNumber.value = data.student_number || ''
    attendanceNumber.value = data.attendance_number ?? null
    if (data.short_name) auth.user.displayName = data.short_name
    avatarPhotoPath.value = data.photo_path || ''
    avatarPhotoUrl.value = await getProfilePhotoUrl(data.photo_path)
    auth.user.profilePhotoPath = avatarPhotoPath.value || null
    auth.user.profilePhotoUrl = avatarPhotoUrl.value
    form.value = {
      short_name: data.short_name === data.full_name ? '' : (data.short_name || ''),
      birth_place: data.birth_place || '',
      birth_date: data.birth_date || '',
      gender: data.gender || '',
      address: data.address || '',
      description: data.description || '',
      hobbies: Array.isArray(data.hobbies) ? data.hobbies : [],
      about_me: Array.isArray(data.about_me) ? data.about_me : [],
      show_student_number: data.show_student_number === true,
      discover_opt_in: data.discover_opt_in !== false
    }
  }
  loading.value = false
}

function selectAvatarFile(event) {
  error.value = ''
  success.value = ''
  const file = event.target.files?.[0]
  if (!file) return
  const allowedTypes = ['image/jpeg', 'image/png', 'image/webp']
  if (!allowedTypes.includes(file.type)) {
    error.value = 'Pilih foto JPG, PNG, atau WebP.'
    event.target.value = ''
    return
  }
  if (file.size > 5 * 1024 * 1024) {
    error.value = 'Ukuran foto maksimal 5 MB.'
    event.target.value = ''
    return
  }
  if (avatarPreview.value) URL.revokeObjectURL(avatarPreview.value)
  if (avatarSourceUrl.value) URL.revokeObjectURL(avatarSourceUrl.value)
  avatarFile.value = file
  avatarPreview.value = ''
  avatarSourceUrl.value = URL.createObjectURL(file)
  avatarCropImage.value = new Image()
  avatarCropImage.value.onload = () => {
    avatarCropZoom.value = 1
    avatarCropOffset.value = { x: 0, y: 0 }
    avatarCropOpen.value = true
  }
  avatarCropImage.value.onerror = () => { error.value = 'Foto tidak dapat dibuka. Coba pilih file lain.' }
  avatarCropImage.value.src = avatarSourceUrl.value
}

const cropImageStyle = computed(() => {
  const image = avatarCropImage.value
  if (!image?.naturalWidth || !image?.naturalHeight) return {}
  const scale = Math.max(240 / image.naturalWidth, 240 / image.naturalHeight) * avatarCropZoom.value
  return {
    width: `${image.naturalWidth * scale}px`,
    height: `${image.naturalHeight * scale}px`,
    left: `calc(50% + ${avatarCropOffset.value.x}px)`,
    top: `calc(50% + ${avatarCropOffset.value.y}px)`
  }
})

function startCropDrag(event) {
  if (event.button !== undefined && event.button !== 0) return
  avatarCropDrag.value = { pointerId: event.pointerId, x: event.clientX, y: event.clientY, offset: { ...avatarCropOffset.value } }
  event.currentTarget.setPointerCapture?.(event.pointerId)
}

function moveCropDrag(event) {
  if (!avatarCropDrag.value) return
  const next = {
    x: avatarCropDrag.value.offset.x + event.clientX - avatarCropDrag.value.x,
    y: avatarCropDrag.value.offset.y + event.clientY - avatarCropDrag.value.y
  }
  avatarCropOffset.value = clampCropOffset(next)
}

function stopCropDrag() { avatarCropDrag.value = null }

function clampCropOffset(offset) {
  const image = avatarCropImage.value
  if (!image?.naturalWidth || !image?.naturalHeight) return offset
  const scale = Math.max(240 / image.naturalWidth, 240 / image.naturalHeight) * avatarCropZoom.value
  const maxX = Math.max(0, (image.naturalWidth * scale - 240) / 2)
  const maxY = Math.max(0, (image.naturalHeight * scale - 240) / 2)
  return { x: Math.min(maxX, Math.max(-maxX, offset.x)), y: Math.min(maxY, Math.max(-maxY, offset.y)) }
}

function updateCropZoom(event) {
  avatarCropZoom.value = Number(event.target.value)
  avatarCropOffset.value = clampCropOffset(avatarCropOffset.value)
}

function applyAvatarCrop() {
  const image = avatarCropImage.value
  if (!image?.naturalWidth || !image?.naturalHeight) return
  const stageSize = 240
  const scale = Math.max(stageSize / image.naturalWidth, stageSize / image.naturalHeight) * avatarCropZoom.value
  const renderedWidth = image.naturalWidth * scale
  const renderedHeight = image.naturalHeight * scale
  const left = (stageSize - renderedWidth) / 2 + avatarCropOffset.value.x
  const top = (stageSize - renderedHeight) / 2 + avatarCropOffset.value.y
  const sourceX = Math.max(0, -left / scale)
  const sourceY = Math.max(0, -top / scale)
  const sourceSize = Math.min(stageSize / scale, image.naturalWidth - sourceX, image.naturalHeight - sourceY)
  const canvas = document.createElement('canvas')
  canvas.width = 512
  canvas.height = 512
  const context = canvas.getContext('2d')
  if (!context || sourceSize <= 0) return
  context.drawImage(image, sourceX, sourceY, sourceSize, sourceSize, 0, 0, 512, 512)
  canvas.toBlob(blob => {
    if (!blob) {
      error.value = 'Foto belum dapat diproses. Coba pilih foto lain.'
      return
    }
    if (avatarPreview.value) URL.revokeObjectURL(avatarPreview.value)
    avatarFile.value = new File([blob], 'avatar.jpg', { type: 'image/jpeg' })
    avatarPreview.value = URL.createObjectURL(blob)
    avatarCropOpen.value = false
  }, 'image/jpeg', 0.92)
}

function cancelAvatarCrop() {
  avatarCropOpen.value = false
  avatarFile.value = null
  if (avatarSourceUrl.value) URL.revokeObjectURL(avatarSourceUrl.value)
  avatarSourceUrl.value = ''
  avatarCropImage.value = null
  if (avatarFileInput.value) avatarFileInput.value.value = ''
}

async function uploadAvatar() {
  const file = avatarFile.value
  if (!file || avatarUploading.value) return
  error.value = ''
  success.value = ''
  avatarUploading.value = true
  const photoPath = `${auth.user.id}/avatar`
  const { error: uploadError } = await supabase.storage
    .from('profile-avatars')
    .upload(photoPath, file, { upsert: true, contentType: file.type, cacheControl: '0' })
  if (uploadError) {
    error.value = 'Foto belum berhasil diunggah. Coba lagi.'
    avatarUploading.value = false
    return
  }
  const { error: saveError } = await supabase.from('student_profile_details').upsert({
    profile_id: auth.user.id,
    photo_path: photoPath,
    updated_at: new Date().toISOString()
  }, { onConflict: 'profile_id' })
  if (saveError) {
    error.value = 'Foto sudah diunggah, tetapi profil belum berhasil diperbarui.'
    avatarUploading.value = false
    return
  }
  avatarPhotoPath.value = photoPath
  avatarPhotoUrl.value = await getProfilePhotoUrl(photoPath)
  auth.user.profilePhotoPath = photoPath
  auth.user.profilePhotoUrl = avatarPhotoUrl.value
  if (avatarPreview.value) URL.revokeObjectURL(avatarPreview.value)
  if (avatarSourceUrl.value) URL.revokeObjectURL(avatarSourceUrl.value)
  avatarSourceUrl.value = ''
  avatarCropImage.value = null
  avatarPreview.value = ''
  avatarFile.value = null
  if (avatarFileInput.value) avatarFileInput.value.value = ''
  success.value = 'Foto profil berhasil diperbarui.'
  avatarUploading.value = false
}

onBeforeUnmount(() => {
  if (avatarPreview.value) URL.revokeObjectURL(avatarPreview.value)
  if (avatarSourceUrl.value) URL.revokeObjectURL(avatarSourceUrl.value)
})

async function saveProfile() {
  error.value = ''
  success.value = ''
  if (form.value.short_name.trim().length > 40) {
    error.value = 'Nama pendek maksimal 40 karakter.'
    return
  }
  if (form.value.hobbies.length > 8 || form.value.about_me.length > 6) {
    error.value = 'Pilihan hobi maksimal 8 dan About Me maksimal 6.'
    return
  }
  saving.value = true
  const payload = {
    profile_id: auth.user.id,
    short_name: form.value.short_name.trim(),
    birth_place: form.value.birth_place.trim(),
    birth_date: form.value.birth_date || null,
    gender: form.value.gender || null,
    address: form.value.address.trim(),
    description: form.value.description.trim(),
    hobbies: form.value.hobbies,
    about_me: form.value.about_me,
    show_student_number: form.value.show_student_number,
    discover_opt_in: form.value.discover_opt_in,
    updated_at: new Date().toISOString()
  }
  const { error: saveError } = await supabase
    .from('student_profile_details')
    .upsert(payload, { onConflict: 'profile_id' })
  if (saveError) {
    error.value = saveError.message
  } else {
    const { data } = await supabase.rpc('get_student_profile', {
      target_profile_id: auth.user.id
    })
    if (data?.short_name) auth.user.displayName = data.short_name
    success.value = 'Profil berhasil disimpan.'
    editorOpen.value = false
  }
  saving.value = false
}

async function equipBackground(item) {
  if (!item.owned || customizing.value) return
  customizing.value = true
  error.value = ''
  const { error: equipError } = await supabase.rpc('equip_shop_item', { p_item_id: item.id })
  if (equipError) error.value = 'Warna belum berhasil dipasang.'
  else cosmetics.value = { ...cosmetics.value, profile_color: item.preview_color }
  customizing.value = false
}

async function useDefaultBackground() {
  if (customizing.value) return
  customizing.value = true
  error.value = ''
  const { error: resetError } = await supabase.rpc('set_default_profile_background')
  if (resetError) error.value = 'Background putih belum berhasil dipasang.'
  else cosmetics.value = { ...cosmetics.value, profile_color: null }
  customizing.value = false
}

async function equipFrame(frame) {
  if (customizing.value || cosmetics.value.profile_frame === frame) return
  if (frame && !ownedFrames.value.includes(frame)) return
  customizing.value = true
  error.value = ''
  const { error: equipError } = await supabase.rpc('equip_profile_frame', { p_frame_id: frame })
  if (equipError) error.value = 'Border profil belum berhasil dipasang. Pastikan migration border profil sudah dijalankan.'
  else {
    cosmetics.value = { ...cosmetics.value, profile_frame: frame }
    auth.user.profileFrame = frame
  }
  customizing.value = false
}

onMounted(loadProfile)
</script>

<template>
  <PagePlaceholder eyebrow="Profil Saya" title="Profil Saya" :icon="UserRound" tone="lavender" test-id="profile-page">
    <div class="profile-page-content">
      <BaseCard class="profile-identity" data-testid="profile-user-card" :style="cosmetics.profile_color ? { backgroundColor: cosmetics.profile_color } : {}">
        <ProfileAvatarFrame :frame="cosmetics.profile_frame" :photo="avatarPhotoUrl" size="md"><span class="profile-avatar">{{ initial }}</span></ProfileAvatarFrame>
        <div class="profile-identity__text">
          <h2 data-testid="profile-display-name" :style="cosmetics.name_color ? { color: cosmetics.name_color } : {}">{{ form.short_name || auth.user?.displayName || 'Profil Siswa' }}</h2>
          <p :style="cosmetics.title_color ? { color: cosmetics.title_color } : {}">{{ auth.roleLabel }} · XI-B2 · SMA Negeri 1 Gianyar</p>
          <small>{{ form.address || 'Lokasi belum diisi' }}</small>
        </div>
        <div class="profile-wallet"><span><Coins :size="17" /> T-Money</span><strong>{{ tMoney === null ? 'Belum tersedia' : tMoney.toLocaleString('id-ID') }}</strong></div>
        <div class="profile-card-actions">
          <button type="button" aria-label="Edit profil" @click="editorOpen = true"><Pencil :size="16"/> Edit Profil</button>
          <button type="button" @click="customizeOpen = true"><Palette :size="16"/> Customize Profile</button>
        </div>
      </BaseCard>

      <p v-if="error" class="profile-message profile-message--error" role="alert">{{ error }}</p>
      <p v-if="success" class="profile-message profile-message--success"><CheckCircle2 :size="16"/> {{ success }}</p>
      <div v-if="loading" class="profile-loading">Memuat informasi profil...</div>
      <BaseCard v-else-if="adminOnly" class="profile-section">
        <h3>Profil Admin</h3>
        <p class="section-note">{{ auth.user?.displayName }} · {{ auth.roleLabel }} · XI-B2</p>
        <p class="section-note">Pengaturan profil siswa tersedia untuk akun yang terhubung ke roster kelas.</p>
      </BaseCard>

      <template v-else-if="!error">
        <BaseCard class="profile-section profile-summary">
          <div class="profile-section__heading"><div><span class="section-kicker">PROFIL SISWA</span><h3>Informasi Saya</h3></div><LockKeyhole :size="18"/></div>
          <div class="readonly-grid">
            <label><span>Nama lengkap</span><input :value="fullName || 'Belum tersedia'" disabled /></label>
            <label><span>Nomor absen</span><input :value="attendanceNumber ?? 'Belum tersedia'" disabled /></label>
            <label><span>Tempat lahir</span><input :value="form.birth_place || 'Belum diisi'" disabled /></label>
            <label><span>Lokasi / alamat</span><input :value="form.address || 'Belum diisi'" disabled /></label>
          </div>
          <div class="summary-description"><b>Deskripsi</b><p>{{ form.description || 'Belum menulis deskripsi.' }}</p></div>
        </BaseCard>
      </template>
    </div>

    <Teleport to="body">
      <div v-if="editorOpen" class="profile-modal-backdrop" @click.self="editorOpen = false">
        <section class="profile-modal" role="dialog" aria-modal="true" aria-label="Edit profil siswa">
          <header class="profile-modal__header"><div><span class="section-kicker">EDIT PROFIL</span><h2>Informasi & preferensi</h2></div><button class="modal-close" aria-label="Tutup" @click="editorOpen = false"><X :size="19"/></button></header>
          <div class="profile-modal__body">
            <BaseCard class="profile-section"><div class="profile-section__heading"><div><span class="section-kicker">IDENTITAS</span><h3>Basic Information</h3></div><LockKeyhole :size="18"/></div><p class="section-note">Nama lengkap, NISN, dan nomor absen dikelola admin.</p><div class="readonly-grid"><label><span>Nama lengkap</span><input :value="fullName || 'Belum tersedia'" disabled /></label><label><span>NISN</span><input :value="studentNumber || 'Belum tersedia'" disabled /></label><label><span>Nomor absen</span><input :value="attendanceNumber ?? 'Belum tersedia'" disabled /></label></div><div class="profile-fields"><label>Nama panggilan / nama tampilan<input v-model="form.short_name" maxlength="40" placeholder="Contoh: Alex"/></label><label>Tempat lahir<input v-model="form.birth_place" maxlength="80" placeholder="Contoh: Denpasar"/></label><label>Tanggal lahir<input v-model="form.birth_date" type="date"/></label><label>Jenis kelamin<select v-model="form.gender"><option value="">Pilih (opsional)</option><option value="L">Laki-laki</option><option value="P">Perempuan</option><option value="Prefer not to say">Tidak ingin menyebutkan</option></select></label><label class="field-full">Alamat tempat tinggal<textarea v-model="form.address" maxlength="180" rows="2" placeholder="Contoh: Gianyar, Bali"/></label></div></BaseCard>
            <BaseCard class="profile-section"><div class="profile-section__heading"><div><span class="section-kicker">MINAT</span><h3><Heart :size="17"/> My Hobbies</h3></div><span class="selection-count">{{ form.hobbies.length }}/8</span></div><p class="section-note">Maksimal 8 pilihan.</p><div class="choice-grid"><button v-for="item in hobbyOptions" :key="item" type="button" :class="{ selected: form.hobbies.includes(item) }" @click="toggleChoice('hobbies', item, 8)">{{ item }}</button></div></BaseCard>
            <BaseCard class="profile-section"><div class="profile-section__heading"><div><span class="section-kicker">TENTANG SAYA</span><h3><Sparkles :size="17"/> About Me</h3></div><span class="selection-count">{{ form.about_me.length }}/6</span></div><p class="section-note">Maksimal 6 pilihan.</p><div class="choice-grid"><button v-for="item in aboutOptions" :key="item" type="button" :class="{ selected: form.about_me.includes(item) }" @click="toggleChoice('about_me', item, 6)">{{ item }}</button></div></BaseCard>
            <BaseCard class="profile-section"><div class="profile-section__heading"><div><span class="section-kicker">DESKRIPSI</span><h3>Deskripsi diri</h3></div><span class="selection-count">{{ form.description.length }}/1000</span></div><textarea v-model="form.description" class="description-input" maxlength="1000" rows="5" placeholder="Tulis deskripsi tentang dirimu..." /></BaseCard>
            <BaseCard class="profile-section"><div class="profile-section__heading"><div><span class="section-kicker">PRIVASI</span><h3>Pengaturan profil</h3></div><LockKeyhole :size="18"/></div><label class="privacy-toggle"><span><b>Tampilkan NISN ke siswa lain</b><small>NISN hanya terlihat di Discover jika dua izin ini aktif.</small></span><input v-model="form.show_student_number" type="checkbox"/></label><label class="privacy-toggle"><span><b>Izinkan profil tampil di Discover Students</b><small>Informasi profil, deskripsi, warna background, dan border ditampilkan ke siswa lain. Saldo T-Money juga akan terlihat di profil Discover.</small></span><input v-model="form.discover_opt_in" type="checkbox"/></label></BaseCard>
            <p v-if="error" class="profile-message profile-message--error" role="alert">{{ error }}</p>
            <button class="profile-save" type="button" :disabled="saving" @click="saveProfile"><Save :size="17"/> {{ saving ? 'Menyimpan...' : 'Simpan perubahan' }}</button>
          </div>
        </section>
      </div>
      <div v-if="customizeOpen" class="profile-modal-backdrop" @click.self="customizeOpen = false">
        <section class="profile-modal customize-modal" role="dialog" aria-modal="true" aria-label="Customize profile">
          <header class="profile-modal__header"><div><span class="section-kicker">CUSTOMIZE PROFILE</span><h2>Border dan background profil</h2></div><button class="modal-close" aria-label="Tutup" @click="customizeOpen = false"><X :size="19"/></button></header>
          <section class="avatar-upload">
            <ProfileAvatarFrame :frame="cosmetics.profile_frame" :photo="avatarPreview || avatarPhotoUrl" size="md"><span class="profile-avatar">{{ initial }}</span></ProfileAvatarFrame>
            <div class="avatar-upload__info"><b>Foto profil</b><small>JPG, PNG, atau WebP · maksimal 5 MB. Foto terlihat oleh anggota kelas yang bisa melihat profilmu.</small><div class="avatar-upload__actions"><button type="button" @click="avatarFileInput?.click()"><Camera :size="15"/> {{ avatarFile ? 'Ganti pilihan' : 'Pilih foto' }}</button><button type="button" :disabled="!avatarFile || avatarUploading" @click="uploadAvatar">{{ avatarUploading ? 'Mengunggah…' : 'Simpan foto' }}</button></div><input ref="avatarFileInput" class="avatar-file-input" type="file" accept="image/jpeg,image/png,image/webp" @change="selectAvatarFile" /></div>
          </section>
          <h3 class="section-note">Pilih border avatar</h3>
          <div class="frame-options">
            <button type="button" class="frame-option" :class="{ selected: !cosmetics.profile_frame }" :disabled="customizing" @click="equipFrame(null)">
              <ProfileAvatarFrame size="sm"><span class="frame-option__initial">A</span></ProfileAvatarFrame>
              <span><b>Tanpa border</b><small>{{ !cosmetics.profile_frame ? 'Sedang digunakan' : 'Gunakan tanpa border' }}</small></span>
              <Check v-if="!cosmetics.profile_frame" :size="17" class="frame-option__check" />
            </button>
            <button v-for="frame in frameOptions" :key="frame.id" type="button" class="frame-option" :class="{ selected: cosmetics.profile_frame === frame.id.slice('frame-'.length), locked: !ownedFrames.includes(frame.id.slice('frame-'.length)) }" :disabled="customizing || !ownedFrames.includes(frame.id.slice('frame-'.length))" @click="equipFrame(frame.id.slice('frame-'.length))">
              <ProfileAvatarFrame :frame="frame.id.slice('frame-'.length)" size="sm"><span class="frame-option__initial">A</span></ProfileAvatarFrame>
              <span><b>{{ frame.name }}</b><small>{{ !ownedFrames.includes(frame.id.slice('frame-'.length)) ? `Terkunci · beli ${frame.price} T-Money di Shop` : (cosmetics.profile_frame === frame.id.slice('frame-'.length) ? 'Sedang digunakan' : 'Sudah dibeli · gunakan border ini') }}</small></span>
              <Check v-if="cosmetics.profile_frame === frame.id.slice('frame-'.length)" :size="17" class="frame-option__check" />
              <LockKeyhole v-else-if="!ownedFrames.includes(frame.id.slice('frame-'.length))" :size="16" class="frame-option__check" />
            </button>
            <p v-if="!frameOptions.length" class="section-note">Border profil belum tersedia di Shop.</p>
          </div>
          <h3 class="section-note">Warna background profil</h3>
          <p class="section-note">Border dan warna yang sudah dibeli bisa dipasang di sini. Beli item baru lewat Reward Shop.</p>
          <div class="background-options"><button type="button" class="background-option" :class="{ selected: !cosmetics.profile_color }" :disabled="customizing" @click="useDefaultBackground"><span class="background-swatch background-swatch--default"><Check v-if="!cosmetics.profile_color" :size="18"/></span><span class="background-option__text"><b>Default · Putih</b><small>{{ cosmetics.profile_color ? 'Gunakan background putih' : 'Sedang digunakan' }}</small></span></button><button v-for="item in orderedBackgrounds" :key="item.id" type="button" class="background-option" :class="{ locked: !item.owned, selected: cosmetics.profile_color === item.preview_color }" :disabled="!item.owned || customizing" @click="equipBackground(item)"><span class="background-swatch" :style="{ backgroundColor: item.preview_color }"><LockKeyhole v-if="!item.owned" :size="16"/><Check v-else-if="cosmetics.profile_color === item.preview_color" :size="18"/></span><span class="background-option__text"><b>{{ item.name }}</b><small>{{ item.owned ? (cosmetics.profile_color === item.preview_color ? 'Sedang digunakan' : 'Sudah dibuka · gunakan') : 'Terkunci · buka di Reward Shop' }}</small></span><LockKeyhole v-if="!item.owned" :size="16" class="option-lock"/></button><p v-if="!backgroundOptions.length" class="section-note">Katalog warna belum tersedia. Admin perlu menerapkan migration Reward Shop.</p></div>
          <p v-if="error" class="profile-message profile-message--error" role="alert">{{ error }}</p>
          <RouterLink class="shop-link" to="/shop" @click="customizeOpen = false">Buka Reward Shop</RouterLink>
        </section>
      </div>
      <div v-if="avatarCropOpen" class="profile-modal-backdrop avatar-crop-backdrop" @click.self="cancelAvatarCrop">
        <section class="profile-modal avatar-crop-modal" role="dialog" aria-modal="true" aria-label="Potong foto profil">
          <header class="profile-modal__header"><div><span class="section-kicker">FOTO PROFIL</span><h2>Atur potongan foto</h2></div><button class="modal-close" aria-label="Batal crop" @click="cancelAvatarCrop"><X :size="19"/></button></header>
          <p class="section-note">Geser foto agar posisinya pas di dalam lingkaran.</p>
          <div class="avatar-crop-stage" @pointerdown="startCropDrag" @pointermove="moveCropDrag" @pointerup="stopCropDrag" @pointercancel="stopCropDrag" @lostpointercapture="stopCropDrag">
            <img :src="avatarSourceUrl" :style="cropImageStyle" alt="Pratinjau potongan foto" draggable="false" />
            <span class="avatar-crop-mask" aria-hidden="true"></span>
          </div>
          <label class="avatar-crop-zoom">Zoom <input type="range" min="1" max="3" step="0.01" :value="avatarCropZoom" @input="updateCropZoom" /></label>
          <div class="avatar-crop-actions"><button type="button" @click="cancelAvatarCrop">Batal</button><button type="button" @click="applyAvatarCrop"><Check :size="16"/> Gunakan foto</button></div>
        </section>
      </div>
    </Teleport>
  </PagePlaceholder>
</template>

<style scoped>
.profile-page-content{display:grid;gap:14px}
.profile-identity{display:flex;align-items:center;gap:14px;flex-wrap:wrap}
.profile-avatar{width:62px;height:62px;border-radius:50%;display:grid;place-items:center;flex-shrink:0;background:#ffffffb8;color:#3b4658;font-size:25px;font-weight:850}
.profile-card-actions{display:flex;gap:8px;flex-wrap:wrap;width:100%;justify-content:flex-end}.profile-card-actions button{display:flex;align-items:center;gap:7px;border:1px solid #ffffff99;border-radius:11px;padding:9px 12px;background:#ffffffb8;color:var(--c-text);font:inherit;font-size:11px;font-weight:800}
.profile-identity__text{min-width:0;flex:1}
.profile-wallet{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:10px 12px;border-radius:12px;background:#f6f2ff;color:#7655b5;min-width:145px}.profile-wallet span{display:flex;align-items:center;gap:6px;font-size:11px;font-weight:800}.profile-wallet strong{font-size:17px;font-weight:900}
.profile-identity__text h2{font-size:18px;font-weight:850}
.profile-identity__text p{font-size:12px;color:var(--c-text-muted);margin-top:4px}
.profile-identity__text small{font-size:10px;color:var(--c-text-soft);display:block;margin-top:5px}
.profile-section{display:grid;gap:14px}
.profile-section__heading{display:flex;align-items:center;justify-content:space-between;gap:10px}
.profile-section__heading>svg{color:var(--c-primary)}
.profile-section__heading h3{display:flex;align-items:center;gap:7px;font-size:16px;font-weight:850;margin-top:4px}
.section-kicker{font-size:9px;font-weight:850;letter-spacing:.1em;color:var(--c-text-muted)}
.section-note{font-size:11px;color:var(--c-text-muted);line-height:1.5}
.readonly-grid,.profile-fields{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}
.profile-fields label,.readonly-grid label{display:grid;gap:6px;font-size:11px;font-weight:750;color:var(--c-text)}
.profile-fields input,.profile-fields select,.profile-fields textarea,.readonly-grid input{width:100%;min-width:0;padding:11px 12px;border:1px solid var(--c-border);border-radius:11px;background:var(--c-gray);color:var(--c-text);font:inherit;font-size:12px}
.description-input{width:100%;min-width:0;resize:vertical;padding:12px;border:1px solid var(--c-border);border-radius:11px;background:var(--c-gray);color:var(--c-text);font:inherit;font-size:12px;line-height:1.55}.description-input:focus{outline:2px solid var(--c-blue-soft);border-color:var(--c-primary);background:white}
.readonly-grid input{background:#f0f1f4;color:var(--c-text-muted);cursor:not-allowed}
.profile-fields input:focus,.profile-fields select:focus,.profile-fields textarea:focus{outline:2px solid var(--c-blue-soft);border-color:var(--c-primary);background:white}
.field-full{grid-column:1/-1}
.selection-count{font-size:10px;font-weight:800;color:var(--c-text-muted);background:var(--c-gray);padding:5px 9px;border-radius:20px}
.choice-grid{display:flex;flex-wrap:wrap;gap:8px}
.choice-grid button{border:1px solid var(--c-border);border-radius:999px;padding:8px 11px;background:var(--c-white);color:var(--c-text);font:inherit;font-size:11px;font-weight:700;transition:background .15s,border-color .15s}
.choice-grid button.selected{background:var(--c-lavender);border-color:var(--c-primary);color:var(--c-primary)}
.privacy-toggle{display:flex;align-items:center;justify-content:space-between;gap:14px;padding:13px;border:1px solid var(--c-border);border-radius:14px;background:var(--c-gray)}
.privacy-toggle span{display:grid;gap:5px}
.privacy-toggle b{font-size:12px}
.privacy-toggle small{font-size:10px;color:var(--c-text-muted);line-height:1.45}
.privacy-toggle input{width:19px;height:19px;accent-color:var(--c-primary);flex-shrink:0}
.profile-save{display:flex;align-items:center;justify-content:center;gap:8px;width:100%;padding:14px;border:0;border-radius:13px;background:var(--c-primary);color:white;font-weight:800;font-size:13px;box-shadow:var(--shadow-primary)}
.profile-save:disabled{opacity:.6;cursor:wait}
.profile-message{display:flex;align-items:center;gap:7px;padding:11px 13px;border-radius:12px;font-size:12px}
.profile-message--error{background:#fff0f0;color:#b42b36}
.profile-message--success{background:#e9f9ef;color:#167b48}
.profile-loading{padding:30px;text-align:center;color:var(--c-text-muted);font-size:12px}
.profile-summary{gap:16px}.summary-description{display:grid;gap:6px;padding-top:12px;border-top:1px solid var(--c-border);font-size:12px}.summary-description p{white-space:pre-wrap;line-height:1.55;color:var(--c-text-muted)}
.profile-modal-backdrop{position:fixed;inset:0;z-index:180;display:grid;place-items:center;padding:18px;background:rgba(24,32,48,.5);backdrop-filter:blur(3px)}.profile-modal{width:min(760px,100%);max-height:min(90dvh,900px);overflow:auto;padding:22px;border:1px solid var(--c-border);border-radius:22px;background:var(--c-white);box-shadow:var(--shadow-lg);color:var(--c-text)}.profile-modal__header{position:sticky;top:-22px;z-index:2;display:flex;justify-content:space-between;align-items:center;gap:12px;margin:-22px -22px 17px;padding:18px 22px;background:var(--c-white);border-bottom:1px solid var(--c-border)}.profile-modal__header h2{font-size:18px;font-weight:850;margin-top:4px}.modal-close{width:36px;height:36px;display:grid;place-items:center;border:0;border-radius:50%;background:var(--c-gray);color:var(--c-text)}.profile-modal__body{display:grid;gap:14px}.customize-modal{width:min(520px,100%)}.background-options{display:grid;gap:8px;margin-top:14px}.background-option{width:100%;display:flex;align-items:center;gap:11px;padding:10px;border:1px solid var(--c-border);border-radius:13px;background:var(--c-white);text-align:left;color:var(--c-text)}.background-option.selected{border-color:var(--c-primary);background:var(--c-lavender)}.background-option.locked{opacity:.58;cursor:not-allowed}.background-swatch{width:42px;height:42px;display:grid;place-items:center;flex:none;border-radius:11px;color:#354053}.background-swatch--default{background:#fff;border:1px solid var(--c-border)}.background-option__text{display:grid;gap:4px;flex:1}.background-option__text b{font-size:12px}.background-option__text small{font-size:10px;color:var(--c-text-muted)}.option-lock{color:var(--c-text-muted)}.shop-link{display:block;margin-top:14px;text-align:center;font-size:12px;font-weight:800;color:var(--c-primary)}
.frame-options{display:grid;gap:8px}.frame-option{width:100%;display:flex;align-items:center;gap:12px;padding:10px;border:1px solid var(--c-border);border-radius:13px;background:var(--c-white);text-align:left;color:var(--c-text)}.frame-option.selected{border-color:var(--c-primary);background:var(--c-lavender)}.frame-option.locked{opacity:.62;cursor:not-allowed}.frame-option>span:nth-child(2){display:grid;gap:4px;flex:1}.frame-option b{font-size:12px}.frame-option small{font-size:10px;color:var(--c-text-muted)}.frame-option__initial{width:100%;height:100%;display:grid;place-items:center;border-radius:50%;background:var(--c-primary);color:white;font-size:16px;font-weight:850}.frame-option__check{color:var(--c-primary)}
.avatar-upload{display:flex;align-items:center;gap:12px;padding:12px;border:1px solid var(--c-border);border-radius:14px;background:var(--c-gray)}.avatar-upload__info{display:grid;gap:6px;min-width:0}.avatar-upload__info>b{font-size:13px}.avatar-upload__info>small{font-size:10px;line-height:1.4;color:var(--c-text-muted)}.avatar-upload__actions{display:flex;gap:7px;flex-wrap:wrap}.avatar-upload__actions button{display:inline-flex;align-items:center;justify-content:center;gap:6px;padding:7px 10px;border:0;border-radius:9px;background:var(--c-white);color:var(--c-primary);font-size:11px;font-weight:800}.avatar-upload__actions button:last-child{background:var(--c-primary);color:white}.avatar-upload__actions button:disabled{opacity:.5;cursor:not-allowed}.avatar-file-input{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}
.avatar-crop-backdrop{z-index:190}.avatar-crop-modal{width:min(380px,100%);display:grid;gap:14px}.avatar-crop-stage{position:relative;width:240px;height:240px;max-width:100%;margin:0 auto;overflow:hidden;border-radius:16px;background:#141824;touch-action:none;cursor:grab;user-select:none}.avatar-crop-stage:active{cursor:grabbing}.avatar-crop-stage img{position:absolute;max-width:none;transform:translate(-50%,-50%);pointer-events:none}.avatar-crop-mask{position:absolute;inset:0;border-radius:50%;box-shadow:0 0 0 999px #1119;pointer-events:none;border:2px solid #fff;box-sizing:border-box}.avatar-crop-zoom{display:flex;align-items:center;gap:12px;font-size:12px;font-weight:800}.avatar-crop-zoom input{flex:1;accent-color:var(--c-primary)}.avatar-crop-actions{display:flex;justify-content:flex-end;gap:8px}.avatar-crop-actions button{display:inline-flex;align-items:center;gap:6px;border:0;border-radius:10px;padding:10px 13px;background:var(--c-gray);color:var(--c-text);font-size:12px;font-weight:800}.avatar-crop-actions button:last-child{background:var(--c-primary);color:white}
@media(max-width:520px){.readonly-grid,.profile-fields{grid-template-columns:1fr}.field-full{grid-column:auto}.profile-identity{flex-wrap:wrap}.profile-wallet{width:100%}}
</style>
