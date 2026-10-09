import { reactive } from 'vue'

const toasts = reactive([])
let nextId = 1

export function useToast() {
  function show(message, type = 'success') {
    const id = nextId++
    toasts.push({ id, message, type })
    setTimeout(() => {
      const i = toasts.findIndex((t) => t.id === id)
      if (i !== -1) toasts.splice(i, 1)
    }, 4000)
  }
  return { toasts, show }
}
