import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-retry-count, traceparent, tracestate, baggage',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method tidak diizinkan.' }, 405)

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !anonKey || !serviceRoleKey) return json({ error: 'Konfigurasi server Supabase belum lengkap.' }, 500)

  const authorization = request.headers.get('Authorization')
  if (!authorization) return json({ error: 'Sesi admin tidak ditemukan.' }, 401)

  let body: { profileId?: unknown; newPassword?: unknown }
  try {
    body = await request.json()
  } catch {
    return json({ error: 'Format permintaan tidak valid.' }, 400)
  }
  if (typeof body.profileId !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(body.profileId)) {
    return json({ error: 'Akun siswa tidak valid.' }, 400)
  }
  if (typeof body.newPassword !== 'string' || body.newPassword.length < 10 || body.newPassword.length > 128) {
    return json({ error: 'Password baru harus terdiri dari 10 sampai 128 karakter.' }, 400)
  }

  const caller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: authData, error: authError } = await caller.auth.getUser()
  if (authError || !authData.user) return json({ error: 'Sesi login tidak valid.' }, 401)

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: callerProfile, error: callerProfileError } = await admin
    .from('profiles').select('role').eq('id', authData.user.id).maybeSingle()
  if (callerProfileError || callerProfile?.role !== 'admin') return json({ error: 'Hanya admin kelas yang dapat mereset password.' }, 403)

  const { data: student, error: studentError } = await admin
    .from('profiles').select('id, role').eq('id', body.profileId).maybeSingle()
  if (studentError) return json({ error: 'Tidak dapat memeriksa akun siswa.' }, 500)
  if (!student || student.role !== 'student') return json({ error: 'Akun siswa tidak ditemukan.' }, 404)

  const { error: passwordError } = await admin.auth.admin.updateUserById(student.id, { password: body.newPassword })
  if (passwordError) return json({ error: `Password gagal diperbarui: ${passwordError.message}` }, 400)

  const { error: profileError } = await admin
    .from('profiles').update({ must_change_password: true }).eq('id', student.id)
  if (profileError) {
    return json({ error: 'Password sudah diperbarui, tetapi status wajib ganti password belum tersimpan. Periksa akun siswa sebelum membagikan password.' }, 500)
  }

  return json({ success: true })
})
