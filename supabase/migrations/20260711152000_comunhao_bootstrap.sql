create extension if not exists pgcrypto;

create table if not exists public.churches (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
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

alter table public.churches add column if not exists app_name text;
alter table public.churches add column if not exists tagline text;
alter table public.churches add column if not exists hero_title text;
alter table public.churches add column if not exists hero_subtitle text;
alter table public.churches add column if not exists default_currency text not null default 'MZN';

create table if not exists public.profiles (
  id uuid primary key,
  full_name text not null,
  phone text,
  email text,
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.memberships (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  unique (church_id, profile_id)
);

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

grant usage on schema public to anon, authenticated;
grant select on public.churches to anon, authenticated;
grant select on public.church_payment_settings to anon, authenticated;
grant select on public.announcements to anon, authenticated;
grant select on public.events to anon, authenticated;
grant select on public.donation_campaigns to anon, authenticated;

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
    select 1
    from pg_policies
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
    select 1
    from pg_policies
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
    select 1
    from pg_policies
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
    select 1
    from pg_policies
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
    select 1
    from pg_policies
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
