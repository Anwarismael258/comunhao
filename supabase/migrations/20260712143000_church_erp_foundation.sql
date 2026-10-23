alter table public.events
  add column if not exists event_type text not null default 'culto';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'events_event_type_check'
  ) then
    alter table public.events
      add constraint events_event_type_check
      check (
        event_type in (
          'culto',
          'congresso',
          'vigilia',
          'batismo',
          'casamento',
          'conferencia',
          'ensaio',
          'reuniao',
          'outro'
        )
      );
  end if;
end $$;

create table if not exists public.church_ministries (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  name text not null,
  description text,
  leader_membership_id uuid references public.memberships(id) on delete set null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (church_id, name)
);

create table if not exists public.ministry_members (
  id uuid primary key default gen_random_uuid(),
  ministry_id uuid not null references public.church_ministries(id) on delete cascade,
  membership_id uuid not null references public.memberships(id) on delete cascade,
  role text not null default 'member',
  created_at timestamptz not null default now(),
  unique (ministry_id, membership_id)
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'ministry_members_role_check'
  ) then
    alter table public.ministry_members
      add constraint ministry_members_role_check
      check (role in ('leader', 'assistant', 'member'));
  end if;
end $$;

create table if not exists public.church_assets (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  category text not null default 'outro',
  name text not null,
  quantity integer not null default 1 check (quantity > 0),
  item_condition text not null default 'good',
  location text,
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_assets_category_check'
  ) then
    alter table public.church_assets
      add constraint church_assets_category_check
      check (
        category in (
          'instrumento',
          'computador',
          'projetor',
          'veiculo',
          'cadeira',
          'mesa',
          'som',
          'mobilia',
          'outro'
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_assets_condition_check'
  ) then
    alter table public.church_assets
      add constraint church_assets_condition_check
      check (
        item_condition in (
          'new',
          'good',
          'fair',
          'needs_repair',
          'retired'
        )
      );
  end if;
end $$;

create table if not exists public.church_visitors (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  full_name text not null,
  phone text,
  status text not null default 'new',
  first_visit_at timestamptz not null default now(),
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_visitors_status_check'
  ) then
    alter table public.church_visitors
      add constraint church_visitors_status_check
      check (status in ('new', 'returning', 'integrated'));
  end if;
end $$;

create table if not exists public.church_expenses (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  category text not null default 'operacional',
  title text not null,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'MZN',
  spent_at timestamptz not null default now(),
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_expenses_category_check'
  ) then
    alter table public.church_expenses
      add constraint church_expenses_category_check
      check (
        category in (
          'operacional',
          'manutencao',
          'construcao',
          'missoes',
          'acao_social',
          'salario',
          'evento',
          'outro'
        )
      );
  end if;
end $$;

create index if not exists idx_church_ministries_church_id
  on public.church_ministries(church_id);

create index if not exists idx_ministry_members_ministry_id
  on public.ministry_members(ministry_id);

create index if not exists idx_ministry_members_membership_id
  on public.ministry_members(membership_id);

create index if not exists idx_church_assets_church_id
  on public.church_assets(church_id);

create index if not exists idx_church_visitors_church_id
  on public.church_visitors(church_id);

create index if not exists idx_church_expenses_church_id
  on public.church_expenses(church_id);

create or replace function public.ensure_default_church_ministries(
  p_church_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.church_ministries (
    church_id,
    name,
    description,
    active
  )
  values
    (p_church_id, 'Louvor', 'Escala de musica, ensaios e adoracao.', true),
    (p_church_id, 'Intercessao', 'Cobertura de oracao e apoio espiritual.', true),
    (p_church_id, 'Jovens', 'Acompanhamento da juventude da igreja.', true),
    (p_church_id, 'Criancas', 'Ministerio infantil e ensino das criancas.', true),
    (p_church_id, 'Mulheres', 'Comunidade e cuidado das mulheres.', true),
    (p_church_id, 'Homens', 'Comunidade e cuidado dos homens.', true),
    (p_church_id, 'Evangelismo', 'Acoes de alcance e missoes locais.', true)
  on conflict (church_id, name) do nothing;
end;
$$;

create or replace function public.handle_new_church_operational_defaults()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.ensure_default_church_ministries(new.id);
  return new;
end;
$$;

drop trigger if exists handle_new_church_operational_defaults on public.churches;
create trigger handle_new_church_operational_defaults
  after insert on public.churches
  for each row execute procedure public.handle_new_church_operational_defaults();

do $$
declare
  church_row record;
begin
  for church_row in
    select id
    from public.churches
  loop
    perform public.ensure_default_church_ministries(church_row.id);
  end loop;
end $$;

grant select, insert, update, delete on public.church_ministries to authenticated;
grant select, insert, update, delete on public.ministry_members to authenticated;
grant select, insert, update, delete on public.church_assets to authenticated;
grant select, insert, update, delete on public.church_visitors to authenticated;
grant select, insert, update, delete on public.church_expenses to authenticated;
grant execute on function public.ensure_default_church_ministries(uuid) to authenticated;

alter table public.church_ministries enable row level security;
alter table public.ministry_members enable row level security;
alter table public.church_assets enable row level security;
alter table public.church_visitors enable row level security;
alter table public.church_expenses enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_ministries'
      and policyname = 'Members can read ministries in own church'
  ) then
    create policy "Members can read ministries in own church"
      on public.church_ministries
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
      and tablename = 'church_ministries'
      and policyname = 'Church admins can manage ministries in own church'
  ) then
    create policy "Church admins can manage ministries in own church"
      on public.church_ministries
      for all
      to authenticated
      using (
        public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[]
        )
      )
      with check (
        public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[]
        )
        and public.church_subscription_allows_writes(church_id)
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'ministry_members'
      and policyname = 'Members can read ministry memberships in own church'
  ) then
    create policy "Members can read ministry memberships in own church"
      on public.ministry_members
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.church_ministries ministry
          where ministry.id = ministry_members.ministry_id
            and public.has_church_role(
              ministry.church_id,
              array['member', 'leader', 'pastor', 'church_admin']::text[]
            )
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'ministry_members'
      and policyname = 'Church admins can manage ministry memberships in own church'
  ) then
    create policy "Church admins can manage ministry memberships in own church"
      on public.ministry_members
      for all
      to authenticated
      using (
        exists (
          select 1
          from public.church_ministries ministry
          where ministry.id = ministry_members.ministry_id
            and public.has_church_role(
              ministry.church_id,
              array['pastor', 'church_admin']::text[]
            )
        )
      )
      with check (
        exists (
          select 1
          from public.church_ministries ministry
          where ministry.id = ministry_members.ministry_id
            and public.has_church_role(
              ministry.church_id,
              array['pastor', 'church_admin']::text[]
            )
            and public.church_subscription_allows_writes(ministry.church_id)
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_assets'
      and policyname = 'Church admins can manage assets in own church'
  ) then
    create policy "Church admins can manage assets in own church"
      on public.church_assets
      for all
      to authenticated
      using (
        public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[]
        )
      )
      with check (
        public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[]
        )
        and public.church_subscription_allows_writes(church_id)
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_visitors'
      and policyname = 'Church admins can manage visitors in own church'
  ) then
    create policy "Church admins can manage visitors in own church"
      on public.church_visitors
      for all
      to authenticated
      using (
        public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[]
        )
      )
      with check (
        public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[]
        )
        and public.church_subscription_allows_writes(church_id)
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_expenses'
      and policyname = 'Church admins can manage expenses in own church'
  ) then
    create policy "Church admins can manage expenses in own church"
      on public.church_expenses
      for all
      to authenticated
      using (
        public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[]
        )
      )
      with check (
        public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[]
        )
        and public.church_subscription_allows_writes(church_id)
      );
  end if;
end $$;
