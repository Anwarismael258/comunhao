alter table public.subscription_plans
  add column if not exists admin_limit integer,
  add column if not exists billing_cycle_days integer not null default 30;

insert into public.subscription_plans (
  code,
  name,
  description,
  price_mzn,
  member_limit,
  admin_limit,
  sort_order,
  is_public,
  is_paid,
  billing_cycle_days,
  features
)
values
  (
    'starter',
    'Starter',
    'Plano base para igrejas pequenas com todas as funcoes essenciais.',
    100,
    50,
    1,
    1,
    true,
    true,
    30,
    jsonb_build_array(
      'Ate 50 membros',
      'Gestao de membros',
      'QR Code do membro',
      'Codigo da igreja',
      'Eventos',
      'Anuncios',
      'Pedidos de oracao',
      'Dizimos, ofertas e campanhas',
      'Carteira da igreja',
      'Levantamentos',
      'Notificacoes',
      'Calendario',
      'Perfil da igreja',
      'Backup automatico',
      'Suporte padrao'
    )
  ),
  (
    'essential',
    'Essencial',
    'Plano para igrejas em crescimento com relatorios e administracao avancada.',
    300,
    500,
    5,
    2,
    true,
    true,
    30,
    jsonb_build_array(
      'Tudo do Starter',
      'Ate 500 membros',
      'Ministerios e departamentos',
      'Relatorios financeiros',
      'Relatorios de crescimento',
      'Estatisticas',
      'Ate 5 administradores',
      'Exportacao PDF',
      'Exportacao Excel',
      'Historico completo',
      'Filtros avancados',
      'Dashboard avancado'
    )
  ),
  (
    'premium',
    'Premium',
    'Plano completo para grandes igrejas e ministerios.',
    600,
    null,
    null,
    3,
    true,
    true,
    30,
    jsonb_build_array(
      'Tudo do Essencial',
      'Membros ilimitados',
      'Administradores ilimitados',
      'Suporte prioritario',
      'Relatorios personalizados',
      'Paineis avancados',
      'API futura',
      'Branding personalizado',
      'Integracoes premium',
      'Funcionalidades antecipadas',
      'Maior capacidade de armazenamento'
    )
  )
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  price_mzn = excluded.price_mzn,
  member_limit = excluded.member_limit,
  admin_limit = excluded.admin_limit,
  sort_order = excluded.sort_order,
  is_public = excluded.is_public,
  is_paid = excluded.is_paid,
  billing_cycle_days = excluded.billing_cycle_days,
  features = excluded.features;

alter table public.church_subscription_requests
  add column if not exists payment_provider text,
  add column if not exists payer_phone text,
  add column if not exists payment_reference text,
  add column if not exists payment_notes text,
  add column if not exists expected_amount_mzn numeric(12,2),
  add column if not exists payment_submitted_at timestamptz,
  add column if not exists recorded_revenue_entry_id uuid references public.wallet_ledger_entries(id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_subscription_requests_payment_provider_check'
  ) then
    alter table public.church_subscription_requests
      add constraint church_subscription_requests_payment_provider_check
      check (
        payment_provider is null
        or payment_provider in ('mpesa', 'emola')
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_subscription_requests_expected_amount_check'
  ) then
    alter table public.church_subscription_requests
      add constraint church_subscription_requests_expected_amount_check
      check (
        expected_amount_mzn is null
        or expected_amount_mzn >= 0
      );
  end if;
end $$;

update public.church_subscription_requests request
set expected_amount_mzn = plan.price_mzn
from public.subscription_plans plan
where plan.code = request.requested_plan_code
  and request.expected_amount_mzn is null;

update public.church_subscriptions
set
  current_period_started_at = coalesce(
    current_period_started_at,
    activated_at,
    updated_at,
    now()
  ),
  current_period_ends_at = coalesce(
    current_period_ends_at,
    coalesce(activated_at, updated_at, now()) + interval '30 days'
  ),
  updated_at = now(),
  admin_notes = coalesce(
    nullif(admin_notes, ''),
    'Subscricao atualizada para o modelo oficial mensal da Comunhao.'
  )
where plan_code = 'starter'
  and status = 'active'
  and current_period_ends_at is null;

create index if not exists idx_wallet_ledger_entries_reference
  on public.wallet_ledger_entries(reference_table, reference_id);

create or replace function public.subscription_effective_status(
  p_status text,
  p_plan_code text,
  p_trial_ends_at timestamptz,
  p_current_period_ends_at timestamptz,
  p_grace_period_ends_at timestamptz,
  p_grace_days integer default 7
)
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  effective_grace_days integer := greatest(coalesce(p_grace_days, 7), 0);
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

    if implied_grace_end >= now() then
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

    if implied_grace_end is null or implied_grace_end >= now() then
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

    if implied_grace_end >= now() then
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
        grace_period_ends_at
      ) in ('trial', 'active', 'grace_period')
      from public.church_subscriptions
      where church_id = p_church_id
      limit 1
    ),
    true
  );
$$;

create or replace function public.submit_subscription_plan_request(
  p_church_id uuid,
  p_plan_code text,
  p_payment_provider text default null,
  p_payer_phone text default null,
  p_payment_reference text default null,
  p_payment_notes text default null
)
returns public.church_subscription_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.church_subscription_requests;
  selected_plan public.subscription_plans%rowtype;
  normalized_reference text := nullif(trim(coalesce(p_payment_reference, '')), '');
  normalized_provider text := nullif(trim(coalesce(p_payment_provider, '')), '');
begin
  if not public.has_church_role(
    p_church_id,
    array['pastor', 'church_admin']::text[]
  ) then
    raise exception 'Only church admins can request a plan for this church.';
  end if;

  select *
  into selected_plan
  from public.subscription_plans
  where code = p_plan_code
    and is_public = true;

  if not found then
    raise exception 'Unknown subscription plan: %', p_plan_code;
  end if;

  if selected_plan.price_mzn > 0 then
    if normalized_provider is null then
      raise exception 'Selecione M-Pesa ou E-Mola para confirmar o pagamento.';
    end if;

    if normalized_reference is null then
      raise exception 'Introduza a referencia do pagamento para o plano escolhido.';
    end if;
  end if;

  if normalized_provider is not null
    and normalized_provider not in ('mpesa', 'emola') then
    raise exception 'Invalid payment provider: %', normalized_provider;
  end if;

  update public.church_subscription_requests
  set
    status = 'cancelled',
    reviewed_at = now(),
    reviewed_by = auth.uid(),
    review_notes = 'Substituido por um pedido mais recente.'
  where church_id = p_church_id
    and status = 'pending';

  insert into public.church_subscription_requests (
    church_id,
    requested_plan_code,
    requested_by,
    status,
    payment_provider,
    payer_phone,
    payment_reference,
    payment_notes,
    expected_amount_mzn,
    payment_submitted_at
  )
  values (
    p_church_id,
    p_plan_code,
    auth.uid(),
    'pending',
    normalized_provider,
    nullif(trim(coalesce(p_payer_phone, '')), ''),
    normalized_reference,
    nullif(trim(coalesce(p_payment_notes, '')), ''),
    selected_plan.price_mzn,
    case
      when normalized_provider is null and normalized_reference is null then null
      else now()
    end
  )
  returning *
  into result;

  return result;
end;
$$;

create or replace function public.request_subscription_plan(
  p_church_id uuid,
  p_plan_code text
)
returns public.church_subscription_requests
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.submit_subscription_plan_request(
    p_church_id,
    p_plan_code,
    null,
    null,
    null,
    null
  );
end;
$$;

create or replace function public.admin_update_church_subscription(
  p_church_id uuid,
  p_status text,
  p_plan_code text default null,
  p_period_days integer default 30,
  p_grace_days integer default 7,
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
  now_value timestamptz := now();
  effective_period_days integer := greatest(coalesce(p_period_days, 30), 1);
  effective_grace_days integer := greatest(coalesce(p_grace_days, 7), 1);
  period_end timestamptz;
  grace_end timestamptz;
begin
  if not public.is_super_admin(auth.uid()) then
    raise exception 'Only super admins can update subscriptions.';
  end if;

  if p_status not in ('trial', 'active', 'grace_period', 'suspended', 'cancelled') then
    raise exception 'Invalid subscription status: %', p_status;
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
  returning *
  into result;

  return result;
end;
$$;

create or replace function public.review_subscription_request(
  p_request_id uuid,
  p_decision text,
  p_period_days integer default 30,
  p_review_notes text default null
)
returns public.church_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.church_subscription_requests%rowtype;
  result public.church_subscriptions;
  revenue_entry_id uuid;
  platform_wallet_id uuid;
  church_name text;
  effective_amount numeric(12,2);
  effective_provider text;
begin
  if not public.is_super_admin(auth.uid()) then
    raise exception 'Only super admins can review subscription requests.';
  end if;

  if p_decision not in ('approved', 'rejected') then
    raise exception 'Invalid subscription review decision: %', p_decision;
  end if;

  select *
  into request_row
  from public.church_subscription_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Subscription request not found.';
  end if;

  if request_row.status <> 'pending' then
    raise exception 'Only pending subscription requests can be reviewed.';
  end if;

  update public.church_subscription_requests
  set
    status = case when p_decision = 'approved' then 'approved' else 'rejected' end,
    reviewed_at = now(),
    reviewed_by = auth.uid(),
    review_notes = p_review_notes
  where id = p_request_id;

  if p_decision = 'rejected' then
    return null;
  end if;

  effective_amount := coalesce(
    request_row.expected_amount_mzn,
    (
      select price_mzn
      from public.subscription_plans
      where code = request_row.requested_plan_code
      limit 1
    ),
    0
  );

  result := public.admin_update_church_subscription(
    request_row.church_id,
    'active',
    request_row.requested_plan_code,
    p_period_days,
    7,
    coalesce(
      p_review_notes,
      'Subscricao ativada manualmente pela equipa Comunhao.'
    )
  );

  if effective_amount > 0 then
    effective_provider := coalesce(request_row.payment_provider, 'mpesa');
    perform public.ensure_wallet_accounts('platform', null, 'Comunhao');

    select id
    into platform_wallet_id
    from public.wallet_accounts
    where owner_type = 'platform'
      and church_id is null
      and provider = effective_provider
    limit 1;

    if platform_wallet_id is null then
      raise exception 'Platform wallet account not found for provider: %', effective_provider;
    end if;

    select name
    into church_name
    from public.churches
    where id = request_row.church_id
    limit 1;

    select id
    into revenue_entry_id
    from public.wallet_ledger_entries
    where reference_table = 'church_subscription_requests'
      and reference_id = request_row.id
      and entry_type = 'subscription_payment'
    limit 1;

    if revenue_entry_id is null then
      insert into public.wallet_ledger_entries (
        wallet_account_id,
        created_by,
        direction,
        entry_type,
        amount,
        currency,
        status,
        description,
        reference_table,
        reference_id,
        metadata,
        posted_at
      )
      values (
        platform_wallet_id,
        auth.uid(),
        'credit',
        'subscription_payment',
        effective_amount,
        'MZN',
        'posted',
        format(
          'Pagamento do plano %s - %s',
          request_row.requested_plan_code,
          coalesce(church_name, 'Igreja')
        ),
        'church_subscription_requests',
        request_row.id,
        jsonb_build_object(
          'church_id', request_row.church_id,
          'plan_code', request_row.requested_plan_code,
          'payment_provider', effective_provider,
          'payment_reference', request_row.payment_reference,
          'requested_by', request_row.requested_by
        ),
        now()
      )
      returning id
      into revenue_entry_id;
    end if;

    update public.church_subscription_requests
    set recorded_revenue_entry_id = revenue_entry_id
    where id = request_row.id;
  end if;

  return result;
end;
$$;

create or replace function public.get_platform_dashboard_snapshot()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if not public.is_super_admin(auth.uid()) then
    raise exception 'Only super admins can read the platform dashboard.';
  end if;

  with church_statuses as (
    select
      church.id,
      church.active,
      coalesce(subscription.plan_code, 'starter') as plan_code,
      public.subscription_effective_status(
        subscription.status,
        subscription.plan_code,
        subscription.trial_ends_at,
        subscription.current_period_ends_at,
        subscription.grace_period_ends_at
      ) as effective_status,
      subscription.trial_ends_at,
      subscription.current_period_ends_at,
      subscription.grace_period_ends_at
    from public.churches church
    left join public.church_subscriptions subscription
      on subscription.church_id = church.id
  ),
  revenue as (
    select
      coalesce(
        sum(
          case
            when ledger.created_at >= date_trunc('month', now()) then ledger.amount
            else 0
          end
        ),
        0
      ) as month_revenue,
      coalesce(
        sum(
          case
            when ledger.created_at >= date_trunc('year', now()) then ledger.amount
            else 0
          end
        ),
        0
      ) as year_revenue,
      coalesce(
        sum(
          case
            when ledger.created_at >= date_trunc('month', now())
              and coalesce(ledger.metadata->>'plan_code', '') = 'starter'
            then ledger.amount
            else 0
          end
        ),
        0
      ) as starter_revenue,
      coalesce(
        sum(
          case
            when ledger.created_at >= date_trunc('month', now())
              and coalesce(ledger.metadata->>'plan_code', '') = 'essential'
            then ledger.amount
            else 0
          end
        ),
        0
      ) as essential_revenue,
      coalesce(
        sum(
          case
            when ledger.created_at >= date_trunc('month', now())
              and coalesce(ledger.metadata->>'plan_code', '') = 'premium'
            then ledger.amount
            else 0
          end
        ),
        0
      ) as premium_revenue
    from public.wallet_ledger_entries ledger
    join public.wallet_accounts wallet
      on wallet.id = ledger.wallet_account_id
    where wallet.owner_type = 'platform'
      and wallet.church_id is null
      and ledger.direction = 'credit'
      and ledger.status = 'posted'
      and ledger.entry_type = 'subscription_payment'
  )
  select jsonb_build_object(
    'total_churches',
    (select count(*) from church_statuses),
    'active_churches',
    (
      select count(*)
      from church_statuses
      where active = true
        and effective_status not in ('suspended', 'cancelled')
    ),
    'inactive_churches',
    (
      select count(*)
      from church_statuses
      where active = false
         or effective_status in ('suspended', 'cancelled')
    ),
    'total_members',
    (
      select count(*)
      from public.memberships
      where status = 'active'
    ),
    'total_pastors',
    (
      select count(*)
      from public.memberships
      where status = 'active'
        and role = 'pastor'
    ),
    'pending_applications',
    (
      select count(*)
      from public.church_applications
      where status = 'submitted'
    ),
    'pending_plan_requests',
    (
      select count(*)
      from public.church_subscription_requests
      where status = 'pending'
    ),
    'pending_withdrawals',
    (
      select count(*)
      from public.wallet_withdrawal_requests
      where status in ('pending', 'processing')
    ),
    'month_revenue',
    revenue.month_revenue,
    'year_revenue',
    revenue.year_revenue,
    'trial_churches',
    (
      select count(*)
      from church_statuses
      where effective_status = 'trial'
    ),
    'grace_churches',
    (
      select count(*)
      from church_statuses
      where effective_status = 'grace_period'
    ),
    'suspended_churches',
    (
      select count(*)
      from church_statuses
      where effective_status in ('suspended', 'cancelled')
    ),
    'expiring_soon_subscriptions',
    (
      select count(*)
      from church_statuses
      where effective_status in ('trial', 'active', 'grace_period')
        and (
          case
            when effective_status = 'trial' then trial_ends_at
            when effective_status = 'active' then current_period_ends_at
            when effective_status = 'grace_period' then coalesce(
              grace_period_ends_at,
              current_period_ends_at + interval '7 days',
              trial_ends_at + interval '7 days'
            )
            else null
          end
        ) between now() and now() + interval '7 days'
    ),
    'starter_revenue',
    revenue.starter_revenue,
    'essential_revenue',
    revenue.essential_revenue,
    'premium_revenue',
    revenue.premium_revenue
  )
  into result
  from revenue;

  return result;
end;
$$;

grant execute on function public.submit_subscription_plan_request(uuid, text, text, text, text, text) to authenticated;
grant execute on function public.get_platform_dashboard_snapshot() to authenticated;

