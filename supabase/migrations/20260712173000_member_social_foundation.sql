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
