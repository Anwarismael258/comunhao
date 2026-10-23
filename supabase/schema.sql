create extension if not exists pgcrypto;

create table if not exists public.churches (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  join_code text,
  app_name text,
  tagline text,
  hero_title text,
  hero_subtitle text,
  logo_url text,
  primary_color text,
  secondary_color text,
  phone text,
  email text,
  city text,
  country text default 'Mozambique',
  default_currency text not null default 'MZN',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.churches add column if not exists join_code text;
alter table public.churches add column if not exists app_name text;
alter table public.churches add column if not exists tagline text;
alter table public.churches add column if not exists hero_title text;
alter table public.churches add column if not exists hero_subtitle text;
alter table public.churches add column if not exists default_currency text not null default 'MZN';

create unique index if not exists idx_churches_join_code_unique
  on public.churches ((upper(join_code)))
  where join_code is not null;

create table if not exists public.profiles (
  id uuid primary key,
  full_name text not null,
  phone text,
  email text,
  birth_date date,
  avatar_url text,
  created_at timestamptz not null default now()
);

alter table public.profiles add column if not exists birth_date date;

create unique index if not exists idx_profiles_phone_unique
  on public.profiles (phone)
  where phone is not null;

create table if not exists public.memberships (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  unique (church_id, profile_id)
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'memberships_role_check'
  ) then
    alter table public.memberships
      add constraint memberships_role_check
      check (role in ('super_admin', 'church_admin', 'pastor', 'leader', 'member'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'memberships_status_check'
  ) then
    alter table public.memberships
      add constraint memberships_status_check
      check (status in ('active', 'blocked', 'removed', 'transferred'));
  end if;
end $$;

create table if not exists public.church_payment_settings (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  provider text not null,
  account_name text,
  account_number text,
  instructions text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  unique (church_id, provider)
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  title text not null,
  body text not null,
  pinned boolean not null default false,
  published_at timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  title text not null,
  description text,
  location text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  registration_required boolean not null default false,
  capacity integer,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.event_registrations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'confirmed',
  created_at timestamptz not null default now(),
  unique (event_id, profile_id)
);

create table if not exists public.donation_campaigns (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  title text not null,
  description text,
  target_amount numeric(12,2),
  start_at timestamptz,
  end_at timestamptz,
  active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.donations (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  profile_id uuid references public.profiles(id),
  campaign_id uuid references public.donation_campaigns(id),
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'MZN',
  payment_method text not null,
  provider text,
  provider_reference text,
  status text not null default 'pending',
  is_recurring boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.prayer_requests (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  profile_id uuid references public.profiles(id),
  title text not null,
  description text not null,
  is_private boolean not null default true,
  status text not null default 'new',
  created_at timestamptz not null default now()
);

create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  church_id uuid not null references public.churches(id) on delete cascade,
  token text not null,
  platform text not null,
  created_at timestamptz not null default now(),
  unique (profile_id, token)
);

create index if not exists idx_memberships_church_id on public.memberships(church_id);
create index if not exists idx_memberships_profile_id on public.memberships(profile_id);
create index if not exists idx_church_payment_settings_church_id on public.church_payment_settings(church_id);
create index if not exists idx_announcements_church_id on public.announcements(church_id);
create index if not exists idx_events_church_id on public.events(church_id);
create index if not exists idx_events_starts_at on public.events(starts_at);
create index if not exists idx_event_registrations_event_id on public.event_registrations(event_id);
create index if not exists idx_donation_campaigns_church_id on public.donation_campaigns(church_id);
create index if not exists idx_donations_church_id on public.donations(church_id);
create index if not exists idx_donations_profile_id on public.donations(profile_id);
create index if not exists idx_prayer_requests_church_id on public.prayer_requests(church_id);

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  metadata_church_id uuid;
  metadata_birth_date date;
begin
  begin
    if coalesce(new.raw_user_meta_data ->> 'church_id', '') <> '' then
      metadata_church_id := (new.raw_user_meta_data ->> 'church_id')::uuid;
    elsif coalesce(new.raw_user_meta_data ->> 'church_slug', '') <> '' then
      select id
      into metadata_church_id
      from public.churches
      where slug = new.raw_user_meta_data ->> 'church_slug'
      limit 1;
    end if;
  exception
    when others then
      metadata_church_id := null;
  end;

  begin
    if coalesce(new.raw_user_meta_data ->> 'birth_date', '') <> '' then
      metadata_birth_date := (new.raw_user_meta_data ->> 'birth_date')::date;
    end if;
  exception
    when others then
      metadata_birth_date := null;
  end;

  insert into public.profiles (
    id,
    full_name,
    phone,
    birth_date
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', 'Membro'),
    new.phone,
    metadata_birth_date
  )
  on conflict (id) do update
    set
      full_name = excluded.full_name,
      phone = excluded.phone,
      birth_date = coalesce(excluded.birth_date, public.profiles.birth_date);

  if metadata_church_id is not null then
    insert into public.memberships (
      church_id,
      profile_id,
      role,
      status
    )
    values (
      metadata_church_id,
      new.id,
      'member',
      'active'
    )
    on conflict (church_id, profile_id) do update
      set
        status = 'active',
        role = public.memberships.role;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_auth_user();

grant usage on schema public to anon, authenticated;
grant select on public.churches to anon, authenticated;
grant select on public.church_payment_settings to anon, authenticated;
grant select on public.announcements to anon, authenticated;
grant select on public.events to anon, authenticated;
grant select on public.donation_campaigns to anon, authenticated;
grant select, update on public.profiles to authenticated;
grant select on public.memberships to authenticated;
grant select, insert, update on public.prayer_requests to authenticated;
grant select, insert, update, delete on public.push_tokens to authenticated;

alter table public.churches enable row level security;
alter table public.church_payment_settings enable row level security;
alter table public.announcements enable row level security;
alter table public.events enable row level security;
alter table public.donation_campaigns enable row level security;
alter table public.profiles enable row level security;
alter table public.memberships enable row level security;
alter table public.event_registrations enable row level security;
alter table public.donations enable row level security;
alter table public.prayer_requests enable row level security;
alter table public.push_tokens enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'churches'
      and policyname = 'Public can read active churches'
  ) then
    create policy "Public can read active churches"
      on public.churches
      for select
      to anon, authenticated
      using (active = true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_payment_settings'
      and policyname = 'Public can read payment settings of active churches'
  ) then
    create policy "Public can read payment settings of active churches"
      on public.church_payment_settings
      for select
      to anon, authenticated
      using (
        exists (
          select 1
          from public.churches c
          where c.id = church_payment_settings.church_id
            and c.active = true
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
      and policyname = 'Public can read published announcements'
  ) then
    create policy "Public can read published announcements"
      on public.announcements
      for select
      to anon, authenticated
      using (
        published_at is not null
        and exists (
          select 1
          from public.churches c
          where c.id = announcements.church_id
            and c.active = true
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
      and policyname = 'Public can read events of active churches'
  ) then
    create policy "Public can read events of active churches"
      on public.events
      for select
      to anon, authenticated
      using (
        exists (
          select 1
          from public.churches c
          where c.id = events.church_id
            and c.active = true
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
      and policyname = 'Public can read active campaigns'
  ) then
    create policy "Public can read active campaigns"
      on public.donation_campaigns
      for select
      to anon, authenticated
      using (
        active = true
        and exists (
          select 1
          from public.churches c
          where c.id = donation_campaigns.church_id
            and c.active = true
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
      and policyname = 'Users can read own profile'
  ) then
    create policy "Users can read own profile"
      on public.profiles
      for select
      to authenticated
      using (auth.uid() = id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'Users can update own profile'
  ) then
    create policy "Users can update own profile"
      on public.profiles
      for update
      to authenticated
      using (auth.uid() = id)
      with check (auth.uid() = id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'memberships'
      and policyname = 'Users can read own memberships'
  ) then
    create policy "Users can read own memberships"
      on public.memberships
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
      and tablename = 'prayer_requests'
      and policyname = 'Users can manage own prayer requests'
  ) then
    create policy "Users can manage own prayer requests"
      on public.prayer_requests
      for all
      to authenticated
      using (auth.uid() = profile_id)
      with check (auth.uid() = profile_id);
  end if;
end $$;

alter table public.memberships
  add column if not exists member_code text,
  add column if not exists baptism_date date;

create unique index if not exists idx_memberships_church_member_code_unique
  on public.memberships (church_id, upper(member_code))
  where member_code is not null;

create or replace function public.generate_member_code(
  p_church_id uuid
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  church_prefix text;
  candidate text;
begin
  select coalesce(
    nullif(regexp_replace(upper(coalesce(join_code, slug)), '[^A-Z0-9]', '', 'g'), ''),
    'MEM'
  )
  into church_prefix
  from public.churches
  where id = p_church_id
  limit 1;

  church_prefix := substr(coalesce(church_prefix, 'MEM'), 1, 3);

  loop
    candidate := church_prefix || '-' || lpad(((random() * 99999)::int)::text, 5, '0');
    exit when not exists (
      select 1
      from public.memberships
      where church_id = p_church_id
        and upper(member_code) = upper(candidate)
    );
  end loop;

  return candidate;
end;
$$;

create or replace function public.handle_membership_defaults()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.member_code is null or btrim(new.member_code) = '' then
    new.member_code := public.generate_member_code(new.church_id);
  end if;

  return new;
end;
$$;

drop trigger if exists handle_membership_defaults on public.memberships;
create trigger handle_membership_defaults
  before insert or update of church_id, member_code
  on public.memberships
  for each row execute procedure public.handle_membership_defaults();

update public.memberships
set member_code = public.generate_member_code(church_id)
where member_code is null
   or btrim(member_code) = '';

alter table public.prayer_requests
  add column if not exists visibility text not null default 'private',
  add column if not exists anonymous_request boolean not null default false,
  add column if not exists allow_responses boolean not null default true;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'prayer_requests_visibility_check'
  ) then
    alter table public.prayer_requests
      add constraint prayer_requests_visibility_check
      check (visibility in ('private', 'public', 'anonymous'));
  end if;
end $$;

update public.prayer_requests
set
  visibility = case
    when is_private then 'private'
    else 'public'
  end,
  anonymous_request = false
where visibility not in ('private', 'public', 'anonymous')
   or (visibility = 'private' and is_private = false);

create table if not exists public.prayer_request_responses (
  id uuid primary key default gen_random_uuid(),
  prayer_request_id uuid not null references public.prayer_requests(id) on delete cascade,
  church_id uuid not null references public.churches(id) on delete cascade,
  responder_profile_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_prayer_request_responses_request_id
  on public.prayer_request_responses(prayer_request_id);

create index if not exists idx_prayer_request_responses_church_id
  on public.prayer_request_responses(church_id);

create or replace function public.handle_prayer_response_defaults()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select church_id
  into new.church_id
  from public.prayer_requests
  where id = new.prayer_request_id
  limit 1;

  if new.church_id is null then
    raise exception 'Prayer request not found.';
  end if;

  return new;
end;
$$;

drop trigger if exists handle_prayer_response_defaults on public.prayer_request_responses;
create trigger handle_prayer_response_defaults
  before insert or update of prayer_request_id
  on public.prayer_request_responses
  for each row execute procedure public.handle_prayer_response_defaults();

grant select, insert, delete on public.prayer_request_responses to authenticated;

alter table public.prayer_request_responses enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'prayer_requests'
      and policyname = 'Members can read public prayer requests in own church'
  ) then
    create policy "Members can read public prayer requests in own church"
      on public.prayer_requests
      for select
      to authenticated
      using (
        visibility in ('public', 'anonymous')
        and public.has_church_role(
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
      and tablename = 'prayer_request_responses'
      and policyname = 'Members can read accessible prayer responses'
  ) then
    create policy "Members can read accessible prayer responses"
      on public.prayer_request_responses
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.prayer_requests request
          where request.id = prayer_request_responses.prayer_request_id
            and request.church_id = prayer_request_responses.church_id
            and (
              auth.uid() = request.profile_id
              or public.has_church_role(
                request.church_id,
                array['leader', 'pastor', 'church_admin']::text[]
              )
              or (
                request.visibility in ('public', 'anonymous')
                and public.has_church_role(
                  request.church_id,
                  array['member', 'leader', 'pastor', 'church_admin']::text[]
                )
              )
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
      and tablename = 'prayer_request_responses'
      and policyname = 'Members can create prayer responses in own church'
  ) then
    create policy "Members can create prayer responses in own church"
      on public.prayer_request_responses
      for insert
      to authenticated
      with check (
        auth.uid() = responder_profile_id
        and exists (
          select 1
          from public.prayer_requests request
          where request.id = prayer_request_responses.prayer_request_id
            and request.church_id = prayer_request_responses.church_id
            and coalesce(request.allow_responses, true)
            and (
              auth.uid() = request.profile_id
              or public.has_church_role(
                request.church_id,
                array['leader', 'pastor', 'church_admin']::text[]
              )
              or (
                request.visibility in ('public', 'anonymous')
                and public.has_church_role(
                  request.church_id,
                  array['member', 'leader', 'pastor', 'church_admin']::text[]
                )
              )
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
      and tablename = 'prayer_request_responses'
      and policyname = 'Users can delete own prayer responses'
  ) then
    create policy "Users can delete own prayer responses"
      on public.prayer_request_responses
      for delete
      to authenticated
      using (
        auth.uid() = responder_profile_id
        or public.has_church_role(
          church_id,
          array['leader', 'pastor', 'church_admin']::text[]
        )
      );
  end if;
end $$;

alter table public.event_registrations
  add column if not exists checked_in_at timestamptz,
  add column if not exists check_in_code text;

create unique index if not exists idx_event_registrations_check_in_code_unique
  on public.event_registrations (upper(check_in_code))
  where check_in_code is not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'event_registrations_status_check'
  ) then
    alter table public.event_registrations
      add constraint event_registrations_status_check
      check (status in ('confirmed', 'checked_in', 'cancelled'));
  end if;
end $$;

create or replace function public.generate_event_check_in_code(
  p_event_id uuid,
  p_profile_id uuid
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  event_prefix text;
  candidate text;
begin
  select coalesce(
    nullif(regexp_replace(upper(coalesce(ch.join_code, ch.slug)), '[^A-Z0-9]', '', 'g'), ''),
    'EVT'
  )
  into event_prefix
  from public.events evt
  join public.churches ch
    on ch.id = evt.church_id
  where evt.id = p_event_id
  limit 1;

  event_prefix := substr(coalesce(event_prefix, 'EVT'), 1, 4);

  loop
    candidate := event_prefix
      || '-'
      || substr(replace(p_profile_id::text, '-', ''), 1, 4)
      || '-'
      || lpad(((random() * 9999)::int)::text, 4, '0');
    exit when not exists (
      select 1
      from public.event_registrations
      where upper(check_in_code) = upper(candidate)
    );
  end loop;

  return candidate;
end;
$$;

create or replace function public.handle_event_registration_defaults()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.check_in_code is null or btrim(new.check_in_code) = '' then
    new.check_in_code := public.generate_event_check_in_code(
      new.event_id,
      new.profile_id
    );
  end if;

  if new.checked_in_at is not null then
    new.status := 'checked_in';
  elsif new.status not in ('confirmed', 'checked_in', 'cancelled') then
    new.status := 'confirmed';
  end if;

  return new;
end;
$$;

drop trigger if exists handle_event_registration_defaults on public.event_registrations;
create trigger handle_event_registration_defaults
  before insert or update of event_id, profile_id, checked_in_at, check_in_code, status
  on public.event_registrations
  for each row execute procedure public.handle_event_registration_defaults();

update public.event_registrations
set check_in_code = public.generate_event_check_in_code(event_id, profile_id)
where check_in_code is null
   or btrim(check_in_code) = '';

grant select on public.event_registrations to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'event_registrations'
      and policyname = 'Users can read own event registrations'
  ) then
    create policy "Users can read own event registrations"
      on public.event_registrations
      for select
      to authenticated
      using (auth.uid() = profile_id);
  end if;
end $$;

create or replace function public.register_for_event(
  p_event_id uuid
)
returns public.event_registrations
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  attendee_count integer;
  registration_row public.event_registrations%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  select *
  into event_row
  from public.events
  where id = p_event_id
  limit 1;

  if event_row.id is null then
    raise exception 'Event not found.';
  end if;

  if not exists (
    select 1
    from public.memberships
    where church_id = event_row.church_id
      and profile_id = auth.uid()
      and status = 'active'
  ) then
    raise exception 'Only active members of this church can register for events.';
  end if;

  if event_row.capacity is not null then
    select count(*)
    into attendee_count
    from public.event_registrations
    where event_id = p_event_id
      and status in ('confirmed', 'checked_in');

    if attendee_count >= event_row.capacity and not exists (
      select 1
      from public.event_registrations
      where event_id = p_event_id
        and profile_id = auth.uid()
    ) then
      raise exception 'Event capacity reached.';
    end if;
  end if;

  insert into public.event_registrations (
    event_id,
    profile_id,
    status,
    checked_in_at
  )
  values (
    p_event_id,
    auth.uid(),
    'confirmed',
    null
  )
  on conflict (event_id, profile_id) do update
    set
      status = 'confirmed',
      checked_in_at = null
  returning *
  into registration_row;

  return registration_row;
end;
$$;

create or replace function public.cancel_event_registration(
  p_event_id uuid
)
returns public.event_registrations
language plpgsql
security definer
set search_path = public
as $$
declare
  registration_row public.event_registrations%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  update public.event_registrations
  set
    status = 'cancelled',
    checked_in_at = null
  where event_id = p_event_id
    and profile_id = auth.uid()
  returning *
  into registration_row;

  if registration_row.id is null then
    raise exception 'Registration not found.';
  end if;

  return registration_row;
end;
$$;

create or replace function public.check_in_to_event(
  p_registration_id uuid
)
returns public.event_registrations
language plpgsql
security definer
set search_path = public
as $$
declare
  registration_row public.event_registrations%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  update public.event_registrations
  set
    status = 'checked_in',
    checked_in_at = coalesce(checked_in_at, now())
  where id = p_registration_id
    and profile_id = auth.uid()
  returning *
  into registration_row;

  if registration_row.id is null then
    raise exception 'Registration not found.';
  end if;

  return registration_row;
end;
$$;

grant execute on function public.register_for_event(uuid) to authenticated;
grant execute on function public.cancel_event_registration(uuid) to authenticated;
grant execute on function public.check_in_to_event(uuid) to authenticated;

create or replace function public.get_church_birthdays(
  p_church_id uuid,
  p_limit integer default 6
)
returns table (
  profile_id uuid,
  full_name text,
  role text,
  birth_date date,
  next_birthday date
)
language sql
security definer
stable
set search_path = public
as $$
  with allowed as (
    select public.has_church_role(
      p_church_id,
      array['member', 'leader', 'pastor', 'church_admin']::text[]
    ) as ok
  )
  select
    p.id as profile_id,
    p.full_name,
    m.role,
    p.birth_date,
    case
      when make_date(
        extract(year from current_date)::int,
        extract(month from p.birth_date)::int,
        least(
          extract(day from p.birth_date)::int,
          extract(day from (date_trunc('month', make_date(
            extract(year from current_date)::int,
            extract(month from p.birth_date)::int,
            1
          ) + interval '1 month - 1 day'))::date)::int
        )
      ) >= current_date
        then make_date(
          extract(year from current_date)::int,
          extract(month from p.birth_date)::int,
          least(
            extract(day from p.birth_date)::int,
            extract(day from (date_trunc('month', make_date(
              extract(year from current_date)::int,
              extract(month from p.birth_date)::int,
              1
            ) + interval '1 month - 1 day'))::date)::int
          )
        )
      else make_date(
        extract(year from current_date)::int + 1,
        extract(month from p.birth_date)::int,
        least(
          extract(day from p.birth_date)::int,
          extract(day from (date_trunc('month', make_date(
            extract(year from current_date)::int + 1,
            extract(month from p.birth_date)::int,
            1
          ) + interval '1 month - 1 day'))::date)::int
        )
      )
    end as next_birthday
  from public.memberships m
  join public.profiles p
    on p.id = m.profile_id
  cross join allowed
  where allowed.ok = true
    and m.church_id = p_church_id
    and m.status = 'active'
    and p.birth_date is not null
  order by next_birthday, p.full_name
  limit greatest(coalesce(p_limit, 6), 1);
$$;

grant execute on function public.get_church_birthdays(uuid, integer) to authenticated;

create table if not exists public.church_communications (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  channel text not null default 'push',
  audience_type text not null default 'all',
  target_role text,
  ministry_id uuid references public.church_ministries(id) on delete set null,
  membership_id uuid references public.memberships(id) on delete set null,
  title text not null,
  body text not null,
  status text not null default 'draft',
  scheduled_at timestamptz,
  sent_at timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_communications_channel_check'
  ) then
    alter table public.church_communications
      add constraint church_communications_channel_check
      check (channel in ('push', 'sms', 'whatsapp', 'email'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_communications_audience_type_check'
  ) then
    alter table public.church_communications
      add constraint church_communications_audience_type_check
      check (audience_type in ('all', 'group', 'ministry', 'person'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_communications_status_check'
  ) then
    alter table public.church_communications
      add constraint church_communications_status_check
      check (status in ('draft', 'queued', 'sent', 'failed', 'cancelled'));
  end if;
end $$;

create index if not exists idx_church_communications_church_id
  on public.church_communications(church_id);

create index if not exists idx_church_communications_status
  on public.church_communications(status);

grant select, insert, update, delete on public.church_communications to authenticated;

alter table public.church_communications enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_communications'
      and policyname = 'Members can read church communications in own church'
  ) then
    create policy "Members can read church communications in own church"
      on public.church_communications
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
      and tablename = 'church_communications'
      and policyname = 'Church admins can manage communications in own church'
  ) then
    create policy "Church admins can manage communications in own church"
      on public.church_communications
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

alter table public.events add column if not exists event_type text not null default 'culto';

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
      check (item_condition in ('new', 'good', 'fair', 'needs_repair', 'retired'));
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

create index if not exists idx_church_ministries_church_id on public.church_ministries(church_id);
create index if not exists idx_ministry_members_ministry_id on public.ministry_members(ministry_id);
create index if not exists idx_ministry_members_membership_id on public.ministry_members(membership_id);
create index if not exists idx_church_assets_church_id on public.church_assets(church_id);
create index if not exists idx_church_visitors_church_id on public.church_visitors(church_id);
create index if not exists idx_church_expenses_church_id on public.church_expenses(church_id);

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
      check (
        role in (
          'super_admin',
          'finance',
          'support_agent',
          'marketing',
          'developer',
          'auditor'
        )
      );
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

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'push_tokens'
      and policyname = 'Users can manage own push tokens'
  ) then
    create policy "Users can manage own push tokens"
      on public.push_tokens
      for all
      to authenticated
      using (auth.uid() = profile_id)
      with check (auth.uid() = profile_id);
  end if;
end $$;
