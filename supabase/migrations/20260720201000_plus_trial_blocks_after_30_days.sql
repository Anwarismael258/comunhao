create or replace function public.subscription_effective_status(
  p_status text,
  p_plan_code text,
  p_trial_ends_at timestamptz,
  p_current_period_ends_at timestamptz,
  p_grace_period_ends_at timestamptz,
  p_grace_days integer default 0
)
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  effective_grace_days integer := greatest(coalesce(p_grace_days, 0), 0);
  implied_grace_end timestamptz;
begin
  if p_status is null or trim(p_status) = '' then
    return 'active';
  end if;

  if p_status in ('cancelled', 'suspended') then
    return p_status;
  end if;

  if p_status = 'trial' then
    if p_trial_ends_at is null or p_trial_ends_at >= now() then
      return 'trial';
    end if;

    implied_grace_end := coalesce(
      p_grace_period_ends_at,
      p_trial_ends_at + make_interval(days => effective_grace_days)
    );

    if effective_grace_days > 0 and implied_grace_end >= now() then
      return 'grace_period';
    end if;

    return 'suspended';
  end if;

  if p_status = 'grace_period' then
    implied_grace_end := coalesce(
      p_grace_period_ends_at,
      case
        when p_current_period_ends_at is not null
          then p_current_period_ends_at + make_interval(days => effective_grace_days)
        when p_trial_ends_at is not null
          then p_trial_ends_at + make_interval(days => effective_grace_days)
        else null
      end
    );

    if effective_grace_days > 0
      and (implied_grace_end is null or implied_grace_end >= now()) then
      return 'grace_period';
    end if;

    return 'suspended';
  end if;

  if p_status = 'active' then
    if p_current_period_ends_at is null or p_current_period_ends_at >= now() then
      return 'active';
    end if;

    implied_grace_end := coalesce(
      p_grace_period_ends_at,
      p_current_period_ends_at + make_interval(days => effective_grace_days)
    );

    if effective_grace_days > 0 and implied_grace_end >= now() then
      return 'grace_period';
    end if;

    return 'suspended';
  end if;

  return p_status;
end;
$$;

create or replace function public.church_subscription_allows_writes(
  p_church_id uuid
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    (
      select public.subscription_effective_status(
        status,
        plan_code,
        trial_ends_at,
        current_period_ends_at,
        grace_period_ends_at,
        0
      ) in ('trial', 'active')
      from public.church_subscriptions
      where church_id = p_church_id
      limit 1
    ),
    true
  );
$$;

create or replace function public.provision_church_trial_subscription(
  p_church_id uuid,
  p_trial_days integer default 30
)
returns public.church_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  trial_start timestamptz := now();
  trial_end timestamptz := now() + make_interval(days => greatest(coalesce(p_trial_days, 30), 1));
  result public.church_subscriptions;
begin
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
    'premium',
    'trial',
    trial_start,
    trial_end,
    trial_start,
    trial_end,
    null,
    null,
    null,
    null,
    now(),
    auth.uid(),
    'Trial Plus automatico de 30 dias.'
  )
  on conflict (church_id) do update
    set
      plan_code = 'premium',
      status = 'trial',
      trial_started_at = excluded.trial_started_at,
      trial_ends_at = excluded.trial_ends_at,
      current_period_started_at = excluded.current_period_started_at,
      current_period_ends_at = excluded.current_period_ends_at,
      grace_period_ends_at = null,
      activated_at = null,
      suspended_at = null,
      cancelled_at = null,
      updated_at = now(),
      updated_by = auth.uid(),
      admin_notes = excluded.admin_notes
  returning * into result;

  return result;
end;
$$;

grant execute on function public.provision_church_trial_subscription(uuid, integer) to authenticated;
