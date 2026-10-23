alter table public.church_ministries
  add column if not exists ministry_type text not null default 'ministry',
  add column if not exists status text not null default 'active',
  add column if not exists vice_leader_membership_id uuid references public.memberships(id) on delete set null,
  add column if not exists secretary_membership_id uuid references public.memberships(id) on delete set null,
  add column if not exists treasurer_membership_id uuid references public.memberships(id) on delete set null,
  add column if not exists color text,
  add column if not exists icon text,
  add column if not exists contact text,
  add column if not exists usual_location text,
  add column if not exists budget_amount numeric(12,2) not null default 0,
  add column if not exists goals text,
  add column if not exists notes text,
  add column if not exists is_demo boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

update public.church_ministries
set status = case when active then 'active' else 'inactive' end
where status is null or status = 'active';

alter table public.ministry_members
  add column if not exists status text not null default 'active',
  add column if not exists started_at date not null default current_date,
  add column if not exists ended_at date,
  add column if not exists appointed_by uuid references public.profiles(id),
  add column if not exists permissions text[] not null default '{}'::text[],
  add column if not exists notes text,
  add column if not exists updated_at timestamptz not null default now();

alter table public.church_assets
  add column if not exists asset_code text,
  add column if not exists description text,
  add column if not exists brand text,
  add column if not exists model text,
  add column if not exists serial_number text,
  add column if not exists acquired_at date,
  add column if not exists acquisition_value numeric(12,2),
  add column if not exists current_value numeric(12,2),
  add column if not exists supplier text,
  add column if not exists receipt_url text,
  add column if not exists responsible_membership_id uuid references public.memberships(id) on delete set null,
  add column if not exists ministry_id uuid references public.church_ministries(id) on delete set null,
  add column if not exists warranty_until date,
  add column if not exists photo_urls text[] not null default '{}'::text[],
  add column if not exists document_url text,
  add column if not exists qr_code text,
  add column if not exists status text not null default 'available',
  add column if not exists is_demo boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

update public.church_assets
set
  status = case
    when item_condition = 'needs_repair' then 'maintenance'
    when item_condition = 'retired' then 'archived'
    else coalesce(status, 'available')
  end,
  asset_code = coalesce(asset_code, 'AST-' || upper(substr(replace(id::text, '-', ''), 1, 8))),
  qr_code = coalesce(qr_code, 'asset:' || id::text);

create table if not exists public.church_groups (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  ministry_id uuid references public.church_ministries(id) on delete set null,
  name text not null,
  group_type text not null default 'cell',
  description text,
  leader_membership_id uuid references public.memberships(id) on delete set null,
  vice_leader_membership_id uuid references public.memberships(id) on delete set null,
  location text,
  usual_day text,
  usual_time text,
  capacity integer,
  audience text not null default 'members',
  objective text,
  notes text,
  status text not null default 'active',
  color text,
  is_demo boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(church_id, name)
);

create table if not exists public.church_group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.church_groups(id) on delete cascade,
  membership_id uuid not null references public.memberships(id) on delete cascade,
  role text not null default 'member',
  status text not null default 'active',
  joined_at date not null default current_date,
  ended_at date,
  notes text,
  created_at timestamptz not null default now(),
  unique(group_id, membership_id)
);

create table if not exists public.ministry_join_requests (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  ministry_id uuid references public.church_ministries(id) on delete cascade,
  group_id uuid references public.church_groups(id) on delete cascade,
  membership_id uuid not null references public.memberships(id) on delete cascade,
  interest text,
  experience text,
  status text not null default 'pending',
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  review_notes text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_join_requests_active_unique
  on public.ministry_join_requests(
    church_id,
    membership_id,
    coalesce(ministry_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(group_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where status in ('pending', 'reviewing', 'interview_required');

create table if not exists public.volunteer_opportunities (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  ministry_id uuid references public.church_ministries(id) on delete set null,
  event_id uuid references public.events(id) on delete set null,
  title text not null,
  description text,
  starts_at timestamptz,
  ends_at timestamptz,
  location text,
  slots integer,
  requirements text,
  responsible_membership_id uuid references public.memberships(id) on delete set null,
  status text not null default 'open',
  is_demo boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.volunteer_applications (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references public.volunteer_opportunities(id) on delete cascade,
  membership_id uuid not null references public.memberships(id) on delete cascade,
  status text not null default 'pending',
  notes text,
  checked_in_at timestamptz,
  created_at timestamptz not null default now(),
  unique(opportunity_id, membership_id)
);

create table if not exists public.service_rosters (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  ministry_id uuid references public.church_ministries(id) on delete set null,
  group_id uuid references public.church_groups(id) on delete set null,
  event_id uuid references public.events(id) on delete set null,
  occurrence_id uuid references public.event_occurrences(id) on delete set null,
  role_title text not null,
  assigned_membership_id uuid not null references public.memberships(id) on delete cascade,
  substitute_membership_id uuid references public.memberships(id) on delete set null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  location text,
  status text not null default 'pending_confirmation',
  confirmation_notes text,
  instructions text,
  is_demo boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.church_projects (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  ministry_id uuid references public.church_ministries(id) on delete set null,
  campaign_id uuid references public.donation_campaigns(id) on delete set null,
  name text not null,
  description text,
  responsible_membership_id uuid references public.memberships(id) on delete set null,
  starts_at date,
  due_at date,
  status text not null default 'planned',
  budget_amount numeric(12,2) not null default 0,
  progress_percent integer not null default 0 check (progress_percent between 0 and 100),
  risks text,
  notes text,
  is_demo boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.operational_tasks (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  ministry_id uuid references public.church_ministries(id) on delete set null,
  group_id uuid references public.church_groups(id) on delete set null,
  project_id uuid references public.church_projects(id) on delete set null,
  title text not null,
  description text,
  responsible_membership_id uuid references public.memberships(id) on delete set null,
  collaborator_membership_ids uuid[] not null default '{}'::uuid[],
  priority text not null default 'normal',
  status text not null default 'todo',
  starts_at timestamptz,
  due_at timestamptz,
  completed_at timestamptz,
  progress_percent integer not null default 0 check (progress_percent between 0 and 100),
  labels text[] not null default '{}'::text[],
  is_demo boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.task_checklist_items (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.operational_tasks(id) on delete cascade,
  text text not null,
  responsible_membership_id uuid references public.memberships(id) on delete set null,
  due_at timestamptz,
  item_order integer not null default 0,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.task_comments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.operational_tasks(id) on delete cascade,
  author_profile_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  attachment_url text,
  edited_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.asset_movements (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.church_assets(id) on delete cascade,
  church_id uuid not null references public.churches(id) on delete cascade,
  from_location text,
  to_location text,
  from_responsible_membership_id uuid references public.memberships(id) on delete set null,
  to_responsible_membership_id uuid references public.memberships(id) on delete set null,
  from_ministry_id uuid references public.church_ministries(id) on delete set null,
  to_ministry_id uuid references public.church_ministries(id) on delete set null,
  movement_type text not null default 'transfer',
  reason text,
  status text not null default 'completed',
  proof_url text,
  registered_by uuid references public.profiles(id),
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.maintenance_requests (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  asset_id uuid references public.church_assets(id) on delete set null,
  maintenance_type text not null default 'corrective',
  problem text not null,
  priority text not null default 'normal',
  responsible_membership_id uuid references public.memberships(id) on delete set null,
  supplier text,
  estimated_cost numeric(12,2),
  final_cost numeric(12,2),
  status text not null default 'requested',
  requested_at timestamptz not null default now(),
  expected_at timestamptz,
  completed_at timestamptz,
  proof_url text,
  notes text,
  preventive_period_days integer,
  last_maintenance_at date,
  next_maintenance_at date,
  is_demo boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.church_rooms (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  name text not null,
  room_type text not null default 'room',
  capacity integer,
  location text,
  equipment text,
  responsible_membership_id uuid references public.memberships(id) on delete set null,
  status text not null default 'available',
  rules text,
  photo_urls text[] not null default '{}'::text[],
  is_demo boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(church_id, name)
);

create table if not exists public.room_reservations (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  room_id uuid not null references public.church_rooms(id) on delete cascade,
  requested_by_membership_id uuid not null references public.memberships(id) on delete cascade,
  responsible_membership_id uuid references public.memberships(id) on delete set null,
  purpose text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'pending',
  decision_by uuid references public.profiles(id),
  decision_at timestamptz,
  decision_notes text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table if not exists public.church_documents (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  ministry_id uuid references public.church_ministries(id) on delete set null,
  project_id uuid references public.church_projects(id) on delete set null,
  title text not null,
  document_type text not null default 'document',
  description text,
  file_url text,
  author_profile_id uuid references public.profiles(id) on delete set null,
  document_date date,
  valid_until date,
  status text not null default 'approved',
  confidentiality text not null default 'internal',
  version integer not null default 1,
  previous_document_id uuid references public.church_documents(id) on delete set null,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.purchase_requests (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  ministry_id uuid references public.church_ministries(id) on delete set null,
  requested_by_membership_id uuid not null references public.memberships(id) on delete cascade,
  item_name text not null,
  quantity integer not null default 1 check (quantity > 0),
  justification text,
  estimated_amount numeric(12,2),
  suggested_supplier text,
  priority text not null default 'normal',
  needed_at date,
  attachment_url text,
  status text not null default 'submitted',
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  approved_amount numeric(12,2),
  selected_supplier text,
  decision_notes text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  ministry_id uuid references public.church_ministries(id) on delete set null,
  name text not null,
  unit text not null default 'un',
  quantity_current numeric(12,2) not null default 0 check (quantity_current >= 0),
  quantity_minimum numeric(12,2) not null default 0,
  location text,
  responsible_membership_id uuid references public.memberships(id) on delete set null,
  is_demo boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(church_id, name)
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.inventory_items(id) on delete cascade,
  church_id uuid not null references public.churches(id) on delete cascade,
  movement_type text not null,
  quantity numeric(12,2) not null check (quantity > 0),
  responsible_membership_id uuid references public.memberships(id) on delete set null,
  destination text,
  reason text,
  registered_by uuid references public.profiles(id),
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.operational_audit_logs (
  id uuid primary key default gen_random_uuid(),
  church_id uuid references public.churches(id) on delete cascade,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  action text not null,
  object_table text not null,
  object_id uuid,
  before_data jsonb,
  after_data jsonb,
  reason text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function public.user_can_manage_operations(p_church_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(public.is_super_admin(p_user_id), false)
    or public.has_church_role(p_church_id, array['pastor', 'church_admin', 'leader']::text[], p_user_id);
$$;

create or replace function public.get_operational_metrics(p_church_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_church_role(p_church_id, array['member', 'leader', 'pastor', 'church_admin']::text[], auth.uid())
     and not public.is_super_admin(auth.uid()) then
    raise exception 'You cannot view operational metrics for this church.';
  end if;

  return jsonb_build_object(
    'ministries_active', (select count(*) from public.church_ministries where church_id = p_church_id and status = 'active' and is_demo = false),
    'groups_active', (select count(*) from public.church_groups where church_id = p_church_id and status = 'active' and is_demo = false),
    'tasks_pending', (select count(*) from public.operational_tasks where church_id = p_church_id and status not in ('done', 'cancelled') and is_demo = false),
    'tasks_overdue', (select count(*) from public.operational_tasks where church_id = p_church_id and due_at < now() and status not in ('done', 'cancelled') and is_demo = false),
    'rosters_pending', (select count(*) from public.service_rosters where church_id = p_church_id and status = 'pending_confirmation' and is_demo = false),
    'assets_maintenance', (select count(*) from public.church_assets where church_id = p_church_id and status = 'maintenance' and is_demo = false),
    'maintenance_pending', (select count(*) from public.maintenance_requests where church_id = p_church_id and status not in ('completed', 'cancelled') and is_demo = false),
    'documents_expiring', (select count(*) from public.church_documents where church_id = p_church_id and valid_until between current_date and current_date + interval '60 days' and status = 'approved' and is_demo = false),
    'reservations_pending', (select count(*) from public.room_reservations where church_id = p_church_id and status = 'pending' and is_demo = false),
    'purchases_pending', (select count(*) from public.purchase_requests where church_id = p_church_id and status in ('submitted', 'reviewing', 'approved') and is_demo = false),
    'stock_low', (select count(*) from public.inventory_items where church_id = p_church_id and quantity_current <= quantity_minimum and is_demo = false)
  );
end;
$$;

drop function if exists public.clear_church_demo_data(uuid);

create or replace function public.clear_church_demo_data(p_church_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.user_can_manage_operations(p_church_id, auth.uid()) then
    raise exception 'You cannot clear demo data for this church.';
  end if;

  delete from public.inventory_movements where church_id = p_church_id and is_demo = true;
  delete from public.inventory_items where church_id = p_church_id and is_demo = true;
  delete from public.purchase_requests where church_id = p_church_id and is_demo = true;
  delete from public.church_documents where church_id = p_church_id and is_demo = true;
  delete from public.room_reservations where church_id = p_church_id and is_demo = true;
  delete from public.church_rooms where church_id = p_church_id and is_demo = true;
  delete from public.maintenance_requests where church_id = p_church_id and is_demo = true;
  delete from public.asset_movements where church_id = p_church_id and is_demo = true;
  delete from public.service_rosters where church_id = p_church_id and is_demo = true;
  delete from public.task_comments where task_id in (select id from public.operational_tasks where church_id = p_church_id and is_demo = true);
  delete from public.task_checklist_items where task_id in (select id from public.operational_tasks where church_id = p_church_id and is_demo = true);
  delete from public.operational_tasks where church_id = p_church_id and is_demo = true;
  delete from public.church_projects where church_id = p_church_id and is_demo = true;
  delete from public.volunteer_applications where opportunity_id in (select id from public.volunteer_opportunities where church_id = p_church_id and is_demo = true);
  delete from public.volunteer_opportunities where church_id = p_church_id and is_demo = true;
  delete from public.ministry_join_requests where church_id = p_church_id and is_demo = true;
  delete from public.church_group_members where group_id in (select id from public.church_groups where church_id = p_church_id and is_demo = true);
  delete from public.church_groups where church_id = p_church_id and is_demo = true;
  update public.church_assets set is_demo = false where church_id = p_church_id and is_demo = true and false;
  delete from public.church_assets where church_id = p_church_id and is_demo = true;
  delete from public.church_ministries where church_id = p_church_id and is_demo = true;
end;
$$;

create or replace function public.seed_vida_nova_operations_demo()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  vida_id uuid;
  sara_profile_id uuid;
  member_profile_id uuid;
  sara_membership_id uuid;
  member_membership_id uuid;
  louvor_id uuid;
  jovens_id uuid;
  infantil_id uuid;
  social_id uuid;
  group_oracao_id uuid;
  group_jovens_id uuid;
  protocolo_id uuid;
  sala_id uuid;
  asset_id uuid;
  project_id uuid;
  inventory_id uuid;
begin
  select id into vida_id
  from public.churches
  where slug in ('vida-nova', 'igreja-vida-nova')
     or regexp_replace(coalesce(phone, ''), '\D', '', 'g') in ('877688695', '258877688695')
     or lower(trim(name)) in ('vida nova', 'igreja vida nova')
  limit 1;

  if vida_id is null then
    return jsonb_build_object('seeded', false, 'reason', 'Vida Nova not found');
  end if;

  sara_profile_id := public.profile_id_by_phone('877688695');
  member_profile_id := public.profile_id_by_phone('827688695');

  select id into sara_membership_id from public.memberships where church_id = vida_id and profile_id = sara_profile_id limit 1;
  select id into member_membership_id from public.memberships where church_id = vida_id and profile_id = member_profile_id limit 1;

  delete from public.inventory_movements where church_id = vida_id and is_demo = true;
  delete from public.inventory_items where church_id = vida_id and is_demo = true;
  delete from public.purchase_requests where church_id = vida_id and is_demo = true;
  delete from public.church_documents where church_id = vida_id and is_demo = true;
  delete from public.room_reservations where church_id = vida_id and is_demo = true;
  delete from public.church_rooms where church_id = vida_id and is_demo = true;
  delete from public.maintenance_requests where church_id = vida_id and is_demo = true;
  delete from public.asset_movements where church_id = vida_id and is_demo = true;
  delete from public.service_rosters where church_id = vida_id and is_demo = true;
  delete from public.task_comments where task_id in (select id from public.operational_tasks where church_id = vida_id and is_demo = true);
  delete from public.task_checklist_items where task_id in (select id from public.operational_tasks where church_id = vida_id and is_demo = true);
  delete from public.operational_tasks where church_id = vida_id and is_demo = true;
  delete from public.church_projects where church_id = vida_id and is_demo = true;
  delete from public.volunteer_applications where opportunity_id in (select id from public.volunteer_opportunities where church_id = vida_id and is_demo = true);
  delete from public.volunteer_opportunities where church_id = vida_id and is_demo = true;
  delete from public.ministry_join_requests where church_id = vida_id and is_demo = true;
  delete from public.church_group_members where group_id in (select id from public.church_groups where church_id = vida_id and is_demo = true);
  delete from public.church_groups where church_id = vida_id and is_demo = true;
  delete from public.church_assets where church_id = vida_id and is_demo = true;
  delete from public.church_ministries where church_id = vida_id and is_demo = true;

  insert into public.church_ministries (church_id, name, description, leader_membership_id, ministry_type, status, color, usual_location, goals, is_demo)
  values
    (vida_id, 'Ministerio de Louvor', 'Equipa de louvor, coral e instrumentos.', sara_membership_id, 'ministry', 'active', '#A855F7', 'Sala de Musica', 'Organizar escalas e ensaios semanais.', true),
    (vida_id, 'Ministerio de Jovens', 'Acompanhamento e discipulado dos jovens.', sara_membership_id, 'ministry', 'active', '#2563EB', 'Sala de Jovens', 'Criar programa juvenil mensal.', true),
    (vida_id, 'Ministerio Infantil', 'Cuidado e ensino de criancas.', sara_membership_id, 'ministry', 'active', '#F59E0B', 'Sala Infantil', 'Reforcar equipa de voluntarios.', true),
    (vida_id, 'Ministerio de Acao Social', 'Apoio a familias e campanhas sociais.', sara_membership_id, 'program', 'active', '#16A34A', 'Secretaria', 'Mapear familias acompanhadas.', true),
    (vida_id, 'Equipa de Protocolo', 'Recepcao, organizacao de filas e apoio em cultos.', sara_membership_id, 'team', 'active', '#DB2777', 'Entrada Principal', 'Treinar novos voluntarios.', true)
  on conflict (church_id, name) do update
    set description = excluded.description,
        leader_membership_id = excluded.leader_membership_id,
        status = excluded.status,
        is_demo = true;

  select id into louvor_id from public.church_ministries where church_id = vida_id and name = 'Ministerio de Louvor';
  select id into jovens_id from public.church_ministries where church_id = vida_id and name = 'Ministerio de Jovens';
  select id into infantil_id from public.church_ministries where church_id = vida_id and name = 'Ministerio Infantil';
  select id into social_id from public.church_ministries where church_id = vida_id and name = 'Ministerio de Acao Social';
  select id into protocolo_id from public.church_ministries where church_id = vida_id and name = 'Equipa de Protocolo';

  insert into public.ministry_members (ministry_id, membership_id, role, status, appointed_by, permissions, notes)
  select ministry_id, membership_id, role, 'active', sara_profile_id, permissions, 'Seed operacional Vida Nova'
  from (
    values
      (louvor_id, sara_membership_id, 'leader', array['ministry.manage','ministry.tasks.manage','ministry.assets.view']::text[]),
      (jovens_id, sara_membership_id, 'leader', array['ministry.manage','ministry.tasks.manage']::text[]),
      (infantil_id, sara_membership_id, 'leader', array['ministry.manage','ministry.tasks.manage']::text[]),
      (social_id, sara_membership_id, 'leader', array['ministry.manage','ministry.budget.request']::text[]),
      (protocolo_id, member_membership_id, 'member', array['ministry.view']::text[])
  ) as seed(ministry_id, membership_id, role, permissions)
  where ministry_id is not null and membership_id is not null
  on conflict (ministry_id, membership_id) do update
    set role = excluded.role,
        status = 'active',
        permissions = excluded.permissions;

  insert into public.church_groups (church_id, ministry_id, name, group_type, description, leader_membership_id, location, usual_day, usual_time, capacity, audience, status, is_demo, created_by)
  values
    (vida_id, null, 'Grupo de Oracao', 'prayer_group', 'Grupo semanal de intercessao.', sara_membership_id, 'Sala Pastoral', 'Quarta-feira', '18:00', 25, 'members', 'active', true, sara_profile_id),
    (vida_id, jovens_id, 'Grupo de Jovens', 'youth_group', 'Grupo de estudo e comunhao dos jovens.', sara_membership_id, 'Sala de Jovens', 'Sabado', '16:00', 40, 'members', 'active', true, sara_profile_id)
  on conflict (church_id, name) do update set status = 'active', is_demo = true;

  select id into group_oracao_id from public.church_groups where church_id = vida_id and name = 'Grupo de Oracao';
  select id into group_jovens_id from public.church_groups where church_id = vida_id and name = 'Grupo de Jovens';

  insert into public.church_group_members (group_id, membership_id, role, status)
  select group_id, membership_id, role, 'active'
  from (
    values
      (group_oracao_id, sara_membership_id, 'leader'),
      (group_oracao_id, member_membership_id, 'member'),
      (group_jovens_id, member_membership_id, 'member')
  ) as seed(group_id, membership_id, role)
  where group_id is not null and membership_id is not null
  on conflict (group_id, membership_id) do update set role = excluded.role, status = 'active';

  insert into public.church_projects (church_id, ministry_id, name, description, responsible_membership_id, starts_at, due_at, status, budget_amount, progress_percent, is_demo, created_by)
  values (vida_id, social_id, 'Campanha Social Escolar', 'Organizacao de kits escolares para familias acompanhadas.', sara_membership_id, current_date, current_date + 30, 'active', 45000, 35, true, sara_profile_id)
  returning id into project_id;

  insert into public.operational_tasks (church_id, ministry_id, group_id, project_id, title, description, responsible_membership_id, collaborator_membership_ids, priority, status, starts_at, due_at, progress_percent, is_demo, created_by)
  values
    (vida_id, louvor_id, null, null, 'Preparar escala de louvor de domingo', 'Confirmar vocalistas, instrumentos e ensaio.', sara_membership_id, array[member_membership_id]::uuid[], 'high', 'in_progress', now(), now() + interval '3 days', 45, true, sara_profile_id),
    (vida_id, protocolo_id, null, null, 'Organizar recepcao da Conferencia de Familias', 'Separar equipas de entrada, lugares e apoio.', member_membership_id, array[sara_membership_id]::uuid[], 'normal', 'todo', now(), now() + interval '10 days', 0, true, sara_profile_id),
    (vida_id, social_id, null, project_id, 'Comprar material escolar', 'Levantar lista de material e fornecedores.', sara_membership_id, array[member_membership_id]::uuid[], 'urgent', 'blocked', now(), now() + interval '7 days', 15, true, sara_profile_id);

  insert into public.service_rosters (church_id, ministry_id, group_id, role_title, assigned_membership_id, starts_at, ends_at, location, status, instructions, is_demo, created_by)
  values
    (vida_id, louvor_id, null, 'Vocal principal', member_membership_id, date_trunc('week', now()) + interval '6 days 8 hours', date_trunc('week', now()) + interval '6 days 11 hours', 'Templo Vida Nova', 'pending_confirmation', 'Chegar 1 hora antes para passagem de som.', true, sara_profile_id),
    (vida_id, protocolo_id, null, 'Recepcao', member_membership_id, now() + interval '12 days 7 hours', now() + interval '12 days 12 hours', 'Entrada Principal', 'confirmed', 'Receber familias e orientar lugares.', true, sara_profile_id);

  insert into public.church_assets (church_id, category, name, quantity, item_condition, location, notes, asset_code, status, ministry_id, responsible_membership_id, acquisition_value, current_value, qr_code, is_demo, created_by)
  values
    (vida_id, 'som', 'Mesa de som 16 canais', 1, 'good', 'Templo Vida Nova', 'Usada nos cultos principais.', 'VN-SOM-001', 'available', louvor_id, sara_membership_id, 85000, 70000, 'asset:VN-SOM-001', true, sara_profile_id),
    (vida_id, 'instrumento', 'Teclado Yamaha', 1, 'good', 'Sala de Musica', 'Instrumento do ministerio de louvor.', 'VN-INS-002', 'in_use', louvor_id, member_membership_id, 45000, 38000, 'asset:VN-INS-002', true, sara_profile_id),
    (vida_id, 'projetor', 'Projetor principal', 1, 'needs_repair', 'Templo Vida Nova', 'Imagem com falhas intermitentes.', 'VN-PRJ-003', 'maintenance', null, sara_membership_id, 55000, 25000, 'asset:VN-PRJ-003', true, sara_profile_id);

  select id into asset_id
  from public.church_assets
  where church_id = vida_id and asset_code = 'VN-PRJ-003'
  limit 1;

  insert into public.maintenance_requests (church_id, asset_id, maintenance_type, problem, priority, responsible_membership_id, supplier, estimated_cost, status, expected_at, notes, next_maintenance_at, is_demo, created_by)
  values (vida_id, asset_id, 'corrective', 'Projetor com falha na imagem durante transmissao.', 'high', sara_membership_id, 'Tecnico local', 6500, 'requested', now() + interval '5 days', 'Nao criar despesa paga automaticamente.', current_date + 90, true, sara_profile_id);

  insert into public.church_rooms (church_id, name, room_type, capacity, location, equipment, responsible_membership_id, status, rules, is_demo, created_by)
  values (vida_id, 'Sala Pastoral', 'meeting_room', 20, 'Bloco administrativo', 'Mesa, cadeiras, quadro', sara_membership_id, 'available', 'Reservar com antecedencia.', true, sara_profile_id)
  on conflict (church_id, name) do update set is_demo = true
  returning id into sala_id;

  insert into public.room_reservations (church_id, room_id, requested_by_membership_id, responsible_membership_id, purpose, starts_at, ends_at, status, is_demo)
  values (vida_id, sala_id, member_membership_id, sara_membership_id, 'Reuniao do grupo de oracao', now() + interval '4 days 18 hours', now() + interval '4 days 20 hours', 'pending', true);

  insert into public.church_documents (church_id, ministry_id, project_id, title, document_type, description, file_url, author_profile_id, document_date, valid_until, status, confidentiality, version, is_demo)
  values (vida_id, null, null, 'Licenca de funcionamento', 'license', 'Documento com validade proxima para alerta.', null, sara_profile_id, current_date - 300, current_date + 25, 'approved', 'restricted', 1, true);

  insert into public.purchase_requests (church_id, ministry_id, requested_by_membership_id, item_name, quantity, justification, estimated_amount, suggested_supplier, priority, needed_at, status, is_demo)
  values (vida_id, infantil_id, member_membership_id, 'Tapetes infantis', 6, 'Apoio ao Ministerio Infantil.', 9000, 'Fornecedor local', 'normal', current_date + 14, 'submitted', true);

  insert into public.inventory_items (church_id, ministry_id, name, unit, quantity_current, quantity_minimum, location, responsible_membership_id, is_demo, created_by)
  values (vida_id, social_id, 'Cestas basicas', 'un', 3, 10, 'Armazem', sara_membership_id, true, sara_profile_id)
  on conflict (church_id, name) do update set quantity_current = 3, quantity_minimum = 10, is_demo = true
  returning id into inventory_id;

  insert into public.inventory_movements (item_id, church_id, movement_type, quantity, responsible_membership_id, destination, reason, registered_by, is_demo)
  values (inventory_id, vida_id, 'out', 7, sara_membership_id, 'Familias acompanhadas', 'Entrega social demo', sara_profile_id, true);

  return jsonb_build_object('seeded', true, 'church_id', vida_id);
end;
$$;

select public.seed_vida_nova_operations_demo();

alter table public.church_groups enable row level security;
alter table public.church_group_members enable row level security;
alter table public.ministry_join_requests enable row level security;
alter table public.volunteer_opportunities enable row level security;
alter table public.volunteer_applications enable row level security;
alter table public.service_rosters enable row level security;
alter table public.church_projects enable row level security;
alter table public.operational_tasks enable row level security;
alter table public.task_checklist_items enable row level security;
alter table public.task_comments enable row level security;
alter table public.asset_movements enable row level security;
alter table public.maintenance_requests enable row level security;
alter table public.church_rooms enable row level security;
alter table public.room_reservations enable row level security;
alter table public.church_documents enable row level security;
alter table public.purchase_requests enable row level security;
alter table public.inventory_items enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.operational_audit_logs enable row level security;

create policy "Members can read church groups"
  on public.church_groups for select
  using (public.has_church_role(church_id, array['member','leader','pastor','church_admin']::text[], auth.uid()));

create policy "Operations managers can manage church groups"
  on public.church_groups for all
  using (public.user_can_manage_operations(church_id, auth.uid()))
  with check (public.user_can_manage_operations(church_id, auth.uid()));

create policy "Members can read own group memberships"
  on public.church_group_members for select
  using (
    exists (
      select 1 from public.church_groups g
      where g.id = group_id
        and public.has_church_role(g.church_id, array['member','leader','pastor','church_admin']::text[], auth.uid())
    )
  );

create policy "Operations managers can manage group memberships"
  on public.church_group_members for all
  using (exists (select 1 from public.church_groups g where g.id = group_id and public.user_can_manage_operations(g.church_id, auth.uid())))
  with check (exists (select 1 from public.church_groups g where g.id = group_id and public.user_can_manage_operations(g.church_id, auth.uid())));

create policy "Users can read related join requests"
  on public.ministry_join_requests for select
  using (
    public.user_can_manage_operations(church_id, auth.uid())
    or exists (
      select 1 from public.memberships m
      where m.id = membership_id and m.profile_id = auth.uid()
    )
  );

create policy "Users can create own join requests"
  on public.ministry_join_requests for insert
  with check (
    exists (
      select 1 from public.memberships m
      where m.id = membership_id and m.profile_id = auth.uid() and m.church_id = church_id
    )
  );

create policy "Operations managers can update join requests"
  on public.ministry_join_requests for update
  using (public.user_can_manage_operations(church_id, auth.uid()))
  with check (public.user_can_manage_operations(church_id, auth.uid()));

create policy "Members can read volunteer opportunities"
  on public.volunteer_opportunities for select
  using (public.has_church_role(church_id, array['member','leader','pastor','church_admin']::text[], auth.uid()));

create policy "Operations managers can manage volunteer opportunities"
  on public.volunteer_opportunities for all
  using (public.user_can_manage_operations(church_id, auth.uid()))
  with check (public.user_can_manage_operations(church_id, auth.uid()));

create policy "Users can read own volunteer applications"
  on public.volunteer_applications for select
  using (
    exists (select 1 from public.memberships m where m.id = membership_id and m.profile_id = auth.uid())
    or exists (select 1 from public.volunteer_opportunities o where o.id = opportunity_id and public.user_can_manage_operations(o.church_id, auth.uid()))
  );

create policy "Users can apply to opportunities"
  on public.volunteer_applications for insert
  with check (exists (select 1 from public.memberships m where m.id = membership_id and m.profile_id = auth.uid()));

create policy "Users can read related rosters"
  on public.service_rosters for select
  using (
    public.user_can_manage_operations(church_id, auth.uid())
    or exists (select 1 from public.memberships m where m.id = assigned_membership_id and m.profile_id = auth.uid())
  );

create policy "Operations managers can manage rosters"
  on public.service_rosters for all
  using (public.user_can_manage_operations(church_id, auth.uid()))
  with check (public.user_can_manage_operations(church_id, auth.uid()));

create policy "Users can read related operational tasks"
  on public.operational_tasks for select
  using (
    public.user_can_manage_operations(church_id, auth.uid())
    or exists (select 1 from public.memberships m where m.id = responsible_membership_id and m.profile_id = auth.uid())
    or exists (select 1 from public.memberships m where m.profile_id = auth.uid() and m.id = any(collaborator_membership_ids))
  );

create policy "Operations managers can manage operational tasks"
  on public.operational_tasks for all
  using (public.user_can_manage_operations(church_id, auth.uid()))
  with check (public.user_can_manage_operations(church_id, auth.uid()));

create policy "Members can read non confidential documents"
  on public.church_documents for select
  using (
    confidentiality in ('public','internal')
    and public.has_church_role(church_id, array['member','leader','pastor','church_admin']::text[], auth.uid())
    or public.user_can_manage_operations(church_id, auth.uid())
  );

create policy "Operations managers can manage documents"
  on public.church_documents for all
  using (public.user_can_manage_operations(church_id, auth.uid()))
  with check (public.user_can_manage_operations(church_id, auth.uid()));

create policy "Operations managers can manage maintenance"
  on public.maintenance_requests for all
  using (public.user_can_manage_operations(church_id, auth.uid()))
  with check (public.user_can_manage_operations(church_id, auth.uid()));

create policy "Operations managers can manage rooms and reservations"
  on public.church_rooms for all
  using (public.user_can_manage_operations(church_id, auth.uid()))
  with check (public.user_can_manage_operations(church_id, auth.uid()));

create policy "Operations managers can manage room reservations"
  on public.room_reservations for all
  using (public.user_can_manage_operations(church_id, auth.uid()))
  with check (public.user_can_manage_operations(church_id, auth.uid()));

create policy "Operations managers can manage purchase requests"
  on public.purchase_requests for all
  using (public.user_can_manage_operations(church_id, auth.uid()))
  with check (public.user_can_manage_operations(church_id, auth.uid()));

create policy "Operations managers can manage inventory"
  on public.inventory_items for all
  using (public.user_can_manage_operations(church_id, auth.uid()))
  with check (public.user_can_manage_operations(church_id, auth.uid()));

create policy "Operations managers can manage inventory movements"
  on public.inventory_movements for all
  using (public.user_can_manage_operations(church_id, auth.uid()))
  with check (public.user_can_manage_operations(church_id, auth.uid()));

create policy "Operations managers can read audit logs"
  on public.operational_audit_logs for select
  using (church_id is null or public.user_can_manage_operations(church_id, auth.uid()));

grant select, insert, update on
  public.church_groups,
  public.church_group_members,
  public.ministry_join_requests,
  public.volunteer_opportunities,
  public.volunteer_applications,
  public.service_rosters,
  public.church_projects,
  public.operational_tasks,
  public.task_checklist_items,
  public.task_comments,
  public.asset_movements,
  public.maintenance_requests,
  public.church_rooms,
  public.room_reservations,
  public.church_documents,
  public.purchase_requests,
  public.inventory_items,
  public.inventory_movements,
  public.operational_audit_logs
to authenticated;

grant execute on function public.get_operational_metrics(uuid) to authenticated;
grant execute on function public.clear_church_demo_data(uuid) to authenticated;
revoke execute on function public.seed_vida_nova_operations_demo() from anon, authenticated, public;
