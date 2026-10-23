alter table public.events
  add column if not exists category text,
  add column if not exists status text not null default 'published',
  add column if not exists timezone text not null default 'Africa/Maputo',
  add column if not exists location_name text,
  add column if not exists address text,
  add column if not exists latitude numeric(10,7),
  add column if not exists longitude numeric(10,7),
  add column if not exists online_url text,
  add column if not exists responsible_user_id uuid references public.profiles(id),
  add column if not exists speaker_name text,
  add column if not exists guest_name text,
  add column if not exists organizer_name text,
  add column if not exists program text,
  add column if not exists requirements text,
  add column if not exists registration_fee_mzn numeric(12,2) not null default 0,
  add column if not exists payment_required boolean not null default false,
  add column if not exists attendance_required boolean not null default false,
  add column if not exists is_public boolean not null default true,
  add column if not exists visibility text not null default 'members',
  add column if not exists recurrence_rule text,
  add column if not exists recurrence_parent_id uuid references public.events(id) on delete set null,
  add column if not exists registration_deadline timestamptz,
  add column if not exists checkin_opens_at timestamptz,
  add column if not exists checkin_closes_at timestamptz,
  add column if not exists cover_image_url text,
  add column if not exists ministry_id uuid references public.church_ministries(id) on delete set null,
  add column if not exists cancellation_reason text,
  add column if not exists is_featured boolean not null default false,
  add column if not exists is_demo boolean not null default false,
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists updated_at timestamptz not null default now();

update public.events
set
  category = coalesce(category, event_type, 'service'),
  status = coalesce(status, 'published'),
  location_name = coalesce(location_name, location),
  checkin_opens_at = coalesce(checkin_opens_at, starts_at - interval '2 hours'),
  checkin_closes_at = coalesce(checkin_closes_at, coalesce(ends_at, starts_at + interval '3 hours')),
  updated_at = now()
where category is null
   or location_name is null
   or checkin_opens_at is null
   or checkin_closes_at is null;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'events_event_type_check'
  ) then
    alter table public.events
      drop constraint events_event_type_check;
  end if;
end $$;

alter table public.events
  add constraint events_event_type_check
  check (
    event_type in (
      'service',
      'event',
      'internal_meeting',
      'personal_agenda',
      'culto',
      'congresso',
      'vigilia',
      'batismo',
      'casamento',
      'conferencia',
      'ensaio',
      'reuniao',
      'seminario',
      'retiro',
      'acao_social',
      'formacao',
      'concerto',
      'visita'
    )
  ) not valid;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'events_status_check'
  ) then
    alter table public.events
      drop constraint events_status_check;
  end if;
end $$;

alter table public.events
  add constraint events_status_check
  check (
    status in (
      'draft',
      'scheduled',
      'published',
      'ongoing',
      'completed',
      'cancelled',
      'postponed',
      'archived'
    )
  ) not valid;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'events_visibility_check'
  ) then
    alter table public.events
      drop constraint events_visibility_check;
  end if;
end $$;

alter table public.events
  add constraint events_visibility_check
  check (
    visibility in (
      'all',
      'members',
      'visitors',
      'leaders',
      'pastors',
      'ministry',
      'selected_users',
      'private'
    )
  ) not valid;

create index if not exists idx_events_church_status_start
  on public.events(church_id, status, starts_at);

create index if not exists idx_events_church_type_start
  on public.events(church_id, event_type, starts_at);

create index if not exists idx_events_ministry_start
  on public.events(ministry_id, starts_at)
  where ministry_id is not null;

alter table public.event_registrations
  add column if not exists occurrence_id uuid,
  add column if not exists attendee_count integer not null default 1,
  add column if not exists special_needs text,
  add column if not exists payment_status text not null default 'not_required',
  add column if not exists cancelled_at timestamptz,
  add column if not exists checked_in_by uuid references public.profiles(id),
  add column if not exists check_in_method text,
  add column if not exists check_out_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'event_registrations_status_check'
  ) then
    alter table public.event_registrations
      drop constraint event_registrations_status_check;
  end if;
end $$;

alter table public.event_registrations
  add constraint event_registrations_status_check
  check (
    status in (
      'registered',
      'waiting_list',
      'confirmed',
      'cancelled',
      'checked_in',
      'no_show'
    )
  ) not valid;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'event_registrations_payment_status_check'
  ) then
    alter table public.event_registrations
      drop constraint event_registrations_payment_status_check;
  end if;
end $$;

alter table public.event_registrations
  add constraint event_registrations_payment_status_check
  check (
    payment_status in (
      'not_required',
      'pending',
      'confirmed',
      'failed',
      'refunded'
    )
  ) not valid;

create table if not exists public.event_occurrences (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  church_id uuid not null references public.churches(id) on delete cascade,
  occurrence_start_at timestamptz not null,
  occurrence_end_at timestamptz,
  status text not null default 'scheduled',
  checkin_opens_at timestamptz,
  checkin_closes_at timestamptz,
  qr_token_hash text,
  qr_expires_at timestamptz,
  qr_closed_at timestamptz,
  override_title text,
  override_location text,
  cancellation_reason text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (event_id, occurrence_start_at)
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'event_registrations_occurrence_id_fkey'
  ) then
    alter table public.event_registrations
      add constraint event_registrations_occurrence_id_fkey
      foreign key (occurrence_id)
      references public.event_occurrences(id)
      on delete set null;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'event_occurrences_status_check'
  ) then
    alter table public.event_occurrences
      add constraint event_occurrences_status_check
      check (
        status in (
          'scheduled',
          'ongoing',
          'completed',
          'cancelled',
          'postponed',
          'archived'
        )
      );
  end if;
end $$;

create index if not exists idx_event_occurrences_church_start
  on public.event_occurrences(church_id, occurrence_start_at);

create table if not exists public.event_attendance (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  occurrence_id uuid references public.event_occurrences(id) on delete cascade,
  church_id uuid not null references public.churches(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete set null,
  visitor_id uuid references public.church_visitors(id) on delete set null,
  registration_id uuid references public.event_registrations(id) on delete set null,
  participant_type text not null default 'member',
  check_in_method text not null default 'manual',
  checked_in_at timestamptz not null default now(),
  checked_out_at timestamptz,
  checked_in_by uuid references public.profiles(id),
  status text not null default 'checked_in',
  notes text,
  is_first_visit boolean not null default false,
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'event_attendance_participant_type_check'
  ) then
    alter table public.event_attendance
      add constraint event_attendance_participant_type_check
      check (participant_type in ('member', 'visitor', 'child', 'leader', 'guest'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'event_attendance_method_check'
  ) then
    alter table public.event_attendance
      add constraint event_attendance_method_check
      check (check_in_method in ('qr', 'manual', 'code', 'imported'));
  end if;
end $$;

create unique index if not exists idx_event_attendance_profile_once
  on public.event_attendance(event_id, coalesce(occurrence_id, '00000000-0000-0000-0000-000000000000'::uuid), profile_id)
  where profile_id is not null and status = 'checked_in';

create unique index if not exists idx_event_attendance_visitor_once
  on public.event_attendance(event_id, coalesce(occurrence_id, '00000000-0000-0000-0000-000000000000'::uuid), visitor_id)
  where visitor_id is not null and status = 'checked_in';

create table if not exists public.event_change_history (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  church_id uuid not null references public.churches(id) on delete cascade,
  changed_by uuid references public.profiles(id),
  change_type text not null,
  reason text,
  old_values jsonb not null default '{}'::jsonb,
  new_values jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.birthday_messages (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_by uuid references public.profiles(id),
  message text not null,
  birthday_year integer not null,
  channel text not null default 'internal',
  status text not null default 'pending_internal',
  notification_id uuid references public.internal_notifications(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (church_id, profile_id, birthday_year, channel)
);

create table if not exists public.child_checkins (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  occurrence_id uuid references public.event_occurrences(id) on delete cascade,
  church_id uuid not null references public.churches(id) on delete cascade,
  child_name text not null,
  guardian_profile_id uuid references public.profiles(id) on delete set null,
  guardian_name text,
  guardian_phone text,
  room_name text,
  security_code text not null,
  checked_in_at timestamptz not null default now(),
  checked_out_at timestamptz,
  checked_in_by uuid references public.profiles(id),
  checked_out_by uuid references public.profiles(id),
  pickup_person text,
  notes_private text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function public.user_has_calendar_permission(
  p_church_id uuid,
  p_permission text,
  check_user uuid default auth.uid()
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select case
    when public.is_super_admin(coalesce(check_user, auth.uid())) then true
    when p_permission in (
      'calendar.view',
      'calendar.create',
      'calendar.edit',
      'calendar.cancel',
      'event.manage',
      'service.manage',
      'attendance.view',
      'attendance.manage',
      'checkin.manage',
      'birthday.view',
      'birthday.communicate'
    ) then public.has_church_role(
      p_church_id,
      array['pastor', 'church_admin', 'leader']::text[],
      coalesce(check_user, auth.uid())
    )
    else false
  end;
$$;

create or replace function public.can_view_event(
  p_event_id uuid,
  check_user uuid default auth.uid()
)
returns boolean
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  event_row public.events%rowtype;
begin
  select *
  into event_row
  from public.events
  where id = p_event_id;

  if not found then
    return false;
  end if;

  if event_row.status in ('draft', 'archived') then
    return public.user_has_calendar_permission(event_row.church_id, 'calendar.view', check_user);
  end if;

  if event_row.visibility in ('all', 'visitors') and event_row.is_public = true then
    return true;
  end if;

  if not exists (
    select 1
    from public.memberships membership
    where membership.church_id = event_row.church_id
      and membership.profile_id = coalesce(check_user, auth.uid())
      and membership.status = 'active'
  ) then
    return false;
  end if;

  if event_row.visibility in ('members', 'leaders', 'pastors') then
    return true;
  end if;

  if event_row.visibility = 'ministry' then
    return event_row.ministry_id is null
      or exists (
        select 1
        from public.ministry_members mm
        join public.memberships m on m.id = mm.membership_id
        where mm.ministry_id = event_row.ministry_id
          and m.profile_id = coalesce(check_user, auth.uid())
          and m.status = 'active'
      )
      or public.user_has_calendar_permission(event_row.church_id, 'calendar.view', check_user);
  end if;

  return public.user_has_calendar_permission(event_row.church_id, 'calendar.view', check_user);
end;
$$;

create or replace function public.generate_event_occurrences(
  p_event_id uuid,
  p_until timestamptz default now() + interval '90 days'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  cursor_start timestamptz;
  duration interval;
  created_count integer := 0;
  max_until timestamptz := least(coalesce(p_until, now() + interval '90 days'), now() + interval '370 days');
  frequency text;
begin
  select *
  into event_row
  from public.events
  where id = p_event_id;

  if not found then
    raise exception 'Event not found.';
  end if;

  duration := coalesce(event_row.ends_at, event_row.starts_at + interval '2 hours') - event_row.starts_at;
  cursor_start := event_row.starts_at;
  frequency := lower(coalesce(event_row.recurrence_rule, 'once'));

  loop
    exit when cursor_start > max_until;

    insert into public.event_occurrences (
      event_id,
      church_id,
      occurrence_start_at,
      occurrence_end_at,
      status,
      checkin_opens_at,
      checkin_closes_at,
      is_demo
    )
    values (
      event_row.id,
      event_row.church_id,
      cursor_start,
      cursor_start + duration,
      case when event_row.status in ('published', 'scheduled') then 'scheduled' else event_row.status end,
      cursor_start - interval '2 hours',
      cursor_start + duration + interval '1 hour',
      event_row.is_demo
    )
    on conflict (event_id, occurrence_start_at) do nothing;

    if found then
      created_count := created_count + 1;
    end if;

    if frequency in ('', 'once', 'none') then
      exit;
    elsif frequency like 'daily%' then
      cursor_start := cursor_start + interval '1 day';
    elsif frequency like 'biweekly%' or frequency like 'fortnightly%' then
      cursor_start := cursor_start + interval '14 days';
    elsif frequency like 'monthly%' then
      cursor_start := cursor_start + interval '1 month';
    else
      cursor_start := cursor_start + interval '7 days';
    end if;
  end loop;

  return created_count;
end;
$$;

create or replace function public.open_event_checkin(
  p_occurrence_id uuid,
  p_duration_minutes integer default 180
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  occurrence_row public.event_occurrences%rowtype;
  raw_token text;
begin
  select *
  into occurrence_row
  from public.event_occurrences
  where id = p_occurrence_id
  for update;

  if not found then
    raise exception 'Occurrence not found.';
  end if;

  if not public.user_has_calendar_permission(occurrence_row.church_id, 'checkin.manage', auth.uid()) then
    raise exception 'You cannot open check-in for this event.';
  end if;

  raw_token := encode(gen_random_bytes(24), 'hex');

  update public.event_occurrences
  set
    qr_token_hash = encode(digest(raw_token, 'sha256'), 'hex'),
    qr_expires_at = now() + make_interval(mins => greatest(coalesce(p_duration_minutes, 180), 5)),
    qr_closed_at = null,
    checkin_opens_at = now(),
    checkin_closes_at = now() + make_interval(mins => greatest(coalesce(p_duration_minutes, 180), 5)),
    status = 'ongoing',
    updated_at = now()
  where id = p_occurrence_id;

  return occurrence_row.id::text || ':' || raw_token;
end;
$$;

create or replace function public.close_event_checkin(
  p_occurrence_id uuid
)
returns public.event_occurrences
language plpgsql
security definer
set search_path = public
as $$
declare
  occurrence_row public.event_occurrences%rowtype;
begin
  select *
  into occurrence_row
  from public.event_occurrences
  where id = p_occurrence_id
  for update;

  if not found then
    raise exception 'Occurrence not found.';
  end if;

  if not public.user_has_calendar_permission(occurrence_row.church_id, 'checkin.manage', auth.uid()) then
    raise exception 'You cannot close check-in for this event.';
  end if;

  update public.event_occurrences
  set
    qr_closed_at = now(),
    qr_token_hash = null,
    qr_expires_at = null,
    updated_at = now()
  where id = p_occurrence_id
  returning * into occurrence_row;

  return occurrence_row;
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
begin
  raise exception 'Use check_in_event_with_token or manual_check_in_event.';
end;
$$;

create or replace function public.check_in_event_with_token(
  p_qr_payload text
)
returns public.event_attendance
language plpgsql
security definer
set search_path = public
as $$
declare
  occurrence_uuid uuid;
  raw_token text;
  occurrence_row public.event_occurrences%rowtype;
  registration_row public.event_registrations%rowtype;
  attendee public.event_attendance;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  occurrence_uuid := split_part(p_qr_payload, ':', 1)::uuid;
  raw_token := split_part(p_qr_payload, ':', 2);

  select *
  into occurrence_row
  from public.event_occurrences
  where id = occurrence_uuid
  for update;

  if not found then
    raise exception 'Occurrence not found.';
  end if;

  if occurrence_row.qr_closed_at is not null
    or occurrence_row.qr_expires_at is null
    or occurrence_row.qr_expires_at < now()
    or occurrence_row.qr_token_hash is distinct from encode(digest(raw_token, 'sha256'), 'hex') then
    raise exception 'Invalid or expired check-in token.';
  end if;

  if not exists (
    select 1
    from public.memberships
    where church_id = occurrence_row.church_id
      and profile_id = auth.uid()
      and status = 'active'
  ) then
    raise exception 'Only active members can check in.';
  end if;

  select *
  into registration_row
  from public.event_registrations
  where event_id = occurrence_row.event_id
    and profile_id = auth.uid()
  limit 1;

  if not found then
    insert into public.event_registrations (
      event_id,
      occurrence_id,
      profile_id,
      status,
      checked_in_at,
      check_in_method
    )
    values (
      occurrence_row.event_id,
      occurrence_row.id,
      auth.uid(),
      'checked_in',
      now(),
      'qr'
    )
    returning * into registration_row;
  else
    update public.event_registrations
    set
      occurrence_id = occurrence_row.id,
      status = 'checked_in',
      checked_in_at = coalesce(checked_in_at, now()),
      check_in_method = 'qr',
      updated_at = now()
    where id = registration_row.id
    returning * into registration_row;
  end if;

  insert into public.event_attendance (
    event_id,
    occurrence_id,
    church_id,
    profile_id,
    registration_id,
    participant_type,
    check_in_method,
    checked_in_at,
    status
  )
  values (
    occurrence_row.event_id,
    occurrence_row.id,
    occurrence_row.church_id,
    auth.uid(),
    registration_row.id,
    'member',
    'qr',
    now(),
    'checked_in'
  )
  on conflict do nothing;

  select *
  into attendee
  from public.event_attendance
  where event_id = occurrence_row.event_id
    and occurrence_id = occurrence_row.id
    and profile_id = auth.uid()
  limit 1;

  return attendee;
end;
$$;

create or replace function public.manual_check_in_event(
  p_event_id uuid,
  p_profile_id uuid default null,
  p_visitor_name text default null,
  p_visitor_phone text default null,
  p_notes text default null
)
returns public.event_attendance
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  occurrence_row public.event_occurrences%rowtype;
  visitor_row public.church_visitors%rowtype;
  attendee public.event_attendance;
begin
  select *
  into event_row
  from public.events
  where id = p_event_id;

  if not found then
    raise exception 'Event not found.';
  end if;

  if not public.user_has_calendar_permission(event_row.church_id, 'attendance.manage', auth.uid()) then
    raise exception 'You cannot manage attendance for this event.';
  end if;

  perform public.generate_event_occurrences(p_event_id, event_row.starts_at + interval '1 day');

  select *
  into occurrence_row
  from public.event_occurrences
  where event_id = p_event_id
  order by abs(extract(epoch from (occurrence_start_at - now())))
  limit 1;

  if p_profile_id is null then
    if nullif(trim(coalesce(p_visitor_name, '')), '') is null then
      raise exception 'Visitor name is required for visitor check-in.';
    end if;

    insert into public.church_visitors (
      church_id,
      full_name,
      phone,
      status,
      first_visit_at,
      notes
    )
    values (
      event_row.church_id,
      trim(p_visitor_name),
      nullif(trim(coalesce(p_visitor_phone, '')), ''),
      'new',
      now(),
      p_notes
    )
    on conflict do nothing;

    select *
    into visitor_row
    from public.church_visitors
    where church_id = event_row.church_id
      and full_name = trim(p_visitor_name)
      and (
        p_visitor_phone is null
        or phone = nullif(trim(coalesce(p_visitor_phone, '')), '')
      )
    order by created_at desc
    limit 1;
  end if;

  insert into public.event_attendance (
    event_id,
    occurrence_id,
    church_id,
    profile_id,
    visitor_id,
    participant_type,
    check_in_method,
    checked_in_by,
    notes
  )
  values (
    event_row.id,
    occurrence_row.id,
    event_row.church_id,
    p_profile_id,
    visitor_row.id,
    case when p_profile_id is null then 'visitor' else 'member' end,
    'manual',
    auth.uid(),
    p_notes
  )
  on conflict do nothing;

  select *
  into attendee
  from public.event_attendance
  where event_id = event_row.id
    and coalesce(occurrence_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(occurrence_row.id, '00000000-0000-0000-0000-000000000000'::uuid)
    and (
      (p_profile_id is not null and profile_id = p_profile_id)
      or (p_profile_id is null and visitor_id = visitor_row.id)
    )
  limit 1;

  return attendee;
end;
$$;

create or replace function public.get_event_attendance_summary(
  p_event_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  result jsonb;
begin
  select *
  into event_row
  from public.events
  where id = p_event_id;

  if not found then
    raise exception 'Event not found.';
  end if;

  if not public.user_has_calendar_permission(event_row.church_id, 'attendance.view', auth.uid()) then
    raise exception 'You cannot view attendance for this event.';
  end if;

  select jsonb_build_object(
    'total', count(*),
    'members', count(*) filter (where participant_type in ('member', 'leader')),
    'visitors', count(*) filter (where participant_type = 'visitor'),
    'children', count(*) filter (where participant_type = 'child'),
    'manual', count(*) filter (where check_in_method = 'manual'),
    'qr', count(*) filter (where check_in_method = 'qr')
  )
  into result
  from public.event_attendance
  where event_id = p_event_id
    and status = 'checked_in';

  return coalesce(result, '{}'::jsonb);
end;
$$;

create or replace function public.get_visible_birthdays(
  p_church_id uuid,
  p_days integer default 31
)
returns table (
  profile_id uuid,
  full_name text,
  phone text,
  birth_date date,
  days_until integer
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_church_role(
    p_church_id,
    array['member', 'leader', 'pastor', 'church_admin']::text[],
    auth.uid()
  ) then
    raise exception 'You cannot view birthdays for this church.';
  end if;

  return query
  with birthday_base as (
    select
      profile.id,
      profile.full_name,
      profile.phone,
      profile.birth_date,
      make_date(
        extract(year from current_date)::int,
        extract(month from profile.birth_date)::int,
        least(
          extract(day from profile.birth_date)::int,
          extract(
            day from (
              date_trunc(
                'month',
                make_date(
                  extract(year from current_date)::int,
                  extract(month from profile.birth_date)::int,
                  1
                )
              ) + interval '1 month - 1 day'
            )
          )::int
        )
      ) as birthday_this_year
    from public.memberships membership
    join public.profiles profile on profile.id = membership.profile_id
    where membership.church_id = p_church_id
      and membership.status = 'active'
      and profile.birth_date is not null
  ),
  birthday_next as (
    select
      birthday_base.*,
      case
        when birthday_base.birthday_this_year < current_date
          then birthday_base.birthday_this_year + interval '1 year'
        else birthday_base.birthday_this_year
      end as next_birthday
    from birthday_base
  )
  select
    birthday_next.id,
    birthday_next.full_name,
    case
      when public.user_has_calendar_permission(p_church_id, 'birthday.view', auth.uid())
        then birthday_next.phone
      else null
    end as phone,
    birthday_next.birth_date,
    (birthday_next.next_birthday::date - current_date)::int as days_until
  from birthday_next
  order by days_until
  limit greatest(coalesce(p_days, 31), 1);
end;
$$;

create or replace function public.send_birthday_internal_message(
  p_church_id uuid,
  p_profile_id uuid,
  p_message text
)
returns public.birthday_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  notification_id uuid;
  result public.birthday_messages;
begin
  if not public.user_has_calendar_permission(p_church_id, 'birthday.communicate', auth.uid()) then
    raise exception 'You cannot send birthday messages for this church.';
  end if;

  if nullif(trim(coalesce(p_message, '')), '') is null then
    raise exception 'Message is required.';
  end if;

  notification_id := public.create_internal_notification(
    p_profile_id,
    'Feliz aniversario',
    trim(p_message),
    'birthday',
    p_church_id,
    auth.uid(),
    'normal',
    'profiles',
    p_profile_id,
    '/birthdays',
    '{}'::jsonb
  );

  insert into public.birthday_messages (
    church_id,
    profile_id,
    created_by,
    message,
    birthday_year,
    channel,
    status,
    notification_id
  )
  values (
    p_church_id,
    p_profile_id,
    auth.uid(),
    trim(p_message),
    extract(year from current_date)::int,
    'internal',
    'sent_internal',
    notification_id
  )
  on conflict (church_id, profile_id, birthday_year, channel) do update
    set message = excluded.message,
        notification_id = excluded.notification_id
  returning * into result;

  return result;
end;
$$;

create or replace function public.get_church_calendar_metrics()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin(auth.uid()) then
    raise exception 'Only super admins can view platform calendar metrics.';
  end if;

  return jsonb_build_object(
    'total_events', (select count(*) from public.events where is_demo = false),
    'total_services', (select count(*) from public.events where event_type in ('service', 'culto') and is_demo = false),
    'churches_with_activities', (select count(distinct church_id) from public.events where starts_at >= now() - interval '30 days' and is_demo = false),
    'cancelled_events', (select count(*) from public.events where status = 'cancelled' and is_demo = false),
    'future_occurrences', (select count(*) from public.event_occurrences where occurrence_start_at >= now() and is_demo = false),
    'checkins', (select count(*) from public.event_attendance where is_demo = false),
    'paid_events', (select count(*) from public.events where payment_required = true and is_demo = false)
  );
end;
$$;

create or replace function public.notify_event_relevant_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_OP = 'UPDATE' and (
    old.starts_at is distinct from new.starts_at
    or old.ends_at is distinct from new.ends_at
    or old.location_name is distinct from new.location_name
    or old.location is distinct from new.location
    or old.status is distinct from new.status
    or old.capacity is distinct from new.capacity
    or old.online_url is distinct from new.online_url
  ) then
    insert into public.event_change_history (
      event_id,
      church_id,
      changed_by,
      change_type,
      reason,
      old_values,
      new_values
    )
    values (
      new.id,
      new.church_id,
      auth.uid(),
      case when new.status = 'cancelled' then 'cancelled' else 'updated' end,
      new.cancellation_reason,
      to_jsonb(old),
      to_jsonb(new)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists notify_event_relevant_change on public.events;
create trigger notify_event_relevant_change
  after update on public.events
  for each row
  execute function public.notify_event_relevant_change();

create or replace function public.seed_vida_nova_calendar_demo()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  vida_id uuid;
  sara_id uuid;
  member_id uuid;
  sunday_event_id uuid;
  event_id uuid;
begin
  select id into vida_id from public.churches where lower(trim(name)) = 'vida nova' limit 1;
  sara_id := public.profile_id_by_phone('877688695');
  member_id := public.profile_id_by_phone('827688695');

  if vida_id is null then
    return jsonb_build_object('seeded', false, 'reason', 'Vida Nova not found');
  end if;

  delete from public.event_attendance where church_id = vida_id and is_demo = true;
  delete from public.event_occurrences where church_id = vida_id and is_demo = true;
  delete from public.events where church_id = vida_id and is_demo = true;

  insert into public.events (
    church_id,
    title,
    event_type,
    category,
    description,
    location,
    location_name,
    starts_at,
    ends_at,
    registration_required,
    attendance_required,
    capacity,
    status,
    visibility,
    is_public,
    recurrence_rule,
    speaker_name,
    responsible_user_id,
    is_featured,
    is_demo,
    created_by
  )
  values
    (vida_id, 'Culto Dominical', 'service', 'culto_dominical', 'Culto principal da Igreja Vida Nova.', 'Templo Vida Nova', 'Templo Vida Nova', date_trunc('week', now()) + interval '6 days 9 hours', date_trunc('week', now()) + interval '6 days 11 hours', false, true, 250, 'published', 'members', true, 'weekly', 'Sara', sara_id, true, true, sara_id),
    (vida_id, 'Culto de Oracao', 'service', 'culto_oracao', 'Noite de intercessao e palavra.', 'Templo Vida Nova', 'Templo Vida Nova', now() + interval '3 days 18 hours', now() + interval '3 days 20 hours', false, true, 120, 'published', 'members', true, null, 'Sara', sara_id, false, true, sara_id),
    (vida_id, 'Vigilia de Louvor', 'service', 'vigilia', 'Vigilia mensal de adoracao.', 'Templo Vida Nova', 'Templo Vida Nova', now() + interval '10 days 21 hours', now() + interval '11 days 1 hours', false, true, 180, 'published', 'members', true, null, 'Sara', sara_id, false, true, sara_id),
    (vida_id, 'Conferencia de Familias', 'event', 'conferencia', 'Conferencia para casais e familias.', 'Auditório Vida Nova', 'Auditório Vida Nova', now() + interval '14 days 15 hours', now() + interval '14 days 19 hours', true, true, 80, 'published', 'members', true, null, 'Convidado especial', sara_id, true, true, sara_id),
    (vida_id, 'Acao Social Escolar', 'event', 'acao_social', 'Apoio escolar para familias da comunidade.', 'Bairro Central', 'Bairro Central', now() + interval '21 days 8 hours', now() + interval '21 days 12 hours', true, true, 60, 'published', 'all', true, null, null, sara_id, false, true, sara_id),
    (vida_id, 'Reuniao de Lideres', 'internal_meeting', 'reuniao_lideres', 'Planeamento mensal dos ministerios.', 'Sala de Reunioes', 'Sala de Reunioes', now() + interval '5 days 18 hours', now() + interval '5 days 20 hours', false, true, 30, 'published', 'leaders', false, null, 'Sara', sara_id, false, true, sara_id),
    (vida_id, 'Ensaio do Coral', 'internal_meeting', 'ensaio', 'Preparacao do louvor de domingo.', 'Templo Vida Nova', 'Templo Vida Nova', now() + interval '2 days 17 hours', now() + interval '2 days 19 hours', false, true, 40, 'published', 'ministry', false, 'weekly', null, sara_id, false, true, sara_id),
    (vida_id, 'Transmissao Online - Palavra Pastoral', 'event', 'live_stream', 'Mensagem pastoral transmitida online.', null, 'Online', now() + interval '7 days 20 hours', now() + interval '7 days 21 hours', false, false, null, 'published', 'members', true, null, 'Sara', sara_id, false, true, sara_id)
  returning id into event_id;

  select id into sunday_event_id
  from public.events
  where church_id = vida_id and title = 'Culto Dominical' and is_demo = true
  limit 1;

  perform public.generate_event_occurrences(id, now() + interval '60 days')
  from public.events
  where church_id = vida_id and is_demo = true;

  if member_id is not null and sunday_event_id is not null then
    insert into public.event_registrations (
      event_id,
      profile_id,
      status,
      checked_in_at
    )
    values (
      sunday_event_id,
      member_id,
      'checked_in',
      now()
    )
    on conflict (event_id, profile_id) do update
      set status = 'checked_in',
          checked_in_at = coalesce(public.event_registrations.checked_in_at, now());

    perform public.manual_check_in_event(sunday_event_id, member_id, null, null, 'Seed demo Vida Nova');
  end if;

  return jsonb_build_object('seeded', true);
end;
$$;

select public.seed_vida_nova_calendar_demo();

alter table public.event_occurrences enable row level security;
alter table public.event_attendance enable row level security;
alter table public.event_change_history enable row level security;
alter table public.birthday_messages enable row level security;
alter table public.child_checkins enable row level security;

drop policy if exists "Public can read events of active churches" on public.events;
create policy "Public can read published visible events"
  on public.events
  for select
  to anon, authenticated
  using (
    status in ('scheduled', 'published', 'ongoing', 'completed')
    and is_public = true
    and visibility in ('all', 'visitors')
    and exists (
      select 1 from public.churches c
      where c.id = events.church_id and c.active = true
    )
  );

drop policy if exists "Members can read events for own church"
  on public.events;
create policy "Members can read visible events for own church"
  on public.events
  for select
  to authenticated
  using (public.can_view_event(id, auth.uid()));

drop policy if exists "Church admins can manage events in own church"
  on public.events;
create policy "Calendar managers can manage events in own church"
  on public.events
  for all
  to authenticated
  using (public.user_has_calendar_permission(church_id, 'calendar.edit', auth.uid()))
  with check (public.user_has_calendar_permission(church_id, 'calendar.edit', auth.uid()));

drop policy if exists "Members can read visible event occurrences" on public.event_occurrences;
create policy "Members can read visible event occurrences"
  on public.event_occurrences
  for select
  to authenticated
  using (public.can_view_event(event_id, auth.uid()));

drop policy if exists "Calendar managers can manage occurrences" on public.event_occurrences;
create policy "Calendar managers can manage occurrences"
  on public.event_occurrences
  for all
  to authenticated
  using (public.user_has_calendar_permission(church_id, 'calendar.edit', auth.uid()))
  with check (public.user_has_calendar_permission(church_id, 'calendar.edit', auth.uid()));

drop policy if exists "Users can read own attendance" on public.event_attendance;
create policy "Users can read own attendance"
  on public.event_attendance
  for select
  to authenticated
  using (
    profile_id = auth.uid()
    or public.user_has_calendar_permission(church_id, 'attendance.view', auth.uid())
  );

drop policy if exists "Attendance managers can manage attendance" on public.event_attendance;
create policy "Attendance managers can manage attendance"
  on public.event_attendance
  for all
  to authenticated
  using (public.user_has_calendar_permission(church_id, 'attendance.manage', auth.uid()))
  with check (public.user_has_calendar_permission(church_id, 'attendance.manage', auth.uid()));

drop policy if exists "Calendar managers can read change history" on public.event_change_history;
create policy "Calendar managers can read change history"
  on public.event_change_history
  for select
  to authenticated
  using (public.user_has_calendar_permission(church_id, 'calendar.view', auth.uid()));

drop policy if exists "Birthday messages visible to sender recipient and managers" on public.birthday_messages;
create policy "Birthday messages visible to sender recipient and managers"
  on public.birthday_messages
  for select
  to authenticated
  using (
    profile_id = auth.uid()
    or created_by = auth.uid()
    or public.user_has_calendar_permission(church_id, 'birthday.view', auth.uid())
  );

drop policy if exists "Birthday managers can create messages" on public.birthday_messages;
create policy "Birthday managers can create messages"
  on public.birthday_messages
  for insert
  to authenticated
  with check (public.user_has_calendar_permission(church_id, 'birthday.communicate', auth.uid()));

drop policy if exists "Child checkins only attendance managers" on public.child_checkins;
create policy "Child checkins only attendance managers"
  on public.child_checkins
  for all
  to authenticated
  using (public.user_has_calendar_permission(church_id, 'checkin.manage', auth.uid()))
  with check (public.user_has_calendar_permission(church_id, 'checkin.manage', auth.uid()));

grant select, insert, update on public.event_occurrences to authenticated;
grant select, insert, update on public.event_attendance to authenticated;
grant select on public.event_change_history to authenticated;
grant select, insert on public.birthday_messages to authenticated;
grant select, insert, update on public.child_checkins to authenticated;

grant execute on function public.user_has_calendar_permission(uuid, text, uuid) to authenticated;
grant execute on function public.can_view_event(uuid, uuid) to authenticated;
grant execute on function public.generate_event_occurrences(uuid, timestamptz) to authenticated;
grant execute on function public.open_event_checkin(uuid, integer) to authenticated;
grant execute on function public.close_event_checkin(uuid) to authenticated;
grant execute on function public.check_in_event_with_token(text) to authenticated;
grant execute on function public.manual_check_in_event(uuid, uuid, text, text, text) to authenticated;
grant execute on function public.get_event_attendance_summary(uuid) to authenticated;
grant execute on function public.get_visible_birthdays(uuid, integer) to authenticated;
grant execute on function public.send_birthday_internal_message(uuid, uuid, text) to authenticated;
grant execute on function public.get_church_calendar_metrics() to authenticated;

revoke execute on function public.seed_vida_nova_calendar_demo() from anon, authenticated, public;
