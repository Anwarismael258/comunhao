create or replace function public.register_phone_auth_user(
  p_full_name text,
  p_phone text,
  p_password text,
  p_birth_date date default null,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  user_id uuid := gen_random_uuid();
  normalized_phone text := public.normalize_phone_auth_number(p_phone);
  normalized_name text := nullif(trim(coalesce(p_full_name, '')), '');
  user_metadata jsonb;
begin
  if normalized_name is null then
    raise exception 'O nome completo e obrigatorio.';
  end if;

  if normalized_phone = '' then
    raise exception 'Numero de telefone invalido.';
  end if;

  if char_length(coalesce(p_password, '')) < 6 then
    raise exception 'A palavra-passe deve ter pelo menos 6 caracteres.';
  end if;

  if exists (
    select 1
    from auth.users
    where phone = normalized_phone
      and deleted_at is null
  ) then
    raise exception 'Ja existe uma conta com este numero de telefone.';
  end if;

  user_metadata := coalesce(p_metadata, '{}'::jsonb)
    || jsonb_build_object(
      'sub', user_id::text,
      'full_name', normalized_name,
      'phone', normalized_phone,
      'phone_verified', false,
      'email_verified', false
    );

  if p_birth_date is not null then
    user_metadata := user_metadata || jsonb_build_object(
      'birth_date', p_birth_date::text
    );
  end if;

  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
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
    user_id,
    'authenticated',
    'authenticated',
    null,
    extensions.crypt(p_password, extensions.gen_salt('bf')),
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
    normalized_phone,
    null,
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
  );

  insert into auth.identities (
    provider_id,
    user_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at,
    email,
    id
  )
  values (
    normalized_phone,
    user_id,
    user_metadata,
    'phone',
    null,
    now(),
    now(),
    null,
    gen_random_uuid()
  );

  perform public.request_phone_auth_otp(
    normalized_phone,
    'signup'
  );

  return jsonb_build_object(
    'user_id', user_id,
    'phone', normalized_phone,
    'requires_otp', true
  );
exception
  when unique_violation then
    raise exception 'Ja existe uma conta com este numero de telefone.';
end;
$$;

create or replace function public.verify_phone_auth_otp(
  p_phone text,
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  normalized_phone text := public.normalize_phone_auth_number(p_phone);
  normalized_token text := public.normalize_phone_auth_number(p_token);
  otp_row public.phone_auth_otps%rowtype;
  expected_hash text;
  verified_user_id uuid;
  merged_metadata jsonb;
begin
  if normalized_phone = '' then
    raise exception 'Numero de telefone invalido.';
  end if;

  if char_length(normalized_token) <> 6 then
    raise exception 'O codigo OTP deve ter 6 digitos.';
  end if;

  update public.phone_auth_otps
  set status = 'expired'
  where phone = normalized_phone
    and status = 'pending'
    and expires_at < now();

  select *
  into otp_row
  from public.phone_auth_otps
  where phone = normalized_phone
    and status = 'pending'
  order by created_at desc
  limit 1
  for update;

  if not found then
    raise exception 'Nao existe nenhum codigo ativo para este numero.';
  end if;

  expected_hash := encode(
    extensions.digest(normalized_phone || ':' || normalized_token, 'sha256'),
    'hex'
  );

  if otp_row.otp_hash <> expected_hash then
    update public.phone_auth_otps
    set
      attempts = attempts + 1,
      status = case
        when attempts + 1 >= 5 then 'cancelled'
        else status
      end
    where id = otp_row.id;

    raise exception 'Codigo OTP invalido.';
  end if;

  update public.phone_auth_otps
  set
    attempts = attempts + 1,
    status = 'verified',
    verified_at = now()
  where id = otp_row.id
  returning auth_user_id
  into verified_user_id;

  select coalesce(raw_user_meta_data, '{}'::jsonb)
  into merged_metadata
  from auth.users
  where id = verified_user_id
  limit 1;

  merged_metadata := merged_metadata
    || jsonb_build_object(
      'phone', normalized_phone,
      'phone_verified', true,
      'phone_verified_at', now()
    );

  update auth.users
  set
    phone = normalized_phone,
    phone_confirmed_at = now(),
    raw_user_meta_data = merged_metadata,
    updated_at = now()
  where id = verified_user_id;

  update auth.identities
  set
    provider_id = normalized_phone,
    identity_data = coalesce(identity_data, '{}'::jsonb)
      || jsonb_build_object(
        'phone', normalized_phone,
        'phone_verified', true,
        'phone_verified_at', now()
      ),
    updated_at = now()
  where user_id = verified_user_id
    and provider = 'phone';

  update public.profiles
  set phone = normalized_phone
  where id = verified_user_id;

  update public.phone_auth_otps
  set status = 'cancelled'
  where phone = normalized_phone
    and status = 'pending'
    and id <> otp_row.id;

  return jsonb_build_object(
    'user_id', verified_user_id,
    'phone', normalized_phone,
    'verified_at', now()
  );
end;
$$;

grant execute on function public.register_phone_auth_user(text, text, text, date, jsonb) to anon, authenticated;
grant execute on function public.verify_phone_auth_otp(text, text) to anon, authenticated;
