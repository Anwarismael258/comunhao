create extension if not exists pgcrypto;
create extension if not exists http with schema extensions;

create table if not exists public.phone_auth_otps (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  phone text not null,
  purpose text not null default 'signup',
  otp_hash text not null,
  attempts integer not null default 0,
  status text not null default 'pending',
  last_sent_at timestamptz not null default now(),
  expires_at timestamptz not null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'phone_auth_otps_purpose_check'
  ) then
    alter table public.phone_auth_otps
      add constraint phone_auth_otps_purpose_check
      check (purpose in ('signup', 'login'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'phone_auth_otps_status_check'
  ) then
    alter table public.phone_auth_otps
      add constraint phone_auth_otps_status_check
      check (status in ('pending', 'verified', 'expired', 'cancelled'));
  end if;
end $$;

create index if not exists idx_phone_auth_otps_phone
  on public.phone_auth_otps(phone);

create index if not exists idx_phone_auth_otps_status
  on public.phone_auth_otps(status, expires_at desc);

create or replace function public.handle_phone_auth_otps_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists set_phone_auth_otps_updated_at on public.phone_auth_otps;
create trigger set_phone_auth_otps_updated_at
  before update on public.phone_auth_otps
  for each row
  execute procedure public.handle_phone_auth_otps_updated_at();

create or replace function public.normalize_phone_auth_number(
  p_phone text
)
returns text
language sql
immutable
set search_path = public
as $$
  select regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
$$;

create or replace function public.send_sms_via_mozesms(
  p_phone text,
  p_message text
)
returns jsonb
language plpgsql
security definer
set search_path = public, vault, extensions
as $$
declare
  api_key text;
  api_secret text;
  bearer_secret text;
  sender_id text;
  normalized_phone text := public.normalize_phone_auth_number(p_phone);
  request_headers extensions.http_header[];
  response_record record;
  response_json jsonb;
begin
  if normalized_phone = '' then
    raise exception 'Numero de telefone invalido para envio de SMS.';
  end if;

  if coalesce(trim(coalesce(p_message, '')), '') = '' then
    raise exception 'A mensagem SMS nao pode estar vazia.';
  end if;

  select decrypted_secret
  into api_key
  from vault.decrypted_secrets
  where name = 'mozesms_api_key'
  order by updated_at desc
  limit 1;

  select decrypted_secret
  into api_secret
  from vault.decrypted_secrets
  where name = 'mozesms_api_secret'
  order by updated_at desc
  limit 1;

  select decrypted_secret
  into bearer_secret
  from vault.decrypted_secrets
  where name = 'mozesms_bearer_secret'
  order by updated_at desc
  limit 1;

  select decrypted_secret
  into sender_id
  from vault.decrypted_secrets
  where name = 'mozesms_sender_id'
  order by updated_at desc
  limit 1;

  if api_key is not null and api_key <> '' and api_secret is not null and api_secret <> '' then
    request_headers := array[
      row('X-API-Key', api_key)::extensions.http_header,
      row('X-API-Secret', api_secret)::extensions.http_header
    ]::extensions.http_header[];
  elsif bearer_secret is not null and bearer_secret <> '' then
    request_headers := array[
      row('Authorization', 'Bearer ' || bearer_secret)::extensions.http_header
    ]::extensions.http_header[];
  else
    raise exception 'As credenciais do Mozesms ainda nao foram configuradas.';
  end if;

  select *
  into response_record
  from extensions.http(
    (
      'POST',
      'https://api.mozesms.com/sms/send',
      request_headers,
      'application/json',
      jsonb_build_object(
        'phone', normalized_phone,
        'message', p_message,
        'sender_id', coalesce(nullif(sender_id, ''), 'ESHOP')
      )::text
    )::extensions.http_request
  );

  if response_record.status < 200 or response_record.status >= 300 then
    raise exception 'MozeSMS respondeu com status %: %',
      response_record.status,
      coalesce(nullif(response_record.content, ''), 'sem detalhes');
  end if;

  if coalesce(response_record.content, '') <> '' then
    begin
      response_json := response_record.content::jsonb;
    exception
      when others then
        return jsonb_build_object(
          'status', response_record.status,
          'content', response_record.content
        );
    end;

    if coalesce((response_json->>'success')::boolean, true) is not true then
      raise exception '%', coalesce(
        response_json->>'error',
        response_json->>'message',
        'O Mozesms devolveu um erro ao enviar o SMS.'
      );
    end if;

    return response_json;
  end if;

  return jsonb_build_object(
    'status', response_record.status
  );
end;
$$;

create or replace function public.request_phone_auth_otp(
  p_phone text,
  p_purpose text default 'signup'
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  normalized_phone text := public.normalize_phone_auth_number(p_phone);
  user_row record;
  existing_pending public.phone_auth_otps%rowtype;
  otp_code text;
  otp_hash text;
begin
  if normalized_phone = '' then
    raise exception 'Numero de telefone invalido.';
  end if;

  if p_purpose not in ('signup', 'login') then
    raise exception 'Tipo de OTP invalido.';
  end if;

  select
    u.id,
    u.phone,
    u.deleted_at,
    p.phone as profile_phone
  into user_row
  from auth.users u
  left join public.profiles p
    on p.id = u.id
  where (
      u.phone = normalized_phone
      or p.phone = normalized_phone
      or coalesce(u.raw_user_meta_data->>'phone', '') = normalized_phone
    )
    and u.deleted_at is null
  order by u.created_at desc
  limit 1;

  if not found then
    raise exception 'Nao existe nenhuma conta associada a este numero.';
  end if;

  select *
  into existing_pending
  from public.phone_auth_otps
  where phone = normalized_phone
    and status = 'pending'
  order by created_at desc
  limit 1
  for update;

  if found and existing_pending.last_sent_at > now() - interval '30 seconds' then
    raise exception 'Aguarde alguns segundos antes de pedir um novo codigo.';
  end if;

  update public.phone_auth_otps
  set status = case
        when expires_at < now() then 'expired'
        else 'cancelled'
      end
  where phone = normalized_phone
    and status = 'pending';

  otp_code := lpad((floor(random() * 1000000))::int::text, 6, '0');
  otp_hash := encode(
    extensions.digest(normalized_phone || ':' || otp_code, 'sha256'),
    'hex'
  );

  insert into public.phone_auth_otps (
    auth_user_id,
    phone,
    purpose,
    otp_hash,
    attempts,
    status,
    last_sent_at,
    expires_at
  )
  values (
    user_row.id,
    normalized_phone,
    p_purpose,
    otp_hash,
    0,
    'pending',
    now(),
    now() + interval '10 minutes'
  );

  perform public.send_sms_via_mozesms(
    normalized_phone,
    format('Comunhao OTP: %s', otp_code)
  );

  return jsonb_build_object(
    'phone', normalized_phone,
    'purpose', p_purpose,
    'expires_in_seconds', 600,
    'sent_at', now()
  );
end;
$$;

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
    confirmed_at,
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
    confirmed_at = coalesce(confirmed_at, now()),
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

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  metadata_church_id uuid;
  metadata_birth_date date;
  metadata_phone text;
begin
  begin
    if coalesce(new.raw_user_meta_data ->> 'church_id', '') <> '' then
      metadata_church_id := (new.raw_user_meta_data ->> 'church_id')::uuid;
    elsif coalesce(new.raw_user_meta_data ->> 'church_slug', '') <> '' then
      select id
      into metadata_church_id
      from public.churches
      where slug = new.raw_user_meta_data ->> 'church_slug'
      limit 1;
    end if;
  exception
    when others then
      metadata_church_id := null;
  end;

  begin
    if coalesce(new.raw_user_meta_data ->> 'birth_date', '') <> '' then
      metadata_birth_date := (new.raw_user_meta_data ->> 'birth_date')::date;
    end if;
  exception
    when others then
      metadata_birth_date := null;
  end;

  metadata_phone := nullif(
    coalesce(new.phone, new.raw_user_meta_data ->> 'phone', ''),
    ''
  );

  insert into public.profiles (
    id,
    full_name,
    phone,
    birth_date
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', 'Membro'),
    metadata_phone,
    metadata_birth_date
  )
  on conflict (id) do update
    set
      full_name = excluded.full_name,
      phone = coalesce(excluded.phone, public.profiles.phone),
      birth_date = coalesce(excluded.birth_date, public.profiles.birth_date);

  if metadata_church_id is not null then
    insert into public.memberships (
      church_id,
      profile_id,
      role,
      status
    )
    values (
      metadata_church_id,
      new.id,
      'member',
      'active'
    )
    on conflict (church_id, profile_id) do update
      set
        status = 'active',
        role = public.memberships.role;
  end if;

  return new;
end;
$$;

grant execute on function public.normalize_phone_auth_number(text) to anon, authenticated;
grant execute on function public.register_phone_auth_user(text, text, text, date, jsonb) to anon, authenticated;
grant execute on function public.request_phone_auth_otp(text, text) to anon, authenticated;
grant execute on function public.verify_phone_auth_otp(text, text) to anon, authenticated;
grant execute on function public.send_sms_via_mozesms(text, text) to postgres;

revoke all on public.phone_auth_otps from anon, authenticated, public;
grant select, insert, update, delete on public.phone_auth_otps to postgres;
