-- =====================================================================
-- Nirmara — membuat 3 akun demo langsung lewat SQL Editor
-- (alternatif dari Authentication > Users > Add user).
-- Jalankan SETELAH schema.sql dan SEBELUM seed.sql. Aman dijalankan ulang:
-- akun yang emailnya sudah ada dilewati.
-- Password ketiga akun: Nirmara123!
-- =====================================================================

do $$
declare
  e   text;
  uid uuid;
begin
  foreach e in array array['owner@nirmara.test', 'staff@nirmara.test', 'qc@nirmara.test'] loop
    continue when exists (select 1 from auth.users where email = e);
    uid := gen_random_uuid();

    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                            raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                            confirmation_token, email_change, email_change_token_new, recovery_token)
    values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', e,
            extensions.crypt('Nirmara123!', extensions.gen_salt('bf')), now(),
            '{"provider":"email","providers":["email"]}', '{}', now(), now(),
            '', '', '', '');

    -- login email/password membutuhkan baris identitas yang terhubung
    insert into auth.identities (id, user_id, provider_id, identity_data, provider,
                                 last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), uid, uid::text,
            jsonb_build_object('sub', uid::text, 'email', e, 'email_verified', true),
            'email', now(), now(), now());
  end loop;
end $$;

select email, email_confirmed_at is not null as confirmed from auth.users order by email;
