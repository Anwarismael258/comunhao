do $$
declare
  sara_id uuid;
  vida_id uuid;
  pastor_phone text := '258877688695';
  pastor_password text := 'Latifo123';
  user_metadata jsonb;
begin
  select u.id
    into sara_id
  from auth.users u
  where public.normalize_phone_auth_number(u.phone) = pastor_phone
     or public.normalize_phone_auth_number(u.raw_user_meta_data->>'phone') = pastor_phone
  limit 1;

  if sara_id is null then
    select p.id
      into sara_id
    from public.profiles p
    where public.normalize_phone_auth_number(p.phone) = pastor_phone
    limit 1;
  end if;

  sara_id := coalesce(sara_id, '00000000-0000-0000-0000-258877688695'::uuid);

  user_metadata := jsonb_build_object(
    'sub', sara_id::text,
    'full_name', 'Sara',
    'phone', pastor_phone,
    'phone_verified', true,
    'email_verified', false
  );

  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    encrypted_password,
    email_confirmed_at,
    invited_at,
    confirmation_token,
    confirmation_sent_at,
    recovery_token,
    recovery_sent_at,
    email_change_token_new,
    email_change,
    email_change_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    is_super_admin,
    created_at,
    updated_at,
    phone,
    phone_confirmed_at,
    phone_change,
    phone_change_token,
    phone_change_sent_at,
    email_change_token_current,
    email_change_confirm_status,
    banned_until,
    reauthentication_token,
    reauthentication_sent_at,
    is_sso_user,
    deleted_at,
    is_anonymous
  )
  values (
    '00000000-0000-0000-0000-000000000000',
    sara_id,
    'authenticated',
    'authenticated',
    extensions.crypt(pastor_password, extensions.gen_salt('bf')),
    null,
    null,
    '',
    null,
    '',
    null,
    '',
    '',
    null,
    null,
    jsonb_build_object(
      'provider', 'phone',
      'providers', jsonb_build_array('phone')
    ),
    user_metadata,
    false,
    now(),
    now(),
    pastor_phone,
    now(),
    '',
    '',
    null,
    '',
    0,
    null,
    '',
    null,
    false,
    null,
    false
  )
  on conflict (id) do update
    set encrypted_password = extensions.crypt(pastor_password, extensions.gen_salt('bf')),
        phone = pastor_phone,
        phone_confirmed_at = coalesce(auth.users.phone_confirmed_at, now()),
        raw_app_meta_data = jsonb_build_object(
          'provider', 'phone',
          'providers', jsonb_build_array('phone')
        ),
        raw_user_meta_data = coalesce(auth.users.raw_user_meta_data, '{}'::jsonb)
          || user_metadata,
        updated_at = now(),
        deleted_at = null;

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
    pastor_phone,
    sara_id,
    user_metadata,
    'phone',
    null,
    now(),
    now(),
    gen_random_uuid()
  )
  on conflict (provider, provider_id) do update
    set user_id = sara_id,
        identity_data = user_metadata,
        updated_at = now();

  insert into public.profiles (id, full_name, phone, birth_date)
  values (sara_id, 'Sara', '+258877688695', date '1988-09-12')
  on conflict (id) do update
    set full_name = 'Sara',
        phone = '+258877688695',
        birth_date = coalesce(public.profiles.birth_date, excluded.birth_date);

  select c.id
    into vida_id
  from public.churches c
  where lower(c.name) like '%vida nova%'
     or public.normalize_phone_auth_number(c.phone) = pastor_phone
  order by c.created_at desc nulls last
  limit 1;

  if vida_id is not null then
    update public.churches
       set active = true,
           updated_at = now()
     where id = vida_id;

    insert into public.memberships (church_id, profile_id, role, status)
    values (vida_id, sara_id, 'pastor', 'active')
    on conflict (church_id, profile_id) do update
      set role = 'pastor',
          status = 'active';

    insert into public.church_settings (church_id, owner_profile_id)
    values (vida_id, sara_id)
    on conflict (church_id) do update
      set owner_profile_id = sara_id;

    insert into public.church_subscriptions (
      church_id,
      plan_code,
      status,
      trial_started_at,
      trial_ends_at,
      current_period_started_at,
      current_period_ends_at,
      activated_at,
      admin_notes
    )
    values (
      vida_id,
      'premium',
      'trial',
      now(),
      now() + interval '90 days',
      now(),
      now() + interval '90 days',
      now(),
      'Trial Vida Nova reativado para QA de pastor, feed, agenda, publicacoes e financeiro.'
    )
    on conflict (church_id) do update
      set plan_code = 'premium',
          status = 'trial',
          trial_ends_at = greatest(
            coalesce(public.church_subscriptions.trial_ends_at, now()),
            now() + interval '90 days'
          ),
          current_period_ends_at = greatest(
            coalesce(public.church_subscriptions.current_period_ends_at, now()),
            now() + interval '90 days'
          ),
          suspended_at = null,
          cancelled_at = null,
          activated_at = coalesce(public.church_subscriptions.activated_at, now()),
          updated_at = now(),
          admin_notes = 'Trial Vida Nova reativado para QA de pastor, feed, agenda, publicacoes e financeiro.';
  end if;
end $$;
