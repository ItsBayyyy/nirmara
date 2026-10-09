<script setup>
import { statusLabel } from '@/lib/format'

defineProps({ status: { type: String, required: true } })
</script>

<template>
  <span class="chip" :class="`chip--${status}`">{{ statusLabel(status) }}</span>
</template>

<style scoped>
.chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 22px;
  padding: 0 8px;
  border: 1px solid;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.02em;
  white-space: nowrap;
}

.chip::before {
  content: '';
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--dot);
}

.chip--planned { --dot: #a8a29e; color: #57534e; background: #fafaf9; border-color: #e7e5e4; }
.chip--in_production { --dot: #3b82f6; color: #1d4ed8; background: #eff6ff; border-color: #dbeafe; }
.chip--waiting_qc { --dot: #f59e0b; color: #b45309; background: #fffbeb; border-color: #fde68a; }
.chip--quality_check { --dot: #8b5cf6; color: #6d28d9; background: #f5f3ff; border-color: #e9d5ff; }
.chip--released,
.chip--pass { --dot: #22c55e; color: #15803d; background: #f0fdf4; border-color: #bbf7d0; }
.chip--rejected,
.chip--fail { --dot: #ef4444; color: #b91c1c; background: #fef2f2; border-color: #fecaca; }
</style>
