<script setup>
import { CircleAlert, Croissant, Pencil, Plus, Search, Trash2 } from '@lucide/vue'
import { computed, onMounted, reactive, ref } from 'vue'
import BaseModal from '@/components/BaseModal.vue'
import EmptyState from '@/components/EmptyState.vue'
import PageHeader from '@/components/PageHeader.vue'
import { useAuth } from '@/composables/useAuth'
import { useToast } from '@/composables/useToast'
import { friendlyError } from '@/lib/errors'
import { formatDate } from '@/lib/format'
import { supabase } from '@/lib/supabase'

const { hasRole } = useAuth()
const { show } = useToast()
const canManage = computed(() => hasRole('owner'))

const products = ref([])
const loading = ref(true)
const loadError = ref('')
const search = ref('')
const statusFilter = ref('')

const counts = computed(() => ({
  '': products.value.length,
  active: products.value.filter((p) => p.status === 'active').length,
  inactive: products.value.filter((p) => p.status === 'inactive').length,
}))

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return products.value.filter(
    (p) =>
      (!statusFilter.value || p.status === statusFilter.value) &&
      (!q || p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q)),
  )
})

async function load() {
  const { data, error } = await supabase.from('products').select('*').order('name')
  loadError.value = friendlyError(error)
  products.value = data ?? []
  loading.value = false
}
onMounted(load)

// ---------- form tambah / ubah ----------
const editing = ref(null) // null = tertutup, {} = tambah, produk = ubah
const form = reactive({ sku: '', name: '', unit: 'pcs', status: 'active' })
const errors = reactive({})
const formError = ref('')
const saving = ref(false)

function openForm(product = {}) {
  editing.value = product
  Object.assign(form, { sku: '', name: '', unit: 'pcs', status: 'active' }, product)
  Object.keys(errors).forEach((k) => delete errors[k])
  formError.value = ''
}

function validate() {
  Object.keys(errors).forEach((k) => delete errors[k])
  form.sku = form.sku.trim().toUpperCase()
  if (!form.sku) errors.sku = 'SKU wajib diisi.'
  else if (!/^[A-Z0-9-]{2,30}$/.test(form.sku)) errors.sku = 'Gunakan 2–30 karakter huruf, angka, atau tanda hubung.'
  if (!form.name.trim()) errors.name = 'Nama produk wajib diisi.'
  if (!form.unit.trim()) errors.unit = 'Satuan wajib diisi.'
  return !Object.keys(errors).length
}

async function save() {
  if (!validate()) return
  saving.value = true
  const payload = { sku: form.sku, name: form.name.trim(), unit: form.unit.trim(), status: form.status }
  const { error } = editing.value.id
    ? await supabase.from('products').update(payload).eq('id', editing.value.id)
    : await supabase.from('products').insert(payload)
  saving.value = false
  if (error) {
    if (error.code === '23505') errors.sku = 'SKU sudah dipakai produk lain.'
    else formError.value = friendlyError(error)
    return
  }
  show(editing.value.id ? 'Produk diperbarui' : 'Produk ditambahkan')
  editing.value = null
  load()
}

// ---------- hapus / nonaktifkan (BR-09) ----------
const deleting = ref(null)
const deleteBlocked = ref(false)
const deleteError = ref('')

function openDelete(product) {
  deleting.value = product
  deleteBlocked.value = false
  deleteError.value = ''
}

async function confirmDelete() {
  const { error } = await supabase.from('products').delete().eq('id', deleting.value.id)
  if (error) {
    if (error.code === '23503') deleteBlocked.value = true
    else deleteError.value = friendlyError(error)
    return
  }
  show('Produk dihapus')
  deleting.value = null
  load()
}

async function deactivate(product) {
  const { error } = await supabase.from('products').update({ status: 'inactive' }).eq('id', product.id)
  if (error) return show(friendlyError(error), 'error')
  show(`${product.name} dinonaktifkan`)
  deleting.value = null
  load()
}
</script>

<template>
  <div class="page">
    <PageHeader title="Produk" description="Data master produk yang dapat diproduksi dalam batch.">
      <template #actions>
        <button v-if="canManage" class="btn btn--primary" @click="openForm()"><Plus :size="16" /> Tambah produk</button>
      </template>
    </PageHeader>

    <section class="panel">
      <header class="panel__head">
        <div class="segmented" role="tablist" aria-label="Filter status produk">
          <button v-for="opt in [['', 'Semua'], ['active', 'Aktif'], ['inactive', 'Nonaktif']]" :key="opt[0]"
                  role="tab" :aria-selected="statusFilter === opt[0]" :class="{ 'is-active': statusFilter === opt[0] }"
                  @click="statusFilter = opt[0]">
            {{ opt[1] }} <span class="count">{{ counts[opt[0]] }}</span>
          </button>
        </div>
        <div class="input-affix search">
          <Search :size="16" />
          <input v-model="search" class="input" type="search" placeholder="Cari nama atau SKU" aria-label="Cari produk" />
        </div>
      </header>

      <div v-if="loadError" class="panel__body"><div class="alert alert--error">{{ loadError }}</div></div>
      <div v-else-if="loading" class="panel__body"><span v-for="i in 4" :key="i" class="skeleton" style="margin: 14px 0" /></div>
      <EmptyState v-else-if="!products.length" :icon="Croissant" title="Belum ada produk"
                  description="Tambahkan produk pertama agar Production Staff dapat membuat batch.">
        <button v-if="canManage" class="btn btn--primary" @click="openForm()"><Plus :size="16" /> Tambah produk</button>
      </EmptyState>
      <EmptyState v-else-if="!filtered.length" :icon="Search" title="Tidak ada yang cocok"
                  description="Coba kata kunci lain atau ubah filter status." />
      <div v-else class="table-wrap">
        <table class="table">
          <thead>
            <tr><th>Produk</th><th>SKU</th><th>Satuan</th><th>Status</th><th>Diperbarui</th><th v-if="canManage" /></tr>
          </thead>
          <tbody>
            <tr v-for="p in filtered" :key="p.id">
              <td class="name">{{ p.name }}</td>
              <td class="mono muted">{{ p.sku }}</td>
              <td class="muted">{{ p.unit }}</td>
              <td>
                <span class="pill" :class="p.status === 'active' ? 'pill--on' : 'pill--off'">
                  {{ p.status === 'active' ? 'Aktif' : 'Nonaktif' }}
                </span>
              </td>
              <td class="muted">{{ formatDate(p.updated_at) }}</td>
              <td v-if="canManage" class="num actions">
                <button class="btn btn--ghost btn--icon" :aria-label="`Ubah ${p.name}`" title="Ubah" @click="openForm(p)">
                  <Pencil :size="15" />
                </button>
                <button class="btn btn--ghost btn--icon danger" :aria-label="`Hapus ${p.name}`" title="Hapus" @click="openDelete(p)">
                  <Trash2 :size="15" />
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <BaseModal v-if="editing" :title="editing.id ? 'Ubah produk' : 'Tambah produk'"
               :description="editing.id ? editing.name : 'Produk aktif dapat langsung dipilih saat membuat batch.'"
               @close="editing = null">
      <form id="product-form" class="form-grid" novalidate @submit.prevent="save">
        <div v-if="formError" class="alert alert--error"><CircleAlert :size="16" /><span>{{ formError }}</span></div>
        <div class="field">
          <label for="name">Nama produk</label>
          <input id="name" v-model="form.name" class="input" :class="{ 'input--invalid': errors.name }" placeholder="Chocolate Croissant" />
          <span v-if="errors.name" class="error">{{ errors.name }}</span>
        </div>
        <div class="form-grid form-grid--2">
          <div class="field">
            <label for="sku">SKU</label>
            <input id="sku" v-model="form.sku" class="input mono" :class="{ 'input--invalid': errors.sku }" placeholder="CRS-CHO" />
            <span v-if="errors.sku" class="error">{{ errors.sku }}</span>
          </div>
          <div class="field">
            <label for="unit">Satuan</label>
            <input id="unit" v-model="form.unit" class="input" :class="{ 'input--invalid': errors.unit }" list="unit-options" />
            <datalist id="unit-options"><option value="pcs" /><option value="loyang" /><option value="box" /></datalist>
            <span v-if="errors.unit" class="error">{{ errors.unit }}</span>
          </div>
        </div>
        <div class="field">
          <span class="label">Status</span>
          <div class="segmented">
            <button type="button" :class="{ 'is-active': form.status === 'active' }" @click="form.status = 'active'">Aktif</button>
            <button type="button" :class="{ 'is-active': form.status === 'inactive' }" @click="form.status = 'inactive'">Nonaktif</button>
          </div>
          <span class="hint">Produk nonaktif tidak dapat dipilih untuk batch baru.</span>
        </div>
      </form>
      <template #footer>
        <button class="btn btn--secondary" @click="editing = null">Batal</button>
        <button class="btn btn--primary" type="submit" form="product-form" :disabled="saving">
          {{ saving ? 'Menyimpan…' : 'Simpan' }}
        </button>
      </template>
    </BaseModal>

    <BaseModal v-if="deleting" :title="deleteBlocked ? 'Produk sedang dipakai' : 'Hapus produk?'" @close="deleting = null">
      <p v-if="!deleteBlocked">
        <strong>{{ deleting.name }}</strong> <span class="mono muted">({{ deleting.sku }})</span> akan dihapus permanen.
      </p>
      <p v-else>
        <strong>{{ deleting.name }}</strong> sudah dipakai oleh batch produksi, sehingga tidak dapat dihapus agar riwayat
        batch tetap utuh. Nonaktifkan produk ini supaya tidak bisa dipilih untuk batch baru.
      </p>
      <div v-if="deleteError" class="alert alert--error" style="margin-top: 14px"><CircleAlert :size="16" /><span>{{ deleteError }}</span></div>
      <template #footer>
        <button class="btn btn--secondary" @click="deleting = null">Batal</button>
        <button v-if="deleteBlocked && deleting.status === 'active'" class="btn btn--primary" @click="deactivate(deleting)">
          Nonaktifkan
        </button>
        <button v-if="!deleteBlocked" class="btn btn--danger" @click="confirmDelete">Hapus</button>
      </template>
    </BaseModal>
  </div>
</template>

<style scoped>
.search {
  width: 260px;
}

.name {
  font-weight: 500;
}

.pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: var(--text-2);
}

.pill::before {
  content: '';
  width: 6px;
  height: 6px;
  border-radius: 50%;
}

.pill--on::before {
  background: #22c55e;
}

.pill--off {
  color: var(--muted);
}

.pill--off::before {
  background: var(--border-strong);
}

.actions {
  width: 1%;
}

.actions .btn {
  color: var(--muted);
}

.actions .danger:hover {
  background: var(--danger-soft);
  color: var(--danger);
}

@media (max-width: 720px) {
  .search {
    width: 100%;
  }

  .panel__head {
    flex-wrap: wrap;
  }
}
</style>
