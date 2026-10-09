<script setup>
import { ChevronRight, Inbox, Plus, X } from '@lucide/vue'
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EmptyState from '@/components/EmptyState.vue'
import PageHeader from '@/components/PageHeader.vue'
import StatusChip from '@/components/StatusChip.vue'
import { useAuth } from '@/composables/useAuth'
import { friendlyError } from '@/lib/errors'
import { BATCH_STATUSES, formatDate, formatNumber, statusLabel } from '@/lib/format'
import { supabase } from '@/lib/supabase'

const { hasRole } = useAuth()
const route = useRoute()
const router = useRouter()

const products = ref([])
const batches = ref([])
const statusCounts = ref({})
const loading = ref(true)
const error = ref('')
// filter disimpan di query URL agar bisa dibagikan dan bertahan saat kembali dari detail
const filters = reactive({ status: '', product: '', from: '', to: '' })
const hasExtraFilters = computed(() => filters.product || filters.from || filters.to)
const isQcQueue = computed(() => filters.status === 'waiting_qc' && hasRole('quality_control'))

function readQuery() {
  Object.assign(filters, { status: '', product: '', from: '', to: '' }, route.query)
}

function setFilter(patch) {
  const next = { ...filters, ...patch }
  router.replace({ name: 'batches', query: Object.fromEntries(Object.entries(next).filter(([, v]) => v)) })
}

async function load() {
  loading.value = true
  let q = supabase
    .from('production_batches')
    .select('id, batch_code, production_date, target_qty, produced_qty, status, product:products(name, unit)')
    .order('production_date', { ascending: false })
    .order('batch_code', { ascending: false })
    .limit(200)
  let c = supabase.from('production_batches').select('status')
  if (filters.product) (q = q.eq('product_id', filters.product)), (c = c.eq('product_id', filters.product))
  if (filters.from) (q = q.gte('production_date', filters.from)), (c = c.gte('production_date', filters.from))
  if (filters.to) (q = q.lte('production_date', filters.to)), (c = c.lte('production_date', filters.to))
  if (filters.status) q = q.eq('status', filters.status)
  const [list, all] = await Promise.all([q, c])
  error.value = friendlyError(list.error || all.error)
  batches.value = list.data ?? []
  statusCounts.value = (all.data ?? []).reduce((acc, b) => ({ ...acc, [b.status]: (acc[b.status] ?? 0) + 1 }), {})
  loading.value = false
}

const total = computed(() => Object.values(statusCounts.value).reduce((a, b) => a + b, 0))

function yieldPct(b) {
  return b.produced_qty ? Math.min(100, Math.round((b.produced_qty / b.target_qty) * 100)) : 0
}

watch(() => route.query, () => {
  if (route.name !== 'batches') return
  readQuery()
  load()
})

onMounted(async () => {
  readQuery()
  const { data } = await supabase.from('products').select('id, name').order('name')
  products.value = data ?? []
  load()
})
</script>

<template>
  <div class="page">
    <PageHeader :title="isQcQueue ? 'Antrian QC' : 'Batch produksi'"
                :description="isQcQueue ? 'Batch yang sudah selesai diproduksi dan menunggu inspeksi.' : 'Riwayat seluruh batch beserta posisi lifecycle-nya.'">
      <template #actions>
        <RouterLink v-if="hasRole('production_staff')" :to="{ name: 'batch-new' }" class="btn btn--primary">
          <Plus :size="16" /> Buat batch
        </RouterLink>
      </template>
    </PageHeader>

    <section class="panel">
      <div class="tabs" role="tablist" aria-label="Filter status">
        <button role="tab" :aria-selected="!filters.status" class="tab" :class="{ 'is-active': !filters.status }"
                @click="setFilter({ status: '' })">
          Semua <span class="tab__count">{{ total }}</span>
        </button>
        <button v-for="s in BATCH_STATUSES" :key="s" role="tab" :aria-selected="filters.status === s" class="tab"
                :class="{ 'is-active': filters.status === s }" @click="setFilter({ status: s })">
          {{ statusLabel(s) }} <span class="tab__count">{{ statusCounts[s] ?? 0 }}</span>
        </button>
      </div>

      <div class="filters">
        <select v-model="filters.product" class="select" aria-label="Filter produk" @change="setFilter({ product: filters.product })">
          <option value="">Semua produk</option>
          <option v-for="p in products" :key="p.id" :value="String(p.id)">{{ p.name }}</option>
        </select>
        <div class="range">
          <input v-model="filters.from" type="date" class="input" aria-label="Dari tanggal" @change="setFilter({ from: filters.from })" />
          <span class="muted">–</span>
          <input v-model="filters.to" type="date" class="input" aria-label="Sampai tanggal" :min="filters.from || undefined"
                 @change="setFilter({ to: filters.to })" />
        </div>
        <button v-if="hasExtraFilters" class="btn btn--ghost btn--sm" @click="setFilter({ product: '', from: '', to: '' })">
          <X :size="14" /> Hapus filter
        </button>
        <span class="muted results">{{ loading ? '' : `${batches.length} batch` }}</span>
      </div>

      <div v-if="error" class="panel__body"><div class="alert alert--error">{{ error }}</div></div>
      <div v-else-if="loading" class="panel__body"><span v-for="i in 5" :key="i" class="skeleton" style="margin: 16px 0" /></div>
      <EmptyState v-else-if="!batches.length" :icon="Inbox" title="Tidak ada batch"
                  :description="filters.status || hasExtraFilters ? 'Tidak ada batch yang cocok dengan filter ini.' : 'Batch yang dibuat akan muncul di sini.'" />
      <div v-else class="table-wrap">
        <table class="table">
          <thead>
            <tr><th>Batch</th><th>Tanggal produksi</th><th>Hasil / Target</th><th>Status</th><th /></tr>
          </thead>
          <tbody>
            <tr v-for="b in batches" :key="b.id" class="is-clickable"
                @click="router.push({ name: 'batch-detail', params: { id: b.id } })">
              <td>
                <RouterLink :to="{ name: 'batch-detail', params: { id: b.id } }" class="mono code" @click.stop>{{ b.batch_code }}</RouterLink>
                <span class="cell-sub">{{ b.product.name }}</span>
              </td>
              <td class="muted">{{ formatDate(b.production_date) }}</td>
              <td>
                <div class="yield">
                  <span class="tnum">{{ formatNumber(b.produced_qty) }} <span class="muted">/ {{ formatNumber(b.target_qty) }} {{ b.product.unit }}</span></span>
                  <span class="yield__bar"><span :style="{ width: `${yieldPct(b)}%` }" /></span>
                </div>
              </td>
              <td><StatusChip :status="b.status" /></td>
              <td class="num chev"><ChevronRight :size="16" /></td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </div>
</template>

<style scoped>
.tabs {
  display: flex;
  gap: 20px;
  padding: 0 20px;
  border-bottom: 1px solid var(--border);
  overflow-x: auto;
}

.tab {
  position: relative;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 46px;
  padding: 0;
  border: none;
  background: none;
  color: var(--muted);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.02em;
  cursor: pointer;
  white-space: nowrap;
}

.tab:hover {
  color: var(--text);
}

.tab.is-active {
  color: var(--text);
}

.tab.is-active::after {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  bottom: -1px;
  height: 2px;
  background: var(--text);
}

.tab__count {
  padding: 0 6px;
  border-radius: 999px;
  background: var(--bg-muted);
  color: var(--muted);
  font-weight: 500;
  line-height: 18px;
  font-variant-numeric: tabular-nums;
}

.filters {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  padding: 12px 20px;
  border-bottom: 1px solid var(--border);
}

.filters .select {
  width: 200px;
  height: 32px;
}

.range {
  display: flex;
  align-items: center;
  gap: 6px;
}

.range .input {
  width: 150px;
  height: 32px;
}

.results {
  margin-left: auto;
  font-size: 12px;
}

.code {
  font-weight: 600;
}

.code:hover {
  text-decoration: underline;
  text-underline-offset: 3px;
}

.yield {
  display: flex;
  flex-direction: column;
  gap: 5px;
  width: 150px;
}

.yield__bar {
  height: 4px;
  border-radius: 999px;
  background: var(--bg-muted);
  overflow: hidden;
}

.yield__bar span {
  display: block;
  height: 100%;
  background: var(--text-2);
  border-radius: 999px;
}

.chev {
  width: 1%;
  color: var(--faint);
}
</style>
