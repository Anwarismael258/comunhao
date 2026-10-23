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
