<script setup>
import { X } from '@lucide/vue'
import { onBeforeUnmount, onMounted } from 'vue'

defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  width: { type: String, default: '460px' },
})
const emit = defineEmits(['close'])

function onKey(e) {
  if (e.key === 'Escape') emit('close')
}
onMounted(() => window.addEventListener('keydown', onKey))
onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
</script>

<template>
  <Teleport to="body">
    <div class="backdrop" @mousedown.self="emit('close')">
      <section class="modal" role="dialog" aria-modal="true" :aria-label="title" :style="{ maxWidth: width }">
        <header class="modal__head">
          <div>
            <h2>{{ title }}</h2>
            <p v-if="description" class="muted">{{ description }}</p>
          </div>
          <button class="btn btn--ghost btn--icon" aria-label="Tutup" @click="emit('close')"><X :size="16" /></button>
        </header>
        <div class="modal__body"><slot /></div>
        <footer v-if="$slots.footer" class="modal__foot"><slot name="footer" /></footer>
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.backdrop {
  position: fixed;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 16px;
  background: rgba(28, 25, 23, 0.32);
  backdrop-filter: blur(2px);
  z-index: 50;
  animation: fade 0.15s ease-out;
}

.modal {
  width: 100%;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-lg);
  animation: pop 0.18s ease-out;
}

.modal__head {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
  padding: 20px 20px 0;
}

.modal__head h2 {
  font-size: 16px;
  font-weight: 600;
}

.modal__head p {
  margin-top: 4px;
}

.modal__body {
  padding: 18px 20px 20px;
}

.modal__foot {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  padding: 14px 20px;
  border-top: 1px solid var(--border);
  background: var(--bg-subtle);
  border-radius: 0 0 var(--radius-lg) var(--radius-lg);
}

@keyframes fade {
  from { opacity: 0; }
}

@keyframes pop {
  from { opacity: 0; transform: translateY(6px) scale(0.98); }
}
</style>
