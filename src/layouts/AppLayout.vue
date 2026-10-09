<script setup>
import { ClipboardCheck, Croissant, Layers, LayoutGrid, LogOut } from '@lucide/vue'
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { signOut, useAuth } from '@/composables/useAuth'
import { ROLE_LABELS } from '@/lib/format'

const { auth, hasRole } = useAuth()
const route = useRoute()
const router = useRouter()

const nav = computed(() => [
  { key: 'dashboard', to: { name: 'dashboard' }, label: 'Dashboard', icon: LayoutGrid },
  { key: 'batches', to: { name: 'batches' }, label: 'Batch Produksi', icon: Layers },
  ...(hasRole('quality_control')
    ? [{ key: 'qc', to: { name: 'batches', query: { status: 'waiting_qc' } }, label: 'Antrian QC', icon: ClipboardCheck }]
    : []),
  { key: 'products', to: { name: 'products' }, label: 'Produk', icon: Croissant },
])

const activeKey = computed(() => {
  if (route.name === 'dashboard') return 'dashboard'
  if (route.name === 'products') return 'products'
  if (route.name === 'batches' && route.query.status === 'waiting_qc' && hasRole('quality_control')) return 'qc'
  return route.name?.startsWith('batch') ? 'batches' : ''
})

const initials = computed(() =>
  (auth.profile?.full_name ?? '')
    .split(' ')
    .slice(0, 2)
    .map((w) => w[0])
    .join('')
    .toUpperCase(),
)

async function logout() {
  await signOut()
  router.replace({ name: 'login' })
}
</script>

<template>
  <div class="shell">
    <aside class="sidebar">
      <RouterLink :to="{ name: 'dashboard' }" class="brand">
        <span class="brand__mark">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.4"
               stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 19V5l12 14V5" /></svg>
        </span>
        <span class="brand__name">Nirmara</span>
      </RouterLink>

      <nav class="nav" aria-label="Navigasi utama">
        <p class="nav__section">Operasional</p>
        <RouterLink v-for="item in nav" :key="item.key" :to="item.to" class="nav__item"
                    :class="{ 'is-active': activeKey === item.key }">
          <component :is="item.icon" :size="16" :stroke-width="1.75" />
          {{ item.label }}
        </RouterLink>
      </nav>

      <div class="account">
        <span class="account__avatar">{{ initials }}</span>
        <div class="account__info">
          <p class="account__name">{{ auth.profile?.full_name }}</p>
          <p class="account__role">{{ ROLE_LABELS[auth.profile?.role] }}</p>
        </div>
        <button class="btn btn--ghost btn--icon" title="Keluar" aria-label="Keluar" @click="logout">
          <LogOut :size="16" :stroke-width="1.75" />
        </button>
      </div>
    </aside>

    <main class="main">
      <div class="main__inner"><RouterView /></div>
    </main>
  </div>
</template>

<style scoped>
.shell {
  display: grid;
  grid-template-columns: 236px minmax(0, 1fr);
  min-height: 100vh;
}

.sidebar {
  position: sticky;
  top: 0;
  height: 100vh;
  display: flex;
  flex-direction: column;
  padding: 16px 12px;
  background: var(--bg-subtle);
  border-right: 1px solid var(--border);
}

.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 4px 8px 20px;
}

.brand__mark {
  display: grid;
  place-items: center;
  width: 28px;
  height: 28px;
  border-radius: 7px;
  background: var(--primary);
  color: #fff;
}

.brand__name {
  font-weight: 600;
  font-size: 15px;
  letter-spacing: -0.01em;
}

.nav {
  display: flex;
  flex-direction: column;
  gap: 1px;
}

.nav__section {
  padding: 0 8px 6px;
  color: var(--faint);
  font-size: 11px;
  font-weight: 500;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.nav__item {
  display: flex;
  align-items: center;
  gap: 10px;
  height: 34px;
  padding: 0 8px;
  border-radius: var(--radius);
  color: var(--text-2);
  font-weight: 500;
  white-space: nowrap;
  transition: background-color 0.1s, color 0.1s;
}

.nav__item svg {
  color: var(--muted);
}

.nav__item:hover {
  background: var(--bg-muted);
  color: var(--text);
}

.nav__item.is-active {
  background: var(--bg);
  color: var(--text);
  box-shadow: var(--shadow-sm), 0 0 0 1px var(--border);
}

.nav__item.is-active svg {
  color: var(--accent);
}

.account {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: auto;
  padding: 10px 8px 0;
  border-top: 1px solid var(--border);
}

.account__avatar {
  display: grid;
  place-items: center;
  flex: none;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: var(--accent-soft);
  color: var(--accent);
  font-size: 12px;
  font-weight: 600;
}

.account__info {
  flex: 1;
  min-width: 0;
}

.account__name {
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.account__role {
  color: var(--muted);
  font-size: 12px;
}

.main {
  min-width: 0;
}

.main__inner {
  max-width: 1120px;
  margin: 0 auto;
  padding: 36px 40px 64px;
}

@media (max-width: 860px) {
  .shell {
    grid-template-columns: minmax(0, 1fr);
  }

  .sidebar {
    min-width: 0;
    position: sticky;
    z-index: 10;
    height: auto;
    flex-direction: row;
    align-items: center;
    gap: 4px;
    padding: 8px 12px;
    border-right: none;
    border-bottom: 1px solid var(--border);
    overflow-x: auto;
  }

  .brand {
    padding: 0 8px 0 0;
  }

  .brand__name,
  .nav__section,
  .account__info {
    display: none;
  }

  .nav {
    flex-direction: row;
  }

  .account {
    margin: 0 0 0 auto;
    padding: 0;
    border: none;
  }

  .main__inner {
    padding: 24px 16px 48px;
  }
}
</style>
