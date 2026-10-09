# Nirmara — Aplikasi

Sistem informasi manajemen dan pelacakan batch produksi bakery (tugas wildcard RPL).
Front-end Vue 3 + Vite, back-end Supabase (PostgreSQL + Auth).

## Struktur

```
app/
├── supabase/
│   ├── schema.sql   # tabel, enum, trigger, fungsi RPC, RLS (BR-01 s.d. BR-09)
│   └── seed.sql     # data demo: 3 pengguna, 5 produk, 9 batch di semua status
└── src/
    ├── lib/          # klien Supabase, format, pesan error
    ├── composables/  # useAuth (sesi + peran), useToast
    ├── router/       # rute + guard login dan peran
    ├── layouts/      # sidebar + konten
    ├── components/   # StatusChip, BaseModal, ActivityTimeline
    └── views/        # Login, Dashboard, Produk, Batch, Detail Batch, Quality Inspection
```

## Setup Supabase (sekali)

1. Buat proyek baru di <https://supabase.com/dashboard>.
2. **SQL Editor** → tempel isi `supabase/schema.sql` → Run.
3. **Authentication → Users → Add user → Create new user** (centang *Auto Confirm User*), buat tiga akun:

   | Email | Peran |
   |---|---|
   | `owner@nirmara.test` | Owner / Production Manager |
   | `staff@nirmara.test` | Production Staff |
   | `qc@nirmara.test` | Quality Control |

   Password demo untuk ketiganya: `Nirmara123!`

   Alternatif cepat: jalankan `supabase/demo_users.sql` di SQL Editor untuk membuat ketiga akun sekaligus.
4. **SQL Editor** → tempel isi `supabase/seed.sql` → Run.
5. **Project Settings → API**: salin *Project URL* dan *Publishable key*.

## Menjalankan

```bash
cp .env.example .env.local   # lalu isi VITE_SUPABASE_URL dan VITE_SUPABASE_PUBLISHABLE_KEY
npm install
npm run dev                  # http://localhost:5173
```

## Peta fitur ke SKPL

| Kebutuhan | Halaman / fungsi |
|---|---|
| F-01 Login, logout | `LoginView`, tombol logout di sidebar |
| F-02 Dashboard | `DashboardView` + RPC `dashboard_stats` |
| F-03 CRUD produk (Owner) | `ProductsView` + RLS tabel `products` |
| F-04 Buat batch | `BatchFormView` + RPC `create_batch` |
| F-05 Mulai produksi, kirim ke QC | `BatchDetailView` + RPC `start_production`, `submit_to_qc` |
| F-06 Inspeksi & hasil QC | `BatchDetailView`, `QualityInspectionView` + RPC `start_inspection`, `submit_qc_result` |
| F-07 Riwayat, filter, detail, timeline | `BatchesView`, `BatchDetailView` |
| F-08 Activity log otomatis | dicatat di dalam setiap RPC; tabel `production_logs` append-only |

Aturan bisnis ditegakkan di basis data, bukan hanya di antarmuka: tabel batch, log, dan hasil QC
tidak dapat ditulis langsung oleh pengguna (hanya lewat RPC), dan trigger menolak lompatan status
serta perubahan batch yang sudah final walaupun dilakukan oleh admin.
