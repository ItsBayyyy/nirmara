export const BATCH_STATUSES = ['planned', 'in_production', 'waiting_qc', 'quality_check', 'released', 'rejected']
export const ACTIVE_STATUSES = ['planned', 'in_production', 'waiting_qc', 'quality_check']

export const ROLE_LABELS = {
  production_staff: 'Production Staff',
  quality_control: 'Quality Control',
  owner: 'Owner',
}

export const PASS_THRESHOLD = 90 // sama dengan ambang di fungsi submit_qc_result (BR-05)

export function statusLabel(status) {
  return status ? status.replaceAll('_', ' ').toUpperCase() : '—'
}

const dateFmt = new Intl.DateTimeFormat('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })
const dateTimeFmt = new Intl.DateTimeFormat('id-ID', {
  day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
})
const numberFmt = new Intl.NumberFormat('id-ID')

export function formatDate(value) {
  return value ? dateFmt.format(new Date(value)) : '—'
}

export function formatDateTime(value) {
  return value ? dateTimeFmt.format(new Date(value)) : '—'
}

export function formatNumber(value) {
  return value === null || value === undefined ? '—' : numberFmt.format(value)
}

export function todayISO() {
  const d = new Date()
  return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 10)
}

export function acceptedRate(accepted, produced) {
  return produced > 0 ? Math.round((accepted * 10000) / produced) / 100 : 0
}
