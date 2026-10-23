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

create or replace function public.get_launch_readiness_snapshot(
  p_refresh boolean default true
)
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
    'duplicate_core_profiles', greatest((
      select count(*)
      from public.profiles p
      where public.canonical_mz_phone(p.phone) in ('877688695', '827688695', '841130015')
    ) - 3, 0),
    'personal_wallets_exist', (
      select count(*)
      from public.member_wallet_accounts mw
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

grant execute on function public.user_can_access_organization(uuid, text, uuid) to authenticated, service_role;
grant execute on function public.user_can_access_church(uuid, text, uuid) to authenticated, service_role;
grant execute on function public.get_launch_readiness_snapshot(boolean) to authenticated, service_role;

notify pgrst, 'reload schema';
