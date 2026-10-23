create extension if not exists pg_cron;
create extension if not exists pg_net;
create schema if not exists vault;
create extension if not exists supabase_vault with schema vault;

delete from vault.secrets
where name in (
  'comunhao_project_url',
  'comunhao_publishable_key'
);

select vault.create_secret(
  'https://dxofxuajsrocbxdmekfx.supabase.co',
  'comunhao_project_url',
  'Comunhao Supabase project URL for scheduled Edge Function calls'
);

select vault.create_secret(
  'sb_publishable_ujNSVFdw-kN6KHPsbgleQg_Ws8bHTIZ',
  'comunhao_publishable_key',
  'Comunhao publishable key for scheduled Edge Function calls'
);

create or replace function public.maintain_event_occurrences_all()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row record;
  total_created integer := 0;
begin
  for event_row in
    select id
    from public.events
    where is_demo = false
      and status in ('published', 'scheduled', 'ongoing')
      and starts_at <= now() + interval '120 days'
  loop
    total_created := total_created
      + public.generate_event_occurrences(
          event_row.id,
          now() + interval '120 days'
        );
  end loop;

  return total_created;
end;
$$;

create or replace function public.prepare_event_internal_reminders_all()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer := 0;
begin
  perform public.maintain_event_occurrences_all();

  insert into public.event_reminders (
    event_id,
    occurrence_id,
    church_id,
    channel,
    audience,
    scheduled_for,
    status,
    provider_status,
    created_by
  )
  select
    eo.event_id,
    eo.id,
    eo.church_id,
    'internal',
    'members',
    eo.occurrence_start_at - interval '1 day',
    'queued',
    'internal_only',
    null
  from public.event_occurrences eo
  join public.events e
    on e.id = eo.event_id
  where eo.is_demo = false
    and e.is_demo = false
    and eo.occurrence_start_at between now() and now() + interval '45 days'
    and e.status in ('published', 'scheduled', 'ongoing')
  on conflict do nothing;

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

create or replace function public.dispatch_due_event_internal_reminders(
  p_limit integer default 50
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  reminder_row record;
  inserted_total integer := 0;
  inserted_count integer := 0;
begin
  for reminder_row in
    select
      er.id,
      er.event_id,
      er.occurrence_id,
      er.church_id,
      e.title,
      eo.occurrence_start_at
    from public.event_reminders er
    join public.events e
      on e.id = er.event_id
    left join public.event_occurrences eo
      on eo.id = er.occurrence_id
    where er.channel = 'internal'
      and er.status = 'queued'
      and er.scheduled_for <= now()
      and er.provider_status = 'internal_only'
    order by er.scheduled_for
    limit greatest(coalesce(p_limit, 50), 1)
  loop
    insert into public.internal_notifications (
      recipient_profile_id,
      church_id,
      title,
      message,
      notification_type,
      priority,
      reference_table,
      reference_id,
      action_route,
      delivery_status,
      metadata
    )
    select
      m.profile_id,
      reminder_row.church_id,
      'Lembrete de evento',
      'A igreja tem um evento programado: ' || reminder_row.title,
      'event_reminder',
      'normal',
      'event_reminders',
      reminder_row.id,
      '/events',
      'queued',
      jsonb_build_object(
        'event_id', reminder_row.event_id,
        'occurrence_id', reminder_row.occurrence_id,
        'occurrence_start_at', reminder_row.occurrence_start_at,
        'external_channels', 'not_configured'
      )
    from public.memberships m
    where m.church_id = reminder_row.church_id
      and m.status = 'active'
      and m.profile_id is not null
    on conflict do nothing;

    get diagnostics inserted_count = row_count;
    inserted_total := inserted_total + inserted_count;

    update public.event_reminders
    set
      status = 'sent',
      sent_at = now(),
      provider_status = 'internal_sent'
    where id = reminder_row.id;
  end loop;

  return inserted_total;
end;
$$;

grant execute on function public.maintain_event_occurrences_all() to authenticated;
grant execute on function public.prepare_event_internal_reminders_all() to authenticated;
grant execute on function public.dispatch_due_event_internal_reminders(integer) to authenticated;

do $$
begin
  perform cron.unschedule('comunhao-daily-scripture-engine');
exception
  when others then null;
end $$;

select cron.schedule(
  'comunhao-daily-scripture-engine',
  '5 22 * * *',
  $$
    select net.http_post(
      url := (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'comunhao_project_url'
        limit 1
      ) || '/functions/v1/daily-scripture-engine',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'comunhao_publishable_key'
          limit 1
        ),
        'Authorization', 'Bearer ' || (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'comunhao_publishable_key'
          limit 1
        )
      ),
      body := jsonb_build_object(
        'source', 'supabase_cron',
        'job', 'comunhao-daily-scripture-engine'
      )
    );
  $$
);

do $$
begin
  perform cron.unschedule('comunhao-maintain-calendar-occurrences');
exception
  when others then null;
end $$;

select cron.schedule(
  'comunhao-maintain-calendar-occurrences',
  '10 22 * * *',
  $$ select public.maintain_event_occurrences_all(); $$
);

do $$
begin
  perform cron.unschedule('comunhao-event-internal-reminders');
exception
  when others then null;
end $$;

select cron.schedule(
  'comunhao-event-internal-reminders',
  '*/30 * * * *',
  $$
    select public.prepare_event_internal_reminders_all();
    select public.dispatch_due_event_internal_reminders(100);
  $$
);
