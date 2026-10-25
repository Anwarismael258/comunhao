-- New RPC name avoids stale PostgREST schema-cache metadata for the legacy RPC.
create or replace function public.verify_phone_auth_otp_v2(
  p_phone text,
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
begin
  return public.verify_phone_auth_otp(p_phone, p_token);
end;
$$;

revoke all on function public.verify_phone_auth_otp_v2(text, text) from public;
grant execute on function public.verify_phone_auth_otp_v2(text, text)
  to anon, authenticated, authenticator, service_role;

notify pgrst, 'reload schema';

-- The Comunhão apps use the comunhao PostgREST schema by default.
create or replace function comunhao.verify_phone_auth_otp_v2(
  p_phone text,
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public, comunhao, auth, extensions
as $$
declare
  result jsonb;
  uid uuid;
  normalized text;
begin
  result := comunhao.verify_phone_auth_otp(p_phone, p_token);
  uid := nullif(result->>'user_id', '')::uuid;
  normalized := public.normalize_phone_auth_number(p_phone);
  if uid is not null then
    update auth.users
    set phone = normalized,
        phone_confirmed_at = coalesce(phone_confirmed_at, now()),
        updated_at = now()
    where id = uid;
    update auth.identities
    set provider_id = normalized,
        identity_data = coalesce(identity_data, '{}'::jsonb)
          || jsonb_build_object('phone', normalized, 'phone_verified', true),
        updated_at = now()
    where user_id = uid and provider = 'phone';
  end if;
  return result;
end;
$$;

revoke all on function comunhao.verify_phone_auth_otp_v2(text, text) from public;
grant execute on function comunhao.verify_phone_auth_otp_v2(text, text)
  to anon, authenticated, authenticator, service_role;

notify pgrst, 'reload schema';
