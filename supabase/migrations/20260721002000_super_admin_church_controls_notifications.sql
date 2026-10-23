create or replace function public.notify_church_members(
  p_church_id uuid,
  p_title text,
  p_message text,
  p_notification_type text,
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
      and status = 'active'
      and profile_id is not null
  loop
    perform public.create_internal_notification(
      recipient.profile_id,
      p_title,
      p_message,
      p_notification_type,
      p_church_id,
      auth.uid(),
      p_priority,
      'churches',
      p_church_id,
      '/church-status',
      coalesce(p_metadata, '{}'::jsonb)
    );
    sent_count := sent_count + 1;
  end loop;

  return sent_count;
end;
$$;

create or replace function public.admin_set_church_active_state(
  p_church_id uuid,
  p_active boolean,
  p_notes text default null
)
returns public.churches
language plpgsql
security definer
set search_path = public
as $$
declare
  church_row public.churches%rowtype;
  notification_title text;
  notification_message text;
begin
  if not public.is_super_admin(auth.uid()) then
    raise exception 'Only super admins can update church active state.';
  end if;

  update public.churches
  set
    active = p_active,
    updated_at = now()
  where id = p_church_id
  returning * into church_row;

  if not found then
    raise exception 'Church not found.';
  end if;

  notification_title := case
    when p_active then 'Igreja reativada'
    else 'Igreja desativada'
  end;
  notification_message := case
    when p_active then 'A igreja ' || church_row.name || ' foi reativada pela equipa Comunhao.'
    else 'A igreja ' || church_row.name || ' foi temporariamente desativada pela equipa Comunhao.'
  end;

  if nullif(trim(coalesce(p_notes, '')), '') is not null then
    notification_message := notification_message || ' Motivo: ' || trim(p_notes);
  end if;

  perform public.notify_church_members(
    p_church_id,
    notification_title,
    notification_message,
    case when p_active then 'church_reactivated' else 'church_deactivated' end,
    case when p_active then 'normal' else 'high' end,
    jsonb_build_object(
      'church_id', p_church_id,
      'church_name', church_row.name,
      'active', p_active,
      'notes', p_notes
    )
  );

  perform public.create_platform_audit_log(
    'church.active_state.updated',
    'church',
    p_church_id,
    p_church_id,
    'Igreja ' || church_row.name || case when p_active then ' reativada.' else ' desativada.' end,
    jsonb_build_object(
      'church_id', p_church_id,
      'church_name', church_row.name,
      'active', p_active,
      'notes', p_notes
    )
  );

  return church_row;
end;
$$;

create or replace function public.admin_update_church_subscription(
  p_church_id uuid,
  p_status text,
  p_plan_code text default null,
  p_period_days integer default null,
  p_grace_days integer default null,
  p_notes text default null
)
returns public.church_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_record public.church_subscriptions%rowtype;
  effective_plan text;
  result public.church_subscriptions;
  church_row public.churches%rowtype;
  now_value timestamptz := now();
  effective_period_days integer := greatest(coalesce(p_period_days, 30), 1);
  effective_grace_days integer := greatest(coalesce(p_grace_days, 7), 1);
  period_end timestamptz;
  grace_end timestamptz;
  title text;
  message text;
  notification_type text;
  priority text := 'normal';
begin
  if not public.is_super_admin(auth.uid()) then
    raise exception 'Only super admins can update subscriptions.';
  end if;

  if p_status not in ('trial', 'active', 'grace_period', 'suspended', 'cancelled') then
    raise exception 'Invalid subscription status: %', p_status;
  end if;

  select *
  into church_row
  from public.churches
  where id = p_church_id;

  if not found then
    raise exception 'Church not found.';
  end if;

  select *
  into existing_record
  from public.church_subscriptions
  where church_id = p_church_id
  for update;

  effective_plan := coalesce(p_plan_code, existing_record.plan_code, 'starter');

  if not exists (
    select 1
    from public.subscription_plans
    where code = effective_plan
  ) then
    raise exception 'Unknown subscription plan: %', effective_plan;
  end if;

  period_end := case
    when p_status in ('trial', 'active')
      then now_value + make_interval(days => effective_period_days)
    else existing_record.current_period_ends_at
  end;

  grace_end := case
    when p_status = 'grace_period'
      then now_value + make_interval(days => effective_grace_days)
    else null
  end;

  insert into public.church_subscriptions (
    church_id,
    plan_code,
    status,
    trial_started_at,
    trial_ends_at,
    current_period_started_at,
    current_period_ends_at,
    grace_period_ends_at,
    activated_at,
    suspended_at,
    cancelled_at,
    updated_at,
    updated_by,
    admin_notes
  )
  values (
    p_church_id,
    effective_plan,
    p_status,
    case when p_status = 'trial' then now_value else existing_record.trial_started_at end,
    case when p_status = 'trial' then period_end else existing_record.trial_ends_at end,
    case when p_status in ('trial', 'active') then now_value else existing_record.current_period_started_at end,
    case when p_status in ('trial', 'active') then period_end else existing_record.current_period_ends_at end,
    grace_end,
    case when p_status = 'active' then now_value else existing_record.activated_at end,
    case when p_status = 'suspended' then now_value else null end,
    case when p_status = 'cancelled' then now_value else null end,
    now_value,
    auth.uid(),
    p_notes
  )
  on conflict (church_id) do update
    set
      plan_code = excluded.plan_code,
      status = excluded.status,
      trial_started_at = excluded.trial_started_at,
      trial_ends_at = excluded.trial_ends_at,
      current_period_started_at = excluded.current_period_started_at,
      current_period_ends_at = excluded.current_period_ends_at,
      grace_period_ends_at = excluded.grace_period_ends_at,
      activated_at = excluded.activated_at,
      suspended_at = excluded.suspended_at,
      cancelled_at = excluded.cancelled_at,
      updated_at = excluded.updated_at,
      updated_by = excluded.updated_by,
      admin_notes = excluded.admin_notes
  returning * into result;

  perform public.sync_church_subscription_state(p_church_id);

  if p_status = 'suspended' then
    title := 'Igreja suspensa';
    message := 'A igreja ' || church_row.name || ' foi suspensa pela equipa Comunhao.';
    notification_type := 'church_suspended';
    priority := 'urgent';
  elsif p_status = 'grace_period' then
    title := 'Mais 7 dias concedidos';
    message := 'A igreja ' || church_row.name || ' recebeu mais ' || effective_grace_days || ' dias de tolerancia.';
    notification_type := 'subscription_grace_period';
    priority := 'high';
  elsif p_status in ('active', 'trial') then
    title := 'Igreja reativada';
    message := 'A subscricao da igreja ' || church_row.name || ' foi ativada pela equipa Comunhao.';
    notification_type := 'subscription_reactivated';
  elsif p_status = 'cancelled' then
    title := 'Subscricao cancelada';
    message := 'A subscricao da igreja ' || church_row.name || ' foi cancelada pela equipa Comunhao.';
    notification_type := 'subscription_cancelled';
    priority := 'high';
  end if;

  if title is not null then
    if nullif(trim(coalesce(p_notes, '')), '') is not null then
      message := message || ' Motivo: ' || trim(p_notes);
    end if;

    perform public.notify_church_members(
      p_church_id,
      title,
      message,
      notification_type,
      priority,
      jsonb_build_object(
        'church_id', p_church_id,
        'church_name', church_row.name,
        'status', p_status,
        'plan_code', result.plan_code,
        'notes', p_notes,
        'grace_days', case when p_status = 'grace_period' then effective_grace_days else null end
      )
    );
  end if;

  perform public.create_platform_audit_log(
    'church.subscription.updated',
    'church',
    p_church_id,
    p_church_id,
    'Subscricao da igreja ' || church_row.name || ' atualizada para ' || p_status || '.',
    jsonb_build_object(
      'church_id', p_church_id,
      'church_name', church_row.name,
      'status', p_status,
      'plan_code', result.plan_code,
      'period_days', p_period_days,
      'grace_days', p_grace_days,
      'notes', p_notes
    )
  );

  return result;
end;
$$;

grant execute on function public.notify_church_members(uuid, text, text, text, text, jsonb)
  to authenticated;
grant execute on function public.admin_set_church_active_state(uuid, boolean, text)
  to authenticated;
