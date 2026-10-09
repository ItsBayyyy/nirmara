-- =====================================================================
-- Nirmara — data demo
-- Prasyarat: schema.sql sudah dijalankan, dan tiga akun berikut sudah dibuat
-- di Supabase Dashboard > Authentication > Users > Add user (centang Auto Confirm):
--
--   owner@nirmara.test   (Owner / Production Manager)
--   staff@nirmara.test   (Production Staff)
--   qc@nirmara.test      (Quality Control)
--   password demo untuk ketiganya: Nirmara123!
--
-- Batch demo dibuat lewat fungsi RPC yang sama dengan aplikasi (dengan
-- meniru login tiap peran), sehingga seluruh aturan bisnis ikut teruji.
-- =====================================================================

insert into public.users (id, full_name, role)
select u.id, v.full_name, v.role::public.user_role
from auth.users u
join (values ('owner@nirmara.test', 'Ayu Pratiwi',    'owner'),
             ('staff@nirmara.test', 'Komang Sudarma', 'production_staff'),
             ('qc@nirmara.test',    'Putu Lestari',   'quality_control')) as v (email, full_name, role)
  on u.email = v.email
on conflict (id) do update set full_name = excluded.full_name, role = excluded.role;

insert into public.products (sku, name, unit, status) values
  ('CRS-CHO', 'Chocolate Croissant', 'pcs', 'active'),
  ('CRS-BTR', 'Butter Croissant',    'pcs', 'active'),
  ('CIN-ROL', 'Cinnamon Roll',       'pcs', 'active'),
  ('MLK-BUN', 'Milk Bun',            'pcs', 'active'),
  ('PAR-RSN', 'Pain aux Raisins',    'pcs', 'inactive')
on conflict (sku) do nothing;

do $$
declare
  staff uuid := (select id from auth.users where email = 'staff@nirmara.test');
  qc    uuid := (select id from auth.users where email = 'qc@nirmara.test');
  r     record;
  b     public.production_batches;
  base  timestamptz;
begin
  if staff is null or qc is null then
    raise exception 'Akun berikut belum ada di Authentication > Users: %. Email yang sudah ada: %.',
      concat_ws(', ', case when staff is null then 'staff@nirmara.test' end,
                      case when qc is null then 'qc@nirmara.test' end),
      coalesce((select string_agg(email, ', ') from auth.users), '(belum ada akun)');
  end if;

  -- hari_lalu, sku, target, produced, accepted, hasil QC, catatan QC, status akhir yang diinginkan
  for r in select * from (values
      (6, 'CRS-CHO', 100, 100,  98, 'pass', null,                                          'released'),
      (5, 'CIN-ROL',  80,  78,  66, 'fail', 'Bagian bawah gosong pada satu loyang.',       'rejected'),
      (4, 'MLK-BUN', 120, 120, 110, 'pass', null,                                          'released'),
      (3, 'CRS-BTR',  90,  88,  80, 'pass', null,                                          'released'),
      (2, 'CRS-CHO', 100,  96,  85, 'pass', 'Cacat hanya kosmetik (lipatan), rasa dan kematangan sesuai standar.', 'released'),
      (1, 'CIN-ROL',  80,  80, null, null,  null,                                          'quality_check'),
      (0, 'MLK-BUN', 120, 118, null, null,  null,                                          'waiting_qc'),
      (0, 'CRS-CHO', 100, null, null, null, null,                                          'in_production'),
      (0, 'CRS-BTR',  90, null, null, null, null,                                          'planned')
    ) as t (days_ago, sku, target, produced, accepted, result, qc_note, final_status)
  loop
    perform set_config('request.jwt.claim.sub', staff::text, true);
    b := public.create_batch((select id from public.products where sku = r.sku), r.target,
                             current_date - r.days_ago, null);
    if r.final_status <> 'planned' then
      perform public.start_production(b.id);
    end if;
    if r.produced is not null then
      perform public.submit_to_qc(b.id, r.produced);
    end if;
    perform set_config('request.jwt.claim.sub', qc::text, true);
    if r.final_status in ('quality_check', 'released', 'rejected') then
      perform public.start_inspection(b.id);
    end if;
    if r.result is not null then
      perform public.submit_qc_result(b.id, r.accepted, r.produced - r.accepted,
                                      r.result::public.qc_result, r.qc_note);
    end if;

    -- waktu demo dimundurkan agar timeline terlihat realistis (hanya untuk data seed)
    base := least((current_date - r.days_ago) + time '07:00', now() - interval '5 hours');
    alter table public.production_logs disable trigger production_logs_append_only;
    alter table public.production_batches disable trigger production_batches_guard_transition;
    update public.production_logs l set created_at = base + case l.to_status
        when 'planned' then interval '0' when 'in_production' then interval '15 minutes'
        when 'waiting_qc' then interval '3 hours 30 minutes' when 'quality_check' then interval '4 hours'
        else interval '4 hours 40 minutes' end
      where l.batch_id = b.id;
    update public.production_batches set
        created_at   = base,
        started_at   = case when started_at   is not null then base + interval '15 minutes' end,
        submitted_at = case when submitted_at is not null then base + interval '3 hours 30 minutes' end
      where id = b.id;
    update public.quality_checks set inspected_at = base + interval '4 hours 40 minutes' where batch_id = b.id;
    alter table public.production_batches enable trigger production_batches_guard_transition;
    alter table public.production_logs enable trigger production_logs_append_only;
  end loop;
end $$;
