<script setup>
import { CircleAlert, CircleCheck, CircleX, Info, SearchX } from '@lucide/vue'
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import EmptyState from '@/components/EmptyState.vue'
import PageHeader from '@/components/PageHeader.vue'
import StatusChip from '@/components/StatusChip.vue'
import { useToast } from '@/composables/useToast'
import { friendlyError } from '@/lib/errors'
import { PASS_THRESHOLD, acceptedRate, formatDate, formatNumber } from '@/lib/format'
import { supabase } from '@/lib/supabase'

const props = defineProps({ id: { type: String, required: true } })
const router = useRouter()
const { show } = useToast()

const batch = ref(null)
const loading = ref(true)
const loadError = ref('')
const form = reactive({ accepted: '', rejected: '', result: '', notes: '' })
const resultTouched = ref(false)
const errors = reactive({})
const formError = ref('')
const saving = ref(false)

onMounted(async () => {
  const { data, error } = await supabase
    .from('production_batches')
    .select('id, batch_code, status, produced_qty, target_qty, production_date, product:products(name, unit)')
    .eq('id', props.id)
    .maybeSingle()
  loadError.value = error ? friendlyError(error) : !data ? 'Batch tidak ditemukan.' : ''
  batch.value = data
  loading.value = false
})

const produced = computed(() => batch.value?.produced_qty ?? 0)
const acc = computed(() => Number(form.accepted))
const rej = computed(() => Number(form.rejected))
const filled = computed(() => form.accepted !== '' && form.rejected !== '')
const sumOk = computed(() => filled.value && acc.value + rej.value === produced.value)
const rate = computed(() => (form.accepted === '' ? null : acceptedRate(acc.value, produced.value)))
// BR-05: saran sistem; QC tetap menetapkan hasil akhir
const suggestion = computed(() => (rate.value === null ? null : rate.value >= PASS_THRESHOLD ? 'pass' : 'fail'))
const overriding = computed(() => form.result && suggestion.value && form.result !== suggestion.value)

// mengisi accepted otomatis mengisi rejected (dan sebaliknya) agar jumlahnya pas dengan produced
function fillFrom(field) {
  const v = Number(form[field])
  if (form[field] === '' || !Number.isInteger(v) || v < 0 || v > produced.value) return
  if (field === 'accepted') form.rejected = String(produced.value - v)
  else form.accepted = String(produced.value - v)
}

watch(suggestion, (s) => {
  if (!resultTouched.value) form.result = s ?? ''
})

function choose(result) {
  form.result = result
  resultTouched.value = true
}

function validate() {
  Object.keys(errors).forEach((k) => delete errors[k])
  for (const f of ['accepted', 'rejected']) {
    const v = Number(form[f])
    if (form[f] === '' || !Number.isInteger(v) || v < 0) errors[f] = 'Isi bilangan bulat 0 atau lebih.'
  }
  if (!errors.accepted && !errors.rejected && !sumOk.value) {
    errors.rejected = `Accepted + rejected harus sama dengan produced quantity (${produced.value}).`
  }
  if (!form.result) errors.result = 'Pilih hasil PASS atau FAIL.'
  if (overriding.value && !form.notes.trim()) errors.notes = 'Hasil berbeda dari saran sistem; tuliskan alasannya.'
  return !Object.keys(errors).length
}

async function submit() {
  formError.value = ''
  if (!validate()) return
  saving.value = true
  const { error } = await supabase.rpc('submit_qc_result', {
    p_batch_id: batch.value.id,
    p_accepted_qty: acc.value,
    p_rejected_qty: rej.value,
    p_result: form.result,
    p_notes: form.notes,
  })
  saving.value = false
  if (error) return (formError.value = friendlyError(error))
  show(`Batch ${batch.value.batch_code} ${form.result === 'pass' ? 'RELEASED' : 'REJECTED'}`)
  router.replace({ name: 'batch-detail', params: { id: batch.value.id } })
}
</script>

<template>
  <div class="page">
    <div v-if="loading" class="panel panel__body"><span v-for="i in 4" :key="i" class="skeleton" style="margin: 14px 0" /></div>
    <template v-else-if="loadError">
      <PageHeader title="Quality inspection" :back="{ name: 'batches' }" back-label="Batch produksi" />
      <div class="panel"><EmptyState :icon="SearchX" title="Batch tidak ditemukan" :description="loadError" /></div>
    </template>
    <template v-else>
      <PageHeader title="Quality inspection" :back="{ name: 'batch-detail', params: { id: batch.id } }"
                  :back-label="batch.batch_code">
        <template #description>
          <span class="mono">{{ batch.batch_code }}</span> · {{ batch.product.name }} · {{ formatDate(batch.production_date) }}
        </template>
        <template #actions><StatusChip :status="batch.status" /></template>
      </PageHeader>

      <div v-if="batch.status !== 'quality_check'" class="alert alert--warning">
        <Info :size="16" />
        <span>Inspeksi hanya dapat diisi untuk batch berstatus QUALITY CHECK.
          <template v-if="batch.status === 'waiting_qc'">Mulai inspeksi terlebih dahulu dari halaman detail batch.</template></span>
      </div>

      <div v-else class="layout">
        <form class="panel" novalidate @submit.prevent="submit">
          <div class="panel__body form-grid">
            <div v-if="formError" class="alert alert--error" role="alert"><CircleAlert :size="16" /><span>{{ formError }}</span></div>

            <div class="form-grid form-grid--2">
              <div class="field">
                <label for="accepted">Accepted quantity</label>
                <div class="input-affix">
                  <input id="accepted" v-model="form.accepted" type="number" min="0" :max="produced" step="1"
                         class="input suffix-input" :class="{ 'input--invalid': errors.accepted }" @input="fillFrom('accepted')" />
                  <span class="input-affix__suffix">{{ batch.product.unit }}</span>
                </div>
                <span v-if="errors.accepted" class="error">{{ errors.accepted }}</span>
              </div>
              <div class="field">
                <label for="rejected">Rejected quantity</label>
                <div class="input-affix">
                  <input id="rejected" v-model="form.rejected" type="number" min="0" :max="produced" step="1"
                         class="input suffix-input" :class="{ 'input--invalid': errors.rejected }" @input="fillFrom('rejected')" />
                  <span class="input-affix__suffix">{{ batch.product.unit }}</span>
                </div>
                <span v-if="errors.rejected" class="error">{{ errors.rejected }}</span>
              </div>
            </div>
            <p class="sum" :class="{ 'sum--bad': filled && !sumOk, 'sum--ok': sumOk }">
              <CircleCheck v-if="sumOk" :size="14" />
              <CircleAlert v-else-if="filled" :size="14" />
              Total diperiksa <strong class="tnum">{{ filled ? formatNumber(acc + rej) : '—' }}</strong>
              dari <strong class="tnum">{{ formatNumber(produced) }}</strong> produced
            </p>

            <div class="field">
              <span class="label">Hasil QC</span>
              <div class="choices" role="radiogroup" aria-label="Hasil QC">
                <button type="button" role="radio" :aria-checked="form.result === 'pass'" class="choice choice--pass"
                        :class="{ 'is-selected': form.result === 'pass' }" @click="choose('pass')">
                  <CircleCheck :size="18" />
                  <span><strong>PASS</strong><small>Batch menjadi RELEASED</small></span>
                </button>
                <button type="button" role="radio" :aria-checked="form.result === 'fail'" class="choice choice--fail"
                        :class="{ 'is-selected': form.result === 'fail' }" @click="choose('fail')">
                  <CircleX :size="18" />
                  <span><strong>FAIL</strong><small>Batch menjadi REJECTED</small></span>
                </button>
              </div>
              <span v-if="errors.result" class="error">{{ errors.result }}</span>
            </div>

            <div class="field">
              <label for="notes">
                Catatan inspeksi
                <span v-if="overriding" class="required">wajib, hasil berbeda dari saran sistem</span>
                <span v-else class="muted">(opsional)</span>
              </label>
              <textarea id="notes" v-model="form.notes" class="textarea" :class="{ 'input--invalid': errors.notes }"
                        placeholder="Kondisi produk, jenis cacat, atau alasan keputusan" />
              <span v-if="errors.notes" class="error">{{ errors.notes }}</span>
            </div>
          </div>
          <footer class="form-foot">
            <span class="muted small">Setelah ditetapkan, batch bersifat final.</span>
            <div class="form-actions">
              <RouterLink :to="{ name: 'batch-detail', params: { id: batch.id } }" class="btn btn--secondary">Batal</RouterLink>
              <button class="btn btn--primary" type="submit" :disabled="saving">{{ saving ? 'Menyimpan…' : 'Tetapkan hasil' }}</button>
            </div>
          </footer>
        </form>

        <aside class="panel summary" :class="suggestion && `summary--${suggestion}`">
          <p class="summary__label">Accepted rate</p>
          <p class="summary__rate tnum">{{ rate === null ? '—' : `${rate}%` }}</p>
          <div class="gauge">
            <span class="gauge__fill" :style="{ width: `${rate ?? 0}%` }" />
            <span class="gauge__mark" :style="{ left: `${PASS_THRESHOLD}%` }" />
          </div>
          <p class="gauge__scale" :style="{ paddingRight: `${100 - PASS_THRESHOLD}%` }">ambang lulus {{ PASS_THRESHOLD }}%</p>

          <div class="summary__suggest">
            <p class="muted small">Saran sistem</p>
            <StatusChip v-if="suggestion" :status="suggestion" />
            <p v-else class="muted">Isi accepted quantity</p>
          </div>
          <p class="summary__note muted small">
            Sistem menyarankan PASS bila accepted rate ≥ {{ PASS_THRESHOLD }}%. Keputusan akhir tetap di tangan Quality
            Control; keputusan yang berbeda dari saran wajib disertai alasan.
          </p>
        </aside>
      </div>
    </template>
  </div>
</template>

<style scoped>
.layout {
  display: grid;
  grid-template-columns: minmax(0, 1.6fr) minmax(0, 1fr);
  gap: 20px;
  align-items: start;
}

.suffix-input {
  padding-right: 48px;
}

.small {
  font-size: 12px;
}

.sum {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: -6px;
  color: var(--muted);
  font-size: 13px;
}

.sum strong {
  color: var(--text);
}

.sum--ok {
  color: var(--success);
}

.sum--bad {
  color: var(--danger);
}

.choices {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}

.choice {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  background: var(--bg);
  color: var(--muted);
  text-align: left;
  cursor: pointer;
  box-shadow: var(--shadow-sm);
  transition: border-color 0.12s, background-color 0.12s;
}

.choice span {
  display: flex;
  flex-direction: column;
}

.choice strong {
  color: var(--text);
  font-size: 13px;
}

.choice small {
  font-size: 12px;
}

.choice:hover {
  border-color: var(--border-strong);
}

.choice--pass.is-selected {
  border-color: var(--success);
  background: var(--success-soft);
  color: var(--success);
  box-shadow: 0 0 0 3px rgba(21, 128, 61, 0.12);
}

.choice--fail.is-selected {
  border-color: var(--danger);
  background: var(--danger-soft);
  color: var(--danger);
  box-shadow: 0 0 0 3px rgba(185, 28, 28, 0.12);
}

.required {
  margin-left: 6px;
  color: var(--danger);
  font-size: 12px;
  font-weight: 500;
}

.form-foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 14px 20px;
  border-top: 1px solid var(--border);
  background: var(--bg-subtle);
  border-radius: 0 0 var(--radius-lg) var(--radius-lg);
}

.summary {
  position: sticky;
  top: 24px;
  padding: 20px;
}

.summary__label {
  color: var(--muted);
  font-size: 12px;
  font-weight: 500;
}

.summary__rate {
  margin-top: 4px;
  font-size: 36px;
  font-weight: 600;
  letter-spacing: -0.03em;
}

.summary--pass .summary__rate {
  color: var(--success);
}

.summary--fail .summary__rate {
  color: var(--danger);
}

.gauge {
  position: relative;
  height: 8px;
  margin-top: 14px;
  border-radius: 999px;
  background: var(--bg-muted);
}

.gauge__fill {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: var(--faint);
  transition: width 0.25s ease;
}

.summary--pass .gauge__fill {
  background: #22c55e;
}

.summary--fail .gauge__fill {
  background: #ef4444;
}

.gauge__mark {
  position: absolute;
  top: -4px;
  bottom: -4px;
  width: 2px;
  background: var(--text);
  border-radius: 1px;
}

/* label rata kanan tepat di garis ambang */
.gauge__scale {
  margin-top: 8px;
  color: var(--muted);
  font-size: 11px;
  text-align: right;
  font-variant-numeric: tabular-nums;
}

.summary__suggest {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 20px;
  padding-top: 16px;
  border-top: 1px solid var(--border);
}

.summary__note {
  margin-top: 14px;
  line-height: 1.5;
}

@media (max-width: 860px) {
  .layout {
    grid-template-columns: 1fr;
  }

  .summary {
    position: static;
    order: -1;
  }

  .form-foot {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>
