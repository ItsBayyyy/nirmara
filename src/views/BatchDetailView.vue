<script setup>
import { CircleAlert, ClipboardCheck, Play, SearchX, Send } from '@lucide/vue'
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import ActivityTimeline from '@/components/ActivityTimeline.vue'
import BaseModal from '@/components/BaseModal.vue'
import EmptyState from '@/components/EmptyState.vue'
import LifecycleStepper from '@/components/LifecycleStepper.vue'
import PageHeader from '@/components/PageHeader.vue'
import StatusChip from '@/components/StatusChip.vue'
import { useAuth } from '@/composables/useAuth'
import { useToast } from '@/composables/useToast'
import { friendlyError } from '@/lib/errors'
import { PASS_THRESHOLD, formatDate, formatDateTime, formatNumber } from '@/lib/format'
import { supabase } from '@/lib/supabase'

const props = defineProps({ id: { type: String, required: true } })
const { hasRole } = useAuth()
const { show } = useToast()
const router = useRouter()

const batch = ref(null)
const loading = ref(true)
const error = ref('')

async function load() {
  const { data, error: e } = await supabase
    .from('production_batches')
    .select(`*, product:products(name, sku, unit), creator:users(full_name),
             quality_checks(*, inspector:users(full_name)),
             production_logs(id, from_status, to_status, note, created_at, actor:users(full_name))`)
    .eq('id', props.id)
    .order('created_at', { referencedTable: 'production_logs' })
    .maybeSingle()
  error.value = e ? friendlyError(e) : data ? '' : 'Batch tidak ditemukan.'
  batch.value = data
  loading.value = false
}
onMounted(load)
watch(() => props.id, load)

// relasi satu-ke-satu dapat dikembalikan sebagai objek atau array tergantung versi PostgREST
const qc = computed(() => {
  const q = batch.value?.quality_checks
  return Array.isArray(q) ? q[0] : q
})

const stepTimes = computed(() =>
  Object.fromEntries((batch.value?.production_logs ?? []).map((l) => [l.to_status, l.created_at])),
)

const yieldPct = computed(() =>
  batch.value?.produced_qty ? Math.round((batch.value.produced_qty / batch.value.target_qty) * 1000) / 10 : null,
)

const nextAction = computed(() => {
  const s = batch.value?.status
  if (hasRole('production_staff') && s === 'planned') return { kind: 'start', label: 'Mulai produksi', icon: Play }
  if (hasRole('production_staff') && s === 'in_production') return { kind: 'submit', label: 'Isi hasil & kirim ke QC', icon: Send }
  if (hasRole('quality_control') && s === 'waiting_qc') return { kind: 'inspect', label: 'Mulai inspeksi', icon: ClipboardCheck }
  if (hasRole('quality_control') && s === 'quality_check') return { kind: 'result', label: 'Isi hasil inspeksi', icon: ClipboardCheck }
  return null
})

// ---------- aksi lifecycle (ditegakkan juga di basis data: BR-01, BR-06) ----------
const action = ref(null)
const producedQty = ref('')
const actionError = ref('')
const busy = ref(false)

function trigger(kind) {
  if (kind === 'result') return router.push({ name: 'batch-inspect', params: { id: batch.value.id } })
  action.value = kind
  actionError.value = ''
  producedQty.value = kind === 'submit' ? String(batch.value.target_qty) : ''
}

async function runAction() {
  actionError.value = ''
  let call
  if (action.value === 'start') call = supabase.rpc('start_production', { p_batch_id: batch.value.id })
  if (action.value === 'inspect') call = supabase.rpc('start_inspection', { p_batch_id: batch.value.id })
  if (action.value === 'submit') {
    const qty = Number(producedQty.value)
    if (!Number.isInteger(qty) || qty <= 0) return (actionError.value = 'Produced quantity harus bilangan bulat lebih dari 0.')
    call = supabase.rpc('submit_to_qc', { p_batch_id: batch.value.id, p_produced_qty: qty })
  }
  busy.value = true
  const { error: e } = await call
  busy.value = false
  if (e) return (actionError.value = friendlyError(e))
  const kind = action.value
  action.value = null
  if (kind === 'inspect') return router.push({ name: 'batch-inspect', params: { id: batch.value.id } })
  show(kind === 'start' ? 'Produksi dimulai' : 'Batch dikirim ke QC')
  load()
}

const ACTION_TEXT = {
  start: { title: 'Mulai produksi?', button: 'Mulai produksi', body: 'Status batch berubah dari PLANNED menjadi IN PRODUCTION.' },
  submit: { title: 'Kirim ke QC', button: 'Kirim ke QC', body: 'Isi jumlah unit yang benar-benar dihasilkan. Setelah dikirim, status menjadi WAITING QC dan hasil produksi tidak dapat diubah.' },
  inspect: { title: 'Mulai inspeksi?', button: 'Mulai inspeksi', body: 'Status batch berubah dari WAITING QC menjadi QUALITY CHECK, lalu Anda diarahkan ke form inspeksi.' },
}
</script>

<template>
  <div class="page">
    <div v-if="loading" class="page">
      <span class="skeleton" style="width: 120px" />
      <span class="skeleton" style="width: 280px; height: 26px" />
      <div class="panel panel__body"><span v-for="i in 3" :key="i" class="skeleton" style="margin: 14px 0" /></div>
    </div>

    <template v-else-if="error">
      <PageHeader title="Detail batch" :back="{ name: 'batches' }" back-label="Batch produksi" />
      <div class="panel">
        <EmptyState :icon="SearchX" title="Batch tidak ditemukan" :description="error">
          <RouterLink :to="{ name: 'batches' }" class="btn btn--secondary">Kembali ke daftar batch</RouterLink>
        </EmptyState>
      </div>
    </template>

    <template v-else>
      <PageHeader :title="batch.batch_code" :back="{ name: 'batches' }" back-label="Batch produksi">
        <template #title><span class="mono">{{ batch.batch_code }}</span><StatusChip :status="batch.status" /></template>
        <template #description>{{ batch.product.name }} · diproduksi {{ formatDate(batch.production_date) }}</template>
        <template v-if="nextAction" #actions>
          <button class="btn btn--primary" @click="trigger(nextAction.kind)">
            <component :is="nextAction.icon" :size="16" /> {{ nextAction.label }}
          </button>
        </template>
      </PageHeader>

      <section class="panel panel__body">
        <LifecycleStepper :status="batch.status" :times="stepTimes" />
      </section>

      <div class="grid">
        <div class="col">
          <section class="panel">
            <header class="panel__head"><h2 class="panel__title">Quantity</h2>
              <span v-if="yieldPct !== null" class="muted small">Hasil {{ yieldPct }}% dari target</span>
            </header>
            <div class="qty">
              <div><p class="qty__label">Target</p><p class="qty__value">{{ formatNumber(batch.target_qty) }}</p></div>
              <div><p class="qty__label">Produced</p><p class="qty__value">{{ formatNumber(batch.produced_qty) }}</p></div>
              <div><p class="qty__label">Accepted</p><p class="qty__value" :class="{ ok: qc }">{{ formatNumber(qc?.accepted_qty) }}</p></div>
              <div><p class="qty__label">Rejected</p><p class="qty__value" :class="{ bad: qc }">{{ formatNumber(qc?.rejected_qty) }}</p></div>
            </div>
            <div v-if="qc" class="qty-bar">
              <div class="qty-bar__track">
                <span class="qty-bar__ok" :style="{ width: `${qc.accepted_rate}%` }" />
                <span class="qty-bar__threshold" :style="{ left: `${PASS_THRESHOLD}%` }" title="Ambang QC 90%" />
              </div>
              <p class="muted small">Accepted rate <strong class="tnum">{{ qc.accepted_rate }}%</strong> · ambang lulus {{ PASS_THRESHOLD }}%</p>
            </div>
          </section>

          <section v-if="qc" class="panel">
            <header class="panel__head">
              <h2 class="panel__title">Hasil quality control</h2>
              <StatusChip :status="qc.result" />
            </header>
            <dl class="info panel__body">
              <dt>Saran sistem</dt><dd>{{ qc.suggested_result.toUpperCase() }}
                <span v-if="qc.suggested_result !== qc.result" class="override">ditetapkan berbeda</span></dd>
              <dt>Inspector</dt><dd>{{ qc.inspector?.full_name }}</dd>
              <dt>Waktu inspeksi</dt><dd>{{ formatDateTime(qc.inspected_at) }}</dd>
              <dt>Catatan</dt><dd>{{ qc.notes || '—' }}</dd>
            </dl>
          </section>

          <section class="panel">
            <header class="panel__head"><h2 class="panel__title">Informasi batch</h2></header>
            <dl class="info panel__body">
              <dt>Produk</dt><dd>{{ batch.product.name }} <span class="mono muted">{{ batch.product.sku }}</span></dd>
              <dt>Satuan</dt><dd>{{ batch.product.unit }}</dd>
              <dt>Dibuat oleh</dt><dd>{{ batch.creator?.full_name }}</dd>
              <dt>Mulai produksi</dt><dd>{{ formatDateTime(batch.started_at) }}</dd>
              <dt>Dikirim ke QC</dt><dd>{{ formatDateTime(batch.submitted_at) }}</dd>
              <dt>Catatan</dt><dd>{{ batch.notes || '—' }}</dd>
            </dl>
          </section>
        </div>

        <section class="panel">
          <header class="panel__head">
            <h2 class="panel__title">Activity timeline</h2>
            <span class="muted small">{{ batch.production_logs.length }} aktivitas</span>
          </header>
          <div class="panel__body"><ActivityTimeline :logs="batch.production_logs" /></div>
        </section>
      </div>

      <BaseModal v-if="action" :title="ACTION_TEXT[action].title" :description="ACTION_TEXT[action].body" @close="action = null">
        <form id="action-form" class="form-grid" novalidate @submit.prevent="runAction">
          <div v-if="action === 'submit'" class="field">
            <label for="produced">Produced quantity</label>
            <div class="input-affix">
              <input id="produced" v-model="producedQty" type="number" min="1" step="1" class="input suffix-input" autofocus />
              <span class="input-affix__suffix">{{ batch.product.unit }}</span>
            </div>
            <span class="hint">Target {{ formatNumber(batch.target_qty) }} {{ batch.product.unit }}</span>
          </div>
          <div v-if="actionError" class="alert alert--error" role="alert"><CircleAlert :size="16" /><span>{{ actionError }}</span></div>
        </form>
        <template #footer>
          <button class="btn btn--secondary" @click="action = null">Batal</button>
          <button class="btn btn--primary" type="submit" form="action-form" :disabled="busy">
            {{ busy ? 'Memproses…' : ACTION_TEXT[action].button }}
          </button>
        </template>
      </BaseModal>
    </template>
  </div>
</template>

<style scoped>
.grid {
  display: grid;
  grid-template-columns: minmax(0, 1.45fr) minmax(0, 1fr);
  gap: 20px;
  align-items: start;
}

.col {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.small {
  font-size: 12px;
}

.qty {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
}

.qty > div {
  padding: 18px 20px;
  border-right: 1px solid var(--border);
}

.qty > div:last-child {
  border-right: none;
}

.qty__label {
  color: var(--muted);
  font-size: 12px;
  font-weight: 500;
}

.qty__value {
  margin-top: 4px;
  font-size: 24px;
  font-weight: 600;
  letter-spacing: -0.02em;
  font-variant-numeric: tabular-nums;
}

.ok { color: var(--success); }
.bad { color: var(--danger); }

.qty-bar {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 0 20px 18px;
}

.qty-bar__track {
  position: relative;
  height: 8px;
  border-radius: 999px;
  background: #fecaca;
}

.qty-bar__ok {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: #22c55e;
}

.qty-bar__threshold {
  position: absolute;
  top: -4px;
  bottom: -4px;
  width: 2px;
  background: var(--text);
  border-radius: 1px;
}

.info {
  display: grid;
  grid-template-columns: 140px 1fr;
  gap: 12px 16px;
  margin: 0;
}

.info dt {
  color: var(--muted);
}

.info dd {
  margin: 0;
}

.override {
  margin-left: 6px;
  padding: 1px 6px;
  border-radius: 4px;
  background: var(--warning-soft);
  color: var(--warning);
  font-size: 11px;
  font-weight: 600;
}

.suffix-input {
  padding-right: 48px;
}

@media (max-width: 960px) {
  .grid {
    grid-template-columns: 1fr;
  }

  .qty {
    grid-template-columns: repeat(2, 1fr);
  }

  .qty > div:nth-child(2) {
    border-right: none;
  }
}
</style>
