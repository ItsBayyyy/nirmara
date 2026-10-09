<script setup>
import { formatDateTime, statusLabel } from '@/lib/format'

defineProps({ logs: { type: Array, required: true } })
</script>

<template>
  <ol class="timeline">
    <li v-for="log in logs" :key="log.id" class="timeline__item" :class="`is-${log.to_status}`">
      <span class="timeline__dot" />
      <div class="timeline__body">
        <p class="timeline__title">
          <template v-if="log.from_status">
            {{ statusLabel(log.from_status) }} <span class="muted">→</span>
          </template>
          {{ statusLabel(log.to_status) }}
        </p>
        <p class="timeline__note">{{ log.note }}</p>
        <p class="timeline__meta">{{ log.actor?.full_name ?? '-' }} · {{ formatDateTime(log.created_at) }}</p>
      </div>
    </li>
  </ol>
</template>

<style scoped>
.timeline {
  list-style: none;
  margin: 0;
  padding: 0;
}

.timeline__item {
  position: relative;
  display: flex;
  gap: 14px;
  padding-bottom: 22px;
}

.timeline__item:last-child {
  padding-bottom: 0;
}

.timeline__item:not(:last-child)::before {
  content: '';
  position: absolute;
  left: 4px;
  top: 14px;
  bottom: -2px;
  width: 1px;
  background: var(--border);
}

.timeline__dot {
  flex: none;
  width: 9px;
  height: 9px;
  margin-top: 5px;
  border-radius: 50%;
  background: var(--bg);
  border: 2px solid var(--faint);
}

.is-in_production .timeline__dot { border-color: #3b82f6; }
.is-waiting_qc .timeline__dot { border-color: #f59e0b; }
.is-quality_check .timeline__dot { border-color: #8b5cf6; }
.is-released .timeline__dot { border-color: #22c55e; background: #22c55e; }
.is-rejected .timeline__dot { border-color: #ef4444; background: #ef4444; }

.timeline__title {
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.02em;
}

.timeline__note {
  margin-top: 2px;
  color: var(--text-2);
}

.timeline__meta {
  margin-top: 2px;
  color: var(--muted);
  font-size: 12px;
}
</style>
