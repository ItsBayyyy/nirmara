<script setup>
import { Check, X } from '@lucide/vue'
import { computed } from 'vue'
import { formatDateTime, statusLabel } from '@/lib/format'

// times: { [status]: timestamp } diambil dari activity log
const props = defineProps({
  status: { type: String, required: true },
  times: { type: Object, default: () => ({}) },
  compact: { type: Boolean, default: false }, // hanya jam, untuk ruang sempit
})

const timeFmt = new Intl.DateTimeFormat('id-ID', { hour: '2-digit', minute: '2-digit' })
const formatTime = (t) => (props.compact ? timeFmt.format(new Date(t)) : formatDateTime(t))

const ORDER = ['planned', 'in_production', 'waiting_qc', 'quality_check']

const steps = computed(() => {
  const final = props.status === 'rejected' ? 'rejected' : 'released'
  const current = props.status === 'rejected' || props.status === 'released' ? 4 : ORDER.indexOf(props.status)
  return [...ORDER, final].map((s, i) => ({
    key: s,
    label: statusLabel(s),
    state: i < current || (i === 4 && current === 4) ? 'done' : i === current ? 'current' : 'todo',
    time: props.times[s],
  }))
})
</script>

<template>
  <ol class="stepper" :class="{ 'stepper--compact': compact }">
    <li v-for="(step, i) in steps" :key="step.key" class="step" :class="[`is-${step.state}`, `step--${step.key}`]">
      <span class="step__marker">
        <X v-if="step.key === 'rejected' && step.state === 'done'" :size="12" :stroke-width="3" />
        <Check v-else-if="step.state === 'done'" :size="12" :stroke-width="3" />
        <template v-else>{{ i + 1 }}</template>
      </span>
      <span class="step__text">
        <span class="step__label">{{ step.label }}</span>
        <span class="step__time">{{ step.time ? formatTime(step.time) : '—' }}</span>
      </span>
    </li>
  </ol>
</template>

<style scoped>
.stepper {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  margin: 0;
  padding: 0;
  list-style: none;
}

.step {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding-right: 12px;
}

.step:not(:last-child)::after {
  content: '';
  position: absolute;
  top: 11px;
  left: 30px;
  right: 6px;
  height: 1px;
  background: var(--border);
}

.step.is-done:not(:last-child)::after {
  background: var(--text);
}

.step__marker {
  display: grid;
  place-items: center;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  border: 1px solid var(--border-strong);
  background: var(--bg);
  color: var(--muted);
  font-size: 11px;
  font-weight: 600;
}

.is-done .step__marker {
  border-color: var(--text);
  background: var(--text);
  color: #fff;
}

.is-current .step__marker {
  border: 1.5px solid var(--accent);
  color: var(--accent);
  box-shadow: 0 0 0 4px var(--ring);
}

.step--released.is-done .step__marker { background: var(--success); border-color: var(--success); }
.step--rejected.is-done .step__marker { background: var(--danger); border-color: var(--danger); }

.step__text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.step__label {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.03em;
  color: var(--muted);
}

.is-done .step__label,
.is-current .step__label {
  color: var(--text);
}

.step__time {
  color: var(--faint);
  font-size: 12px;
  font-variant-numeric: tabular-nums;
}

.is-done .step__time {
  color: var(--muted);
}

.stepper--compact .step__label {
  font-size: 10px;
  letter-spacing: 0.02em;
  white-space: nowrap;
}

@media (max-width: 720px) {
  .stepper {
    grid-template-columns: 1fr;
    gap: 14px;
  }

  .step {
    flex-direction: row;
    align-items: center;
  }

  .step::after {
    display: none;
  }
}
</style>
