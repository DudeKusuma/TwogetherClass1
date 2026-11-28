import { supabase } from '@/lib/supabase'

export async function getProfilePhotoUrl(photoPath) {
  if (!photoPath) return ''
  const { data, error } = await supabase
    .storage
    .from('profile-avatars')
    .createSignedUrl(photoPath, 60 * 60)
  return error ? '' : (data?.signedUrl || '')
}
