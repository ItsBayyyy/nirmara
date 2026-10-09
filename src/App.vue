<script setup>
import { CircleAlert, CircleCheck } from '@lucide/vue'
import { useToast } from '@/composables/useToast'

const { toasts } = useToast()
</script>

<template>
  <RouterView />
  <TransitionGroup name="toast" tag="div" class="toast-stack" aria-live="polite">
    <div v-for="t in toasts" :key="t.id" class="toast" :class="`toast--${t.type}`">
      <CircleAlert v-if="t.type === 'error'" :size="16" />
      <CircleCheck v-else :size="16" />
      {{ t.message }}
    </div>
  </TransitionGroup>
</template>
