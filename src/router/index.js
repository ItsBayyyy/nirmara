import { createRouter, createWebHistory } from 'vue-router'
import { initAuth, useAuth } from '@/composables/useAuth'
import AppLayout from '@/layouts/AppLayout.vue'

const routes = [
  { path: '/login', name: 'login', component: () => import('@/views/LoginView.vue'), meta: { public: true } },
  {
    path: '/',
    component: AppLayout,
    children: [
      { path: '', name: 'dashboard', component: () => import('@/views/DashboardView.vue'), meta: { title: 'Dashboard' } },
      { path: 'products', name: 'products', component: () => import('@/views/ProductsView.vue'), meta: { title: 'Produk' } },
      { path: 'batches', name: 'batches', component: () => import('@/views/BatchesView.vue'), meta: { title: 'Batch Produksi' } },
      {
        path: 'batches/new',
        name: 'batch-new',
        component: () => import('@/views/BatchFormView.vue'),
        meta: { title: 'Buat Batch', roles: ['production_staff'] },
      },
      {
        path: 'batches/:id',
        name: 'batch-detail',
        component: () => import('@/views/BatchDetailView.vue'),
        meta: { title: 'Detail Batch' },
        props: true,
      },
      {
        path: 'batches/:id/inspect',
        name: 'batch-inspect',
        component: () => import('@/views/QualityInspectionView.vue'),
        meta: { title: 'Quality Inspection', roles: ['quality_control'] },
        props: true,
      },
    ],
  },
  { path: '/:pathMatch(.*)*', name: 'not-found', component: () => import('@/views/NotFoundView.vue'), meta: { public: true } },
]

const router = createRouter({ history: createWebHistory(), routes })

router.beforeEach(async (to) => {
  await initAuth()
  const { auth, hasRole } = useAuth()
  if (to.name === 'login' && auth.profile) return { name: 'dashboard' }
  if (!to.meta.public && !auth.profile) {
    return { name: 'login', query: to.fullPath !== '/' ? { redirect: to.fullPath } : {} }
  }
  // BR-06: halaman aksi hanya untuk peran yang berwenang
  if (to.meta.roles && !hasRole(...to.meta.roles)) return { name: 'dashboard' }
})

router.afterEach((to) => {
  document.title = to.meta.title ? `${to.meta.title} · Nirmara` : 'Nirmara'
})

export default router
