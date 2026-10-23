create table if not exists public.platform_roles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  unique (profile_id, role)
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'platform_roles_role_check'
  ) then
    alter table public.platform_roles
      add constraint platform_roles_role_check
      check (role in ('super_admin', 'support_agent'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'platform_roles_status_check'
  ) then
    alter table public.platform_roles
      add constraint platform_roles_status_check
      check (status in ('active', 'revoked'));
  end if;
end $$;

create table if not exists public.church_applications (
  id uuid primary key default gen_random_uuid(),
  pastor_profile_id uuid not null references public.profiles(id) on delete cascade,
  church_name text not null,
  city text not null,
  province text,
  country text not null default 'Mozambique',
  phone text not null,
  email text,
  applicant_role text not null default 'pastor',
  logo_url text,
  primary_color text,
  secondary_color text,
  tagline text,
  mpesa text,
  emola text,
  bank_name text,
  bank_account_name text,
  bank_account_number text,
  status text not null default 'draft',
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  review_notes text,
  approved_church_id uuid references public.churches(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_applications_role_check'
  ) then
    alter table public.church_applications
      add constraint church_applications_role_check
      check (applicant_role in ('pastor', 'church_admin'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_applications_status_check'
  ) then
    alter table public.church_applications
      add constraint church_applications_status_check
      check (status in ('draft', 'submitted', 'changes_requested', 'approved', 'rejected'));
  end if;
end $$;

create table if not exists public.church_settings (
  church_id uuid primary key references public.churches(id) on delete cascade,
  source_application_id uuid references public.church_applications(id) on delete set null,
  member_join_mode text not null default 'open',
  join_link text,
  require_member_approval boolean not null default false,
  allow_public_events boolean not null default true,
  allow_public_announcements boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_settings_member_join_mode_check'
  ) then
    alter table public.church_settings
      add constraint church_settings_member_join_mode_check
      check (member_join_mode in ('open', 'invite_only'));
  end if;
end $$;

create index if not exists idx_platform_roles_profile_id
  on public.platform_roles(profile_id);

create index if not exists idx_church_applications_pastor_profile_id
  on public.church_applications(pastor_profile_id);

create index if not exists idx_church_applications_status
  on public.church_applications(status);

create index if not exists idx_church_settings_source_application_id
  on public.church_settings(source_application_id);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.is_super_admin(check_user uuid default auth.uid())
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
        and pr.role = 'super_admin'
        and pr.status = 'active'
    );
$$;

create or replace function public.has_church_role(
  target_church_id uuid,
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
    public.is_super_admin(coalesce(check_user, auth.uid()))
    or exists (
      select 1
      from public.memberships m
      where m.church_id = target_church_id
        and m.profile_id = coalesce(check_user, auth.uid())
        and m.status = 'active'
        and m.role = any (allowed_roles)
    );
$$;

create or replace function public.slugify_text(value text)
returns text
language sql
immutable
as $$
  select trim(both '-' from regexp_replace(lower(coalesce(value, '')), '[^a-z0-9]+', '-', 'g'));
$$;

create or replace function public.generate_unique_church_slug(church_name text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  base_slug text := nullif(public.slugify_text(church_name), '');
  candidate text;
  suffix integer := 1;
begin
  base_slug := coalesce(base_slug, 'igreja');
  candidate := base_slug;

  while exists (
    select 1
    from public.churches
    where slug = candidate
  ) loop
    suffix := suffix + 1;
    candidate := base_slug || '-' || suffix::text;
  end loop;

  return candidate;
end;
$$;

create or replace function public.generate_unique_join_code(church_name text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  prefix text;
  candidate text;
begin
  select string_agg(left(filtered.word, 1), '' order by filtered.ord)
  into prefix
  from (
    select word, ord
    from unnest(
      regexp_split_to_array(
        upper(regexp_replace(coalesce(church_name, ''), '[^A-Za-z0-9 ]', '', 'g')),
        '\s+'
      )
    ) with ordinality as words(word, ord)
    where word <> ''
      and word not in ('IGREJA', 'MINISTERIO', 'COMUNIDADE', 'CHURCH', 'DE', 'DA', 'DO', 'DOS', 'DAS')
    order by ord
    limit 3
  ) as filtered;

  prefix := upper(left(coalesce(nullif(prefix, ''), 'CMP'), 3));

  loop
    candidate := prefix || lpad((floor(random() * 100000))::int::text, 5, '0');
    exit when not exists (
      select 1
      from public.churches
      where upper(join_code) = upper(candidate)
    );
  end loop;

  return candidate;
end;
$$;

create or replace function public.guard_church_application_mutations()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.pastor_profile_id is null then
    new.pastor_profile_id := auth.uid();
  end if;

  if tg_op = 'INSERT' then
    if not public.is_super_admin(auth.uid()) then
      if new.pastor_profile_id is distinct from auth.uid() then
        raise exception 'You can only create your own church application.';
      end if;

      if coalesce(new.status, 'draft') <> 'draft' then
        raise exception 'New church applications must start as draft.';
      end if;

      new.reviewed_at := null;
      new.reviewed_by := null;
      new.review_notes := null;
      new.approved_church_id := null;
    end if;
  else
    if not public.is_super_admin(auth.uid()) then
      if old.pastor_profile_id is distinct from auth.uid() then
        raise exception 'You can only update your own church application.';
      end if;

      if new.pastor_profile_id is distinct from old.pastor_profile_id then
        raise exception 'pastor_profile_id is immutable.';
      end if;

      if new.reviewed_at is distinct from old.reviewed_at
        or new.reviewed_by is distinct from old.reviewed_by
        or new.review_notes is distinct from old.review_notes
        or new.approved_church_id is distinct from old.approved_church_id then
        raise exception 'Review fields are managed by the platform.';
      end if;

      if old.status not in ('draft', 'submitted', 'changes_requested') then
        raise exception 'Reviewed applications can no longer be edited.';
      end if;

      if new.status not in ('draft', 'submitted') then
        raise exception 'Applicants can only save a draft or submit the application.';
      end if;

      if old.status = 'submitted' and new.status = 'draft' then
        raise exception 'Submitted applications cannot return to draft.';
      end if;
    end if;
  end if;

  if new.status = 'submitted'
    and (tg_op = 'INSERT' or old.status is distinct from 'submitted') then
    new.submitted_at := coalesce(new.submitted_at, now());
  elsif new.status = 'draft' then
    new.submitted_at := null;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists set_church_applications_updated_at on public.church_applications;
create trigger set_church_applications_updated_at
  before update on public.church_applications
  for each row execute procedure public.touch_updated_at();

drop trigger if exists guard_church_application_mutations on public.church_applications;
create trigger guard_church_application_mutations
  before insert or update on public.church_applications
  for each row execute procedure public.guard_church_application_mutations();

drop trigger if exists set_church_settings_updated_at on public.church_settings;
create trigger set_church_settings_updated_at
  before update on public.church_settings
  for each row execute procedure public.touch_updated_at();

create or replace function public.submit_church_application(p_application_id uuid)
returns public.church_applications
language plpgsql
security invoker
set search_path = public
as $$
declare
  result public.church_applications;
begin
  update public.church_applications
  set status = 'submitted'
  where id = p_application_id
    and pastor_profile_id = auth.uid()
    and status in ('draft', 'changes_requested')
  returning *
  into result;

  if not found then
    raise exception 'Church application not found or not ready to submit.';
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

insert into public.church_settings (
  church_id,
  member_join_mode,
  join_link,
  require_member_approval
)
select
  c.id,
  'open',
  case
    when c.join_code is null then null
    else 'https://comunhao.app/join/' || upper(c.join_code)
  end,
  false
from public.churches c
where not exists (
  select 1
  from public.church_settings s
  where s.church_id = c.id
);

grant select on public.platform_roles to authenticated;
grant select, insert, update on public.church_applications to authenticated;
grant select, update on public.church_settings to authenticated;
grant select, update on public.churches to authenticated;
grant select, insert, update, delete on public.memberships to authenticated;
grant select, insert, update, delete on public.church_payment_settings to authenticated;
grant select, insert, update, delete on public.announcements to authenticated;
grant select, insert, update, delete on public.events to authenticated;
grant select, insert, update, delete on public.donation_campaigns to authenticated;
grant execute on function public.submit_church_application(uuid) to authenticated;
grant execute on function public.review_church_application(uuid, text, text) to authenticated;

alter table public.platform_roles enable row level security;
alter table public.church_applications enable row level security;
alter table public.church_settings enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_roles'
      and policyname = 'Users can read own platform roles'
  ) then
    create policy "Users can read own platform roles"
      on public.platform_roles
      for select
      to authenticated
      using (auth.uid() = profile_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_roles'
      and policyname = 'Super admins can manage platform roles'
  ) then
    create policy "Super admins can manage platform roles"
      on public.platform_roles
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
      and tablename = 'church_applications'
      and policyname = 'Users can read relevant church applications'
  ) then
    create policy "Users can read relevant church applications"
      on public.church_applications
      for select
      to authenticated
      using (
        auth.uid() = pastor_profile_id
        or public.is_super_admin()
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_applications'
      and policyname = 'Users can create church applications'
  ) then
    create policy "Users can create church applications"
      on public.church_applications
      for insert
      to authenticated
      with check (
        auth.uid() = pastor_profile_id
        or public.is_super_admin()
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_applications'
      and policyname = 'Users can update relevant church applications'
  ) then
    create policy "Users can update relevant church applications"
      on public.church_applications
      for update
      to authenticated
      using (
        auth.uid() = pastor_profile_id
        or public.is_super_admin()
      )
      with check (
        auth.uid() = pastor_profile_id
        or public.is_super_admin()
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_settings'
      and policyname = 'Members can read own church settings'
  ) then
    create policy "Members can read own church settings"
      on public.church_settings
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
      and tablename = 'church_settings'
      and policyname = 'Church admins can manage own church settings'
  ) then
    create policy "Church admins can manage own church settings"
      on public.church_settings
      for update
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
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'churches'
      and policyname = 'Church admins can update own churches'
  ) then
    create policy "Church admins can update own churches"
      on public.churches
      for update
      to authenticated
      using (
        public.has_church_role(
          id,
          array['pastor', 'church_admin']::text[]
        )
      )
      with check (
        public.has_church_role(
          id,
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
      and tablename = 'profiles'
      and policyname = 'Church admins can read profiles in own church'
  ) then
    create policy "Church admins can read profiles in own church"
      on public.profiles
      for select
      to authenticated
      using (
        public.is_super_admin()
        or exists (
          select 1
          from public.memberships manager
          join public.memberships target
            on target.profile_id = profiles.id
           and target.status = 'active'
           and target.church_id = manager.church_id
          where manager.profile_id = auth.uid()
            and manager.status = 'active'
            and manager.role in ('pastor', 'church_admin')
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'memberships'
      and policyname = 'Church admins can read memberships in own church'
  ) then
    create policy "Church admins can read memberships in own church"
      on public.memberships
      for select
      to authenticated
      using (
        public.has_church_role(
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
      and tablename = 'memberships'
      and policyname = 'Church admins can manage memberships in own church'
  ) then
    create policy "Church admins can manage memberships in own church"
      on public.memberships
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
        and role in ('church_admin', 'pastor', 'leader', 'member')
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_payment_settings'
      and policyname = 'Church admins can manage payment settings in own church'
  ) then
    create policy "Church admins can manage payment settings in own church"
      on public.church_payment_settings
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
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'announcements'
      and policyname = 'Church admins can manage announcements in own church'
  ) then
    create policy "Church admins can manage announcements in own church"
      on public.announcements
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
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'events'
      and policyname = 'Church admins can manage events in own church'
  ) then
    create policy "Church admins can manage events in own church"
      on public.events
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
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'donation_campaigns'
      and policyname = 'Church admins can manage campaigns in own church'
  ) then
    create policy "Church admins can manage campaigns in own church"
      on public.donation_campaigns
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
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'prayer_requests'
      and policyname = 'Church admins can read prayer requests in own church'
  ) then
    create policy "Church admins can read prayer requests in own church"
      on public.prayer_requests
      for select
      to authenticated
      using (
        public.has_church_role(
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
      and tablename = 'prayer_requests'
      and policyname = 'Church admins can update prayer requests in own church'
  ) then
    create policy "Church admins can update prayer requests in own church"
      on public.prayer_requests
      for update
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
      );
  end if;
end $$;
