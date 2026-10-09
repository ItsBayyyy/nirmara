<script setup>
import { Compass } from '@lucide/vue'
import EmptyState from '@/components/EmptyState.vue'
</script>

<template>
  <div class="notfound">
    <EmptyState :icon="Compass" title="Halaman tidak ditemukan" description="Alamat yang Anda buka tidak tersedia atau sudah dipindahkan.">
      <RouterLink :to="{ name: 'dashboard' }" class="btn btn--primary">Kembali ke dashboard</RouterLink>
    </EmptyState>
  </div>
</template>

<style scoped>
.notfound {
  min-height: 100vh;
  display: grid;
  place-items: center;
}
</style>
