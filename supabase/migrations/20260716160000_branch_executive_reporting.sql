create table if not exists public.church_organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  legal_name text,
  code text not null unique,
  headquarters_church_id uuid references public.churches(id) on delete set null,
  owner_profile_id uuid references public.profiles(id) on delete set null,
  phone text,
  email text,
  country text not null default 'Mozambique',
  province text,
  city text,
  primary_color text,
  logo_url text,
  settings jsonb not null default '{}'::jsonb,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.churches
  add column if not exists organization_id uuid references public.church_organizations(id) on delete set null,
  add column if not exists parent_church_id uuid references public.churches(id) on delete set null,
  add column if not exists unit_type text not null default 'headquarters',
  add column if not exists unit_code text,
  add column if not exists province text,
  add column if not exists district text,
  add column if not exists neighborhood text,
  add column if not exists address text,
  add column if not exists latitude numeric(10,7),
  add column if not exists longitude numeric(10,7),
  add column if not exists opened_at date,
  add column if not exists unit_status text not null default 'active',
  add column if not exists capacity integer,
  add column if not exists settings jsonb not null default '{}'::jsonb,
  add column if not exists is_demo boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.church_regions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.church_organizations(id) on delete cascade,
  name text not null,
  region_type text not null default 'region',
  province text,
  district text,
  supervisor_profile_id uuid references public.profiles(id) on delete set null,
  settings jsonb not null default '{}'::jsonb,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, name)
);

alter table public.churches
  add column if not exists region_id uuid references public.church_regions(id) on delete set null;

create table if not exists public.church_unit_leaderships (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  organization_id uuid references public.church_organizations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null,
  starts_at date not null default current_date,
  ends_at date,
  status text not null default 'active',
  permissions text[] not null default '{}'::text[],
  notes text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (church_id, profile_id, role)
);

create table if not exists public.member_transfer_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.church_organizations(id) on delete cascade,
  member_profile_id uuid not null references public.profiles(id) on delete cascade,
  origin_church_id uuid not null references public.churches(id) on delete cascade,
  destination_church_id uuid not null references public.churches(id) on delete cascade,
  requested_by_profile_id uuid references public.profiles(id) on delete set null,
  reason text,
  notes text,
  status text not null default 'submitted',
  origin_decision text,
  origin_decided_by uuid references public.profiles(id) on delete set null,
  origin_decided_at timestamptz,
  destination_decision text,
  destination_decided_by uuid references public.profiles(id) on delete set null,
  destination_decided_at timestamptz,
  completed_at timestamptz,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.executive_goals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.church_organizations(id) on delete cascade,
  church_id uuid references public.churches(id) on delete cascade,
  responsible_profile_id uuid references public.profiles(id) on delete set null,
  name text not null,
  description text,
  goal_type text not null,
  source text not null default 'manual',
  initial_value numeric(14,2) not null default 0,
  target_value numeric(14,2) not null default 0,
  current_value numeric(14,2) not null default 0,
  unit text not null default 'count',
  period_start date not null,
  period_end date not null,
  status text not null default 'planned',
  milestones jsonb not null default '[]'::jsonb,
  notes text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.executive_goal_updates (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references public.executive_goals(id) on delete cascade,
  previous_value numeric(14,2),
  new_value numeric(14,2) not null,
  update_source text not null default 'manual',
  updated_by_profile_id uuid references public.profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.executive_alerts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.church_organizations(id) on delete cascade,
  church_id uuid references public.churches(id) on delete cascade,
  assigned_profile_id uuid references public.profiles(id) on delete set null,
  severity text not null default 'medium',
  alert_type text not null,
  title text not null,
  description text not null,
  status text not null default 'open',
  resolution text,
  resolved_by_profile_id uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.executive_reports (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.church_organizations(id) on delete cascade,
  church_id uuid references public.churches(id) on delete cascade,
  report_type text not null,
  title text not null,
  period_start date not null,
  period_end date not null,
  filters jsonb not null default '{}'::jsonb,
  metrics jsonb not null default '{}'::jsonb,
  status text not null default 'ready',
  sensitive boolean not null default false,
  is_demo boolean not null default false,
  generated_by_profile_id uuid references public.profiles(id) on delete set null,
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.executive_report_exports (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references public.executive_reports(id) on delete set null,
  organization_id uuid not null references public.church_organizations(id) on delete cascade,
  church_id uuid references public.churches(id) on delete cascade,
  requested_by_profile_id uuid references public.profiles(id) on delete set null,
  format text not null,
  filters jsonb not null default '{}'::jsonb,
  contains_sensitive_data boolean not null default false,
  export_status text not null default 'registered',
  storage_path text,
  created_at timestamptz not null default now()
);

create table if not exists public.organization_audit_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.church_organizations(id) on delete set null,
  church_id uuid references public.churches(id) on delete set null,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid,
  summary text not null,
  details jsonb not null default '{}'::jsonb,
  sensitive boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_churches_organization_id on public.churches(organization_id);
create index if not exists idx_churches_parent_church_id on public.churches(parent_church_id);
create index if not exists idx_churches_region_id on public.churches(region_id);
create index if not exists idx_churches_unit_status on public.churches(unit_status);
create index if not exists idx_church_regions_organization_id on public.church_regions(organization_id);
create index if not exists idx_church_unit_leaderships_church on public.church_unit_leaderships(church_id, status);
create index if not exists idx_church_unit_leaderships_profile on public.church_unit_leaderships(profile_id, status);
create index if not exists idx_member_transfer_requests_org_status on public.member_transfer_requests(organization_id, status);
create index if not exists idx_member_transfer_requests_member on public.member_transfer_requests(member_profile_id);
create index if not exists idx_executive_goals_org_period on public.executive_goals(organization_id, period_start, period_end);
create index if not exists idx_executive_alerts_org_status on public.executive_alerts(organization_id, status, severity);
create index if not exists idx_executive_reports_org_period on public.executive_reports(organization_id, period_start, period_end);
create index if not exists idx_executive_report_exports_org_created on public.executive_report_exports(organization_id, created_at desc);
create index if not exists idx_organization_audit_logs_org_created on public.organization_audit_logs(organization_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_church_organizations_updated_at on public.church_organizations;
create trigger set_church_organizations_updated_at
  before update on public.church_organizations
  for each row execute function public.set_updated_at();

drop trigger if exists set_churches_updated_at on public.churches;
create trigger set_churches_updated_at
  before update on public.churches
  for each row execute function public.set_updated_at();

drop trigger if exists set_church_regions_updated_at on public.church_regions;
create trigger set_church_regions_updated_at
  before update on public.church_regions
  for each row execute function public.set_updated_at();

drop trigger if exists set_church_unit_leaderships_updated_at on public.church_unit_leaderships;
create trigger set_church_unit_leaderships_updated_at
  before update on public.church_unit_leaderships
  for each row execute function public.set_updated_at();

drop trigger if exists set_member_transfer_requests_updated_at on public.member_transfer_requests;
create trigger set_member_transfer_requests_updated_at
  before update on public.member_transfer_requests
  for each row execute function public.set_updated_at();

drop trigger if exists set_executive_goals_updated_at on public.executive_goals;
create trigger set_executive_goals_updated_at
  before update on public.executive_goals
  for each row execute function public.set_updated_at();

drop trigger if exists set_executive_alerts_updated_at on public.executive_alerts;
create trigger set_executive_alerts_updated_at
  before update on public.executive_alerts
  for each row execute function public.set_updated_at();

create or replace function public.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid();
$$;

create or replace function public.user_can_access_organization(
  p_organization_id uuid,
  p_permission text default null,
  p_user uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(auth.role(), '') = 'service_role'
    or current_user in ('postgres', 'supabase_admin')
    or public.has_platform_role(array['super_admin', 'support_agent', 'auditor']::text[], coalesce(p_user, auth.uid()))
    or exists (
      select 1
      from public.memberships m
      join public.churches c on c.id = m.church_id
      where m.profile_id = coalesce(p_user, auth.uid())
        and m.status = 'active'
        and c.organization_id = p_organization_id
        and (
          m.role in ('pastor', 'church_admin')
          or coalesce(p_permission, '') = ''
        )
    )
    or exists (
      select 1
      from public.church_unit_leaderships l
      where l.profile_id = coalesce(p_user, auth.uid())
        and l.organization_id = p_organization_id
        and l.status = 'active'
        and (
          coalesce(p_permission, '') = ''
          or p_permission = any(l.permissions)
        )
    );
$$;

create or replace function public.user_can_access_church(
  p_church_id uuid,
  p_permission text default null,
  p_user uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(auth.role(), '') = 'service_role'
    or current_user in ('postgres', 'supabase_admin')
    or public.has_platform_role(array['super_admin', 'support_agent', 'auditor']::text[], coalesce(p_user, auth.uid()))
    or exists (
      select 1
      from public.memberships m
      where m.profile_id = coalesce(p_user, auth.uid())
        and m.church_id = p_church_id
        and m.status = 'active'
    )
    or exists (
      select 1
      from public.churches c
      where c.id = p_church_id
        and c.organization_id is not null
        and public.user_can_access_organization(c.organization_id, p_permission, coalesce(p_user, auth.uid()))
    );
$$;

create or replace function public.create_organization_audit_log(
  p_organization_id uuid,
  p_action text,
  p_target_type text,
  p_target_id uuid default null,
  p_church_id uuid default null,
  p_summary text default null,
  p_details jsonb default '{}'::jsonb,
  p_sensitive boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  log_id uuid;
begin
  insert into public.organization_audit_logs (
    organization_id,
    church_id,
    actor_profile_id,
    action,
    target_type,
    target_id,
    summary,
    details,
    sensitive
  )
  values (
    p_organization_id,
    p_church_id,
    auth.uid(),
    p_action,
    p_target_type,
    p_target_id,
    coalesce(nullif(trim(coalesce(p_summary, '')), ''), p_action),
    coalesce(p_details, '{}'::jsonb),
    coalesce(p_sensitive, false)
  )
  returning id into log_id;

  return log_id;
end;
$$;

create or replace function public.ensure_church_organization(
  p_church_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  church_row public.churches%rowtype;
  owner_id uuid;
  org_id uuid;
begin
  select * into church_row
  from public.churches
  where id = p_church_id
  limit 1;

  if church_row.id is null then
    raise exception 'Church not found.';
  end if;

  if church_row.organization_id is not null then
    return church_row.organization_id;
  end if;

  select owner_profile_id into owner_id
  from public.church_settings
  where church_id = p_church_id
  limit 1;

  insert into public.church_organizations (
    name,
    code,
    headquarters_church_id,
    owner_profile_id,
    phone,
    email,
    province,
    city,
    primary_color,
    logo_url,
    is_demo
  )
  values (
    church_row.name,
    upper(regexp_replace(coalesce(church_row.slug, church_row.name), '[^a-zA-Z0-9]+', '-', 'g')),
    p_church_id,
    owner_id,
    church_row.phone,
    church_row.email,
    church_row.province,
    church_row.city,
    church_row.primary_color,
    church_row.logo_url,
    church_row.is_demo
  )
  on conflict (code) do update
  set headquarters_church_id = coalesce(public.church_organizations.headquarters_church_id, excluded.headquarters_church_id)
  returning id into org_id;

  update public.churches
  set
    organization_id = org_id,
    parent_church_id = null,
    unit_type = 'headquarters',
    unit_status = case when active then 'active' else 'suspended' end,
    unit_code = coalesce(unit_code, upper(regexp_replace(coalesce(slug, name), '[^a-zA-Z0-9]+', '-', 'g'))),
    is_demo = false
  where id = p_church_id;

  if owner_id is not null then
    insert into public.church_unit_leaderships (
      church_id,
      organization_id,
      profile_id,
      role,
      permissions
    )
    values (
      p_church_id,
      org_id,
      owner_id,
      'pastor_presidente',
      array[
        'organization.view',
        'organization.manage',
        'branch.create',
        'branch.approve',
        'branch.manage',
        'branch.metrics.view',
        'branch.finance.view',
        'branch.members.view',
        'branch.transfer_member',
        'reports.consolidated.view',
        'reports.branch.view',
        'goals.manage'
      ]::text[]
    )
    on conflict (church_id, profile_id, role) do update
    set
      organization_id = excluded.organization_id,
      status = 'active',
      permissions = excluded.permissions;
  end if;

  return org_id;
end;
$$;

create or replace function public.create_branch_unit(
  p_parent_church_id uuid,
  p_name text,
  p_unit_type text default 'congregation',
  p_city text default null,
  p_province text default null,
  p_pastor_phone text default null,
  p_leader_phone text default null,
  p_unit_status text default 'active',
  p_is_demo boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  org_id uuid;
  parent_row public.churches%rowtype;
  branch_id uuid;
  pastor_id uuid;
  leader_id uuid;
  base_slug text;
begin
  select * into parent_row
  from public.churches
  where id = p_parent_church_id
  limit 1;

  if parent_row.id is null then
    raise exception 'Parent church not found.';
  end if;

  org_id := public.ensure_church_organization(p_parent_church_id);

  if not public.user_can_access_organization(org_id, 'branch.create', auth.uid()) then
    raise exception 'Not allowed to create a congregation.';
  end if;

  base_slug := lower(regexp_replace(coalesce(nullif(trim(p_name), ''), 'congregacao'), '[^a-zA-Z0-9]+', '-', 'g'));

  insert into public.churches (
    name,
    slug,
    app_name,
    tagline,
    logo_url,
    primary_color,
    secondary_color,
    phone,
    city,
    country,
    active,
    organization_id,
    parent_church_id,
    unit_type,
    unit_code,
    province,
    unit_status,
    is_demo,
    settings
  )
  values (
    trim(p_name),
    base_slug || '-' || substr(gen_random_uuid()::text, 1, 8),
    trim(p_name),
    'Congregacao ligada a ' || parent_row.name,
    parent_row.logo_url,
    parent_row.primary_color,
    parent_row.secondary_color,
    coalesce(p_pastor_phone, p_leader_phone, parent_row.phone),
    coalesce(nullif(trim(p_city), ''), parent_row.city),
    coalesce(parent_row.country, 'Mozambique'),
    p_unit_status in ('active', 'preparation', 'reorganization'),
    org_id,
    p_parent_church_id,
    coalesce(nullif(trim(p_unit_type), ''), 'congregation'),
    upper(substr(base_slug, 1, 16)) || '-' || substr(gen_random_uuid()::text, 1, 4),
    coalesce(nullif(trim(p_province), ''), parent_row.province),
    coalesce(nullif(trim(p_unit_status), ''), 'active'),
    coalesce(p_is_demo, false),
    jsonb_build_object('created_from', 'create_branch_unit')
  )
  returning id into branch_id;

  pastor_id := public.profile_id_by_phone(p_pastor_phone);
  leader_id := public.profile_id_by_phone(coalesce(p_leader_phone, p_pastor_phone));

  if pastor_id is not null then
    insert into public.memberships (church_id, profile_id, role, status)
    values (branch_id, pastor_id, 'pastor', 'active')
    on conflict (church_id, profile_id) do update
    set role = 'pastor', status = 'active';

    insert into public.church_unit_leaderships (
      church_id,
      organization_id,
      profile_id,
      role,
      permissions,
      is_demo
    )
    values (
      branch_id,
      org_id,
      pastor_id,
      'pastor_local',
      array['reports.branch.view', 'goals.manage']::text[],
      coalesce(p_is_demo, false)
    )
    on conflict (church_id, profile_id, role) do update
    set status = 'active', permissions = excluded.permissions;

    perform public.create_internal_notification(
      pastor_id,
      'Congregacao atribuida',
      'Foi nomeado responsavel por ' || trim(p_name) || '.',
      'branch_assigned',
      branch_id,
      auth.uid(),
      'normal',
      'churches',
      branch_id,
      '/church/branches',
      jsonb_build_object('organization_id', org_id)
    );
  end if;

  if leader_id is not null and leader_id is distinct from pastor_id then
    insert into public.memberships (church_id, profile_id, role, status)
    values (branch_id, leader_id, 'church_admin', 'active')
    on conflict (church_id, profile_id) do update
    set role = 'church_admin', status = 'active';
  end if;

  perform public.create_organization_audit_log(
    org_id,
    'branch.created',
    'church',
    branch_id,
    branch_id,
    'Congregacao criada: ' || trim(p_name),
    jsonb_build_object('parent_church_id', p_parent_church_id, 'is_demo', coalesce(p_is_demo, false)),
    false
  );

  return branch_id;
end;
$$;

create or replace function public.create_member_transfer_request(
  p_member_phone text,
  p_origin_church_id uuid,
  p_destination_church_id uuid,
  p_reason text default null,
  p_notes text default null,
  p_is_demo boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  org_id uuid;
  member_id uuid;
  request_id uuid;
begin
  select organization_id into org_id
  from public.churches
  where id = p_origin_church_id
  limit 1;

  if org_id is null then
    org_id := public.ensure_church_organization(p_origin_church_id);
  end if;

  if not exists (
    select 1
    from public.churches
    where id = p_destination_church_id
      and organization_id = org_id
  ) then
    raise exception 'Destination church is not in the same organization.';
  end if;

  if not public.user_can_access_organization(org_id, 'branch.transfer_member', auth.uid()) then
    raise exception 'Not allowed to transfer members.';
  end if;

  member_id := public.profile_id_by_phone(p_member_phone);
  if member_id is null then
    raise exception 'Member profile not found.';
  end if;

  if not exists (
    select 1
    from public.memberships
    where church_id = p_origin_church_id
      and profile_id = member_id
      and status = 'active'
  ) then
    raise exception 'Active origin membership not found.';
  end if;

  insert into public.member_transfer_requests (
    organization_id,
    member_profile_id,
    origin_church_id,
    destination_church_id,
    requested_by_profile_id,
    reason,
    notes,
    status,
    is_demo
  )
  values (
    org_id,
    member_id,
    p_origin_church_id,
    p_destination_church_id,
    auth.uid(),
    p_reason,
    p_notes,
    'submitted',
    coalesce(p_is_demo, false)
  )
  returning id into request_id;

  perform public.create_organization_audit_log(
    org_id,
    'member_transfer.requested',
    'member_transfer_request',
    request_id,
    p_origin_church_id,
    'Transferencia de membro solicitada.',
    jsonb_build_object('destination_church_id', p_destination_church_id, 'member_profile_id', member_id),
    true
  );

  return request_id;
end;
$$;

create or replace function public.get_organization_dashboard(
  p_church_id uuid,
  p_include_demo boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  org_id uuid;
  units jsonb;
  goals jsonb;
  alerts jsonb;
  reports jsonb;
  dashboard_metrics jsonb;
begin
  select organization_id into org_id
  from public.churches
  where id = p_church_id
  limit 1;

  if org_id is null then
    org_id := public.ensure_church_organization(p_church_id);
  end if;

  if not public.user_can_access_organization(org_id, 'reports.consolidated.view', auth.uid()) then
    raise exception 'Not allowed to view consolidated reports.';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'name', c.name,
      'slug', c.slug,
      'unit_type', c.unit_type,
      'unit_code', c.unit_code,
      'parent_church_id', c.parent_church_id,
      'city', c.city,
      'province', c.province,
      'unit_status', c.unit_status,
      'active', c.active,
      'is_demo', c.is_demo,
      'member_count', (
        select count(*)
        from public.memberships m
        where m.church_id = c.id
          and m.status = 'active'
      ),
      'pastor_name', (
        select p.full_name
        from public.memberships m
        join public.profiles p on p.id = m.profile_id
        where m.church_id = c.id
          and m.status = 'active'
          and m.role = 'pastor'
        order by m.created_at
        limit 1
      )
    )
    order by c.parent_church_id nulls first, c.created_at
  ), '[]'::jsonb) into units
  from public.churches c
  where c.organization_id = org_id
    and (p_include_demo or c.is_demo = false);

  select jsonb_build_object(
    'total_churches', count(*),
    'active_churches', count(*) filter (where c.unit_status = 'active' and c.active),
    'preparation_churches', count(*) filter (where c.unit_status = 'preparation'),
    'total_members', coalesce(sum((
      select count(*)
      from public.memberships m
      where m.church_id = c.id
        and m.status = 'active'
    )), 0),
    'active_campaigns', (
      select count(*)
      from public.donation_campaigns dc
      where dc.church_id in (select id from public.churches where organization_id = org_id and (p_include_demo or is_demo = false))
        and dc.active = true
    ),
    'confirmed_contributions', (
      select coalesce(sum(d.amount), 0)
      from public.donations d
      where d.church_id in (select id from public.churches where organization_id = org_id and (p_include_demo or is_demo = false))
        and d.status = 'confirmed'
    ),
    'monthly_revenue', (
      select coalesce(sum(w.amount), 0)
      from public.wallet_ledger_entries w
      where w.church_id in (select id from public.churches where organization_id = org_id and (p_include_demo or is_demo = false))
        and w.direction = 'credit'
        and w.status = 'posted'
        and date_trunc('month', w.created_at) = date_trunc('month', now())
    ),
    'monthly_expenses', (
      select coalesce(sum(e.amount), 0)
      from public.church_expenses e
      where e.church_id in (select id from public.churches where organization_id = org_id and (p_include_demo or is_demo = false))
        and e.status in ('approved', 'paid', 'confirmed')
        and date_trunc('month', e.spent_at) = date_trunc('month', now())
    ),
    'open_tasks', (
      select count(*)
      from public.operational_tasks t
      where t.church_id in (select id from public.churches where organization_id = org_id and (p_include_demo or is_demo = false))
        and t.status not in ('done', 'cancelled')
    ),
    'overdue_tasks', (
      select count(*)
      from public.operational_tasks t
      where t.church_id in (select id from public.churches where organization_id = org_id and (p_include_demo or is_demo = false))
        and t.status not in ('done', 'cancelled')
        and t.due_at < now()
    ),
    'open_alerts', (
      select count(*)
      from public.executive_alerts a
      where a.organization_id = org_id
        and a.status = 'open'
        and (p_include_demo or a.is_demo = false)
    ),
    'goals_at_risk', (
      select count(*)
      from public.executive_goals g
      where g.organization_id = org_id
        and g.status = 'at_risk'
        and (p_include_demo or g.is_demo = false)
    )
  ) into dashboard_metrics
  from public.churches c
  where c.organization_id = org_id
    and (p_include_demo or c.is_demo = false);

  select coalesce(jsonb_agg(to_jsonb(g) order by g.period_end, g.created_at desc), '[]'::jsonb)
  into goals
  from (
    select id, organization_id, church_id, name, description, goal_type, source,
      initial_value, target_value, current_value, unit, period_start, period_end,
      status, milestones, notes, is_demo, created_at
    from public.executive_goals
    where organization_id = org_id
      and (p_include_demo or is_demo = false)
    order by period_end, created_at desc
    limit 12
  ) g;

  select coalesce(jsonb_agg(to_jsonb(a) order by a.created_at desc), '[]'::jsonb)
  into alerts
  from (
    select id, organization_id, church_id, severity, alert_type, title, description,
      status, resolution, is_demo, created_at
    from public.executive_alerts
    where organization_id = org_id
      and (p_include_demo or is_demo = false)
    order by created_at desc
    limit 12
  ) a;

  select coalesce(jsonb_agg(to_jsonb(r) order by r.generated_at desc), '[]'::jsonb)
  into reports
  from (
    select id, organization_id, church_id, report_type, title, period_start, period_end,
      filters, metrics, status, sensitive, is_demo, generated_at
    from public.executive_reports
    where organization_id = org_id
      and (p_include_demo or is_demo = false)
    order by generated_at desc
    limit 8
  ) r;

  perform public.create_organization_audit_log(
    org_id,
    'dashboard.viewed',
    'church_organization',
    org_id,
    p_church_id,
    'Painel consolidado consultado.',
    jsonb_build_object('include_demo', p_include_demo),
    true
  );

  return jsonb_build_object(
    'organization_id', org_id,
    'metrics', coalesce(dashboard_metrics, '{}'::jsonb),
    'units', units,
    'goals', goals,
    'alerts', alerts,
    'reports', reports
  );
end;
$$;

create or replace function public.register_executive_report_export(
  p_report_id uuid,
  p_format text,
  p_filters jsonb default '{}'::jsonb,
  p_contains_sensitive_data boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  report_row public.executive_reports%rowtype;
  export_id uuid;
begin
  select * into report_row
  from public.executive_reports
  where id = p_report_id
  limit 1;

  if report_row.id is null then
    raise exception 'Report not found.';
  end if;

  if not public.user_can_access_organization(report_row.organization_id, 'reports.consolidated.view', auth.uid()) then
    raise exception 'Not allowed to export this report.';
  end if;

  insert into public.executive_report_exports (
    report_id,
    organization_id,
    church_id,
    requested_by_profile_id,
    format,
    filters,
    contains_sensitive_data
  )
  values (
    report_row.id,
    report_row.organization_id,
    report_row.church_id,
    auth.uid(),
    lower(coalesce(nullif(trim(p_format), ''), 'pdf')),
    coalesce(p_filters, '{}'::jsonb),
    coalesce(p_contains_sensitive_data, false)
  )
  returning id into export_id;

  perform public.create_organization_audit_log(
    report_row.organization_id,
    'report.exported',
    'executive_report',
    report_row.id,
    report_row.church_id,
    'Exportacao de relatorio registada.',
    jsonb_build_object('format', p_format, 'export_id', export_id),
    coalesce(p_contains_sensitive_data, false)
  );

  return export_id;
end;
$$;

create or replace function public.resolve_executive_alert(
  p_alert_id uuid,
  p_resolution text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  alert_row public.executive_alerts%rowtype;
begin
  select * into alert_row
  from public.executive_alerts
  where id = p_alert_id
  limit 1;

  if alert_row.id is null then
    raise exception 'Alert not found.';
  end if;

  if not public.user_can_access_organization(alert_row.organization_id, 'goals.manage', auth.uid()) then
    raise exception 'Not allowed to resolve this alert.';
  end if;

  update public.executive_alerts
  set
    status = 'resolved',
    resolution = p_resolution,
    resolved_by_profile_id = auth.uid(),
    resolved_at = now()
  where id = p_alert_id;

  perform public.create_organization_audit_log(
    alert_row.organization_id,
    'alert.resolved',
    'executive_alert',
    p_alert_id,
    alert_row.church_id,
    'Alerta executivo resolvido.',
    jsonb_build_object('resolution', p_resolution),
    false
  );

  return p_alert_id;
end;
$$;

alter table public.church_organizations enable row level security;
alter table public.church_regions enable row level security;
alter table public.church_unit_leaderships enable row level security;
alter table public.member_transfer_requests enable row level security;
alter table public.executive_goals enable row level security;
alter table public.executive_goal_updates enable row level security;
alter table public.executive_alerts enable row level security;
alter table public.executive_reports enable row level security;
alter table public.executive_report_exports enable row level security;
alter table public.organization_audit_logs enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'church_organizations' and policyname = 'Members can view their organization') then
    create policy "Members can view their organization"
      on public.church_organizations for select to authenticated
      using (public.user_can_access_organization(id));
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'church_regions' and policyname = 'Members can view allowed regions') then
    create policy "Members can view allowed regions"
      on public.church_regions for select to authenticated
      using (public.user_can_access_organization(organization_id));
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'church_unit_leaderships' and policyname = 'Members can view allowed leaderships') then
    create policy "Members can view allowed leaderships"
      on public.church_unit_leaderships for select to authenticated
      using (public.user_can_access_organization(organization_id));
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'member_transfer_requests' and policyname = 'Members can view allowed transfer requests') then
    create policy "Members can view allowed transfer requests"
      on public.member_transfer_requests for select to authenticated
      using (public.user_can_access_organization(organization_id, 'branch.transfer_member'));
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'executive_goals' and policyname = 'Members can view allowed goals') then
    create policy "Members can view allowed goals"
      on public.executive_goals for select to authenticated
      using (public.user_can_access_organization(organization_id, 'branch.metrics.view'));
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'executive_goal_updates' and policyname = 'Members can view allowed goal updates') then
    create policy "Members can view allowed goal updates"
      on public.executive_goal_updates for select to authenticated
      using (
        exists (
          select 1 from public.executive_goals g
          where g.id = executive_goal_updates.goal_id
            and public.user_can_access_organization(g.organization_id, 'branch.metrics.view')
        )
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'executive_alerts' and policyname = 'Members can view allowed alerts') then
    create policy "Members can view allowed alerts"
      on public.executive_alerts for select to authenticated
      using (public.user_can_access_organization(organization_id, 'branch.metrics.view'));
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'executive_reports' and policyname = 'Members can view allowed reports') then
    create policy "Members can view allowed reports"
      on public.executive_reports for select to authenticated
      using (public.user_can_access_organization(organization_id, 'reports.consolidated.view'));
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'executive_report_exports' and policyname = 'Members can view allowed report exports') then
    create policy "Members can view allowed report exports"
      on public.executive_report_exports for select to authenticated
      using (public.user_can_access_organization(organization_id, 'reports.consolidated.view'));
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'organization_audit_logs' and policyname = 'Members can view allowed organization audit') then
    create policy "Members can view allowed organization audit"
      on public.organization_audit_logs for select to authenticated
      using (public.user_can_access_organization(organization_id, 'reports.consolidated.view'));
  end if;
end $$;

grant select on public.church_organizations to authenticated;
grant select on public.church_regions to authenticated;
grant select on public.church_unit_leaderships to authenticated;
grant select on public.member_transfer_requests to authenticated;
grant select on public.executive_goals to authenticated;
grant select on public.executive_goal_updates to authenticated;
grant select on public.executive_alerts to authenticated;
grant select on public.executive_reports to authenticated;
grant select on public.executive_report_exports to authenticated;
grant select on public.organization_audit_logs to authenticated;

grant execute on function public.ensure_church_organization(uuid) to authenticated, service_role;
grant execute on function public.create_branch_unit(uuid, text, text, text, text, text, text, text, boolean) to authenticated, service_role;
grant execute on function public.create_member_transfer_request(text, uuid, uuid, text, text, boolean) to authenticated, service_role;
grant execute on function public.get_organization_dashboard(uuid, boolean) to authenticated, service_role;
grant execute on function public.register_executive_report_export(uuid, text, jsonb, boolean) to authenticated, service_role;
grant execute on function public.resolve_executive_alert(uuid, text) to authenticated, service_role;

do $$
declare
  vida_id uuid;
  org_id uuid;
  sara_id uuid;
  member_id uuid;
  branch_a uuid;
  branch_b uuid;
  branch_c uuid;
  report_id uuid;
begin
  select id into vida_id
  from public.churches
  where slug = 'vida-nova'
  limit 1;

  if vida_id is null then
    return;
  end if;

  org_id := public.ensure_church_organization(vida_id);
  sara_id := public.profile_id_by_phone('877688695');
  member_id := public.profile_id_by_phone('827688695');

  update public.church_organizations
  set
    name = 'Igreja Vida Nova',
    phone = '877688695',
    province = 'Maputo',
    city = 'Maputo',
    primary_color = '#B57EDC',
    owner_profile_id = coalesce(sara_id, owner_profile_id)
  where id = org_id;

  update public.churches
  set
    name = 'Igreja Vida Nova',
    app_name = 'Igreja Vida Nova',
    phone = '877688695',
    province = 'Maputo',
    city = 'Maputo',
    primary_color = '#B57EDC',
    unit_type = 'headquarters',
    unit_status = 'active',
    is_demo = false
  where id = vida_id;

  insert into public.church_regions (organization_id, name, region_type, province, supervisor_profile_id, is_demo)
  values (org_id, 'Maputo Sul', 'zona_pastoral', 'Maputo', sara_id, true)
  on conflict (organization_id, name) do update
  set supervisor_profile_id = excluded.supervisor_profile_id;

  insert into public.churches (
    name, slug, app_name, tagline, primary_color, phone, city, province, country,
    active, organization_id, parent_church_id, unit_type, unit_code, unit_status, is_demo
  )
  values
    ('Vida Nova Chamanculo', 'vida-nova-chamanculo-demo', 'Vida Nova Chamanculo', 'Congregacao demo da Igreja Vida Nova.', '#B57EDC', '877688695', 'Maputo', 'Maputo', 'Mozambique', true, org_id, vida_id, 'congregation', 'VN-CHM', 'active', true),
    ('Vida Nova Matola', 'vida-nova-matola-demo', 'Vida Nova Matola', 'Congregacao demo da Igreja Vida Nova.', '#B57EDC', '877688695', 'Matola', 'Maputo', 'Mozambique', true, org_id, vida_id, 'branch', 'VN-MAT', 'active', true),
    ('Vida Nova Zimpeto', 'vida-nova-zimpeto-demo', 'Vida Nova Zimpeto', 'Ponto de pregacao em preparacao.', '#B57EDC', '877688695', 'Maputo', 'Maputo', 'Mozambique', true, org_id, vida_id, 'preaching_point', 'VN-ZIM', 'preparation', true)
  on conflict (slug) do update
  set
    organization_id = excluded.organization_id,
    parent_church_id = excluded.parent_church_id,
    unit_status = excluded.unit_status,
    is_demo = true;

  select id into branch_a from public.churches where slug = 'vida-nova-chamanculo-demo';
  select id into branch_b from public.churches where slug = 'vida-nova-matola-demo';
  select id into branch_c from public.churches where slug = 'vida-nova-zimpeto-demo';

  if sara_id is not null then
    insert into public.church_unit_leaderships (church_id, organization_id, profile_id, role, permissions, is_demo)
    values
      (vida_id, org_id, sara_id, 'pastor_presidente', array['organization.view','organization.manage','branch.create','branch.approve','branch.manage','branch.metrics.view','branch.finance.view','branch.members.view','branch.transfer_member','reports.consolidated.view','reports.branch.view','goals.manage']::text[], false),
      (branch_a, org_id, sara_id, 'supervisor_regional', array['branch.metrics.view','reports.branch.view']::text[], true),
      (branch_b, org_id, sara_id, 'supervisor_regional', array['branch.metrics.view','reports.branch.view']::text[], true)
    on conflict (church_id, profile_id, role) do update
    set permissions = excluded.permissions, status = 'active';
  end if;

  insert into public.executive_goals (
    organization_id, church_id, responsible_profile_id, name, description, goal_type,
    source, initial_value, target_value, current_value, unit, period_start, period_end, status, is_demo
  )
  values
    (org_id, vida_id, sara_id, 'Crescimento de membros', 'Meta demo para acompanhar crescimento da sede e congregacoes.', 'member_growth', 'manual', 120, 180, 148, 'membros', date_trunc('month', now())::date, (date_trunc('month', now()) + interval '1 month - 1 day')::date, 'active', true),
    (org_id, vida_id, sara_id, 'Abertura de congregacoes', 'Preparar novas frentes missionarias em Maputo.', 'branch_opening', 'manual', 2, 4, 3, 'unidades', date_trunc('year', now())::date, (date_trunc('year', now()) + interval '1 year - 1 day')::date, 'at_risk', true)
  on conflict do nothing;

  insert into public.executive_alerts (
    organization_id, church_id, assigned_profile_id, severity, alert_type, title, description, status, is_demo
  )
  values
    (org_id, branch_c, sara_id, 'medium', 'branch_preparation', 'Congregacao em preparacao', 'Vida Nova Zimpeto precisa concluir lideranca e agenda inaugural.', 'open', true),
    (org_id, vida_id, sara_id, 'high', 'goal_at_risk', 'Meta de expansao em risco', 'A abertura de congregacoes esta abaixo do ritmo previsto.', 'open', true)
  on conflict do nothing;

  if member_id is not null and branch_a is not null then
    insert into public.member_transfer_requests (
      organization_id, member_profile_id, origin_church_id, destination_church_id,
      requested_by_profile_id, reason, status, is_demo
    )
    values (
      org_id, member_id, vida_id, branch_a, sara_id,
      'Membro vai congregar numa unidade mais proxima.', 'submitted', true
    )
    on conflict do nothing;
  end if;

  insert into public.executive_reports (
    organization_id, church_id, report_type, title, period_start, period_end,
    filters, metrics, status, sensitive, is_demo, generated_by_profile_id
  )
  values (
    org_id,
    vida_id,
    'monthly_summary',
    'Resumo mensal consolidado demo',
    date_trunc('month', now())::date,
    (date_trunc('month', now()) + interval '1 month - 1 day')::date,
    jsonb_build_object('include_demo', true, 'province', 'Maputo'),
    public.get_organization_dashboard(vida_id, true)->'metrics',
    'ready',
    false,
    true,
    sara_id
  )
  returning id into report_id;

  perform public.create_organization_audit_log(
    org_id,
    'demo.seeded',
    'church_organization',
    org_id,
    vida_id,
    'Dados demo de congregacoes, metas, alertas e relatorio criados para Igreja Vida Nova.',
    jsonb_build_object('report_id', report_id),
    false
  );
end $$;
