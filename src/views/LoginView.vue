<script setup>
import { ChevronRight, CircleAlert, ClipboardCheck, Croissant, Lock, Mail, Wheat } from '@lucide/vue'
import { reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import LifecycleStepper from '@/components/LifecycleStepper.vue'
import StatusChip from '@/components/StatusChip.vue'
import { signIn } from '@/composables/useAuth'
import { friendlyError } from '@/lib/errors'
import { isConfigured } from '@/lib/supabase'

const router = useRouter()
const route = useRoute()
const form = reactive({ email: '', password: '' })
const errors = reactive({ email: '', password: '' })
const formError = ref('')
const loading = ref(false)

// contoh statis untuk panel ilustrasi; bukan data dari basis data
const sampleTimes = {
  planned: '2026-10-05T07:00:00',
  in_production: '2026-10-05T07:15:00',
  waiting_qc: '2026-10-05T10:30:00',
  quality_check: '2026-10-05T11:00:00',
  released: '2026-10-05T11:40:00',
}

// Akun demo dari supabase/seed.sql. Matikan dengan VITE_DEMO_LOGIN=false di .env
// sebelum aplikasi dipakai sungguhan, karena password demo ikut terbawa ke bundle.
const DEMO_PASSWORD = 'Nirmara123!'
const demoEnabled = import.meta.env.VITE_DEMO_LOGIN !== 'false'
const demoAccounts = [
  { email: 'owner@nirmara.test', role: 'Owner', desc: 'Kelola produk & pantau produksi', icon: Croissant },
  { email: 'staff@nirmara.test', role: 'Production Staff', desc: 'Buat batch & catat hasil produksi', icon: Wheat },
  { email: 'qc@nirmara.test', role: 'Quality Control', desc: 'Inspeksi & tetapkan PASS/FAIL', icon: ClipboardCheck },
]
const demoLoading = ref('')

async function demoLogin(account) {
  form.email = account.email
  form.password = DEMO_PASSWORD
  errors.email = errors.password = ''
  demoLoading.value = account.email
  await submit()
  demoLoading.value = ''
}

function validate() {
  errors.email = /^\S+@\S+\.\S+$/.test(form.email) ? '' : 'Masukkan alamat email yang valid.'
  errors.password = form.password ? '' : 'Password wajib diisi.'
  return !errors.email && !errors.password
}

async function submit() {
  formError.value = ''
  if (!validate()) return
  loading.value = true
  try {
    await signIn(form.email.trim(), form.password)
    router.replace(route.query.redirect || { name: 'dashboard' })
  } catch (e) {
    formError.value = friendlyError(e)
    form.password = ''
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login">
    <section class="login__form-side">
      <div class="login__brand">
        <span class="login__mark">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.4"
               stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 19V5l12 14V5" /></svg>
        </span>
        Nirmara
      </div>

      <div class="login__content">
        <div class="login__heading">
          <h1>Masuk ke Nirmara</h1>
          <p class="muted">Gunakan akun yang diberikan Owner untuk mengakses batch produksi.</p>
        </div>

        <div v-if="!isConfigured" class="alert alert--warning">
          <CircleAlert :size="16" />
          <span>Koneksi Supabase belum dikonfigurasi. Isi <code>.env</code> dengan URL dan publishable key proyek,
            lalu jalankan ulang <code>npm run dev</code>.</span>
        </div>

        <form class="form-grid" novalidate @submit.prevent="submit">
          <div v-if="formError" class="alert alert--error" role="alert">
            <CircleAlert :size="16" /><span>{{ formError }}</span>
          </div>
          <div class="field">
            <label for="email">Email</label>
            <div class="input-affix">
              <Mail :size="16" />
              <input id="email" v-model="form.email" type="email" class="input"
                     :class="{ 'input--invalid': errors.email }" autocomplete="username" placeholder="nama@nirmara.test" />
            </div>
            <span v-if="errors.email" class="error">{{ errors.email }}</span>
          </div>
          <div class="field">
            <label for="password">Password</label>
            <div class="input-affix">
              <Lock :size="16" />
              <input id="password" v-model="form.password" type="password" class="input"
                     :class="{ 'input--invalid': errors.password }" autocomplete="current-password" placeholder="••••••••" />
            </div>
            <span v-if="errors.password" class="error">{{ errors.password }}</span>
          </div>
          <button class="btn btn--primary btn--block login__submit" type="submit" :disabled="loading || !isConfigured">
            {{ loading && !demoLoading ? 'Memproses…' : 'Masuk' }}
          </button>
        </form>

        <div v-if="demoEnabled" class="demo">
          <p class="demo__divider"><span>atau masuk cepat dengan akun demo</span></p>
          <div class="demo__list">
            <button v-for="a in demoAccounts" :key="a.email" type="button" class="demo__item"
                    :disabled="loading || !isConfigured" @click="demoLogin(a)">
              <span class="demo__icon"><component :is="a.icon" :size="16" /></span>
              <span class="demo__text">
                <strong>{{ a.role }}</strong>
                <small>{{ demoLoading === a.email ? 'Memproses…' : a.desc }}</small>
              </span>
              <ChevronRight :size="16" class="demo__chev" />
            </button>
          </div>
        </div>
      </div>

      <p class="login__foot muted">Sistem pelacakan batch produksi bakery · RPL 2026</p>
    </section>

    <aside class="login__showcase" aria-hidden="true">
      <div class="showcase">
        <p class="showcase__eyebrow">Satu batch, satu riwayat utuh</p>
        <h2 class="showcase__title">Dari adonan sampai rilis, setiap langkah tercatat.</h2>

        <div class="showcase__card">
          <div class="showcase__card-head">
            <div>
              <p class="mono showcase__code">BT-261005-001</p>
              <p class="muted">Chocolate Croissant</p>
            </div>
            <StatusChip status="released" />
          </div>
          <LifecycleStepper status="released" :times="sampleTimes" compact class="showcase__stepper" />
          <div class="showcase__qty">
            <div><span class="muted">Target</span><strong>100</strong></div>
            <div><span class="muted">Produced</span><strong>100</strong></div>
            <div><span class="muted">Accepted</span><strong>98</strong></div>
            <div><span class="muted">Rejected</span><strong>2</strong></div>
          </div>
          <div class="showcase__bar"><span style="width: 98%" /></div>
          <p class="showcase__note muted">Accepted rate 98% · melewati ambang QC 90%</p>
        </div>
      </div>
    </aside>
  </div>
</template>

<style scoped>
.login {
  display: grid;
  grid-template-columns: minmax(380px, 1fr) minmax(0, 1.15fr);
  min-height: 100vh;
}

.login__form-side {
  display: flex;
  flex-direction: column;
  padding: 32px 48px;
}

.login__brand {
  display: flex;
  align-items: center;
  gap: 10px;
  font-weight: 600;
  font-size: 15px;
}

.login__mark {
  display: grid;
  place-items: center;
  width: 28px;
  height: 28px;
  border-radius: 7px;
  background: var(--primary);
  color: #fff;
}

.login__content {
  width: 100%;
  max-width: 360px;
  margin: auto;
  display: flex;
  flex-direction: column;
  gap: 28px;
}

.login__heading h1 {
  font-size: 26px;
  font-weight: 600;
}

.login__heading p {
  margin-top: 8px;
}

.login__submit {
  height: 38px;
  margin-top: 4px;
}

.demo__divider {
  display: flex;
  align-items: center;
  gap: 12px;
  color: var(--faint);
  font-size: 12px;
}

.demo__divider::before,
.demo__divider::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--border);
}

.demo__list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-top: 14px;
}

.demo__item {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  background: var(--bg);
  color: var(--text);
  text-align: left;
  cursor: pointer;
  box-shadow: var(--shadow-sm);
  transition: border-color 0.12s, background-color 0.12s;
}

.demo__item:hover:not(:disabled) {
  border-color: var(--border-strong);
  background: var(--bg-subtle);
}

.demo__item:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.demo__icon {
  display: grid;
  place-items: center;
  flex: none;
  width: 32px;
  height: 32px;
  border-radius: var(--radius-sm);
  background: var(--accent-soft);
  color: var(--accent);
}

.demo__text {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-width: 0;
}

.demo__text strong {
  font-size: 13px;
  font-weight: 600;
}

.demo__text small {
  color: var(--muted);
  font-size: 12px;
}

.demo__chev {
  color: var(--faint);
}

.login__foot {
  font-size: 12px;
}

.login__showcase {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 48px;
  background-color: var(--bg-subtle);
  background-image:
    linear-gradient(to right, rgba(28, 25, 23, 0.04) 1px, transparent 1px),
    linear-gradient(to bottom, rgba(28, 25, 23, 0.04) 1px, transparent 1px);
  background-size: 32px 32px;
  border-left: 1px solid var(--border);
}

.showcase {
  width: 100%;
  max-width: 560px;
}

.showcase__eyebrow {
  color: var(--accent);
  font-size: 13px;
  font-weight: 500;
}

.showcase__title {
  margin-top: 8px;
  font-size: 28px;
  font-weight: 600;
  letter-spacing: -0.025em;
  max-width: 440px;
}

.showcase__card {
  margin-top: 32px;
  padding: 22px;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-lg);
}

.showcase__card-head {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.showcase__code {
  font-weight: 600;
  font-size: 15px;
}

.showcase__stepper {
  margin-top: 24px;
}

.showcase__qty {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  margin-top: 24px;
  padding-top: 18px;
  border-top: 1px solid var(--border);
}

.showcase__qty div {
  display: flex;
  flex-direction: column;
  gap: 2px;
  font-size: 12px;
}

.showcase__qty strong {
  font-size: 20px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}

.showcase__bar {
  height: 6px;
  margin-top: 16px;
  border-radius: 999px;
  background: #fecaca;
  overflow: hidden;
}

.showcase__bar span {
  display: block;
  height: 100%;
  background: #22c55e;
}

.showcase__note {
  margin-top: 8px;
  font-size: 12px;
}

@media (max-width: 960px) {
  .login {
    grid-template-columns: 1fr;
  }

  .login__showcase {
    display: none;
  }

  .login__form-side {
    padding: 24px;
  }
}
</style>
