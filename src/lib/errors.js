// Mengubah error Supabase/PostgreSQL menjadi pesan yang bisa ditindaklanjuti pengguna.
// Pesan dari fungsi RPC (raise exception) sudah berbahasa Indonesia dan dipakai apa adanya.
export function friendlyError(error) {
  if (!error) return ''
  switch (error.code) {
    case 'invalid_credentials':
      return 'Email atau password salah.'
    case '23505':
      return 'Data dengan nilai yang sama sudah ada (misalnya SKU sudah dipakai produk lain).'
    case '23503':
      return 'Data ini sudah dipakai oleh batch produksi sehingga tidak dapat dihapus.'
    case '23514':
      return 'Isian tidak memenuhi aturan validasi.'
    default:
      break
  }
  if (error.message?.includes('row-level security') || error.message?.includes('permission denied')) {
    return 'Peran Anda tidak memiliki izin untuk aksi ini.'
  }
  if (error.message === 'Failed to fetch') {
    return 'Tidak dapat terhubung ke server. Periksa koneksi internet.'
  }
  return error.message || 'Terjadi kesalahan yang tidak diketahui.'
}
