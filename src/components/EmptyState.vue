<script setup>
defineProps({
  icon: { type: [Object, Function], required: true },
  title: { type: String, required: true },
  description: { type: String, default: '' },
})
</script>

<template>
  <div class="empty">
    <span class="empty__icon"><component :is="icon" :size="20" /></span>
    <p class="empty__title">{{ title }}</p>
    <p v-if="description" class="empty__desc">{{ description }}</p>
    <div v-if="$slots.default" class="empty__action"><slot /></div>
  </div>
</template>

<style scoped>
.empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 56px 24px;
  text-align: center;
}

.empty__icon {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  margin-bottom: 14px;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--muted);
  box-shadow: var(--shadow-sm);
}

.empty__title {
  font-weight: 600;
}

.empty__desc {
  max-width: 360px;
  margin-top: 4px;
  color: var(--muted);
}

.empty__action {
  margin-top: 18px;
}
</style>
