create table if not exists public.launch_checklist_items (
  id uuid primary key default gen_random_uuid(),
  item_key text not null unique,
  title text not null,
  category text not null,
  status text not null default 'not_started'
    check (status in ('not_started', 'in_progress', 'blocked', 'done')),
  responsible text,
  notes text,
  sort_order integer not null default 0,
  is_critical boolean not null default true,
  evidence jsonb not null default '{}'::jsonb,
  updated_by_profile_id uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.pilot_feedback (
  id uuid primary key default gen_random_uuid(),
  church_id uuid references public.churches(id) on delete set null,
  reporter_profile_id uuid references public.profiles(id) on delete set null,
  page text,
  feedback_type text not null default 'bug'
    check (feedback_type in ('bug', 'suggestion', 'rating', 'support')),
  title text not null,
  description text not null,
  priority text not null default 'normal'
    check (priority in ('low', 'normal', 'high', 'critical')),
  status text not null default 'new'
    check (status in ('new', 'reviewing', 'fixing', 'fixed', 'closed')),
  attachment_url text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.church_onboarding_progress (
  church_id uuid primary key references public.churches(id) on delete cascade,
  confirmed_church_data boolean not null default false,
  confirmed_leadership boolean not null default false,
  uploaded_logo boolean not null default false,
  configured_branding boolean not null default false,
  configured_payment_methods boolean not null default false,
  configured_withdrawal_destination boolean not null default false,
  selected_plan boolean not null default false,
  added_leaders boolean not null default false,
  created_first_service boolean not null default false,
  created_first_publication boolean not null default false,
  created_first_campaign boolean not null default false,
  invited_members boolean not null default false,
  completed_at timestamptz,
  updated_by_profile_id uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.production_integration_status (
  id uuid primary key default gen_random_uuid(),
  integration_key text not null unique,
  title text not null,
  category text not null,
  status text not null default 'not_configured'
    check (status in ('not_configured', 'pending_credentials', 'sandbox', 'configured', 'blocked')),
  environment text not null default 'production',
  provider text,
  notes text,
  last_checked_at timestamptz,
  evidence jsonb not null default '{}'::jsonb,
  updated_by_profile_id uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_launch_checklist_status
  on public.launch_checklist_items(status, category, sort_order);
create index if not exists idx_pilot_feedback_church_status
  on public.pilot_feedback(church_id, status, priority, created_at desc);
create index if not exists idx_production_integration_status_category
  on public.production_integration_status(category, status);

drop trigger if exists set_launch_checklist_items_updated_at on public.launch_checklist_items;
create trigger set_launch_checklist_items_updated_at
  before update on public.launch_checklist_items
  for each row execute function public.set_updated_at();

drop trigger if exists set_pilot_feedback_updated_at on public.pilot_feedback;
create trigger set_pilot_feedback_updated_at
  before update on public.pilot_feedback
  for each row execute function public.set_updated_at();

drop trigger if exists set_church_onboarding_progress_updated_at on public.church_onboarding_progress;
create trigger set_church_onboarding_progress_updated_at
  before update on public.church_onboarding_progress
  for each row execute function public.set_updated_at();

drop trigger if exists set_production_integration_status_updated_at on public.production_integration_status;
create trigger set_production_integration_status_updated_at
  before update on public.production_integration_status
  for each row execute function public.set_updated_at();

insert into public.launch_checklist_items (item_key, title, category, status, responsible, notes, sort_order, is_critical)
values
  ('supabase_project', 'Supabase remoto ligado e migrations aplicadas', 'Supabase', 'done', 'Tecnico', 'Projeto Comunhao ligado ao ref dxofxuajsrocbxdmekfx.', 10, true),
  ('migrations_validated', 'Migrations sem divergencia', 'Supabase', 'done', 'Tecnico', 'migration list alinhada ate 20260716170000.', 20, true),
  ('rls_smoke_tests', 'Smoke tests de RLS por perfil', 'Seguranca', 'in_progress', 'Tecnico', 'Validar todos os perfis reais antes do piloto.', 30, true),
  ('storage_buckets', 'Buckets de storage e policies configurados', 'Storage', 'in_progress', 'Tecnico', 'Buckets criados; falta teste com upload real por igreja.', 40, true),
  ('backups_restore', 'Backup e restauracao testados', 'Operacao', 'blocked', 'Administrador Supabase', 'Nao considerar pronto sem ensaio de restore.', 50, true),
  ('monitoring', 'Monitorizacao e alertas de erros', 'Operacao', 'blocked', 'Tecnico', 'Falta provider real para erros Flutter/Edge Functions.', 60, true),
  ('mpesa_provider', 'M-Pesa real configurado', 'Pagamentos', 'blocked', 'Financeiro', 'Credenciais reais devem ficar no backend/Edge Function.', 70, true),
  ('emola_provider', 'E-Mola real configurado', 'Pagamentos', 'blocked', 'Financeiro', 'Credenciais reais devem ficar no backend/Edge Function.', 80, true),
  ('card_provider', 'Visa/Mastercard com provedor PCI', 'Pagamentos', 'blocked', 'Financeiro', 'Sem provedor escolhido; cartoes ficam desativados/em breve.', 90, true),
  ('push_notifications', 'Push notifications configurado', 'Notificacoes', 'blocked', 'Tecnico', 'Internas funcionam; push externo pendente.', 100, false),
  ('email_sms_whatsapp', 'E-mail, SMS e WhatsApp com providers reais', 'Notificacoes', 'blocked', 'Tecnico', 'Nao marcar como entregue sem confirmacao do provedor.', 110, false),
  ('cron_jobs', 'Cron/rotinas automáticas idempotentes', 'Automacao', 'blocked', 'Tecnico', 'Falta configurar schedule real no Supabase.', 120, true),
  ('privacy_terms', 'Termos, privacidade e consentimentos', 'Legal', 'blocked', 'Responsavel legal', 'Texto legal precisa revisao humana.', 130, true),
  ('android_release', 'Android pronto para teste fechado', 'Publicacao', 'not_started', 'Tecnico', 'Keystore nao deve ficar no repositorio.', 140, false),
  ('web_release', 'Web com HTTPS, dominio e rollback', 'Publicacao', 'not_started', 'Tecnico', 'Validar dominio e cache antes do piloto.', 150, true),
  ('ios_release', 'iOS/TestFlight documentado', 'Publicacao', 'blocked', 'Tecnico', 'Build iOS exige Mac.', 160, false),
  ('vida_nova_pilot', 'Piloto Igreja Vida Nova preparado', 'Piloto', 'in_progress', 'Sara', 'Iniciar com pastor, lideres, financeiro e 10-30 membros.', 170, true)
on conflict (item_key) do update
set
  title = excluded.title,
  category = excluded.category,
  responsible = excluded.responsible,
  sort_order = excluded.sort_order,
  is_critical = excluded.is_critical,
  notes = coalesce(public.launch_checklist_items.notes, excluded.notes);

insert into public.production_integration_status (integration_key, title, category, status, environment, provider, notes)
values
  ('mpesa', 'M-Pesa', 'payment', 'pending_credentials', 'production', 'M-Pesa', 'Preparar Edge Function; nao guardar credenciais no Flutter.'),
  ('emola', 'E-Mola', 'payment', 'pending_credentials', 'production', 'E-Mola', 'Preparar Edge Function; nao guardar credenciais no Flutter.'),
  ('cards', 'Visa/Mastercard', 'payment', 'blocked', 'production', null, 'Escolher provedor com pagina hospedada/SDK seguro e PCI.'),
  ('push', 'Push notifications', 'notification', 'blocked', 'production', null, 'Internas continuam independentes de push.'),
  ('sms', 'SMS', 'notification', 'pending_credentials', 'production', null, 'Supabase avisa que SMS provider ainda nao esta ativo.'),
  ('whatsapp', 'WhatsApp', 'notification', 'blocked', 'production', null, 'Exige provider e consentimento.'),
  ('email', 'E-mail', 'notification', 'blocked', 'production', null, 'Exige provider, templates e logs.'),
  ('cron', 'Cron/Schedules', 'automation', 'blocked', 'production', 'Supabase', 'Configurar schedules idempotentes.'),
  ('monitoring', 'Monitorizacao', 'operations', 'blocked', 'production', null, 'Escolher provider e separar logs dev/prod.'),
  ('backup_restore', 'Backups e restore', 'operations', 'blocked', 'production', 'Supabase', 'Backups automáticos nao bastam sem teste de restore.')
on conflict (integration_key) do update
set
  title = excluded.title,
  category = excluded.category,
  environment = excluded.environment,
  provider = excluded.provider,
  notes = coalesce(public.production_integration_status.notes, excluded.notes);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('church-logos', 'church-logos', false, 2097152, array['image/png','image/jpeg','image/webp','image/svg+xml']),
  ('campaign-media', 'campaign-media', false, 5242880, array['image/png','image/jpeg','image/webp']),
  ('finance-proofs', 'finance-proofs', false, 5242880, array['image/png','image/jpeg','image/webp','application/pdf']),
  ('finance-receipts', 'finance-receipts', false, 5242880, array['application/pdf','image/png','image/jpeg']),
  ('church-documents', 'church-documents', false, 10485760, array['application/pdf','image/png','image/jpeg','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document']),
  ('asset-media', 'asset-media', false, 5242880, array['image/png','image/jpeg','image/webp','application/pdf']),
  ('profile-media', 'profile-media', false, 2097152, array['image/png','image/jpeg','image/webp']),
  ('request-attachments', 'request-attachments', false, 5242880, array['image/png','image/jpeg','image/webp','application/pdf']),
  ('event-media', 'event-media', false, 5242880, array['image/png','image/jpeg','image/webp']),
  ('pilot-feedback', 'pilot-feedback', false, 5242880, array['image/png','image/jpeg','image/webp','application/pdf'])
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Church members can read scoped private storage"
  on storage.objects;
create policy "Church members can read scoped private storage"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id in (
      'church-logos',
      'campaign-media',
      'finance-receipts',
      'church-documents',
      'asset-media',
      'profile-media',
      'request-attachments',
      'event-media',
      'pilot-feedback'
    )
    and exists (
      select 1
      from public.memberships m
      where m.profile_id = auth.uid()
        and m.status = 'active'
        and split_part(storage.objects.name, '/', 1) = m.church_id::text
    )
  );

drop policy if exists "Church managers can upload scoped private storage"
  on storage.objects;
create policy "Church managers can upload scoped private storage"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id in (
      'church-logos',
      'campaign-media',
      'finance-proofs',
      'finance-receipts',
      'church-documents',
      'asset-media',
      'profile-media',
      'request-attachments',
      'event-media',
      'pilot-feedback'
    )
    and exists (
      select 1
      from public.memberships m
      where m.profile_id = auth.uid()
        and m.status = 'active'
        and m.role in ('pastor', 'church_admin', 'finance', 'secretary', 'leader')
        and split_part(storage.objects.name, '/', 1) = m.church_id::text
    )
  );

create or replace function public.get_demo_cleanup_summary(p_church_id uuid)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  org_id uuid;
begin
  select organization_id into org_id
  from public.churches
  where id = p_church_id;

  if not public.user_can_access_church(p_church_id, 'organization.manage', auth.uid()) then
    raise exception 'Not allowed to inspect demo data.';
  end if;

  return jsonb_build_object(
    'demo_churches', (select count(*) from public.churches where organization_id = org_id and is_demo = true),
    'demo_goals', (select count(*) from public.executive_goals where organization_id = org_id and is_demo = true),
    'demo_alerts', (select count(*) from public.executive_alerts where organization_id = org_id and is_demo = true),
    'demo_reports', (select count(*) from public.executive_reports where organization_id = org_id and is_demo = true),
    'demo_transfers', (select count(*) from public.member_transfer_requests where organization_id = org_id and is_demo = true),
    'demo_leaderships', (select count(*) from public.church_unit_leaderships where organization_id = org_id and is_demo = true)
  );
end;
$$;

create or replace function public.cleanup_church_demo_data(
  p_church_id uuid,
  p_confirmation text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  org_id uuid;
  summary jsonb;
begin
  if p_confirmation <> 'LIMPAR DEMO' then
    raise exception 'Confirmation text is required.';
  end if;

  select organization_id into org_id
  from public.churches
  where id = p_church_id;

  if not public.user_can_access_church(p_church_id, 'organization.manage', auth.uid()) then
    raise exception 'Not allowed to clean demo data.';
  end if;

  summary := public.get_demo_cleanup_summary(p_church_id);

  delete from public.executive_report_exports
  where organization_id = org_id
    and report_id in (select id from public.executive_reports where organization_id = org_id and is_demo = true);

  delete from public.executive_reports where organization_id = org_id and is_demo = true;
  delete from public.executive_alerts where organization_id = org_id and is_demo = true;
  delete from public.executive_goal_updates
  where goal_id in (select id from public.executive_goals where organization_id = org_id and is_demo = true);
  delete from public.executive_goals where organization_id = org_id and is_demo = true;
  delete from public.member_transfer_requests where organization_id = org_id and is_demo = true;
  delete from public.church_unit_leaderships where organization_id = org_id and is_demo = true;
  delete from public.churches
  where organization_id = org_id
    and is_demo = true
    and parent_church_id is not null;

  perform public.create_organization_audit_log(
    org_id,
    'demo.cleaned',
    'church_organization',
    org_id,
    p_church_id,
    'Dados de demonstracao removidos com confirmacao explicita.',
    summary,
    false
  );

  return summary;
end;
$$;

create or replace function public.submit_pilot_feedback(
  p_church_id uuid,
  p_title text,
  p_description text,
  p_feedback_type text default 'bug',
  p_priority text default 'normal',
  p_page text default null,
  p_attachment_url text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  feedback_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if p_church_id is not null and not public.user_can_access_church(p_church_id, null, auth.uid()) then
    raise exception 'Not allowed to send feedback for this church.';
  end if;

  insert into public.pilot_feedback (
    church_id,
    reporter_profile_id,
    page,
    feedback_type,
    title,
    description,
    priority,
    attachment_url,
    metadata
  )
  values (
    p_church_id,
    auth.uid(),
    p_page,
    coalesce(nullif(trim(p_feedback_type), ''), 'bug'),
    trim(p_title),
    trim(p_description),
    coalesce(nullif(trim(p_priority), ''), 'normal'),
    p_attachment_url,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into feedback_id;

  return feedback_id;
end;
$$;

create or replace function public.update_launch_checklist_item(
  p_item_key text,
  p_status text,
  p_notes text default null,
  p_responsible text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if not public.has_platform_role(array['super_admin', 'support_agent', 'developer', 'auditor']::text[], auth.uid()) then
    raise exception 'Only platform admins can update launch checklist.';
  end if;

  update public.launch_checklist_items
  set
    status = p_status,
    notes = coalesce(p_notes, notes),
    responsible = coalesce(p_responsible, responsible),
    updated_by_profile_id = auth.uid()
  where item_key = p_item_key
  returning to_jsonb(launch_checklist_items.*) into result;

  if result is null then
    raise exception 'Checklist item not found.';
  end if;

  perform public.create_platform_audit_log(
    'launch_checklist.updated',
    'launch_checklist_item',
    null,
    null,
    'Checklist de lancamento atualizado: ' || p_item_key,
    jsonb_build_object('item_key', p_item_key, 'status', p_status)
  );

  return result;
end;
$$;

create or replace function public.get_launch_readiness_snapshot()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  vida_id uuid;
  checklist jsonb;
  integrations jsonb;
  storage_items jsonb;
  vida_checks jsonb;
  demo_summary jsonb;
  blockers integer;
  critical_open integer;
  classification text;
begin
  if not public.has_platform_role(array['super_admin', 'support_agent', 'developer', 'auditor']::text[], auth.uid()) then
    raise exception 'Only platform admins can view launch readiness.';
  end if;

  select id into vida_id
  from public.churches
  where slug = 'vida-nova'
  limit 1;

  select coalesce(jsonb_agg(to_jsonb(i) order by i.sort_order), '[]'::jsonb)
  into checklist
  from (
    select item_key, title, category, status, responsible, notes, sort_order, is_critical, updated_at
    from public.launch_checklist_items
  ) i;

  select coalesce(jsonb_agg(to_jsonb(i) order by i.category, i.title), '[]'::jsonb)
  into integrations
  from (
    select integration_key, title, category, status, environment, provider, notes, last_checked_at
    from public.production_integration_status
  ) i;

  select coalesce(jsonb_agg(to_jsonb(b) order by b.id), '[]'::jsonb)
  into storage_items
  from (
    select id, public, file_size_limit, allowed_mime_types
    from storage.buckets
    where id in (
      'church-logos',
      'campaign-media',
      'finance-proofs',
      'finance-receipts',
      'church-documents',
      'asset-media',
      'profile-media',
      'request-attachments',
      'event-media',
      'pilot-feedback',
      'pastoral-publications'
    )
  ) b;

  if vida_id is not null then
    demo_summary := public.get_demo_cleanup_summary(vida_id);
  else
    demo_summary := '{}'::jsonb;
  end if;

  select jsonb_build_object(
    'vida_nova_exists', vida_id is not null,
    'sara_is_owner_pastor', exists (
      select 1
      from public.profiles p
      join public.memberships m on m.profile_id = p.id
      join public.church_settings cs on cs.church_id = m.church_id
      where public.canonical_mz_phone(p.phone) = public.canonical_mz_phone('877688695')
        and m.church_id = vida_id
        and m.role = 'pastor'
        and m.status = 'active'
        and cs.owner_profile_id = p.id
    ),
    'member_827688695_active', exists (
      select 1
      from public.profiles p
      join public.memberships m on m.profile_id = p.id
      where public.canonical_mz_phone(p.phone) = public.canonical_mz_phone('827688695')
        and m.church_id = vida_id
        and m.status = 'active'
    ),
    'admin_841130015_super_admin', exists (
      select 1
      from public.profiles p
      join public.platform_roles r on r.profile_id = p.id
      where public.canonical_mz_phone(p.phone) = public.canonical_mz_phone('841130015')
        and r.role = 'super_admin'
        and r.status = 'active'
    ),
    'duplicate_core_profiles', (
      select count(*)
      from public.profiles p
      where public.canonical_mz_phone(p.phone) in ('877688695', '827688695', '841130015')
    ) - 3,
    'personal_wallets_exist', (
      select count(*)
      from public.member_wallets mw
      join public.profiles p on p.id = mw.profile_id
      where public.canonical_mz_phone(p.phone) in ('877688695', '827688695', '841130015')
    )
  ) into vida_checks;

  select count(*) into blockers
  from public.launch_checklist_items
  where status = 'blocked';

  select count(*) into critical_open
  from public.launch_checklist_items
  where is_critical
    and status <> 'done';

  classification := case
    when blockers > 0 then 'not_ready'
    when critical_open > 0 then 'ready_for_staging'
    when exists (select 1 from public.production_integration_status where status in ('blocked', 'pending_credentials', 'not_configured')) then 'ready_for_pilot'
    else 'ready_for_production'
  end;

  return jsonb_build_object(
    'classification', classification,
    'blockers', blockers,
    'critical_open', critical_open,
    'checklist', checklist,
    'integrations', integrations,
    'storage', storage_items,
    'vida_nova', vida_checks,
    'demo_summary', demo_summary,
    'generated_at', now()
  );
end;
$$;

alter table public.launch_checklist_items enable row level security;
alter table public.pilot_feedback enable row level security;
alter table public.church_onboarding_progress enable row level security;
alter table public.production_integration_status enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'launch_checklist_items' and policyname = 'Platform admins can read launch checklist') then
    create policy "Platform admins can read launch checklist"
      on public.launch_checklist_items for select to authenticated
      using (public.has_platform_role(array['super_admin', 'support_agent', 'developer', 'auditor']::text[], auth.uid()));
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'production_integration_status' and policyname = 'Platform admins can read integration status') then
    create policy "Platform admins can read integration status"
      on public.production_integration_status for select to authenticated
      using (public.has_platform_role(array['super_admin', 'support_agent', 'developer', 'auditor']::text[], auth.uid()));
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'pilot_feedback' and policyname = 'Church users can create own pilot feedback') then
    create policy "Church users can create own pilot feedback"
      on public.pilot_feedback for insert to authenticated
      with check (
        reporter_profile_id = auth.uid()
        and (church_id is null or public.user_can_access_church(church_id, null, auth.uid()))
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'pilot_feedback' and policyname = 'Platform admins can read pilot feedback') then
    create policy "Platform admins can read pilot feedback"
      on public.pilot_feedback for select to authenticated
      using (public.has_platform_role(array['super_admin', 'support_agent', 'developer', 'auditor']::text[], auth.uid()));
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'church_onboarding_progress' and policyname = 'Church managers can view onboarding progress') then
    create policy "Church managers can view onboarding progress"
      on public.church_onboarding_progress for select to authenticated
      using (public.user_can_access_church(church_id, null, auth.uid()));
  end if;
end $$;

grant select on public.launch_checklist_items to authenticated;
grant select on public.production_integration_status to authenticated;
grant select, insert on public.pilot_feedback to authenticated;
grant select on public.church_onboarding_progress to authenticated;

grant execute on function public.get_launch_readiness_snapshot() to authenticated, service_role;
grant execute on function public.update_launch_checklist_item(text, text, text, text) to authenticated, service_role;
grant execute on function public.get_demo_cleanup_summary(uuid) to authenticated, service_role;
grant execute on function public.cleanup_church_demo_data(uuid, text) to authenticated, service_role;
grant execute on function public.submit_pilot_feedback(uuid, text, text, text, text, text, text, jsonb) to authenticated, service_role;
