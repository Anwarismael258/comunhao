alter table public.events
  add column if not exists allow_waiting_list boolean not null default true,
  add column if not exists paid_checkout_provider text,
  add column if not exists paid_checkout_url text,
  add column if not exists recurrence_edit_scope text not null default 'series';

alter table public.event_registrations
  add column if not exists waiting_list_position integer,
  add column if not exists promoted_at timestamptz;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'events_recurrence_edit_scope_check'
  ) then
    alter table public.events
      drop constraint events_recurrence_edit_scope_check;
  end if;
end $$;

alter table public.events
  add constraint events_recurrence_edit_scope_check
  check (recurrence_edit_scope in ('occurrence', 'future', 'series')) not valid;

create table if not exists public.event_reminders (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  occurrence_id uuid references public.event_occurrences(id) on delete cascade,
  church_id uuid not null references public.churches(id) on delete cascade,
  channel text not null default 'internal',
  audience text not null default 'members',
  scheduled_for timestamptz not null,
  status text not null default 'queued',
  provider_status text not null default 'internal_only',
  created_by uuid references public.profiles(id),
  sent_at timestamptz,
  error_message text,
  created_at timestamptz not null default now(),
  unique (event_id, occurrence_id, channel, audience, scheduled_for)
);

alter table public.event_reminders enable row level security;

drop policy if exists "Calendar managers can manage event reminders" on public.event_reminders;
create policy "Calendar managers can manage event reminders"
  on public.event_reminders
  for all
  to authenticated
  using (public.user_has_calendar_permission(church_id, 'calendar.edit', auth.uid()))
  with check (public.user_has_calendar_permission(church_id, 'calendar.edit', auth.uid()));

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

  if new.attendee_count is null or new.attendee_count < 1 then
    new.attendee_count := 1;
  end if;

  if new.checked_in_at is not null then
    new.status := 'checked_in';
  elsif new.status not in (
    'registered',
    'waiting_list',
    'confirmed',
    'cancelled',
    'checked_in',
    'no_show'
  ) then
    new.status := 'confirmed';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

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
  occupied_count integer := 0;
  wait_count integer := 0;
  target_status text := 'confirmed';
  target_payment_status text := 'not_required';
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

  select *
  into registration_row
  from public.event_registrations
  where event_id = p_event_id
    and profile_id = auth.uid()
  limit 1;

  if registration_row.id is not null and registration_row.status <> 'cancelled' then
    return registration_row;
  end if;

  if event_row.payment_required = true
     or coalesce(event_row.registration_fee_mzn, 0) > 0 then
    target_payment_status := 'pending';
  end if;

  if event_row.capacity is not null then
    select coalesce(sum(coalesce(attendee_count, 1)), 0)
    into occupied_count
    from public.event_registrations
    where event_id = p_event_id
      and status in ('registered', 'confirmed', 'checked_in');

    if occupied_count >= event_row.capacity then
      if coalesce(event_row.allow_waiting_list, true) then
        select count(*)
        into wait_count
        from public.event_registrations
        where event_id = p_event_id
          and status = 'waiting_list';
        target_status := 'waiting_list';
      else
        raise exception 'Event capacity reached.';
      end if;
    end if;
  end if;

  insert into public.event_registrations (
    event_id,
    profile_id,
    status,
    payment_status,
    waiting_list_position,
    checked_in_at,
    cancelled_at
  )
  values (
    p_event_id,
    auth.uid(),
    target_status,
    target_payment_status,
    case when target_status = 'waiting_list' then wait_count + 1 else null end,
    null,
    null
  )
  on conflict (event_id, profile_id) do update
    set
      status = excluded.status,
      payment_status = excluded.payment_status,
      waiting_list_position = excluded.waiting_list_position,
      checked_in_at = null,
      cancelled_at = null,
      promoted_at = null
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
  event_row public.events%rowtype;
  registration_row public.event_registrations%rowtype;
  promoted_row public.event_registrations%rowtype;
  occupied_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  select *
  into event_row
  from public.events
  where id = p_event_id
  limit 1;

  update public.event_registrations
  set
    status = 'cancelled',
    checked_in_at = null,
    cancelled_at = now()
  where event_id = p_event_id
    and profile_id = auth.uid()
  returning *
  into registration_row;

  if registration_row.id is null then
    raise exception 'Registration not found.';
  end if;

  if event_row.capacity is not null then
    select coalesce(sum(coalesce(attendee_count, 1)), 0)
    into occupied_count
    from public.event_registrations
    where event_id = p_event_id
      and status in ('registered', 'confirmed', 'checked_in');

    if occupied_count < event_row.capacity then
      select *
      into promoted_row
      from public.event_registrations
      where event_id = p_event_id
        and status = 'waiting_list'
      order by waiting_list_position nulls last, created_at
      limit 1;

      if promoted_row.id is not null then
        update public.event_registrations
        set
          status = 'confirmed',
          waiting_list_position = null,
          promoted_at = now()
        where id = promoted_row.id;
      end if;
    end if;
  end if;

  return registration_row;
end;
$$;

create or replace function public.manual_child_check_in_event(
  p_event_id uuid,
  p_occurrence_id uuid default null,
  p_child_name text default null,
  p_guardian_name text default null,
  p_guardian_phone text default null,
  p_room_name text default null,
  p_notes text default null
)
returns public.child_checkins
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  occurrence_row public.event_occurrences%rowtype;
  child_row public.child_checkins%rowtype;
  code text;
begin
  select *
  into event_row
  from public.events
  where id = p_event_id;

  if not found then
    raise exception 'Event not found.';
  end if;

  if not public.user_has_calendar_permission(event_row.church_id, 'checkin.manage', auth.uid()) then
    raise exception 'You cannot manage child check-in for this event.';
  end if;

  if nullif(trim(coalesce(p_child_name, '')), '') is null then
    raise exception 'Child name is required.';
  end if;

  perform public.generate_event_occurrences(p_event_id, event_row.starts_at + interval '1 day');

  if p_occurrence_id is not null then
    select *
    into occurrence_row
    from public.event_occurrences
    where id = p_occurrence_id
      and event_id = p_event_id;
  end if;

  if occurrence_row.id is null then
    select *
    into occurrence_row
    from public.event_occurrences
    where event_id = p_event_id
    order by abs(extract(epoch from (occurrence_start_at - now())))
    limit 1;
  end if;

  code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));

  insert into public.child_checkins (
    event_id,
    occurrence_id,
    church_id,
    child_name,
    guardian_name,
    guardian_phone,
    room_name,
    security_code,
    checked_in_by,
    notes_private
  )
  values (
    event_row.id,
    occurrence_row.id,
    event_row.church_id,
    trim(p_child_name),
    nullif(trim(coalesce(p_guardian_name, '')), ''),
    nullif(trim(coalesce(p_guardian_phone, '')), ''),
    nullif(trim(coalesce(p_room_name, '')), ''),
    code,
    auth.uid(),
    p_notes
  )
  returning *
  into child_row;

  insert into public.event_attendance (
    event_id,
    occurrence_id,
    church_id,
    participant_type,
    check_in_method,
    checked_in_by,
    notes
  )
  values (
    event_row.id,
    occurrence_row.id,
    event_row.church_id,
    'child',
    'manual',
    auth.uid(),
    concat_ws(' | ', trim(p_child_name), nullif(trim(coalesce(p_guardian_name, '')), ''), p_notes)
  );

  return child_row;
end;
$$;

create or replace function public.check_out_child_event(
  p_child_checkin_id uuid,
  p_security_code text,
  p_pickup_person text default null
)
returns public.child_checkins
language plpgsql
security definer
set search_path = public
as $$
declare
  child_row public.child_checkins%rowtype;
begin
  select *
  into child_row
  from public.child_checkins
  where id = p_child_checkin_id;

  if not found then
    raise exception 'Child check-in not found.';
  end if;

  if not public.user_has_calendar_permission(child_row.church_id, 'checkin.manage', auth.uid()) then
    raise exception 'You cannot manage child check-out.';
  end if;

  if upper(trim(coalesce(p_security_code, ''))) <> upper(child_row.security_code) then
    raise exception 'Invalid pickup code.';
  end if;

  update public.child_checkins
  set
    checked_out_at = coalesce(checked_out_at, now()),
    checked_out_by = auth.uid(),
    pickup_person = nullif(trim(coalesce(p_pickup_person, '')), '')
  where id = p_child_checkin_id
  returning *
  into child_row;

  return child_row;
end;
$$;

create or replace function public.prepare_event_internal_reminders(
  p_church_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer := 0;
begin
  if not public.user_has_calendar_permission(p_church_id, 'calendar.edit', auth.uid()) then
    raise exception 'You cannot prepare reminders for this church.';
  end if;

  insert into public.event_reminders (
    event_id,
    occurrence_id,
    church_id,
    channel,
    audience,
    scheduled_for,
    status,
    provider_status,
    created_by
  )
  select
    eo.event_id,
    eo.id,
    eo.church_id,
    'internal',
    'members',
    eo.occurrence_start_at - interval '1 day',
    'queued',
    'internal_only',
    auth.uid()
  from public.event_occurrences eo
  join public.events e
    on e.id = eo.event_id
  where eo.church_id = p_church_id
    and eo.occurrence_start_at between now() and now() + interval '30 days'
    and e.status in ('published', 'scheduled', 'ongoing')
  on conflict do nothing;

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

grant select, insert, update on public.event_reminders to authenticated;
grant execute on function public.manual_child_check_in_event(uuid, uuid, text, text, text, text, text) to authenticated;
grant execute on function public.check_out_child_event(uuid, text, text) to authenticated;
grant execute on function public.prepare_event_internal_reminders(uuid) to authenticated;
