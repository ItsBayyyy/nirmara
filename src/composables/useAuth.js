import { reactive, readonly } from 'vue'
import { supabase } from '@/lib/supabase'

const state = reactive({ session: null, profile: null })
let initPromise = null

async function loadProfile(userId) {
  const { data, error } = await supabase.from('users').select('id, full_name, role').eq('id', userId).maybeSingle()
  if (error) throw error
  return data
}

async function applySession(session) {
  state.session = session
  state.profile = session ? await loadProfile(session.user.id) : null
}

export function initAuth() {
  initPromise ??= (async () => {
    const { data } = await supabase.auth.getSession()
    await applySession(data.session).catch(() => applySession(null))
    supabase.auth.onAuthStateChange((event, session) => {
      // Panggilan Supabase di dalam callback ini ditunda agar tidak terjadi deadlock (anjuran supabase-js).
      if (event === 'SIGNED_OUT') applySession(null)
      else if (event === 'SIGNED_IN' && session?.user.id !== state.profile?.id) {
        setTimeout(() => applySession(session), 0)
      } else state.session = session
    })
  })()
  return initPromise
}

export async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) throw error
  const profile = await loadProfile(data.user.id)
  if (!profile) {
    await supabase.auth.signOut()
    throw new Error('Akun ini belum terdaftar sebagai pengguna Nirmara. Hubungi Owner.')
  }
  state.session = data.session
  state.profile = profile
}

export async function signOut() {
  await supabase.auth.signOut()
  state.session = null
  state.profile = null
}

export function useAuth() {
  return {
    auth: readonly(state),
    hasRole: (...roles) => roles.includes(state.profile?.role),
  }
}
