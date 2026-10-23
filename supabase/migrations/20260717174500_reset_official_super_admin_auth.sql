do $$
declare
  admin_id uuid := 'c9c739d6-82ff-415e-af7d-581cae0fd453'::uuid;
  admin_phone text := '258841130015';
  admin_password text := 'Latifo123';
  user_metadata jsonb;
begin
  user_metadata := jsonb_build_object(
    'sub', admin_id::text,
    'full_name', 'Admin Comunhao',
    'phone', admin_phone,
    'phone_verified', true,
    'email_verified', false
  );

  update auth.users
  set encrypted_password = extensions.crypt(admin_password, extensions.gen_salt('bf')),
      phone = admin_phone,
      phone_confirmed_at = coalesce(phone_confirmed_at, now()),
      raw_app_meta_data = jsonb_build_object(
        'provider', 'phone',
        'providers', jsonb_build_array('phone')
      ),
      raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
        || user_metadata,
      updated_at = now(),
      deleted_at = null
  where id = admin_id
     or public.normalize_phone_auth_number(phone) = admin_phone
     or public.normalize_phone_auth_number(raw_user_meta_data->>'phone') = admin_phone;

  insert into auth.identities (
    provider_id,
    user_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at,
    id
  )
  values (
    admin_phone,
    admin_id,
    user_metadata,
    'phone',
    null,
    now(),
    now(),
    gen_random_uuid()
  )
  on conflict (provider, provider_id) do update
    set user_id = admin_id,
        identity_data = user_metadata,
        updated_at = now();

  insert into public.profiles (id, full_name, phone)
  values (admin_id, 'Admin Comunhao', '+258841130015')
  on conflict (id) do update
    set phone = '+258841130015',
        full_name = coalesce(nullif(public.profiles.full_name, ''), excluded.full_name);

  insert into public.platform_roles (profile_id, role, status)
  values (admin_id, 'super_admin', 'active')
  on conflict (profile_id, role) do update
    set status = 'active';
end $$;
