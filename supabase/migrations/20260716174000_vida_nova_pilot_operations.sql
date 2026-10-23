create table if not exists public.pilot_programs (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  name text not null,
  status text not null default 'preparing'
    check (status in ('preparing', 'active', 'paused', 'completed', 'rejected')),
  version text not null default '0.9.0',
  starts_at date,
  ends_at date,
  participant_target_min integer not null default 10,
  participant_target_max integer not null default 30,
  public_signup_enabled boolean not null default false,
  notes text,
  created_by_profile_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (church_id, name)
);

create table if not exists public.pilot_participants (
  id uuid primary key default gen_random_uuid(),
  pilot_id uuid not null references public.pilot_programs(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete set null,
  phone text,
  display_name text,
  participant_role text not null default 'member'
    check (participant_role in ('pastor', 'leader', 'finance', 'member', 'super_admin', 'support')),
  status text not null default 'invited'
    check (status in ('invited', 'active', 'paused', 'removed')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (pilot_id, phone, participant_role)
);

create table if not exists public.pilot_daily_runs (
  id uuid primary key default gen_random_uuid(),
  pilot_id uuid not null references public.pilot_programs(id) on delete cascade,
  day_number integer not null check (day_number between 1 and 30),
  title text not null,
  objective text not null,
  status text not null default 'not_started'
    check (status in ('not_started', 'in_progress', 'blocked', 'done')),
  planned_for date,
  completed_at timestamptz,
  owner_profile_id uuid references public.profiles(id) on delete set null,
  result_summary text,
  blockers text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (pilot_id, day_number)
);

create table if not exists public.pilot_daily_tasks (
  id uuid primary key default gen_random_uuid(),
  daily_run_id uuid not null references public.pilot_daily_runs(id) on delete cascade,
  title text not null,
  category text not null,
  status text not null default 'not_started'
    check (status in ('not_started', 'in_progress', 'blocked', 'done')),
  severity_if_failed text not null default 'medium'
    check (severity_if_failed in ('low', 'medium', 'high', 'critical')),
  evidence text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.pilot_feedback
  add column if not exists severity text not null default 'medium'
    check (severity in ('low', 'medium', 'high', 'critical')),
  add column if not exists device_info text,
  add column if not exists app_version text,
  add column if not exists assigned_to_profile_id uuid references public.profiles(id) on delete set null,
  add column if not exists resolution text,
  add column if not exists resolved_at timestamptz;

create table if not exists public.pilot_satisfaction_responses (
  id uuid primary key default gen_random_uuid(),
  pilot_id uuid references public.pilot_programs(id) on delete set null,
  church_id uuid references public.churches(id) on delete set null,
  respondent_profile_id uuid references public.profiles(id) on delete set null,
  ease_login integer check (ease_login between 1 and 5),
  ease_find_features integer check (ease_find_features between 1 and 5),
  publications_worked integer check (publications_worked between 1 and 5),
  contributions_worked integer check (contributions_worked between 1 and 5),
  requests_worked integer check (requests_worked between 1 and 5),
  notifications_useful integer check (notifications_useful between 1 and 5),
  feels_secure integer check (feels_secure between 1 and 5),
  hardest_part text,
  improvement_suggestion text,
  recommend_score integer check (recommend_score between 0 and 10),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.support_articles (
  id uuid primary key default gen_random_uuid(),
  audience text not null default 'member'
    check (audience in ('pastor', 'leader', 'finance', 'member', 'super_admin')),
  title text not null,
  body text not null,
  action_route text,
  sort_order integer not null default 0,
  published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (audience, title)
);

create table if not exists public.pilot_daily_snapshots (
  id uuid primary key default gen_random_uuid(),
  pilot_id uuid not null references public.pilot_programs(id) on delete cascade,
  snapshot_date date not null default current_date,
  active_users integer not null default 0,
  pending_feedback integer not null default 0,
  critical_feedback integer not null default 0,
  pending_contributions integer not null default 0,
  pending_withdrawals integer not null default 0,
  open_pastoral_requests integer not null default 0,
  notifications_failed integer not null default 0,
  storage_failures integer not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  unique (pilot_id, snapshot_date)
);

create index if not exists idx_pilot_programs_church_status
  on public.pilot_programs(church_id, status);
create index if not exists idx_pilot_participants_pilot_role
  on public.pilot_participants(pilot_id, participant_role, status);
create index if not exists idx_pilot_feedback_severity_status
  on public.pilot_feedback(severity, status, created_at desc);
create index if not exists idx_pilot_daily_tasks_status
  on public.pilot_daily_tasks(status, severity_if_failed);
create index if not exists idx_pilot_satisfaction_pilot
  on public.pilot_satisfaction_responses(pilot_id, created_at desc);

drop trigger if exists set_pilot_programs_updated_at on public.pilot_programs;
create trigger set_pilot_programs_updated_at
  before update on public.pilot_programs
  for each row execute function public.set_updated_at();

drop trigger if exists set_pilot_participants_updated_at on public.pilot_participants;
create trigger set_pilot_participants_updated_at
  before update on public.pilot_participants
  for each row execute function public.set_updated_at();

drop trigger if exists set_pilot_daily_runs_updated_at on public.pilot_daily_runs;
create trigger set_pilot_daily_runs_updated_at
  before update on public.pilot_daily_runs
  for each row execute function public.set_updated_at();

drop trigger if exists set_pilot_daily_tasks_updated_at on public.pilot_daily_tasks;
create trigger set_pilot_daily_tasks_updated_at
  before update on public.pilot_daily_tasks
  for each row execute function public.set_updated_at();

drop trigger if exists set_support_articles_updated_at on public.support_articles;
create trigger set_support_articles_updated_at
  before update on public.support_articles
  for each row execute function public.set_updated_at();

do $$
declare
  vida_id uuid;
  sara_id uuid;
  admin_id uuid;
  member_id uuid;
  v_pilot_id uuid;
begin
  select id into vida_id from public.churches where slug = 'vida-nova' limit 1;
  if vida_id is null then
    return;
  end if;

  sara_id := public.profile_id_by_phone('877688695');
  admin_id := public.profile_id_by_phone('841130015');
  member_id := public.profile_id_by_phone('827688695');

  insert into public.pilot_programs (
    church_id,
    name,
    status,
    version,
    starts_at,
    ends_at,
    public_signup_enabled,
    notes,
    created_by_profile_id
  )
  values (
    vida_id,
    'Piloto Fechado Igreja Vida Nova',
    'preparing',
    '0.9.0',
    current_date,
    current_date + 28,
    false,
    'Piloto fechado com Sara, lideres, financeiro, membros selecionados e superadministrador.',
    admin_id
  )
  on conflict (church_id, name) do update
  set
    status = excluded.status,
    version = excluded.version,
    public_signup_enabled = false
  returning id into v_pilot_id;

  insert into public.pilot_participants (pilot_id, profile_id, phone, display_name, participant_role, status)
  values
    (v_pilot_id, sara_id, '877688695', 'Sara', 'pastor', 'active'),
    (v_pilot_id, admin_id, '841130015', 'Superadministrador', 'super_admin', 'active'),
    (v_pilot_id, member_id, '827688695', 'Membro Vida Nova', 'member', 'active')
  on conflict (pilot_id, phone, participant_role) do update
  set profile_id = excluded.profile_id, status = excluded.status;

  insert into public.pilot_daily_runs (pilot_id, day_number, title, objective, planned_for, owner_profile_id)
  values
    (v_pilot_id, 1, 'Contas e membros', 'Login, cadastro, entrada, aprovacao, perfil, carteira e notificacoes.', current_date, sara_id),
    (v_pilot_id, 2, 'Conteudo', 'Publicacoes, leitura, guardar, comentarios e notificacoes.', current_date + 1, sara_id),
    (v_pilot_id, 3, 'Agenda', 'Cultos, eventos, inscricao, lembrete, check-in, presenca e visitantes.', current_date + 2, sara_id),
    (v_pilot_id, 4, 'Financeiro controlado', 'Campanhas, contribuicoes pendentes, confirmacao manual, recibos, despesas e levantamentos sem pagamentos reais.', current_date + 3, sara_id),
    (v_pilot_id, 5, 'Pedidos e acompanhamento', 'Pedidos pastorais, confidencialidade, atribuicao, resposta e pedidos administrativos.', current_date + 4, sara_id),
    (v_pilot_id, 6, 'Operacoes', 'Ministerios, grupos, tarefas, escalas, patrimonio, manutencao, documentos e reservas.', current_date + 5, sara_id),
    (v_pilot_id, 7, 'Relatorios', 'Indicadores, filtros, exportacao, auditoria e dados demo versus reais.', current_date + 6, admin_id)
  on conflict (pilot_id, day_number) do update
  set title = excluded.title, objective = excluded.objective, planned_for = excluded.planned_for;

  insert into public.pilot_daily_tasks (daily_run_id, title, category, severity_if_failed, sort_order)
  select r.id, task.title, task.category, task.severity, task.sort_order
  from public.pilot_daily_runs r
  cross join lateral (
    values
      ('Login funciona', 'auth', 'critical', 10),
      ('Fluxo principal do dia concluido', 'workflow', 'high', 20),
      ('Notificacoes corretas', 'notifications', 'high', 30),
      ('Sem exposicao indevida', 'security', 'critical', 40),
      ('Feedback registado', 'feedback', 'medium', 50)
  ) as task(title, category, severity, sort_order)
  where r.pilot_id = v_pilot_id
  on conflict do nothing;

  insert into public.support_articles (audience, title, body, action_route, sort_order)
  values
    ('member', 'Como entrar', 'Use o telefone registado, confirme a palavra-passe e contacte suporte se nao conseguir recuperar o acesso.', '/auth', 10),
    ('member', 'Como solicitar entrada', 'Abra a igreja Vida Nova, envie o pedido de entrada e aguarde aprovacao da equipa pastoral.', '/join', 20),
    ('member', 'Como contribuir', 'Use contribuicoes pendentes ate M-Pesa/E-Mola reais ficarem autorizados. Nao partilhe dados de cartao.', '/contributions', 30),
    ('member', 'Como criar pedido pastoral', 'Crie o pedido e escolha a privacidade correta. Conteudo confidencial fica restrito.', '/care', 40),
    ('pastor', 'Roteiro do piloto', 'Siga os 7 dias do piloto e registe problemas antes de expandir para outras igrejas.', '/pilot', 10),
    ('finance', 'Financeiro no piloto', 'Nao use pagamentos reais sem credenciais autorizadas. Confirme manualmente apenas com permissao.', '/finance', 10),
    ('super_admin', 'Criterios de expansao', 'Nao expandir se houver erro critico, isolamento quebrado, saldo incorreto ou backup nao testado.', '/launch', 10)
  on conflict (audience, title) do update
  set body = excluded.body, action_route = excluded.action_route, sort_order = excluded.sort_order;
end $$;

create or replace function public.get_pilot_dashboard_snapshot(
  p_church_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_church_id uuid;
  pilot_row public.pilot_programs%rowtype;
  participants jsonb;
  runs jsonb;
  feedback_summary jsonb;
  satisfaction jsonb;
begin
  if p_church_id is null then
    select id into target_church_id from public.churches where slug = 'vida-nova' limit 1;
  else
    target_church_id := p_church_id;
  end if;

  if target_church_id is null then
    raise exception 'Church not found.';
  end if;

  if not (
    public.has_platform_role(array['super_admin', 'support_agent', 'developer', 'auditor']::text[], auth.uid())
    or public.user_can_access_church(target_church_id, 'organization.manage', auth.uid())
  ) then
    raise exception 'Not allowed to view pilot dashboard.';
  end if;

  select * into pilot_row
  from public.pilot_programs
  where church_id = target_church_id
  order by created_at desc
  limit 1;

  if pilot_row.id is null then
    return jsonb_build_object('status', 'not_configured');
  end if;

  select coalesce(jsonb_agg(to_jsonb(p) order by p.participant_role, p.display_name), '[]'::jsonb)
  into participants
  from (
    select participant_role, status, phone, display_name
    from public.pilot_participants
    where pilot_id = pilot_row.id
  ) p;

  select coalesce(jsonb_agg(to_jsonb(r) order by r.day_number), '[]'::jsonb)
  into runs
  from (
    select
      r.id,
      r.day_number,
      r.title,
      r.objective,
      r.status,
      r.planned_for,
      r.result_summary,
      r.blockers,
      (
        select count(*) from public.pilot_daily_tasks t
        where t.daily_run_id = r.id
      ) as task_count,
      (
        select count(*) from public.pilot_daily_tasks t
        where t.daily_run_id = r.id and t.status = 'done'
      ) as done_count,
      (
        select count(*) from public.pilot_daily_tasks t
        where t.daily_run_id = r.id and t.status = 'blocked'
      ) as blocked_count
    from public.pilot_daily_runs r
    where r.pilot_id = pilot_row.id
  ) r;

  select jsonb_build_object(
    'total', count(*),
    'open', count(*) filter (where status in ('new', 'reviewing', 'fixing')),
    'critical', count(*) filter (where severity = 'critical' and status not in ('resolved', 'closed')),
    'high', count(*) filter (where severity = 'high' and status not in ('resolved', 'closed'))
  )
  into feedback_summary
  from public.pilot_feedback
  where church_id = target_church_id;

  select jsonb_build_object(
    'responses', count(*),
    'avg_recommend_score', coalesce(round(avg(recommend_score)::numeric, 1), 0)
  )
  into satisfaction
  from public.pilot_satisfaction_responses
  where pilot_id = pilot_row.id;

  return jsonb_build_object(
    'pilot', to_jsonb(pilot_row),
    'participants', participants,
    'runs', runs,
    'feedback', feedback_summary,
    'satisfaction', satisfaction,
    'support_articles', (
      select count(*) from public.support_articles where published = true
    ),
    'generated_at', now()
  );
end;
$$;

create or replace function public.submit_pilot_satisfaction(
  p_church_id uuid,
  p_ease_login integer,
  p_ease_find_features integer,
  p_publications_worked integer,
  p_contributions_worked integer,
  p_requests_worked integer,
  p_notifications_useful integer,
  p_feels_secure integer,
  p_hardest_part text default null,
  p_improvement_suggestion text default null,
  p_recommend_score integer default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  pilot_id uuid;
  response_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if not public.user_can_access_church(p_church_id, null, auth.uid()) then
    raise exception 'Not allowed to submit satisfaction for this church.';
  end if;

  select id into pilot_id
  from public.pilot_programs
  where church_id = p_church_id
  order by created_at desc
  limit 1;

  insert into public.pilot_satisfaction_responses (
    pilot_id,
    church_id,
    respondent_profile_id,
    ease_login,
    ease_find_features,
    publications_worked,
    contributions_worked,
    requests_worked,
    notifications_useful,
    feels_secure,
    hardest_part,
    improvement_suggestion,
    recommend_score
  )
  values (
    pilot_id,
    p_church_id,
    auth.uid(),
    p_ease_login,
    p_ease_find_features,
    p_publications_worked,
    p_contributions_worked,
    p_requests_worked,
    p_notifications_useful,
    p_feels_secure,
    p_hardest_part,
    p_improvement_suggestion,
    p_recommend_score
  )
  returning id into response_id;

  return response_id;
end;
$$;

alter table public.pilot_programs enable row level security;
alter table public.pilot_participants enable row level security;
alter table public.pilot_daily_runs enable row level security;
alter table public.pilot_daily_tasks enable row level security;
alter table public.pilot_satisfaction_responses enable row level security;
alter table public.support_articles enable row level security;
alter table public.pilot_daily_snapshots enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'pilot_programs' and policyname = 'Pilot visible to platform and church managers') then
    create policy "Pilot visible to platform and church managers"
      on public.pilot_programs for select to authenticated
      using (
        public.has_platform_role(array['super_admin', 'support_agent', 'developer', 'auditor']::text[], auth.uid())
        or public.user_can_access_church(church_id, 'organization.manage', auth.uid())
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'pilot_participants' and policyname = 'Pilot participants visible to pilot managers') then
    create policy "Pilot participants visible to pilot managers"
      on public.pilot_participants for select to authenticated
      using (
        exists (
          select 1 from public.pilot_programs p
          where p.id = pilot_participants.pilot_id
            and (
              public.has_platform_role(array['super_admin', 'support_agent', 'developer', 'auditor']::text[], auth.uid())
              or public.user_can_access_church(p.church_id, 'organization.manage', auth.uid())
            )
        )
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'pilot_daily_runs' and policyname = 'Pilot runs visible to pilot managers') then
    create policy "Pilot runs visible to pilot managers"
      on public.pilot_daily_runs for select to authenticated
      using (
        exists (
          select 1 from public.pilot_programs p
          where p.id = pilot_daily_runs.pilot_id
            and (
              public.has_platform_role(array['super_admin', 'support_agent', 'developer', 'auditor']::text[], auth.uid())
              or public.user_can_access_church(p.church_id, 'organization.manage', auth.uid())
            )
        )
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'pilot_daily_tasks' and policyname = 'Pilot tasks visible to pilot managers') then
    create policy "Pilot tasks visible to pilot managers"
      on public.pilot_daily_tasks for select to authenticated
      using (
        exists (
          select 1
          from public.pilot_daily_runs r
          join public.pilot_programs p on p.id = r.pilot_id
          where r.id = pilot_daily_tasks.daily_run_id
            and (
              public.has_platform_role(array['super_admin', 'support_agent', 'developer', 'auditor']::text[], auth.uid())
              or public.user_can_access_church(p.church_id, 'organization.manage', auth.uid())
            )
        )
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'support_articles' and policyname = 'Published support articles are visible') then
    create policy "Published support articles are visible"
      on public.support_articles for select to authenticated
      using (published = true);
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'pilot_satisfaction_responses' and policyname = 'Members can create own satisfaction response') then
    create policy "Members can create own satisfaction response"
      on public.pilot_satisfaction_responses for insert to authenticated
      with check (
        respondent_profile_id = auth.uid()
        and public.user_can_access_church(church_id, null, auth.uid())
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'pilot_satisfaction_responses' and policyname = 'Platform can read satisfaction responses') then
    create policy "Platform can read satisfaction responses"
      on public.pilot_satisfaction_responses for select to authenticated
      using (public.has_platform_role(array['super_admin', 'support_agent', 'developer', 'auditor']::text[], auth.uid()));
  end if;
end $$;

grant select on public.pilot_programs to authenticated;
grant select on public.pilot_participants to authenticated;
grant select on public.pilot_daily_runs to authenticated;
grant select on public.pilot_daily_tasks to authenticated;
grant select, insert on public.pilot_satisfaction_responses to authenticated;
grant select on public.support_articles to authenticated;
grant select on public.pilot_daily_snapshots to authenticated;

grant execute on function public.get_pilot_dashboard_snapshot(uuid) to authenticated, service_role;
grant execute on function public.submit_pilot_satisfaction(uuid, integer, integer, integer, integer, integer, integer, integer, text, text, integer) to authenticated, service_role;

notify pgrst, 'reload schema';
