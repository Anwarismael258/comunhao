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
