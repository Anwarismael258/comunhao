create or replace function public.delete_my_account()
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  current_profile_id uuid := auth.uid();
  deleted_phone text;
begin
  if current_profile_id is null then
    raise exception 'Sessao invalida.';
  end if;

  select phone
  into deleted_phone
  from auth.users
  where id = current_profile_id
    and deleted_at is null
  limit 1;

  if not found then
    raise exception 'Conta nao encontrada ou ja apagada.';
  end if;

  update public.memberships
  set status = 'removed'
  where profile_id = current_profile_id
    and status <> 'removed';

  delete from public.push_tokens
  where profile_id = current_profile_id;

  delete from public.phone_auth_otps
  where auth_user_id = current_profile_id;

  update public.profiles
  set
    full_name = 'Conta apagada',
    phone = null,
    email = null,
    avatar_url = null,
    avatar_storage_path = null
  where id = current_profile_id;

  update auth.identities
  set
    provider_id = current_profile_id::text,
    identity_data = jsonb_build_object(
      'sub', current_profile_id::text,
      'deleted', true,
      'deleted_at', now()
    ),
    updated_at = now()
  where user_id = current_profile_id;

  update auth.users
  set
    phone = null,
    encrypted_password = extensions.crypt(gen_random_uuid()::text, extensions.gen_salt('bf')),
    phone_confirmed_at = null,
    raw_user_meta_data = jsonb_build_object(
      'deleted', true,
      'deleted_at', now()
    ),
    raw_app_meta_data = jsonb_build_object(
      'provider', 'phone',
      'providers', jsonb_build_array('phone'),
      'deleted', true
    ),
    deleted_at = now(),
    updated_at = now()
  where id = current_profile_id;

  return jsonb_build_object(
    'deleted', true,
    'profile_id', current_profile_id,
    'phone', deleted_phone
  );
end;
$$;

grant execute on function public.delete_my_account() to authenticated;
