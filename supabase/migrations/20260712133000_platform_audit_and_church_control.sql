alter table public.church_settings
  add column if not exists owner_profile_id uuid references public.profiles(id) on delete set null;

create index if not exists idx_church_settings_owner_profile_id
  on public.church_settings(owner_profile_id);

create or replace function public.has_platform_role(
  allowed_roles text[],
  check_user uuid default auth.uid()
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select
    coalesce(auth.role(), '') = 'service_role'
    or exists (
      select 1
      from public.platform_roles pr
      where pr.profile_id = coalesce(check_user, auth.uid())
        and pr.role = any (coalesce(allowed_roles, array[]::text[]))
        and pr.status = 'active'
    );
$$;

create table if not exists public.platform_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid references public.profiles(id) on delete set null,
  actor_name text,
  actor_phone text,
  action text not null,
  target_type text not null,
  target_id uuid,
  church_id uuid references public.churches(id) on delete set null,
  church_name text,
  summary text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_platform_audit_logs_created_at
  on public.platform_audit_logs(created_at desc);

create index if not exists idx_platform_audit_logs_church_id
  on public.platform_audit_logs(church_id);

create index if not exists idx_platform_audit_logs_action
  on public.platform_audit_logs(action);

create or replace function public.create_platform_audit_log(
  p_action text,
  p_target_type text,
  p_target_id uuid default null,
  p_church_id uuid default null,
  p_summary text default null,
  p_details jsonb default '{}'::jsonb
)
returns public.platform_audit_logs
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_row public.profiles%rowtype;
  church_label text;
  result public.platform_audit_logs;
begin
  if not public.has_platform_role(
    array['super_admin', 'finance', 'support_agent', 'marketing', 'developer', 'auditor']::text[],
    auth.uid()
  ) then
    raise exception 'Only the platform team can write audit logs.';
  end if;

  select *
  into actor_row
  from public.profiles
  where id = auth.uid()
  limit 1;

  if p_church_id is not null then
    select name
    into church_label
    from public.churches
    where id = p_church_id
    limit 1;
  end if;

  insert into public.platform_audit_logs (
    actor_profile_id,
    actor_name,
    actor_phone,
    action,
    target_type,
    target_id,
    church_id,
    church_name,
    summary,
    details
  )
  values (
    auth.uid(),
    actor_row.full_name,
    actor_row.phone,
    p_action,
    p_target_type,
    p_target_id,
    p_church_id,
    church_label,
    coalesce(nullif(trim(coalesce(p_summary, '')), ''), p_action),
    coalesce(p_details, '{}'::jsonb)
  )
  returning *
  into result;

  return result;
end;
$$;

create or replace function public.transfer_church_owner(
  p_church_id uuid,
  p_new_owner_profile_id uuid,
  p_new_role text default 'pastor'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  church_exists boolean;
begin
  if not public.is_super_admin(auth.uid()) then
    raise exception 'Only super admins can transfer church ownership.';
  end if;

  if p_new_role not in ('pastor', 'church_admin') then
    raise exception 'Invalid owner role: %', p_new_role;
  end if;

  select exists(
    select 1
    from public.churches
    where id = p_church_id
  )
  into church_exists;

  if not church_exists then
    raise exception 'Church not found.';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = p_new_owner_profile_id
  ) then
    raise exception 'Profile not found for the new owner.';
  end if;

  insert into public.memberships (
    church_id,
    profile_id,
    role,
    status
  )
  values (
    p_church_id,
    p_new_owner_profile_id,
    p_new_role,
    'active'
  )
  on conflict (church_id, profile_id) do update
    set
      role = excluded.role,
      status = 'active';

  insert into public.church_settings (
    church_id,
    owner_profile_id
  )
  values (
    p_church_id,
    p_new_owner_profile_id
  )
  on conflict (church_id) do update
    set
      owner_profile_id = excluded.owner_profile_id,
      updated_at = now();

  return p_new_owner_profile_id;
end;
$$;

create or replace function public.reset_church_workspace(
  p_church_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_announcements integer := 0;
  deleted_events integer := 0;
  deleted_prayer_requests integer := 0;
  deleted_campaigns integer := 0;
begin
  if not public.is_super_admin(auth.uid()) then
    raise exception 'Only super admins can reset church workspaces.';
  end if;

  if not exists (
    select 1
    from public.churches
    where id = p_church_id
  ) then
    raise exception 'Church not found.';
  end if;

  delete from public.announcements
  where church_id = p_church_id;
  get diagnostics deleted_announcements = row_count;

  delete from public.events
  where church_id = p_church_id;
  get diagnostics deleted_events = row_count;

  delete from public.prayer_requests
  where church_id = p_church_id;
  get diagnostics deleted_prayer_requests = row_count;

  delete from public.donation_campaigns
  where church_id = p_church_id;
  get diagnostics deleted_campaigns = row_count;

  update public.church_settings
  set updated_at = now()
  where church_id = p_church_id;

  return jsonb_build_object(
    'announcements_deleted', deleted_announcements,
    'events_deleted', deleted_events,
    'prayer_requests_deleted', deleted_prayer_requests,
    'campaigns_deleted', deleted_campaigns
  );
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
      owner_profile_id,
      member_join_mode,
      join_link,
      require_member_approval
    )
    values (
      new_church_id,
      application_row.id,
      application_row.pastor_profile_id,
      'open',
      'https://comunhao.app/join/' || new_join_code,
      false
    )
    on conflict (church_id) do update
      set
        source_application_id = excluded.source_application_id,
        owner_profile_id = excluded.owner_profile_id,
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
    perform public.ensure_wallet_accounts('church', new_church_id, application_row.church_name);

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

update public.church_settings settings
set owner_profile_id = applications.pastor_profile_id
from public.church_applications applications
where settings.owner_profile_id is null
  and settings.source_application_id = applications.id;

update public.church_settings settings
set owner_profile_id = owners.profile_id
from (
  select distinct on (church_id)
    church_id,
    profile_id
  from public.memberships
  where status = 'active'
    and role in ('pastor', 'church_admin')
  order by
    church_id,
    case role when 'pastor' then 0 else 1 end,
    created_at
) owners
where settings.owner_profile_id is null
  and settings.church_id = owners.church_id;

grant select on public.platform_audit_logs to authenticated;
grant execute on function public.create_platform_audit_log(text, text, uuid, uuid, text, jsonb) to authenticated;
grant execute on function public.transfer_church_owner(uuid, uuid, text) to authenticated;
grant execute on function public.reset_church_workspace(uuid) to authenticated;

alter table public.platform_audit_logs enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_audit_logs'
      and policyname = 'Platform team can read audit logs'
  ) then
    create policy "Platform team can read audit logs"
      on public.platform_audit_logs
      for select
      to authenticated
      using (
        public.has_platform_role(
          array['super_admin', 'finance', 'support_agent', 'marketing', 'developer', 'auditor']::text[]
        )
      );
  end if;
end $$;
