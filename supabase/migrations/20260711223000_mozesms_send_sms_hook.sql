create extension if not exists http with schema extensions;

create or replace function public.send_sms_hook(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, vault, extensions
as $$
declare
  api_key text;
  api_secret text;
  sender_id text;
  target_phone text;
  otp_code text;
  sms_body text;
  response_record record;
  response_json jsonb;
begin
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
  into sender_id
  from vault.decrypted_secrets
  where name = 'mozesms_sender_id'
  order by updated_at desc
  limit 1;

  target_phone := coalesce(event->'user'->>'phone', '');
  otp_code := coalesce(event->'sms'->>'otp', '');

  if api_key is null or api_key = '' then
    return jsonb_build_object(
      'error',
      jsonb_build_object(
        'http_code', 500,
        'message', 'MozeSMS API key is not configured.'
      )
    );
  end if;

  if api_secret is null or api_secret = '' then
    return jsonb_build_object(
      'error',
      jsonb_build_object(
        'http_code', 500,
        'message', 'MozeSMS API secret is not configured.'
      )
    );
  end if;

  if target_phone = '' or otp_code = '' then
    return jsonb_build_object(
      'error',
      jsonb_build_object(
        'http_code', 400,
        'message', 'Phone number or OTP payload is missing.'
      )
    );
  end if;

  sms_body := format('Comunhao OTP: %s', otp_code);

  select *
  into response_record
  from extensions.http(
    (
      'POST',
      'https://api.mozesms.com/sms/send',
      array[
        row('X-API-Key', api_key)::extensions.http_header,
        row('X-API-Secret', api_secret)::extensions.http_header
      ]::extensions.http_header[],
      'application/json',
      jsonb_build_object(
        'phone', replace(target_phone, '+', ''),
        'message', sms_body,
        'sender_id', coalesce(nullif(sender_id, ''), 'Comunhao')
      )::text
    )::extensions.http_request
  );

  if response_record.status < 200 or response_record.status >= 300 then
    return jsonb_build_object(
      'error',
      jsonb_build_object(
        'http_code', 500,
        'message', format(
          'MozeSMS request failed with status %s.',
          response_record.status
        )
      )
    );
  end if;

  if coalesce(response_record.content, '') <> '' then
    begin
      response_json := response_record.content::jsonb;
      if coalesce((response_json->>'success')::boolean, true) is not true then
        return jsonb_build_object(
          'error',
          jsonb_build_object(
            'http_code', 500,
            'message', coalesce(
              response_json->>'error',
              'MozeSMS returned an application error.'
            )
          )
        );
      end if;
    exception
      when others then
        null;
    end;
  end if;

  return event;
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.send_sms_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.send_sms_hook(jsonb) from anon, authenticated, public;
