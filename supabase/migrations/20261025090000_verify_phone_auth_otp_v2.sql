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
begin
  return comunhao.verify_phone_auth_otp(p_phone, p_token);
end;
$$;

revoke all on function comunhao.verify_phone_auth_otp_v2(text, text) from public;
grant execute on function comunhao.verify_phone_auth_otp_v2(text, text)
  to anon, authenticated, authenticator, service_role;

notify pgrst, 'reload schema';
