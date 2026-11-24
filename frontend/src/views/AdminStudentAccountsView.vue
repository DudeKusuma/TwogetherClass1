<script setup>
import { ref } from 'vue'
import { ArrowLeft, Copy, Download, KeyRound, ShieldCheck, Users } from 'lucide-vue-next'
import { RouterLink } from 'vue-router'
import { supabase } from '@/lib/supabase'
import BaseButton from '@/components/base/BaseButton.vue'

const loading = ref(false)
const error = ref('')
const result = ref(null)
const copied = ref(false)
const students = ref([])
const studentsLoading = ref(false)
const studentError = ref('')
const resettingId = ref('')
const resetTarget = ref(null)
const newPassword = ref('')
const resetError = ref('')
const resetSuccess = ref(null)
const resetCopied = ref(false)

async function loadStudents() {
  if (!supabase) return
  studentsLoading.value = true
  studentError.value = ''
  const { data, error: queryError } = await supabase
    .from('profiles')
    .select('id, display_name, username, attendance_number, role')
    .eq('role', 'student')
    .order('attendance_number', { ascending: true, nullsFirst: false })
  studentsLoading.value = false
  if (queryError) {
    studentError.value = queryError.message
    return
  }
  students.value = data || []
}

function openReset(student) {
  resetTarget.value = student
  newPassword.value = ''
  resetError.value = ''
  resetSuccess.value = null
  resetCopied.value = false
}

function closeReset() {
  resetTarget.value = null
  resetSuccess.value = null
  newPassword.value = ''
  resetError.value = ''
  resetCopied.value = false
}

async function resetPassword() {
  if (!resetTarget.value || resettingId.value) return
  resetError.value = ''
  if (newPassword.value.length < 10 || newPassword.value.length > 128) {
    resetError.value = 'Password harus terdiri dari 10 sampai 128 karakter.'
    return
  }
  const confirmed = window.confirm(`Reset password ${resetTarget.value.username || resetTarget.value.display_name}? Siswa akan diminta mengganti password saat masuk berikutnya.`)
  if (!confirmed) return
  resettingId.value = resetTarget.value.id
  const { data, error: invokeError } = await supabase.functions.invoke('rapid-processor', {
    body: { profileId: resetTarget.value.id, newPassword: newPassword.value },
  })
  resettingId.value = ''
  if (invokeError || data?.error || data?.success !== true) {
    resetError.value = data?.error || invokeError?.message || 'Password gagal direset.'
    return
  }
  resetSuccess.value = { username: resetTarget.value.username, password: newPassword.value }
  newPassword.value = ''
}

async function copyResetPassword() {
  if (!resetSuccess.value) return
  await navigator.clipboard.writeText(`Username: ${resetSuccess.value.username}\nPassword baru: ${resetSuccess.value.password}`)
  resetCopied.value = true
}

async function createAccounts() {
  if (loading.value) return
  const confirmed = window.confirm('Buat akun untuk seluruh siswa yang ada di roster XI-B2? Akun yang sudah ada tidak akan dibuat ulang atau di-reset password-nya.')
  if (!confirmed) return

  loading.value = true
  error.value = ''
  result.value = null
  copied.value = false
  const { data, error: invokeError } = await supabase.functions.invoke('create-student-accounts', { body: {} })
  loading.value = false
  if (invokeError) {
    error.value = invokeError.message || 'Tidak dapat menghubungi layanan pembuatan akun.'
    return
  }
  if (data?.error) {
    error.value = data.error
    return
  }
  result.value = data
  await loadStudents()
}

loadStudents()

function csvEscape(value) {
  return `"${String(value ?? '').replaceAll('"', '""')}"`
}

function downloadCredentials() {
  if (!result.value?.created?.length) return
  const rows = [['Nomor Absen', 'Nama', 'Username', 'Password Sementara'], ...result.value.created.map((item) => [item.attendance_number, item.full_name, item.username, item.password])]
  const csv = '\uFEFF' + rows.map((row) => row.map(csvEscape).join(',')).join('\r\n')
  const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }))
  const link = document.createElement('a')
  link.href = url
  link.download = 'akun-siswa-xi-b2.csv'
  link.click()
  URL.revokeObjectURL(url)
}

async function copyCredentials() {
  if (!result.value?.created?.length) return
  const lines = result.value.created.map((item) => `${item.attendance_number}. ${item.full_name}\nUsername: ${item.username}\nPassword sementara: ${item.password}`)
  await navigator.clipboard.writeText(lines.join('\n\n'))
  copied.value = true
}
</script>

<template>
  <div class="accounts-page">
    <RouterLink to="/admin-power" class="back-link"><ArrowLeft :size="16" /> Kembali ke Admin Power</RouterLink>
    <header class="page-head">
      <span class="page-head__eyebrow">Admin Power</span>
      <h1 class="page-head__title">Akun Siswa</h1>
      <p class="page-head__desc">Buat akun login username untuk siswa XI-B2 berdasarkan data roster kelas.</p>
    </header>

    <section class="info-card">
      <div class="info-icon"><Users :size="22" /></div>
      <div>
        <h2>Username otomatis</h2>
        <p>Nomor absen 1–43 akan mendapatkan username <strong>siswa01</strong> sampai <strong>siswa43</strong>. Setiap akun dibuat dengan password sementara acak dan langsung ditautkan ke nama serta NIS pada roster.</p>
      </div>
    </section>

    <section class="action-card">
      <div class="action-heading"><ShieldCheck :size="20" /><strong>Pembuatan akun aman</strong></div>
      <p>Proses ini hanya bisa dijalankan oleh admin. Password hanya ditampilkan satu kali untuk akun yang baru dibuat. Simpan file kredensial di tempat aman dan bagikan secara pribadi kepada siswa.</p>
      <BaseButton block :disabled="loading" @click="createAccounts">
        <KeyRound :size="17" /> {{ loading ? 'Sedang membuat akun…' : 'Buat akun 43 siswa' }}
      </BaseButton>
      <p v-if="error" class="error-message" role="alert">{{ error }}</p>
    </section>

    <section class="result-card student-accounts">
      <div class="accounts-heading">
        <div><h2>Akun siswa</h2><p class="result-note">Password lama tidak dapat ditampilkan. Reset akan mengganti password dan mewajibkan siswa membuat password baru saat login.</p></div>
        <BaseButton size="sm" variant="secondary" :disabled="studentsLoading" @click="loadStudents">{{ studentsLoading ? 'Memuat…' : 'Muat ulang' }}</BaseButton>
      </div>
      <p v-if="studentError" class="error-message" role="alert">{{ studentError }}</p>
      <p v-else-if="studentsLoading && !students.length" class="result-note">Memuat akun siswa…</p>
      <p v-else-if="!students.length" class="result-note">Belum ada akun siswa.</p>
      <div v-else class="table-wrap">
        <table class="account-table">
          <thead><tr><th>Absen</th><th>Nama</th><th>Username</th><th>Aksi</th></tr></thead>
          <tbody><tr v-for="student in students" :key="student.id">
            <td>{{ student.attendance_number ?? '—' }}</td><td>{{ student.display_name }}</td><td><code>{{ student.username || '—' }}</code></td>
            <td><BaseButton size="sm" variant="secondary" :disabled="Boolean(resettingId)" @click="openReset(student)"><KeyRound :size="15" /> Reset password</BaseButton></td>
          </tr></tbody>
        </table>
      </div>
    </section>

    <div v-if="resetTarget" class="reset-overlay" role="presentation" @click.self="closeReset">
      <section class="reset-dialog" role="dialog" aria-modal="true" aria-labelledby="reset-title">
        <button class="reset-close" type="button" aria-label="Tutup" @click="closeReset">×</button>
        <h2 id="reset-title">Reset password siswa</h2>
        <p class="result-note">{{ resetTarget.display_name }} · <code>{{ resetTarget.username }}</code></p>
        <template v-if="resetSuccess">
          <div class="reset-credential"><strong>Password baru</strong><code>{{ resetSuccess.password }}</code><small>Simpan dan berikan kepada siswa secara pribadi. Password ini hanya ditampilkan selama dialog terbuka.</small></div>
          <div class="credential-actions"><BaseButton size="sm" @click="copyResetPassword"><Copy :size="16" /> {{ resetCopied ? 'Tersalin' : 'Salin kredensial' }}</BaseButton><BaseButton size="sm" variant="secondary" @click="closeReset">Selesai</BaseButton></div>
        </template>
        <form v-else @submit.prevent="resetPassword">
          <label class="reset-label">Password baru<input v-model="newPassword" type="password" autocomplete="new-password" minlength="10" maxlength="128" placeholder="Minimal 10 karakter" required /></label>
          <p class="reset-hint">Siswa akan diminta mengganti password ini saat login berikutnya.</p>
          <p v-if="resetError" class="error-message" role="alert">{{ resetError }}</p>
          <div class="credential-actions"><BaseButton type="submit" :disabled="Boolean(resettingId)"><KeyRound :size="16" /> {{ resettingId ? 'Mereset…' : 'Simpan password baru' }}</BaseButton><BaseButton type="button" variant="secondary" @click="closeReset">Batal</BaseButton></div>
        </form>
      </section>
    </div>


    <section v-if="result" class="result-card" aria-live="polite">
      <h2>Hasil pembuatan akun</h2>
      <p class="result-note">{{ result.message }}</p>
      <div class="stats">
        <div><strong>{{ result.created?.length || 0 }}</strong><span>Akun baru</span></div>
        <div><strong>{{ result.alreadyCreated?.length || 0 }}</strong><span>Sudah ada</span></div>
        <div><strong>{{ result.failures?.length || 0 }}</strong><span>Gagal</span></div>
      </div>
      <div v-if="result.created?.length" class="credential-actions">
        <BaseButton size="sm" @click="downloadCredentials"><Download :size="16" /> Unduh CSV</BaseButton>
        <BaseButton size="sm" variant="secondary" @click="copyCredentials"><Copy :size="16" /> {{ copied ? 'Tersalin' : 'Salin kredensial' }}</BaseButton>
      </div>
      <div v-if="result.created?.length" class="table-wrap">
        <table>
          <thead><tr><th>Absen</th><th>Nama</th><th>Username</th><th>Password sementara</th></tr></thead>
          <tbody>
            <tr v-for="item in result.created" :key="item.username">
              <td>{{ item.attendance_number }}</td><td>{{ item.full_name }}</td><td><code>{{ item.username }}</code></td><td><code>{{ item.password }}</code></td>
            </tr>
          </tbody>
        </table>
      </div>
      <div v-if="result.alreadyCreated?.length" class="sub-result">
        <strong>Akun yang sudah ada (password tidak diubah)</strong>
        <p v-for="item in result.alreadyCreated" :key="item.username">{{ item.attendance_number }} · {{ item.full_name }} · {{ item.username }}</p>
      </div>
      <div v-if="result.failures?.length" class="sub-result failures">
        <strong>Akun yang perlu diperiksa</strong>
        <p v-for="item in result.failures" :key="item.username">{{ item.username }} · {{ item.full_name }}: {{ item.error }}</p>
      </div>
    </section>
  </div>
</template>

<style scoped>
.accounts-page { display: flex; flex-direction: column; gap: var(--space-4); }
.back-link { display: inline-flex; align-items: center; gap: 7px; width: fit-content; color: var(--c-primary); font-size: 13px; font-weight: 700; }
.info-card, .action-card, .result-card { padding: var(--space-5); border: 1px solid var(--c-border); border-radius: var(--radius-lg); background: var(--c-white); box-shadow: var(--shadow-sm); }
.info-card { display: flex; align-items: flex-start; gap: var(--space-3); }
.info-icon { width: 44px; height: 44px; flex: 0 0 44px; display: grid; place-items: center; border-radius: 14px; color: var(--c-primary); background: var(--c-blue-soft); }
h2 { font-size: 16px; font-weight: 800; margin-bottom: 7px; }
.info-card p, .action-card > p, .result-note { color: var(--c-text-muted); font-size: 13px; line-height: 1.65; }
.action-heading { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; color: var(--c-text); }
.action-card > p { margin-bottom: var(--space-4); }
.error-message { margin-top: 12px; color: var(--c-danger) !important; }
.stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin: var(--space-4) 0; }
.stats > div { padding: 12px; border-radius: var(--radius-md); background: var(--c-gray); display: flex; flex-direction: column; gap: 3px; }
.stats strong { font-size: 22px; }.stats span { color: var(--c-text-muted); font-size: 11px; }
.credential-actions { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: var(--space-3); }
.accounts-heading { display:flex; justify-content:space-between; align-items:flex-start; gap:12px; margin-bottom:12px; }.accounts-heading h2{margin-bottom:4px}.account-table td:last-child{white-space:normal}.reset-overlay{position:fixed;inset:0;z-index:100;display:grid;place-items:center;padding:20px;background:#17203380}.reset-dialog{position:relative;width:min(100%,460px);padding:22px;border-radius:18px;background:white;box-shadow:var(--shadow-lg)}.reset-close{position:absolute;top:10px;right:12px;border:0;background:transparent;font-size:26px;color:var(--c-text-muted);cursor:pointer}.reset-label{display:grid;gap:7px;margin-top:18px;font-size:13px;font-weight:700}.reset-label input{width:100%;padding:11px 12px;border:1px solid var(--c-border);border-radius:10px;font:inherit}.reset-hint{margin-top:8px;color:var(--c-text-muted);font-size:12px}.reset-credential{display:grid;gap:8px;padding:14px;margin:16px 0;border-radius:12px;background:var(--c-mint)}.reset-credential code{font-size:16px;word-break:break-all}.reset-credential small{color:var(--c-text-muted);line-height:1.45}
.table-wrap { overflow-x: auto; border: 1px solid var(--c-border); border-radius: var(--radius-md); }
table { width: 100%; border-collapse: collapse; min-width: 620px; font-size: 12px; text-align: left; }
th, td { padding: 10px 12px; border-bottom: 1px solid var(--c-border); white-space: nowrap; }
th { background: var(--c-gray); font-weight: 800; } td code { font-size: 11px; }
.sub-result { margin-top: var(--space-4); font-size: 12px; line-height: 1.7; }.sub-result p { color: var(--c-text-muted); }.failures { color: var(--c-danger); }
@media (max-width: 480px) { .info-card, .action-card, .result-card { padding: var(--space-4); } }
</style>
