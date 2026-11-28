<script setup>
import { computed, onMounted, ref } from 'vue'
import { Compass, Search, UsersRound } from 'lucide-vue-next'
import PagePlaceholder from '@/components/shared/PagePlaceholder.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import StudentProfileModal from '@/components/shared/StudentProfileModal.vue'
import ProfileAvatarFrame from '@/components/shared/ProfileAvatarFrame.vue'
import { getProfilePhotoUrl } from '@/lib/profilePhotos'
import { supabase } from '@/lib/supabase'

const students = ref([])
const loading = ref(true)
const error = ref('')
const query = ref('')
const selectedInterest = ref('Semua')
const selectedProfileId = ref('')
const interests = computed(() => ['Semua', ...new Set(students.value.flatMap(s => s.hobbies || []))].sort((a, b) => a === 'Semua' ? -1 : a.localeCompare(b)))
const filtered = computed(() => students.value.filter(s => {
  const text = `${s.display_name || ''} ${(s.hobbies || []).join(' ')} ${(s.about_me || []).join(' ')}`.toLowerCase()
  return text.includes(query.value.toLowerCase()) && (selectedInterest.value === 'Semua' || (s.hobbies || []).includes(selectedInterest.value))
}))

async function load() {
  loading.value = true
  const { data, error: requestError } = await supabase.rpc('get_discover_students')
  if (requestError) error.value = 'Discover Students belum siap. Admin perlu menjalankan migration fitur komunitas.'
  else students.value = await Promise.all((data || []).map(async student => ({
    ...student,
    photoUrl: await getProfilePhotoUrl(student.photo_path)
  })))
  loading.value = false
}

onMounted(load)
</script>

<template>
  <PagePlaceholder eyebrow="Class Community" title="Discover Students" :icon="Compass" tone="lavender" test-id="discover-page">
    <div class="discover-layout">
      <BaseCard class="discover-intro"><UsersRound :size="22"/><div><strong>Kenali teman sekelas lebih dekat</strong><p>Temukan teman berdasarkan hobi dan minat yang mereka pilih untuk dibagikan.</p></div></BaseCard>
      <div class="discover-tools">
        <label class="discover-search"><Search :size="17"/><input v-model="query" placeholder="Cari nama, hobi, atau minat..." /></label>
        <div class="interest-filters"><button v-for="tag in interests" :key="tag" :class="{ active: selectedInterest === tag }" @click="selectedInterest = tag">{{ tag }}</button></div>
      </div>
      <p v-if="loading" class="discover-muted">Memuat daftar siswa...</p>
      <p v-else-if="error" class="discover-error">{{ error }}</p>
      <p v-else-if="!filtered.length" class="discover-muted">Belum ada profil yang cocok. Profil yang mengizinkan tampil akan muncul setelah perubahan profil disimpan.</p>
      <div v-else class="student-grid">
        <BaseCard
          v-for="student in filtered"
          :key="student.profile_id"
          tag="button"
          type="button"
          class="student-card"
          :style="{ '--student-card-bg': student.profile_color || '#ffffff' }"
          :aria-label="`Lihat profil ${student.display_name}`"
          @click="selectedProfileId = student.profile_id"
        >
          <div class="student-top">
            <ProfileAvatarFrame :frame="student.profile_frame" :photo="student.photoUrl" size="discover"><span class="student-avatar">{{ (student.display_name || '?').charAt(0) }}</span></ProfileAvatarFrame>
            <div><h2>{{ student.display_name }}</h2><small>{{ student.role === 'admin' ? `Admin · ${student.job_title || 'Admin Kelas'}` : (student.about_me?.slice(0, 2).join(' · ') || 'Teman XI-B2') }}</small></div>
          </div>
          <div class="hobby-tags"><span v-for="hobby in (student.hobbies || []).slice(0, 8)" :key="hobby">{{ hobby }}</span></div>
          <span class="student-card-hint">Lihat profil</span>
        </BaseCard>
      </div>
      <p class="discover-muted">Detail yang ditampilkan mengikuti izin berbagi profil siswa. NISN hanya terlihat jika siswa mengaktifkan izinnya.</p>
    </div>
    <StudentProfileModal :profile-id="selectedProfileId" :discover-context="true" @close="selectedProfileId = ''" />
  </PagePlaceholder>
</template>

<style scoped>
.discover-layout{display:flex;flex-direction:column;gap:16px}
.discover-intro{display:flex;gap:13px;align-items:center;background:linear-gradient(120deg,#f2efff,#edf8ff);color:var(--c-primary)}
.discover-intro strong{font-size:15px;color:var(--c-text)}
.discover-intro p{font-size:12px;color:var(--c-text-muted);margin-top:4px}
.discover-tools{display:flex;flex-direction:column;gap:11px}
.discover-search{height:46px;display:flex;align-items:center;gap:9px;padding:0 13px;border:1px solid var(--c-border);border-radius:13px;background:white;color:var(--c-text-muted)}
.discover-search input{border:0;outline:0;flex:1;min-width:0;background:transparent;font:inherit;font-size:13px}
.interest-filters{display:flex;gap:7px;flex-wrap:wrap}
.interest-filters button{border:1px solid var(--c-border);border-radius:20px;background:white;padding:7px 11px;font-size:11px;font-weight:700;color:var(--c-text-muted)}
.interest-filters button.active{background:var(--c-blue-soft);border-color:var(--c-primary);color:var(--c-primary)}
.student-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}
.student-card{width:100%;appearance:none;display:flex;flex-direction:column;align-items:stretch;gap:14px;padding:var(--space-5);text-align:left;color:var(--c-text);font:inherit;cursor:pointer;background:var(--student-card-bg,#fff)!important;transition:transform .16s ease,box-shadow .16s ease}
.student-card:hover,.student-card:focus-visible{transform:translateY(-2px);box-shadow:var(--shadow-md)}
.student-card:focus-visible{outline:3px solid var(--c-primary);outline-offset:2px}
.student-card-hint{font-size:10px;font-weight:800;color:var(--c-primary)}
.student-top{display:flex;align-items:center;gap:11px}
.student-avatar{width:43px;height:43px;border-radius:50%;display:grid;place-items:center;background:var(--c-lavender);color:var(--c-primary);font-size:18px;font-weight:850}
.student-top h2{font-size:14px}
.student-top small{font-size:10px;color:var(--c-text-muted)}
.hobby-tags{display:flex;flex-wrap:wrap;gap:6px}
.hobby-tags span{font-size:10px;background:var(--c-gray);border-radius:20px;padding:6px 8px;color:var(--c-text-muted)}
.discover-muted,.discover-error{font-size:12px;color:var(--c-text-muted);line-height:1.5}
.discover-error{color:var(--c-danger)}
@media(max-width:800px){.student-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:500px){.student-grid{grid-template-columns:1fr}}
</style>
