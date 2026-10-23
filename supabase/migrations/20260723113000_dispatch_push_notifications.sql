create extension if not exists pg_net;
create schema if not exists vault;
create extension if not exists supabase_vault with schema vault;

create or replace function public.dispatch_internal_notification_push()
returns trigger
language plpgsql
security definer
set search_path = public, vault, extensions
as $$
declare
  project_url text;
  publishable_key text;
begin
  select decrypted_secret
  into project_url
  from vault.decrypted_secrets
  where name = 'comunhao_project_url'
  limit 1;

  select decrypted_secret
  into publishable_key
  from vault.decrypted_secrets
  where name = 'comunhao_publishable_key'
  limit 1;

  if project_url is null or publishable_key is null then
    insert into public.notification_delivery_attempts (
      notification_id,
      channel,
      provider,
      delivery_status,
      last_error
    )
    values (
      new.id,
      'push',
      'firebase',
      'provider_not_configured',
      'Missing comunhao_project_url or comunhao_publishable_key in Vault.'
    );
    return new;
  end if;

  perform net.http_post(
    url := project_url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', publishable_key,
      'Authorization', 'Bearer ' || publishable_key
    ),
    body := jsonb_build_object(
      'notification_id', new.id,
      'recipient_profile_id', new.recipient_profile_id,
      'notification_type', new.notification_type
    ),
    timeout_milliseconds := 5000
  );

  return new;
exception
  when others then
    insert into public.notification_delivery_attempts (
      notification_id,
      channel,
      provider,
      delivery_status,
      last_error
    )
    values (
      new.id,
      'push',
      'firebase',
      'failed',
      left(sqlerrm, 1000)
    );
    return new;
end;
$$;

drop trigger if exists dispatch_internal_notification_push_trigger
  on public.internal_notifications;

create trigger dispatch_internal_notification_push_trigger
after insert on public.internal_notifications
for each row
execute function public.dispatch_internal_notification_push();

grant execute on function public.dispatch_internal_notification_push()
  to authenticated, service_role;
