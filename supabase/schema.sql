-- =====================================================================
-- Nirmara — skema basis data (Supabase / PostgreSQL)
-- Jalankan sekali di Supabase Dashboard > SQL Editor pada proyek baru.
--
-- Prinsip: aturan bisnis (BR-01 s.d. BR-09 di SKPL) ditegakkan di basis
-- data. Tabel batch, log, dan hasil QC tidak punya policy tulis untuk
-- pengguna; semua perubahan lewat fungsi RPC di bawah, yang memeriksa
-- peran, status, dan kuantitas, lalu mencatat log dalam satu transaksi.
-- =====================================================================

create schema if not exists private;

-- ---------------------------------------------------------------------
-- Tipe enum
-- ---------------------------------------------------------------------
create type public.user_role      as enum ('production_staff', 'quality_control', 'owner');
create type public.product_status as enum ('active', 'inactive');
create type public.batch_status   as enum ('planned', 'in_production', 'waiting_qc',
                                           'quality_check', 'released', 'rejected');
create type public.qc_result      as enum ('pass', 'fail');

-- ---------------------------------------------------------------------
-- Tabel
-- ---------------------------------------------------------------------
create table public.users (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  varchar(100)     not null check (btrim(full_name) <> ''),
  role       public.user_role not null,
  created_at timestamptz      not null default now()
);

create table public.products (
  id         bigint generated always as identity primary key,
  sku        varchar(30)           not null unique check (btrim(sku) <> ''),
  name       varchar(100)          not null check (btrim(name) <> ''),
  unit       varchar(20)           not null check (btrim(unit) <> ''),
  status     public.product_status not null default 'active',
  created_at timestamptz           not null default now(),
  updated_at timestamptz           not null default now()
);

create table public.production_batches (
  id              bigint generated always as identity primary key,
  batch_code      varchar(20)         not null unique,
  product_id      bigint              not null references public.products (id) on delete restrict,
  target_qty      integer             not null check (target_qty > 0),               -- BR-03
  produced_qty    integer                      check (produced_qty > 0),             -- BR-03
  production_date date                not null,
  status          public.batch_status not null default 'planned',
  notes           text,
  created_by      uuid                not null references public.users (id),
  started_at      timestamptz,
  submitted_at    timestamptz,
  created_at      timestamptz         not null default now(),
  -- BR-03: setelah dikirim ke QC, produced_qty wajib ada
  constraint batch_produced_required
    check (status in ('planned', 'in_production') or produced_qty is not null)
);

create table public.production_logs (
  id          bigint generated always as identity primary key,
  batch_id    bigint              not null references public.production_batches (id) on delete restrict,
  actor_id    uuid                not null references public.users (id),
  from_status public.batch_status,
  to_status   public.batch_status not null,
  note        text,
  created_at  timestamptz         not null default now()
);

create table public.quality_checks (
  id               bigint generated always as identity primary key,
  batch_id         bigint           not null unique references public.production_batches (id) on delete restrict,
  inspector_id     uuid             not null references public.users (id),
  accepted_qty     integer          not null check (accepted_qty >= 0),             -- BR-04
  rejected_qty     integer          not null check (rejected_qty >= 0),             -- BR-04
  accepted_rate    numeric(5, 2)    not null check (accepted_rate between 0 and 100),
  suggested_result public.qc_result not null,
  result           public.qc_result not null,
  notes            text,
  inspected_at     timestamptz      not null default now(),
  -- BR-05: hasil yang berbeda dari saran sistem wajib disertai alasan
  constraint qc_override_needs_note
    check (result = suggested_result or nullif(btrim(notes), '') is not null)
);

create index production_batches_status_idx on public.production_batches (status);
create index production_batches_date_idx   on public.production_batches (production_date desc);
create index production_batches_product_idx on public.production_batches (product_id);
create index production_logs_batch_idx     on public.production_logs (batch_id, created_at);

-- ---------------------------------------------------------------------
-- Trigger penjaga (lapisan kedua, berlaku juga untuk admin/SQL langsung)
-- ---------------------------------------------------------------------
create function private.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger products_touch_updated_at
  before update on public.products
  for each row execute function private.touch_updated_at();

-- BR-01 dan BR-07: status hanya maju satu langkah; RELEASED/REJECTED final.
create function private.guard_batch_transition() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.status in ('released', 'rejected') then
    raise exception 'Batch % sudah final (%) dan tidak dapat diubah.',
      old.batch_code, upper(old.status::text);
  end if;
  if new.status is distinct from old.status and not (
       (old.status = 'planned'       and new.status = 'in_production')
    or (old.status = 'in_production' and new.status = 'waiting_qc')
    or (old.status = 'waiting_qc'    and new.status = 'quality_check')
    or (old.status = 'quality_check' and new.status in ('released', 'rejected'))
  ) then
    raise exception 'Transisi status dari % ke % tidak diizinkan.',
      upper(replace(old.status::text, '_', ' ')), upper(replace(new.status::text, '_', ' '));
  end if;
  return new;
end $$;

create trigger production_batches_guard_transition
  before update on public.production_batches
  for each row execute function private.guard_batch_transition();

-- BR-08: log bersifat append-only.
create function private.forbid_log_change() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'Activity log tidak dapat diubah atau dihapus.';
end $$;

create trigger production_logs_append_only
  before update or delete on public.production_logs
  for each row execute function private.forbid_log_change();

-- ---------------------------------------------------------------------
-- Helper privat (tidak terekspos sebagai RPC)
-- ---------------------------------------------------------------------
create function private.auth_role() returns public.user_role
language sql stable security definer set search_path = '' as $$
  select role from public.users where id = auth.uid()
$$;

create function private.status_label(s public.batch_status) returns text
language sql immutable set search_path = '' as $$
  select upper(replace(s::text, '_', ' '))
$$;

-- BR-06: memastikan pemanggil memiliki peran yang diminta.
create function private.require_role(p_role public.user_role) returns void
language plpgsql stable security definer set search_path = '' as $$
declare
  labels constant jsonb := '{"production_staff":"Production Staff","quality_control":"Quality Control","owner":"Owner"}';
begin
  if auth.uid() is null then
    raise exception 'Sesi login tidak ditemukan. Silakan login ulang.' using errcode = '42501';
  end if;
  if private.auth_role() is distinct from p_role then
    raise exception 'Aksi ini hanya dapat dilakukan oleh %.', labels ->> p_role::text using errcode = '42501';
  end if;
end $$;

-- Mengunci batch dan memastikan statusnya sesuai sebelum aksi.
create function private.lock_batch(p_batch_id bigint, p_expected public.batch_status)
returns public.production_batches
language plpgsql security definer set search_path = '' as $$
declare
  b public.production_batches;
begin
  select * into b from public.production_batches where id = p_batch_id for update;
  if not found then
    raise exception 'Batch tidak ditemukan.';
  end if;
  if b.status <> p_expected then
    raise exception 'Batch % berstatus %; aksi ini hanya untuk batch berstatus %.',
      b.batch_code, private.status_label(b.status), private.status_label(p_expected);
  end if;
  return b;
end $$;

create function private.log_status(p_batch_id bigint, p_from public.batch_status,
                                   p_to public.batch_status, p_note text default null)
returns void
language sql security definer set search_path = '' as $$
  insert into public.production_logs (batch_id, actor_id, from_status, to_status, note)
  values (p_batch_id, auth.uid(), p_from, p_to, p_note)
$$;

-- ---------------------------------------------------------------------
-- RPC: lifecycle batch
-- ---------------------------------------------------------------------
-- SKPL-F-04.0 Membuat batch (BR-02, BR-03, BR-09)
create function public.create_batch(p_product_id bigint, p_target_qty integer,
                                    p_production_date date, p_notes text default null)
returns public.production_batches
language plpgsql security definer set search_path = '' as $$
declare
  prod public.products;
  seq  integer;
  b    public.production_batches;
begin
  perform private.require_role('production_staff');

  select * into prod from public.products where id = p_product_id;
  if not found then
    raise exception 'Produk tidak ditemukan.';
  end if;
  if prod.status <> 'active' then
    raise exception 'Produk % sedang nonaktif dan tidak dapat diproduksi.', prod.name;
  end if;
  if p_target_qty is null or p_target_qty <= 0 then
    raise exception 'Target quantity harus lebih dari 0.';
  end if;
  if p_production_date is null then
    raise exception 'Tanggal produksi wajib diisi.';
  end if;

  -- nomor urut per tanggal produksi; kunci mencegah kode ganda saat dibuat bersamaan
  perform pg_advisory_xact_lock(hashtext('batch_code:' || p_production_date::text));
  select coalesce(max(substring(batch_code from 11)::integer), 0) + 1 into seq
    from public.production_batches where production_date = p_production_date;

  insert into public.production_batches (batch_code, product_id, target_qty, production_date, notes, created_by)
  values ('BT-' || to_char(p_production_date, 'YYMMDD') || '-' || lpad(seq::text, 3, '0'),
          p_product_id, p_target_qty, p_production_date, nullif(btrim(p_notes), ''), auth.uid())
  returning * into b;

  perform private.log_status(b.id, null, 'planned', 'Batch dibuat');
  return b;
end $$;

-- SKPL-F-05.0 Memulai produksi
create function public.start_production(p_batch_id bigint)
returns public.production_batches
language plpgsql security definer set search_path = '' as $$
declare
  b public.production_batches;
begin
  perform private.require_role('production_staff');
  b := private.lock_batch(p_batch_id, 'planned');
  update public.production_batches
     set status = 'in_production', started_at = now()
   where id = b.id returning * into b;
  perform private.log_status(b.id, 'planned', 'in_production', 'Produksi dimulai');
  return b;
end $$;

-- SKPL-F-05.1 Mengisi hasil produksi dan mengirim ke QC
create function public.submit_to_qc(p_batch_id bigint, p_produced_qty integer)
returns public.production_batches
language plpgsql security definer set search_path = '' as $$
declare
  b public.production_batches;
begin
  perform private.require_role('production_staff');
  b := private.lock_batch(p_batch_id, 'in_production');
  if p_produced_qty is null or p_produced_qty <= 0 then
    raise exception 'Produced quantity harus lebih dari 0.';
  end if;
  update public.production_batches
     set status = 'waiting_qc', produced_qty = p_produced_qty, submitted_at = now()
   where id = b.id returning * into b;
  perform private.log_status(b.id, 'in_production', 'waiting_qc',
                             format('Hasil produksi %s unit dikirim ke QC', p_produced_qty));
  return b;
end $$;

-- SKPL-F-06.0 Memulai inspeksi
create function public.start_inspection(p_batch_id bigint)
returns public.production_batches
language plpgsql security definer set search_path = '' as $$
declare
  b public.production_batches;
begin
  perform private.require_role('quality_control');
  b := private.lock_batch(p_batch_id, 'waiting_qc');
  update public.production_batches set status = 'quality_check'
   where id = b.id returning * into b;
  perform private.log_status(b.id, 'waiting_qc', 'quality_check', 'Inspeksi dimulai');
  return b;
end $$;

-- SKPL-F-06.1 & F-06.2 Mencatat hasil inspeksi dan menetapkan PASS/FAIL (BR-04, BR-05, BR-07)
create function public.submit_qc_result(p_batch_id bigint, p_accepted_qty integer, p_rejected_qty integer,
                                        p_result public.qc_result, p_notes text default null)
returns public.quality_checks
language plpgsql security definer set search_path = '' as $$
declare
  pass_threshold constant numeric := 90;
  b         public.production_batches;
  rate      numeric(5, 2);
  suggested public.qc_result;
  qc        public.quality_checks;
  final     public.batch_status;
begin
  perform private.require_role('quality_control');
  b := private.lock_batch(p_batch_id, 'quality_check');

  if p_accepted_qty is null or p_rejected_qty is null or p_accepted_qty < 0 or p_rejected_qty < 0 then
    raise exception 'Accepted dan rejected quantity wajib diisi dan tidak boleh negatif.';
  end if;
  if p_accepted_qty + p_rejected_qty <> b.produced_qty then
    raise exception 'Accepted (%) + rejected (%) harus sama dengan produced quantity (%).',
      p_accepted_qty, p_rejected_qty, b.produced_qty;
  end if;
  if p_result is null then
    raise exception 'Hasil QC (PASS/FAIL) wajib dipilih.';
  end if;

  rate := round(p_accepted_qty * 100.0 / b.produced_qty, 2);
  suggested := case when rate >= pass_threshold then 'pass' else 'fail' end;
  if p_result <> suggested and nullif(btrim(p_notes), '') is null then
    raise exception 'Hasil berbeda dari saran sistem (%); catatan alasan wajib diisi.', upper(suggested::text);
  end if;

  insert into public.quality_checks (batch_id, inspector_id, accepted_qty, rejected_qty,
                                     accepted_rate, suggested_result, result, notes)
  values (b.id, auth.uid(), p_accepted_qty, p_rejected_qty, rate, suggested, p_result, nullif(btrim(p_notes), ''))
  returning * into qc;

  final := case when p_result = 'pass' then 'released' else 'rejected' end;
  update public.production_batches set status = final where id = b.id;
  perform private.log_status(b.id, 'quality_check', final,
                             format('QC %s: %s accepted, %s rejected (%s%%)',
                                    upper(p_result::text), p_accepted_qty, p_rejected_qty, rate));
  return qc;
end $$;

-- SKPL-F-02.0 Ringkasan dashboard (bulan berjalan untuk unit dan pass rate)
create function public.dashboard_stats()
returns json
language sql stable set search_path = '' as $$
  select json_build_object(
    'active_batches', count(*) filter (where status in ('planned', 'in_production', 'waiting_qc', 'quality_check')),
    'waiting_qc',     count(*) filter (where status = 'waiting_qc'),
    'units_produced', coalesce(sum(produced_qty) filter (
                        where produced_qty is not null
                          and date_trunc('month', production_date) = date_trunc('month', current_date)), 0),
    'released',       count(*) filter (where status = 'released'
                          and date_trunc('month', production_date) = date_trunc('month', current_date)),
    'rejected',       count(*) filter (where status = 'rejected'
                          and date_trunc('month', production_date) = date_trunc('month', current_date))
  )
  from public.production_batches
$$;

-- ---------------------------------------------------------------------
-- Hak akses dan Row Level Security
-- ---------------------------------------------------------------------
alter table public.users              enable row level security;
alter table public.products           enable row level security;
alter table public.production_batches enable row level security;
alter table public.production_logs    enable row level security;
alter table public.quality_checks     enable row level security;

-- semua pengguna login dapat membaca seluruh data operasional
create policy "users dapat dibaca pengguna login" on public.users
  for select to authenticated using (true);
create policy "produk dapat dibaca pengguna login" on public.products
  for select to authenticated using (true);
create policy "batch dapat dibaca pengguna login" on public.production_batches
  for select to authenticated using (true);
create policy "log dapat dibaca pengguna login" on public.production_logs
  for select to authenticated using (true);
create policy "hasil QC dapat dibaca pengguna login" on public.quality_checks
  for select to authenticated using (true);

-- BR-06: hanya Owner yang mengelola produk
create policy "owner menambah produk" on public.products
  for insert to authenticated with check ((select private.auth_role()) = 'owner');
create policy "owner mengubah produk" on public.products
  for update to authenticated
  using ((select private.auth_role()) = 'owner') with check ((select private.auth_role()) = 'owner');
create policy "owner menghapus produk" on public.products
  for delete to authenticated using ((select private.auth_role()) = 'owner');

revoke all on all tables in schema public from anon;
grant usage on schema public to authenticated;
grant select on all tables in schema public to authenticated;
grant insert, update, delete on public.products to authenticated;

grant usage on schema private to authenticated;
revoke all on all functions in schema private from public, anon;
grant execute on function private.auth_role() to authenticated;

revoke all on function public.create_batch(bigint, integer, date, text)                       from public, anon;
revoke all on function public.start_production(bigint)                                        from public, anon;
revoke all on function public.submit_to_qc(bigint, integer)                                   from public, anon;
revoke all on function public.start_inspection(bigint)                                        from public, anon;
revoke all on function public.submit_qc_result(bigint, integer, integer, public.qc_result, text) from public, anon;
revoke all on function public.dashboard_stats()                                               from public, anon;
grant execute on function public.create_batch(bigint, integer, date, text)                       to authenticated;
grant execute on function public.start_production(bigint)                                        to authenticated;
grant execute on function public.submit_to_qc(bigint, integer)                                   to authenticated;
grant execute on function public.start_inspection(bigint)                                        to authenticated;
grant execute on function public.submit_qc_result(bigint, integer, integer, public.qc_result, text) to authenticated;
grant execute on function public.dashboard_stats()                                               to authenticated;
