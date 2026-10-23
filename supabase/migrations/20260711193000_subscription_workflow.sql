create table if not exists public.subscription_plans (
  code text primary key,
  name text not null,
  description text,
  price_mzn numeric(12,2) not null default 0,
  member_limit integer,
  sort_order integer not null default 0,
  is_public boolean not null default true,
  is_paid boolean not null default false,
  features jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.church_subscriptions (
  church_id uuid primary key references public.churches(id) on delete cascade,
  plan_code text not null references public.subscription_plans(code),
  status text not null default 'trial',
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  current_period_started_at timestamptz,
  current_period_ends_at timestamptz,
  grace_period_ends_at timestamptz,
  activated_at timestamptz,
  suspended_at timestamptz,
  cancelled_at timestamptz,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id),
  admin_notes text
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_subscriptions_status_check'
  ) then
    alter table public.church_subscriptions
      add constraint church_subscriptions_status_check
      check (status in ('trial', 'active', 'grace_period', 'suspended', 'cancelled'));
  end if;
end $$;

create table if not exists public.church_subscription_requests (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  requested_plan_code text not null references public.subscription_plans(code),
  requested_by uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending',
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  review_notes text
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_subscription_requests_status_check'
  ) then
    alter table public.church_subscription_requests
      add constraint church_subscription_requests_status_check
      check (status in ('pending', 'approved', 'rejected', 'cancelled'));
  end if;
end $$;

create index if not exists idx_church_subscriptions_plan_code
  on public.church_subscriptions(plan_code);

create index if not exists idx_church_subscriptions_status
  on public.church_subscriptions(status);

create index if not exists idx_church_subscription_requests_church_id
  on public.church_subscription_requests(church_id);

create index if not exists idx_church_subscription_requests_status
  on public.church_subscription_requests(status);

insert into public.subscription_plans (
  code,
  name,
  description,
  price_mzn,
  member_limit,
  sort_order,
  is_public,
  is_paid,
  features
)
values
  (
    'starter',
    'Starter',
    'Plano gratuito para igrejas pequenas.',
    0,
    50,
    1,
    true,
    false,
    jsonb_build_array(
      'Ate 50 membros',
      'Eventos',
      'Anuncios',
      'Pedidos de oracao',
      'Perfil dos membros',
      'QR Code',
      'Codigo da igreja',
      'Notificacoes basicas'
    )
  ),
  (
    'essential',
    'Essencial',
    'Plano pago para igrejas em crescimento.',
    0,
    500,
    2,
    true,
    true,
    jsonb_build_array(
      'Tudo do Starter',
      'Ate 500 membros',
      'Dizimos e ofertas',
      'Relatorios',
      'Gestao financeira',
      'Ministerios',
      'Exportacao de dados',
      'Notificacoes avancadas'
    )
  ),
  (
    'premium',
    'Premium',
    'Plano completo sem limites funcionais.',
    0,
    null,
    3,
    true,
    true,
    jsonb_build_array(
      'Membros ilimitados',
      'Todas as funcionalidades',
      'Relatorios avancados',
      'Suporte prioritario',
      'Novas funcionalidades em primeira mao'
    )
  )
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  price_mzn = excluded.price_mzn,
  member_limit = excluded.member_limit,
  sort_order = excluded.sort_order,
  is_public = excluded.is_public,
  is_paid = excluded.is_paid,
  features = excluded.features;

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
    'Trial Premium automatico de 30 dias.'
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
declare
  result public.church_subscription_requests;
begin
  if not public.has_church_role(
    p_church_id,
    array['pastor', 'church_admin']::text[]
  ) then
    raise exception 'Only church admins can request a plan for this church.';
  end if;

  if not exists (
    select 1
    from public.subscription_plans
    where code = p_plan_code
      and is_public = true
  ) then
    raise exception 'Unknown subscription plan: %', p_plan_code;
  end if;

  update public.church_subscription_requests
  set status = 'cancelled',
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      review_notes = 'Substituido por um pedido mais recente.'
  where church_id = p_church_id
    and status = 'pending';

  insert into public.church_subscription_requests (
    church_id,
    requested_plan_code,
    requested_by,
    status
  )
  values (
    p_church_id,
    p_plan_code,
    auth.uid(),
    'pending'
  )
  returning *
  into result;

  return result;
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
    when p_status = 'active'
      and effective_plan <> 'starter'
      then now_value + make_interval(days => greatest(coalesce(p_period_days, 30), 1))
    when p_status = 'trial'
      then now_value + make_interval(days => greatest(coalesce(p_period_days, 30), 1))
    else existing_record.current_period_ends_at
  end;

  grace_end := case
    when p_status = 'grace_period'
      then now_value + make_interval(days => greatest(coalesce(p_grace_days, 7), 1))
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
    case
      when p_status = 'active' and effective_plan = 'starter' then null
      when p_status in ('trial', 'active') then period_end
      else existing_record.current_period_ends_at
    end,
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

  if request_row.requested_plan_code = 'starter' then
    result := public.admin_update_church_subscription(
      request_row.church_id,
      'active',
      'starter',
      null,
      null,
      coalesce(p_review_notes, 'Plano Starter ativado.')
    );
  else
    result := public.admin_update_church_subscription(
      request_row.church_id,
      'active',
      request_row.requested_plan_code,
      p_period_days,
      7,
      coalesce(p_review_notes, 'Subscricao paga ativada manualmente pela equipa Comunhao.')
    );
  end if;

  return result;
end;
$$;

create or replace function public.review_church_application(
  p_application_id uuid,
  p_decision text,
  p_review_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  application_row public.church_applications%rowtype;
  new_church_id uuid;
  new_slug text;
  new_join_code text;
begin
  if not public.is_super_admin(auth.uid()) then
    raise exception 'Only super admins can review church applications.';
  end if;

  if p_decision not in ('approved', 'changes_requested', 'rejected') then
    raise exception 'Invalid review decision: %', p_decision;
  end if;

  select *
  into application_row
  from public.church_applications
  where id = p_application_id
  for update;

  if not found then
    raise exception 'Church application not found.';
  end if;

  if application_row.status <> 'submitted' then
    raise exception 'Only submitted applications can be reviewed. Current status: %', application_row.status;
  end if;

  if p_decision = 'approved' then
    new_slug := public.generate_unique_church_slug(application_row.church_name);
    new_join_code := public.generate_unique_join_code(application_row.church_name);

    insert into public.churches (
      name,
      slug,
      join_code,
      app_name,
      tagline,
      hero_title,
      hero_subtitle,
      logo_url,
      primary_color,
      secondary_color,
      phone,
      email,
      city,
      country,
      active
    )
    values (
      application_row.church_name,
      new_slug,
      new_join_code,
      application_row.church_name,
      coalesce(application_row.tagline, 'Powered by Comunhao'),
      application_row.church_name,
      'Comunidade ativa, organizada e ligada em um so lugar.',
      application_row.logo_url,
      application_row.primary_color,
      application_row.secondary_color,
      application_row.phone,
      application_row.email,
      application_row.city,
      application_row.country,
      true
    )
    returning id
    into new_church_id;

    insert into public.church_settings (
      church_id,
      source_application_id,
      member_join_mode,
      join_link,
      require_member_approval
    )
    values (
      new_church_id,
      application_row.id,
      'open',
      'https://comunhao.app/join/' || new_join_code,
      false
    )
    on conflict (church_id) do update
      set
        source_application_id = excluded.source_application_id,
        join_link = excluded.join_link,
        require_member_approval = excluded.require_member_approval;

    if nullif(trim(coalesce(application_row.mpesa, '')), '') is not null then
      insert into public.church_payment_settings (
        church_id,
        provider,
        account_name,
        account_number,
        instructions,
        is_primary
      )
      values (
        new_church_id,
        'mpesa',
        application_row.church_name,
        application_row.mpesa,
        'Recebe dizimos e ofertas por M-Pesa.',
        true
      )
      on conflict (church_id, provider) do update
        set
          account_name = excluded.account_name,
          account_number = excluded.account_number,
          instructions = excluded.instructions,
          is_primary = excluded.is_primary;
    end if;

    if nullif(trim(coalesce(application_row.emola, '')), '') is not null then
      insert into public.church_payment_settings (
        church_id,
        provider,
        account_name,
        account_number,
        instructions,
        is_primary
      )
      values (
        new_church_id,
        'emola',
        application_row.church_name,
        application_row.emola,
        'Recebe dizimos e ofertas por e-Mola.',
        false
      )
      on conflict (church_id, provider) do update
        set
          account_name = excluded.account_name,
          account_number = excluded.account_number,
          instructions = excluded.instructions,
          is_primary = excluded.is_primary;
    end if;

    if nullif(trim(coalesce(application_row.bank_name, '')), '') is not null
      or nullif(trim(coalesce(application_row.bank_account_number, '')), '') is not null then
      insert into public.church_payment_settings (
        church_id,
        provider,
        account_name,
        account_number,
        instructions,
        is_primary
      )
      values (
        new_church_id,
        'bank',
        coalesce(
          nullif(trim(coalesce(application_row.bank_account_name, '')), ''),
          application_row.church_name
        ),
        application_row.bank_account_number,
        coalesce(
          nullif(trim(coalesce(application_row.bank_name, '')), ''),
          'Conta bancaria oficial da igreja.'
        ),
        false
      )
      on conflict (church_id, provider) do update
        set
          account_name = excluded.account_name,
          account_number = excluded.account_number,
          instructions = excluded.instructions,
          is_primary = excluded.is_primary;
    end if;

    insert into public.memberships (
      church_id,
      profile_id,
      role,
      status
    )
    values (
      new_church_id,
      application_row.pastor_profile_id,
      application_row.applicant_role,
      'active'
    )
    on conflict (church_id, profile_id) do update
      set
        role = excluded.role,
        status = 'active';

    perform public.provision_church_trial_subscription(new_church_id, 30);

    update public.church_applications
    set
      status = 'approved',
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      review_notes = p_review_notes,
      approved_church_id = new_church_id,
      updated_at = now()
    where id = p_application_id;

    return new_church_id;
  end if;

  update public.church_applications
  set
    status = p_decision,
    reviewed_at = now(),
    reviewed_by = auth.uid(),
    review_notes = p_review_notes,
    updated_at = now()
  where id = p_application_id;

  return null;
end;
$$;

insert into public.church_subscriptions (
  church_id,
  plan_code,
  status,
  trial_started_at,
  trial_ends_at,
  current_period_started_at,
  current_period_ends_at,
  updated_at,
  admin_notes
)
select
  c.id,
  'premium',
  'trial',
  now(),
  now() + interval '30 days',
  now(),
  now() + interval '30 days',
  now(),
  'Backfill automatico do periodo experimental.'
from public.churches c
where not exists (
  select 1
  from public.church_subscriptions s
  where s.church_id = c.id
);

grant select on public.subscription_plans to anon, authenticated;
grant select on public.church_subscriptions to authenticated;
grant select on public.church_subscription_requests to authenticated;
grant execute on function public.provision_church_trial_subscription(uuid, integer) to authenticated;
grant execute on function public.request_subscription_plan(uuid, text) to authenticated;
grant execute on function public.admin_update_church_subscription(uuid, text, text, integer, integer, text) to authenticated;
grant execute on function public.review_subscription_request(uuid, text, integer, text) to authenticated;

alter table public.subscription_plans enable row level security;
alter table public.church_subscriptions enable row level security;
alter table public.church_subscription_requests enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'subscription_plans'
      and policyname = 'Public can read subscription plans'
  ) then
    create policy "Public can read subscription plans"
      on public.subscription_plans
      for select
      to anon, authenticated
      using (is_public = true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_subscriptions'
      and policyname = 'Members can read own church subscriptions'
  ) then
    create policy "Members can read own church subscriptions"
      on public.church_subscriptions
      for select
      to authenticated
      using (
        public.has_church_role(
          church_id,
          array['member', 'leader', 'pastor', 'church_admin']::text[]
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_subscriptions'
      and policyname = 'Super admins can manage subscriptions'
  ) then
    create policy "Super admins can manage subscriptions"
      on public.church_subscriptions
      for all
      to authenticated
      using (public.is_super_admin())
      with check (public.is_super_admin());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_subscription_requests'
      and policyname = 'Church admins can read own subscription requests'
  ) then
    create policy "Church admins can read own subscription requests"
      on public.church_subscription_requests
      for select
      to authenticated
      using (
        public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[]
        )
        or public.is_super_admin()
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_subscription_requests'
      and policyname = 'Church admins can create subscription requests'
  ) then
    create policy "Church admins can create subscription requests"
      on public.church_subscription_requests
      for insert
      to authenticated
      with check (
        auth.uid() = requested_by
        and public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[]
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_subscription_requests'
      and policyname = 'Super admins can manage subscription requests'
  ) then
    create policy "Super admins can manage subscription requests"
      on public.church_subscription_requests
      for all
      to authenticated
      using (public.is_super_admin())
      with check (public.is_super_admin());
  end if;
end $$;
