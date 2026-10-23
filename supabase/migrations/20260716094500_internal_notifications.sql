create table if not exists public.internal_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_profile_id uuid not null references public.profiles(id) on delete cascade,
  church_id uuid references public.churches(id) on delete cascade,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  title text not null,
  message text not null,
  notification_type text not null,
  priority text not null default 'normal',
  reference_table text,
  reference_id uuid,
  action_route text,
  delivery_status text not null default 'queued',
  read_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists idx_internal_notifications_recipient_created
  on public.internal_notifications(recipient_profile_id, created_at desc);

create index if not exists idx_internal_notifications_unread
  on public.internal_notifications(recipient_profile_id, read_at)
  where read_at is null and archived_at is null;

create unique index if not exists idx_internal_notifications_dedupe
  on public.internal_notifications(
    recipient_profile_id,
    notification_type,
    reference_table,
    reference_id
  )
  where reference_table is not null
    and reference_id is not null
    and archived_at is null;

create table if not exists public.notification_preferences (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  internal_enabled boolean not null default true,
  push_enabled boolean not null default true,
  sms_enabled boolean not null default false,
  whatsapp_enabled boolean not null default false,
  email_enabled boolean not null default false,
  topics jsonb not null default jsonb_build_object(
    'services', true,
    'events', true,
    'messages', true,
    'campaigns', true,
    'birthdays', true,
    'requests', true,
    'contributions', true,
    'urgent', true
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_delivery_attempts (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.internal_notifications(id) on delete cascade,
  channel text not null,
  provider text,
  delivery_status text not null default 'queued',
  attempt_count integer not null default 0,
  last_error text,
  sent_at timestamptz,
  delivered_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_notification_delivery_attempts_notification
  on public.notification_delivery_attempts(notification_id);

create or replace function public.ensure_notification_preferences(
  p_profile_id uuid
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notification_preferences (profile_id)
  values (p_profile_id)
  on conflict (profile_id) do nothing;
$$;

create or replace function public.create_internal_notification(
  p_recipient_profile_id uuid,
  p_title text,
  p_message text,
  p_notification_type text,
  p_church_id uuid default null,
  p_actor_profile_id uuid default null,
  p_priority text default 'normal',
  p_reference_table text default null,
  p_reference_id uuid default null,
  p_action_route text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  notification_id uuid;
  preferences_row public.notification_preferences%rowtype;
begin
  if p_recipient_profile_id is null then
    raise exception 'recipient_profile_id is required.';
  end if;

  perform public.ensure_notification_preferences(p_recipient_profile_id);

  select *
  into preferences_row
  from public.notification_preferences
  where profile_id = p_recipient_profile_id;

  if coalesce(preferences_row.internal_enabled, true) = false
    and p_notification_type not in (
      'security',
      'payment',
      'account',
      'contribution_confirmed',
      'contribution_rejected',
      'subscription_expired'
    ) then
    return null;
  end if;

  insert into public.internal_notifications (
    recipient_profile_id,
    church_id,
    actor_profile_id,
    title,
    message,
    notification_type,
    priority,
    reference_table,
    reference_id,
    action_route,
    delivery_status,
    metadata
  )
  values (
    p_recipient_profile_id,
    p_church_id,
    p_actor_profile_id,
    p_title,
    p_message,
    p_notification_type,
    p_priority,
    p_reference_table,
    p_reference_id,
    p_action_route,
    'delivered',
    coalesce(p_metadata, '{}'::jsonb)
  )
  on conflict (
    recipient_profile_id,
    notification_type,
    reference_table,
    reference_id
  )
  where reference_table is not null
    and reference_id is not null
    and archived_at is null
  do update
  set
    title = excluded.title,
    message = excluded.message,
    delivery_status = excluded.delivery_status,
    metadata = internal_notifications.metadata || excluded.metadata,
    created_at = now()
  returning id into notification_id;

  insert into public.notification_delivery_attempts (
    notification_id,
    channel,
    provider,
    delivery_status,
    attempt_count,
    sent_at,
    delivered_at
  )
  values (
    notification_id,
    'in_app',
    'internal',
    'delivered',
    1,
    now(),
    now()
  )
  on conflict do nothing;

  if coalesce(preferences_row.push_enabled, true) then
    insert into public.notification_delivery_attempts (
      notification_id,
      channel,
      provider,
      delivery_status,
      last_error
    )
    values (
      notification_id,
      'push',
      null,
      'provider_not_configured',
      'Push provider is not configured.'
    );
  end if;

  if coalesce(preferences_row.sms_enabled, false) then
    insert into public.notification_delivery_attempts (
      notification_id,
      channel,
      provider,
      delivery_status,
      last_error
    )
    values (
      notification_id,
      'sms',
      null,
      'provider_not_configured',
      'SMS provider is not configured.'
    );
  end if;

  if coalesce(preferences_row.whatsapp_enabled, false) then
    insert into public.notification_delivery_attempts (
      notification_id,
      channel,
      provider,
      delivery_status,
      last_error
    )
    values (
      notification_id,
      'whatsapp',
      null,
      'provider_not_configured',
      'WhatsApp provider is not configured.'
    );
  end if;

  if coalesce(preferences_row.email_enabled, false) then
    insert into public.notification_delivery_attempts (
      notification_id,
      channel,
      provider,
      delivery_status,
      last_error
    )
    values (
      notification_id,
      'email',
      null,
      'provider_not_configured',
      'Email provider is not configured.'
    );
  end if;

  return notification_id;
end;
$$;

create or replace function public.mark_internal_notification_read(
  p_notification_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.internal_notifications
  set read_at = coalesce(read_at, now())
  where id = p_notification_id
    and recipient_profile_id = auth.uid();

  update public.notification_delivery_attempts
  set
    delivery_status = case
      when channel = 'in_app' then 'read'
      else delivery_status
    end,
    read_at = coalesce(read_at, now()),
    updated_at = now()
  where notification_id = p_notification_id
    and exists (
      select 1
      from public.internal_notifications notification
      where notification.id = p_notification_id
        and notification.recipient_profile_id = auth.uid()
    );
end;
$$;

create or replace function public.mark_all_internal_notifications_read()
returns void
language sql
security definer
set search_path = public
as $$
  update public.internal_notifications
  set read_at = coalesce(read_at, now())
  where recipient_profile_id = auth.uid()
    and read_at is null
    and archived_at is null;
$$;

create or replace function public.archive_internal_notification(
  p_notification_id uuid
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.internal_notifications
  set archived_at = coalesce(archived_at, now())
  where id = p_notification_id
    and recipient_profile_id = auth.uid();
$$;

create or replace function public.notify_church_managers(
  p_church_id uuid,
  p_title text,
  p_message text,
  p_notification_type text,
  p_actor_profile_id uuid default null,
  p_priority text default 'normal',
  p_reference_table text default null,
  p_reference_id uuid default null,
  p_action_route text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  manager_row record;
  created_count integer := 0;
begin
  for manager_row in
    select distinct profile_id
    from public.memberships
    where church_id = p_church_id
      and status = 'active'
      and role in ('pastor', 'church_admin')
  loop
    perform public.create_internal_notification(
      manager_row.profile_id,
      p_title,
      p_message,
      p_notification_type,
      p_church_id,
      p_actor_profile_id,
      p_priority,
      p_reference_table,
      p_reference_id,
      p_action_route,
      p_metadata
    );
    created_count := created_count + 1;
  end loop;

  return created_count;
end;
$$;

grant select, update on public.internal_notifications to authenticated;
grant select, insert, update on public.notification_preferences to authenticated;
grant select on public.notification_delivery_attempts to authenticated;
grant execute on function public.ensure_notification_preferences(uuid) to authenticated;
grant execute on function public.create_internal_notification(uuid, text, text, text, uuid, uuid, text, text, uuid, text, jsonb) to authenticated;
grant execute on function public.mark_internal_notification_read(uuid) to authenticated;
grant execute on function public.mark_all_internal_notifications_read() to authenticated;
grant execute on function public.archive_internal_notification(uuid) to authenticated;
grant execute on function public.notify_church_managers(uuid, text, text, text, uuid, text, text, uuid, text, jsonb) to authenticated;

alter table public.internal_notifications enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notification_delivery_attempts enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'internal_notifications'
      and policyname = 'Users can read own notifications'
  ) then
    create policy "Users can read own notifications"
      on public.internal_notifications
      for select
      to authenticated
      using (recipient_profile_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'internal_notifications'
      and policyname = 'Users can update own notifications'
  ) then
    create policy "Users can update own notifications"
      on public.internal_notifications
      for update
      to authenticated
      using (recipient_profile_id = auth.uid())
      with check (recipient_profile_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'notification_preferences'
      and policyname = 'Users can read own notification preferences'
  ) then
    create policy "Users can read own notification preferences"
      on public.notification_preferences
      for select
      to authenticated
      using (profile_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'notification_preferences'
      and policyname = 'Users can update own notification preferences'
  ) then
    create policy "Users can update own notification preferences"
      on public.notification_preferences
      for update
      to authenticated
      using (profile_id = auth.uid())
      with check (profile_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'notification_delivery_attempts'
      and policyname = 'Users can read own notification delivery attempts'
  ) then
    create policy "Users can read own notification delivery attempts"
      on public.notification_delivery_attempts
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.internal_notifications notification
          where notification.id = notification_delivery_attempts.notification_id
            and notification.recipient_profile_id = auth.uid()
        )
      );
  end if;
end $$;
