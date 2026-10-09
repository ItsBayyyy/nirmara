<script setup>
import { ArrowLeft } from '@lucide/vue'

defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  back: { type: [Object, String], default: null },
  backLabel: { type: String, default: 'Kembali' },
})
</script>

<template>
  <header class="page-header">
    <RouterLink v-if="back" :to="back" class="page-header__back">
      <ArrowLeft :size="14" /> {{ backLabel }}
    </RouterLink>
    <div class="page-header__row">
      <div class="page-header__text">
        <h1><slot name="title">{{ title }}</slot></h1>
        <p v-if="description || $slots.description" class="muted">
          <slot name="description">{{ description }}</slot>
        </p>
      </div>
      <div v-if="$slots.actions" class="page-header__actions"><slot name="actions" /></div>
    </div>
  </header>
</template>

<style scoped>
.page-header {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.page-header__back {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  width: fit-content;
  color: var(--muted);
  font-size: 13px;
}

.page-header__back:hover {
  color: var(--text);
}

.page-header__row {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}

.page-header h1 {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 22px;
  font-weight: 600;
}

.page-header p {
  margin-top: 4px;
}

.page-header__actions {
  display: flex;
  gap: 8px;
}
</style>
