<script setup>
import { ArrowRight, ClipboardCheck, Croissant, Inbox, Plus } from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import EmptyState from '@/components/EmptyState.vue'
import PageHeader from '@/components/PageHeader.vue'
import StatusChip from '@/components/StatusChip.vue'
import { useAuth } from '@/composables/useAuth'
import { friendlyError } from '@/lib/errors'
import { ACTIVE_STATUSES, formatDate, formatNumber, statusLabel } from '@/lib/format'
import { supabase } from '@/lib/supabase'

const { auth, hasRole } = useAuth()
const router = useRouter()
const stats = ref(null)
const active = ref([])
const recent = ref([])
const loading = ref(true)
const error = ref('')

onMounted(async () => {
  const cols = 'id, batch_code, production_date, target_qty, produced_qty, status, product:products(name, unit)'
  const [s, a, r] = await Promise.all([
    supabase.rpc('dashboard_stats'),
    supabase.from('production_batches').select(cols).in('status', ACTIVE_STATUSES).order('production_date'),
    supabase.from('production_batches').select(cols).order('created_at', { ascending: false }).limit(6),
  ])
  error.value = friendlyError(s.error || a.error || r.error)
  stats.value = s.data
  active.value = a.data ?? []
  recent.value = r.data ?? []
  loading.value = false
})

const greeting = computed(() => {
  const h = new Date().getHours()
  const part = h < 11 ? 'Selamat pagi' : h < 15 ? 'Selamat siang' : h < 18 ? 'Selamat sore' : 'Selamat malam'
  return `${part}, ${auth.profile?.full_name.split(' ')[0] ?? ''}`
})
const today = new Intl.DateTimeFormat('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }).format(new Date())

const passRate = computed(() => {
  const s = stats.value
  if (!s || s.released + s.rejected === 0) return null
  return Math.round((s.released * 1000) / (s.released + s.rejected)) / 10
})

const kpis = computed(() => [
  { label: 'Batch aktif', value: formatNumber(stats.value?.active_batches), sub: 'belum RELEASED / REJECTED' },
  { label: 'Menunggu QC', value: formatNumber(stats.value?.waiting_qc), sub: 'status WAITING QC' },
  { label: 'Unit diproduksi', value: formatNumber(stats.value?.units_produced), sub: 'bulan ini' },
  {
    label: 'QC pass rate',
    value: passRate.value === null ? '—' : `${passRate.value}%`,
    sub: stats.value ? `${stats.value.released} rilis · ${stats.value.rejected} ditolak bulan ini` : 'bulan ini',
  },
])

const pipeline = computed(() =>
  ACTIVE_STATUSES.map((s) => ({ status: s, count: active.value.filter((b) => b.status === s).length })),
)

// daftar tindakan mengikuti peran: staff melanjutkan produksi, QC memeriksa, owner memantau
const todo = computed(() => {
  if (hasRole('production_staff')) {
    return { title: 'Perlu tindakan Anda', hint: 'Batch yang menunggu dimulai atau dikirim ke QC',
             items: active.value.filter((b) => ['planned', 'in_production'].includes(b.status)) }
  }
  if (hasRole('quality_control')) {
    return { title: 'Perlu tindakan Anda', hint: 'Batch yang menunggu atau sedang diinspeksi',
             items: active.value.filter((b) => ['waiting_qc', 'quality_check'].includes(b.status)) }
  }
  return { title: 'Sedang berjalan', hint: 'Seluruh batch yang belum selesai', items: active.value }
})

function openBatch(b) {
  router.push({ name: 'batch-detail', params: { id: b.id } })
}
</script>

<template>
  <div class="page">
    <PageHeader :title="greeting" :description="`${today} · ringkasan produksi dan quality control`">
      <template #actions>
        <RouterLink v-if="hasRole('production_staff')" :to="{ name: 'batch-new' }" class="btn btn--primary">
          <Plus :size="16" /> Buat batch
        </RouterLink>
        <RouterLink v-if="hasRole('quality_control')" :to="{ name: 'batches', query: { status: 'waiting_qc' } }"
                    class="btn btn--primary"><ClipboardCheck :size="16" /> Antrian QC</RouterLink>
        <RouterLink v-if="hasRole('owner')" :to="{ name: 'products' }" class="btn btn--secondary">
          <Croissant :size="16" /> Kelola produk
        </RouterLink>
      </template>
    </PageHeader>

    <div v-if="error" class="alert alert--error">{{ error }}</div>

    <section class="kpis panel">
      <div v-for="k in kpis" :key="k.label" class="kpi">
        <p class="kpi__label">{{ k.label }}</p>
        <span v-if="loading" class="skeleton" style="width: 64px; height: 28px; margin: 6px 0" />
        <p v-else class="kpi__value">{{ k.value }}</p>
        <p class="kpi__sub">{{ k.sub }}</p>
      </div>
    </section>

    <section class="panel">
      <header class="panel__head">
        <h2 class="panel__title">Pipeline produksi</h2>
        <span class="muted">{{ active.length }} batch aktif</span>
      </header>
      <div class="panel__body">
        <div class="pipe-bar" role="img" :aria-label="`${active.length} batch aktif`">
          <template v-if="active.length">
            <span v-for="p in pipeline" v-show="p.count" :key="p.status" :class="`seg seg--${p.status}`"
                  :style="{ flexGrow: p.count }" />
          </template>
          <span v-else class="seg seg--empty" />
        </div>
        <div class="pipe-legend">
          <RouterLink v-for="p in pipeline" :key="p.status" :to="{ name: 'batches', query: { status: p.status } }"
                      class="pipe-item">
            <span :class="`dot dot--${p.status}`" />
            <span class="pipe-item__label">{{ statusLabel(p.status) }}</span>
            <span class="pipe-item__count tnum">{{ p.count }}</span>
          </RouterLink>
        </div>
      </div>
    </section>

    <div class="cols">
      <section class="panel">
        <header class="panel__head">
          <h2 class="panel__title">Batch terbaru</h2>
          <RouterLink :to="{ name: 'batches' }" class="btn btn--ghost btn--sm">Lihat semua <ArrowRight :size="14" /></RouterLink>
        </header>
        <div v-if="loading" class="panel__body"><span v-for="i in 4" :key="i" class="skeleton" style="margin: 14px 0" /></div>
        <EmptyState v-else-if="!recent.length" :icon="Inbox" title="Belum ada batch"
                    description="Batch yang dibuat Production Staff akan muncul di sini." />
        <div v-else class="table-wrap">
          <table class="table">
            <thead><tr><th>Batch</th><th>Tanggal</th><th class="num">Hasil / Target</th><th>Status</th></tr></thead>
            <tbody>
              <tr v-for="b in recent" :key="b.id" class="is-clickable" @click="openBatch(b)">
                <td><span class="mono strong">{{ b.batch_code }}</span><span class="cell-sub">{{ b.product.name }}</span></td>
                <td class="muted">{{ formatDate(b.production_date) }}</td>
                <td class="num">{{ formatNumber(b.produced_qty) }} <span class="muted">/ {{ formatNumber(b.target_qty) }}</span></td>
                <td><StatusChip :status="b.status" /></td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section class="panel">
        <header class="panel__head">
          <div>
            <h2 class="panel__title">{{ todo.title }}</h2>
            <p class="muted small">{{ todo.hint }}</p>
          </div>
          <span class="count-badge tnum">{{ todo.items.length }}</span>
        </header>
        <div v-if="loading" class="panel__body"><span v-for="i in 3" :key="i" class="skeleton" style="margin: 14px 0" /></div>
        <EmptyState v-else-if="!todo.items.length" :icon="ClipboardCheck" title="Semua beres"
                    description="Tidak ada batch yang menunggu tindakan Anda." />
        <ul v-else class="todo">
          <li v-for="b in todo.items" :key="b.id">
            <RouterLink :to="{ name: 'batch-detail', params: { id: b.id } }" class="todo__item">
              <div>
                <p class="mono strong">{{ b.batch_code }}</p>
                <p class="muted small">{{ b.product.name }} · {{ formatDate(b.production_date) }}</p>
              </div>
              <StatusChip :status="b.status" />
            </RouterLink>
          </li>
        </ul>
      </section>
    </div>
  </div>
</template>

<style scoped>
.kpis {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.kpi {
  padding: 18px 20px;
  border-right: 1px solid var(--border);
}

.kpi:last-child {
  border-right: none;
}

.kpi__label {
  color: var(--muted);
  font-size: 13px;
  font-weight: 500;
}

.kpi__value {
  margin: 6px 0 2px;
  font-size: 28px;
  font-weight: 600;
  letter-spacing: -0.02em;
  font-variant-numeric: tabular-nums;
}

.kpi__sub {
  color: var(--faint);
  font-size: 12px;
}

.pipe-bar {
  display: flex;
  gap: 3px;
  height: 10px;
}

.seg {
  border-radius: 3px;
  min-width: 6px;
}

.seg--planned { background: #d6d3d1; }
.seg--in_production { background: #3b82f6; }
.seg--waiting_qc { background: #f59e0b; }
.seg--quality_check { background: #8b5cf6; }
.seg--empty { flex: 1; background: var(--bg-muted); }

.pipe-legend {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
  margin-top: 16px;
}

.pipe-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  border-radius: var(--radius);
  transition: background-color 0.1s;
}

.pipe-item:hover {
  background: var(--bg-subtle);
}

.pipe-item__label {
  flex: 1;
  color: var(--text-2);
  font-size: 12px;
  font-weight: 500;
  letter-spacing: 0.02em;
}

.pipe-item__count {
  font-weight: 600;
}

.dot {
  width: 8px;
  height: 8px;
  border-radius: 2px;
}

.dot--planned { background: #d6d3d1; }
.dot--in_production { background: #3b82f6; }
.dot--waiting_qc { background: #f59e0b; }
.dot--quality_check { background: #8b5cf6; }

.cols {
  display: grid;
  grid-template-columns: minmax(0, 1.65fr) minmax(0, 1fr);
  gap: 20px;
  align-items: start;
}

.strong {
  font-weight: 600;
}

.small {
  font-size: 12px;
}

.count-badge {
  min-width: 24px;
  height: 22px;
  padding: 0 7px;
  border-radius: 999px;
  background: var(--bg-muted);
  color: var(--text-2);
  font-size: 12px;
  font-weight: 600;
  line-height: 22px;
  text-align: center;
}

.todo {
  list-style: none;
  margin: 0;
  padding: 6px;
}

.todo__item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 12px;
  border-radius: var(--radius);
}

.todo__item:hover {
  background: var(--bg-subtle);
}

@media (max-width: 960px) {
  .kpis,
  .pipe-legend {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .kpi:nth-child(2) {
    border-right: none;
  }

  .kpi:nth-child(-n + 2) {
    border-bottom: 1px solid var(--border);
  }

  .cols {
    grid-template-columns: 1fr;
  }
}
</style>
