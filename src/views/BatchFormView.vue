<script setup>
import { CircleAlert, Info } from '@lucide/vue'
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import PageHeader from '@/components/PageHeader.vue'
import StatusChip from '@/components/StatusChip.vue'
import { useToast } from '@/composables/useToast'
import { friendlyError } from '@/lib/errors'
import { formatDate, formatNumber, todayISO } from '@/lib/format'
import { supabase } from '@/lib/supabase'

const router = useRouter()
const { show } = useToast()
const products = ref([])
const form = reactive({ product_id: '', target_qty: '', production_date: todayISO(), notes: '' })
const errors = reactive({})
const formError = ref('')
const saving = ref(false)

onMounted(async () => {
  // BR-09: hanya produk aktif yang dapat dipilih
  const { data, error } = await supabase.from('products').select('id, name, sku, unit').eq('status', 'active').order('name')
  formError.value = friendlyError(error)
  products.value = data ?? []
})

const product = computed(() => products.value.find((p) => p.id === Number(form.product_id)))
const codePreview = computed(() => {
  const d = form.production_date ? form.production_date.slice(2).replaceAll('-', '') : 'YYMMDD'
  return `BT-${d}-NNN`
})

function validate() {
  Object.keys(errors).forEach((k) => delete errors[k])
  if (!form.product_id) errors.product_id = 'Pilih produk yang akan diproduksi.'
  const qty = Number(form.target_qty)
  if (!Number.isInteger(qty) || qty <= 0) errors.target_qty = 'Target quantity harus bilangan bulat lebih dari 0.'
  if (!form.production_date) errors.production_date = 'Tanggal produksi wajib diisi.'
  return !Object.keys(errors).length
}

async function submit() {
  formError.value = ''
  if (!validate()) return
  saving.value = true
  const { data, error } = await supabase.rpc('create_batch', {
    p_product_id: Number(form.product_id),
    p_target_qty: Number(form.target_qty),
    p_production_date: form.production_date,
    p_notes: form.notes,
  })
  saving.value = false
  if (error) return (formError.value = friendlyError(error))
  show(`Batch ${data.batch_code} dibuat`)
  router.replace({ name: 'batch-detail', params: { id: data.id } })
}
</script>

<template>
  <div class="page">
    <PageHeader title="Buat batch produksi" description="Satu batch mewakili satu kali produksi untuk satu produk."
                :back="{ name: 'batches' }" back-label="Batch produksi" />

    <div class="layout">
      <form class="panel" novalidate @submit.prevent="submit">
        <div class="panel__body form-grid">
          <div v-if="formError" class="alert alert--error" role="alert"><CircleAlert :size="16" /><span>{{ formError }}</span></div>
          <div class="field">
            <label for="product">Produk</label>
            <select id="product" v-model="form.product_id" class="select" :class="{ 'input--invalid': errors.product_id }">
              <option value="" disabled>Pilih produk aktif</option>
              <option v-for="p in products" :key="p.id" :value="p.id">{{ p.name }} · {{ p.sku }}</option>
            </select>
            <span v-if="errors.product_id" class="error">{{ errors.product_id }}</span>
            <span v-else class="hint">Produk berstatus nonaktif tidak ditampilkan.</span>
          </div>
          <div class="form-grid form-grid--2">
            <div class="field">
              <label for="target">Target quantity</label>
              <div class="input-affix">
                <input id="target" v-model="form.target_qty" type="number" min="1" step="1" class="input no-icon"
                       :class="{ 'input--invalid': errors.target_qty }" placeholder="100" />
                <span class="input-affix__suffix">{{ product?.unit ?? 'pcs' }}</span>
              </div>
              <span v-if="errors.target_qty" class="error">{{ errors.target_qty }}</span>
            </div>
            <div class="field">
              <label for="date">Tanggal produksi</label>
              <input id="date" v-model="form.production_date" type="date" class="input"
                     :class="{ 'input--invalid': errors.production_date }" />
              <span v-if="errors.production_date" class="error">{{ errors.production_date }}</span>
            </div>
          </div>
          <div class="field">
            <label for="notes">Catatan <span class="muted">(opsional)</span></label>
            <textarea id="notes" v-model="form.notes" class="textarea" placeholder="Misalnya: pesanan khusus kafe mitra" />
          </div>
        </div>
        <footer class="form-foot">
          <RouterLink :to="{ name: 'batches' }" class="btn btn--secondary">Batal</RouterLink>
          <button class="btn btn--primary" type="submit" :disabled="saving">{{ saving ? 'Menyimpan…' : 'Simpan batch' }}</button>
        </footer>
      </form>

      <aside class="preview panel">
        <p class="preview__eyebrow">Pratinjau</p>
        <div class="preview__head">
          <p class="mono preview__code">{{ codePreview }}</p>
          <StatusChip status="planned" />
        </div>
        <dl class="preview__list">
          <dt>Produk</dt><dd>{{ product?.name ?? '—' }}</dd>
          <dt>Target</dt><dd class="tnum">{{ form.target_qty ? `${formatNumber(Number(form.target_qty))} ${product?.unit ?? ''}` : '—' }}</dd>
          <dt>Tanggal</dt><dd>{{ form.production_date ? formatDate(form.production_date) : '—' }}</dd>
        </dl>
        <p class="preview__note">
          <Info :size="14" />
          <span>NNN adalah nomor urut batch pada tanggal tersebut, diberikan sistem saat disimpan.</span>
        </p>
      </aside>
    </div>
  </div>
</template>

<style scoped>
.layout {
  display: grid;
  grid-template-columns: minmax(0, 1.6fr) minmax(0, 1fr);
  gap: 20px;
  align-items: start;
}

.no-icon {
  padding-left: 11px !important;
  padding-right: 48px;
}

.form-foot {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  padding: 14px 20px;
  border-top: 1px solid var(--border);
  background: var(--bg-subtle);
  border-radius: 0 0 var(--radius-lg) var(--radius-lg);
}

.preview {
  padding: 20px;
  background: var(--bg-subtle);
}

.preview__eyebrow {
  color: var(--muted);
  font-size: 12px;
  font-weight: 500;
}

.preview__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-top: 8px;
}

.preview__code {
  font-size: 17px;
  font-weight: 600;
}

.preview__list {
  display: grid;
  grid-template-columns: 80px 1fr;
  gap: 8px 12px;
  margin: 18px 0 0;
  padding-top: 16px;
  border-top: 1px solid var(--border);
}

.preview__list dt {
  color: var(--muted);
}

.preview__list dd {
  margin: 0;
  font-weight: 500;
}

.preview__note {
  display: flex;
  gap: 8px;
  margin-top: 18px;
  color: var(--muted);
  font-size: 12px;
}

.preview__note svg {
  flex: none;
  margin-top: 2px;
}

@media (max-width: 860px) {
  .layout {
    grid-template-columns: 1fr;
  }
}
</style>
