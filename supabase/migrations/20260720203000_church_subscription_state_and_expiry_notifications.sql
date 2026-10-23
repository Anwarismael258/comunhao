alter table public.churches
  add column if not exists subscription_status text not null default 'trial',
  add column if not exists trial_ends_at timestamptz,
  add column if not exists subscription_ends_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'churches_subscription_status_check'
      and conrelid = 'public.churches'::regclass
  ) then
    alter table public.churches
      add constraint churches_subscription_status_check
      check (subscription_status in ('trial', 'active', 'overdue', 'suspended'));
  end if;
end;
$$;

create index if not exists idx_churches_subscription_status
  on public.churches(subscription_status);

create index if not exists idx_churches_subscription_ends_at
  on public.churches(subscription_ends_at);

create or replace function public.map_church_subscription_status(
  p_status text
)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_status = 'trial' then 'trial'
    when p_status = 'active' then 'active'
    when p_status = 'grace_period' then 'overdue'
    when p_status in ('suspended', 'cancelled') then 'suspended'
    else 'active'
  end;
$$;

create or replace function public.sync_church_subscription_state(
  p_church_id uuid
)
returns public.churches
language plpgsql
security definer
set search_path = public
as $$
declare
  subscription_row public.church_subscriptions%rowtype;
  effective_status text;
  church_row public.churches%rowtype;
begin
  select *
  into subscription_row
  from public.church_subscriptions
  where church_id = p_church_id
  limit 1;

  if not found then
    update public.churches
    set
      subscription_status = coalesce(subscription_status, 'trial'),
      updated_at = now()
    where id = p_church_id
    returning * into church_row;

    return church_row;
  end if;

  effective_status := public.subscription_effective_status(
    subscription_row.status,
    subscription_row.plan_code,
    subscription_row.trial_ends_at,
    subscription_row.current_period_ends_at,
    subscription_row.grace_period_ends_at,
    0
  );

  update public.churches
  set
    subscription_status = public.map_church_subscription_status(effective_status),
    trial_ends_at = subscription_row.trial_ends_at,
    subscription_ends_at = case
      when effective_status = 'trial' then subscription_row.trial_ends_at
      else coalesce(
        subscription_row.current_period_ends_at,
        subscription_row.trial_ends_at
      )
    end,
    updated_at = now()
  where id = p_church_id
  returning * into church_row;

  return church_row;
end;
$$;

create or replace function public.sync_church_subscription_state_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.sync_church_subscription_state(new.church_id);
  return new;
end;
$$;

drop trigger if exists trg_sync_church_subscription_state
  on public.church_subscriptions;

create trigger trg_sync_church_subscription_state
after insert or update on public.church_subscriptions
for each row execute function public.sync_church_subscription_state_trigger();

create or replace function public.refresh_church_subscription_state(
  p_church_id uuid
)
returns public.churches
language plpgsql
security definer
set search_path = public
as $$
declare
  church_row public.churches%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Sessao expirada.';
  end if;

  if not exists (
    select 1
    from public.memberships
    where church_id = p_church_id
      and profile_id = auth.uid()
      and status = 'active'
  )
  and not public.has_platform_role(
    array['super_admin', 'support_agent', 'developer', 'auditor']::text[],
    auth.uid()
  ) then
    raise exception 'Sem permissao para atualizar esta igreja.';
  end if;

  perform public.run_subscription_expiry_maintenance(p_church_id);
  select * into church_row from public.sync_church_subscription_state(p_church_id);
  return church_row;
end;
$$;

create or replace function public.notify_church_subscription_guardians(
  p_church_id uuid,
  p_notification_type text,
  p_title text,
  p_message text,
  p_priority text default 'normal',
  p_metadata jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient record;
  sent_count integer := 0;
begin
  for recipient in
    select distinct profile_id
    from public.memberships
    where church_id = p_church_id
      and role in ('pastor', 'church_admin')
      and status = 'active'
      and profile_id is not null
  loop
    perform public.create_internal_notification(
      recipient.profile_id,
      p_title,
      p_message,
      p_notification_type,
      p_church_id,
      null,
      p_priority,
      'churches',
      p_church_id,
      '/subscription',
      coalesce(p_metadata, '{}'::jsonb)
    );
    sent_count := sent_count + 1;
  end loop;

  return sent_count;
end;
$$;

create or replace function public.run_subscription_expiry_maintenance(
  p_church_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  subscription_row record;
  effective_status text;
  days_until_end integer;
  processed_count integer := 0;
begin
  for subscription_row in
    select s.*, c.name as church_name
    from public.church_subscriptions s
    join public.churches c on c.id = s.church_id
    where p_church_id is null or s.church_id = p_church_id
  loop
    effective_status := public.subscription_effective_status(
      subscription_row.status,
      subscription_row.plan_code,
      subscription_row.trial_ends_at,
      subscription_row.current_period_ends_at,
      subscription_row.grace_period_ends_at,
      0
    );

    if effective_status = 'trial'
      and subscription_row.trial_ends_at is not null then
      days_until_end :=
        (subscription_row.trial_ends_at at time zone 'Africa/Maputo')::date
        - (now() at time zone 'Africa/Maputo')::date;

      if days_until_end in (7, 3, 1) then
        perform public.notify_church_subscription_guardians(
          subscription_row.church_id,
          'subscription_trial_' || days_until_end || '_days',
          case
            when days_until_end = 1 then 'A subscricao termina amanha'
            else 'A subscricao termina em ' || days_until_end || ' dias'
          end,
          case
            when days_until_end = 7 then 'A sua subscricao termina em 7 dias.'
            when days_until_end = 3 then 'Restam apenas 3 dias do periodo experimental.'
            else 'A subscricao termina amanha.'
          end,
          case when days_until_end = 1 then 'high' else 'normal' end,
          jsonb_build_object(
            'days_until_end', days_until_end,
            'church_name', subscription_row.church_name,
            'trial_ends_at', subscription_row.trial_ends_at
          )
        );
      end if;
    end if;

    if effective_status = 'suspended'
      and subscription_row.status <> 'suspended' then
      update public.church_subscriptions
      set
        status = 'suspended',
        suspended_at = coalesce(suspended_at, now()),
        updated_at = now(),
        admin_notes = trim(
          both E'\n' from concat_ws(
            E'\n',
            nullif(admin_notes, ''),
            'Suspensa automaticamente por fim do periodo pago/trial.'
          )
        )
      where church_id = subscription_row.church_id;

      perform public.notify_church_subscription_guardians(
        subscription_row.church_id,
        'subscription_expired',
        'Igreja suspensa por falta de pagamento',
        'A sua igreja foi suspensa por falta de pagamento. Renove para reativar todos os servicos.',
        'urgent',
        jsonb_build_object(
          'church_name', subscription_row.church_name,
          'trial_ends_at', subscription_row.trial_ends_at,
          'subscription_ends_at', coalesce(
            subscription_row.current_period_ends_at,
            subscription_row.trial_ends_at
          )
        )
      );
    end if;

    perform public.sync_church_subscription_state(subscription_row.church_id);
    processed_count := processed_count + 1;
  end loop;

  return processed_count;
end;
$$;

select public.sync_church_subscription_state(church_id)
from public.church_subscriptions;

select public.run_subscription_expiry_maintenance();

grant execute on function public.map_church_subscription_status(text)
  to authenticated;
grant execute on function public.sync_church_subscription_state(uuid)
  to authenticated;
grant execute on function public.refresh_church_subscription_state(uuid)
  to authenticated;
grant execute on function public.run_subscription_expiry_maintenance(uuid)
  to authenticated;

do $$
begin
  perform cron.unschedule('comunhao-subscription-expiry-maintenance');
exception
  when others then
    null;
end;
$$;

select cron.schedule(
  'comunhao-subscription-expiry-maintenance',
  '15 6 * * *',
  $$select public.run_subscription_expiry_maintenance();$$
);
