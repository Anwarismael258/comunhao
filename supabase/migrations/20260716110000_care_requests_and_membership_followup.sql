alter table public.memberships
  add column if not exists entry_date date,
  add column if not exists approved_at timestamptz,
  add column if not exists ministry_id uuid references public.church_ministries(id) on delete set null,
  add column if not exists followup_responsible_membership_id uuid references public.memberships(id) on delete set null,
  add column if not exists last_activity_at timestamptz,
  add column if not exists status_reason text,
  add column if not exists neighborhood text,
  add column if not exists gender text;

alter table public.memberships
  drop constraint if exists memberships_status_check;

alter table public.memberships
  add constraint memberships_status_check
  check (status in (
    'visitor',
    'in_follow_up',
    'candidate',
    'active',
    'inactive',
    'blocked',
    'suspended',
    'removed',
    'transferred',
    'deceased',
    'archived'
  ));

alter table public.church_join_requests
  add column if not exists full_name text,
  add column if not exists phone text,
  add column if not exists birth_date date,
  add column if not exists gender text,
  add column if not exists neighborhood text,
  add column if not exists previous_church text,
  add column if not exists reason text,
  add column if not exists ministry_interest text,
  add column if not exists observation text,
  add column if not exists consent_data_processing boolean not null default false,
  add column if not exists assigned_membership_id uuid references public.memberships(id) on delete set null,
  add column if not exists internal_notes text,
  add column if not exists information_requested text,
  add column if not exists member_response text,
  add column if not exists decision_reason text,
  add column if not exists is_demo boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

alter table public.pastoral_requests
  add column if not exists subject text,
  add column if not exists privacy_level text not null default 'pastor_only',
  add column if not exists preferred_contact text,
  add column if not exists contact_availability text,
  add column if not exists attachment_url text,
  add column if not exists consent_forwarding boolean not null default false,
  add column if not exists assigned_by uuid references public.profiles(id) on delete set null,
  add column if not exists assigned_at timestamptz,
  add column if not exists first_opened_at timestamptz,
  add column if not exists resolved_at timestamptz,
  add column if not exists closed_at timestamptz,
  add column if not exists is_demo boolean not null default false;

create table if not exists public.administrative_requests (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete set null,
  request_type text not null default 'other',
  subject text not null,
  description text not null,
  attachment_url text,
  status text not null default 'new',
  assigned_membership_id uuid references public.memberships(id) on delete set null,
  due_at timestamptz,
  response text,
  internal_notes text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.church_request_timeline (
  id uuid primary key default gen_random_uuid(),
  church_id uuid references public.churches(id) on delete cascade,
  request_table text not null,
  request_id uuid not null,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  action text not null,
  public_message text,
  internal_note text,
  previous_state jsonb,
  new_state jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.pastoral_request_extraordinary_access (
  id uuid primary key default gen_random_uuid(),
  pastoral_request_id uuid not null references public.pastoral_requests(id) on delete cascade,
  admin_profile_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_church_join_requests_church_status
  on public.church_join_requests(church_id, status, created_at desc);

create index if not exists idx_pastoral_requests_church_status
  on public.pastoral_requests(church_id, status, urgency, created_at desc);

create index if not exists idx_administrative_requests_church_status
  on public.administrative_requests(church_id, status, created_at desc);

create index if not exists idx_church_request_timeline_request
  on public.church_request_timeline(request_table, request_id, created_at);

drop trigger if exists touch_church_join_requests_updated_at on public.church_join_requests;
create trigger touch_church_join_requests_updated_at
  before update on public.church_join_requests
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_administrative_requests_updated_at on public.administrative_requests;
create trigger touch_administrative_requests_updated_at
  before update on public.administrative_requests
  for each row execute function public.touch_updated_at();

create or replace function public.create_church_join_request(
  p_church_id uuid,
  p_full_name text,
  p_phone text,
  p_birth_date date default null,
  p_gender text default null,
  p_neighborhood text default null,
  p_previous_church text default null,
  p_reason text default null,
  p_ministry_interest text default null,
  p_observation text default null,
  p_consent_data_processing boolean default false
)
returns public.church_join_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.church_join_requests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if p_consent_data_processing is not true then
    raise exception 'Consent is required.';
  end if;

  perform public.ensure_member_wallet(auth.uid(), p_phone);

  insert into public.church_join_requests (
    church_id,
    profile_id,
    full_name,
    phone,
    birth_date,
    gender,
    neighborhood,
    previous_church,
    reason,
    ministry_interest,
    observation,
    consent_data_processing,
    message,
    status
  )
  values (
    p_church_id,
    auth.uid(),
    trim(p_full_name),
    trim(p_phone),
    p_birth_date,
    nullif(trim(coalesce(p_gender, '')), ''),
    nullif(trim(coalesce(p_neighborhood, '')), ''),
    nullif(trim(coalesce(p_previous_church, '')), ''),
    nullif(trim(coalesce(p_reason, '')), ''),
    nullif(trim(coalesce(p_ministry_interest, '')), ''),
    nullif(trim(coalesce(p_observation, '')), ''),
    p_consent_data_processing,
    nullif(trim(coalesce(p_reason, '')), ''),
    'pending'
  )
  on conflict (church_id, profile_id) do update
  set
    full_name = excluded.full_name,
    phone = excluded.phone,
    birth_date = excluded.birth_date,
    gender = excluded.gender,
    neighborhood = excluded.neighborhood,
    previous_church = excluded.previous_church,
    reason = excluded.reason,
    ministry_interest = excluded.ministry_interest,
    observation = excluded.observation,
    consent_data_processing = excluded.consent_data_processing,
    status = case
      when public.church_join_requests.status in ('approved', 'under_review', 'more_information_required') then public.church_join_requests.status
      else 'pending'
    end,
    member_response = null,
    updated_at = now()
  where public.church_join_requests.status not in ('approved')
  returning * into request_row;

  if request_row.id is null then
    select * into request_row
    from public.church_join_requests
    where church_id = p_church_id
      and profile_id = auth.uid();
  end if;

  insert into public.church_request_timeline (
    church_id,
    request_table,
    request_id,
    actor_profile_id,
    action,
    public_message
  )
  values (
    p_church_id,
    'church_join_requests',
    request_row.id,
    auth.uid(),
    'created_or_updated',
    'Pedido de entrada enviado.'
  );

  return request_row;
end;
$$;

create or replace function public.respond_church_join_request(
  p_request_id uuid,
  p_member_response text
)
returns public.church_join_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.church_join_requests%rowtype;
begin
  update public.church_join_requests
  set
    member_response = trim(coalesce(p_member_response, '')),
    status = case
      when status = 'more_information_required' then 'under_review'
      else status
    end
  where id = p_request_id
    and profile_id = auth.uid()
    and status in ('pending', 'under_review', 'more_information_required')
  returning * into request_row;

  if request_row.id is null then
    raise exception 'Join request not available.';
  end if;

  insert into public.church_request_timeline (
    church_id,
    request_table,
    request_id,
    actor_profile_id,
    action,
    public_message
  )
  values (
    request_row.church_id,
    'church_join_requests',
    request_row.id,
    auth.uid(),
    'member_response',
    'O membro enviou informacoes adicionais.'
  );

  return request_row;
end;
$$;

create or replace function public.cancel_church_join_request(
  p_request_id uuid
)
returns public.church_join_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.church_join_requests%rowtype;
begin
  update public.church_join_requests
  set status = 'cancelled'
  where id = p_request_id
    and profile_id = auth.uid()
    and status in ('pending', 'under_review', 'more_information_required')
  returning * into request_row;

  if request_row.id is null then
    raise exception 'Join request not available.';
  end if;

  insert into public.church_request_timeline (
    church_id,
    request_table,
    request_id,
    actor_profile_id,
    action,
    public_message
  )
  values (
    request_row.church_id,
    'church_join_requests',
    request_row.id,
    auth.uid(),
    'cancelled',
    'Pedido cancelado pelo utilizador.'
  );

  return request_row;
end;
$$;

create or replace function public.review_church_join_request(
  p_request_id uuid,
  p_status text,
  p_notes text default null
)
returns public.church_join_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.church_join_requests%rowtype;
  normalized_status text;
begin
  normalized_status := lower(trim(coalesce(p_status, '')));

  if normalized_status not in ('under_review', 'more_information_required', 'approved', 'rejected') then
    raise exception 'Invalid join request status.';
  end if;

  select *
  into request_row
  from public.church_join_requests
  where id = p_request_id
  for update;

  if request_row.id is null then
    raise exception 'Join request not found.';
  end if;

  if not public.has_church_role(
    request_row.church_id,
    array['pastor', 'church_admin', 'leader']::text[],
    auth.uid()
  ) then
    raise exception 'Only church leaders can review join requests.';
  end if;

  if normalized_status = 'approved' then
    insert into public.memberships (
      church_id,
      profile_id,
      role,
      status,
      approved_at,
      entry_date,
      neighborhood,
      gender
    )
    values (
      request_row.church_id,
      request_row.profile_id,
      'member',
      'active',
      now(),
      current_date,
      request_row.neighborhood,
      request_row.gender
    )
    on conflict (church_id, profile_id) do update
    set
      status = 'active',
      approved_at = coalesce(public.memberships.approved_at, now()),
      entry_date = coalesce(public.memberships.entry_date, current_date),
      neighborhood = coalesce(excluded.neighborhood, public.memberships.neighborhood),
      gender = coalesce(excluded.gender, public.memberships.gender),
      role = case
        when public.memberships.role in ('pastor', 'church_admin', 'leader') then public.memberships.role
        else 'member'
      end;
  end if;

  update public.church_join_requests
  set
    status = normalized_status,
    reviewed_by = auth.uid(),
    reviewed_at = case when normalized_status in ('approved', 'rejected') then now() else reviewed_at end,
    review_notes = case when normalized_status in ('approved', 'rejected') then p_notes else review_notes end,
    information_requested = case when normalized_status = 'more_information_required' then p_notes else information_requested end,
    decision_reason = case when normalized_status = 'rejected' then p_notes else decision_reason end
  where id = p_request_id
  returning * into request_row;

  insert into public.church_request_timeline (
    church_id,
    request_table,
    request_id,
    actor_profile_id,
    action,
    public_message,
    internal_note
  )
  values (
    request_row.church_id,
    'church_join_requests',
    request_row.id,
    auth.uid(),
    normalized_status,
    case
      when normalized_status = 'approved' then 'Pedido aprovado.'
      when normalized_status = 'rejected' then 'Pedido rejeitado.'
      when normalized_status = 'more_information_required' then 'A igreja solicitou mais informacoes.'
      else 'Pedido em analise.'
    end,
    p_notes
  );

  perform public.create_internal_notification(
    request_row.profile_id,
    case
      when normalized_status = 'approved' then 'Pedido aprovado'
      when normalized_status = 'rejected' then 'Pedido rejeitado'
      when normalized_status = 'more_information_required' then 'Mais informacoes solicitadas'
      else 'Pedido em analise'
    end,
    case
      when normalized_status = 'approved' then 'A tua entrada na igreja foi aprovada.'
      when normalized_status = 'rejected' then 'A tua entrada na igreja foi rejeitada.'
      when normalized_status = 'more_information_required' then 'A igreja pediu mais informacoes para continuar a analise.'
      else 'A lideranca iniciou a analise do teu pedido.'
    end,
    'join_request',
    request_row.church_id,
    auth.uid(),
    'normal',
    'church_join_requests',
    request_row.id,
    '/requests/join/' || request_row.id::text,
    jsonb_build_object('status', normalized_status)
  );

  return request_row;
end;
$$;

create or replace function public.create_pastoral_request(
  p_church_id uuid,
  p_category text,
  p_title text,
  p_message text,
  p_urgency text default 'normal',
  p_privacy_level text default 'pastor_only',
  p_preferred_contact text default null,
  p_contact_availability text default null,
  p_attachment_url text default null,
  p_consent_forwarding boolean default false
)
returns public.pastoral_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.pastoral_requests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  insert into public.pastoral_requests (
    church_id,
    profile_id,
    request_area,
    category,
    title,
    subject,
    message,
    urgency,
    confidentiality,
    privacy_level,
    preferred_contact,
    contact_availability,
    attachment_url,
    consent_forwarding,
    hide_body_in_notifications,
    status
  )
  values (
    p_church_id,
    auth.uid(),
    'pastoral',
    p_category,
    trim(p_title),
    trim(p_title),
    trim(p_message),
    p_urgency,
    p_privacy_level,
    p_privacy_level,
    nullif(trim(coalesce(p_preferred_contact, '')), ''),
    nullif(trim(coalesce(p_contact_availability, '')), ''),
    nullif(trim(coalesce(p_attachment_url, '')), ''),
    p_consent_forwarding,
    true,
    'new'
  )
  returning * into request_row;

  insert into public.church_request_timeline (
    church_id,
    request_table,
    request_id,
    actor_profile_id,
    action,
    public_message
  )
  values (
    request_row.church_id,
    'pastoral_requests',
    request_row.id,
    auth.uid(),
    'created',
    'Pedido pastoral criado.'
  );

  return request_row;
end;
$$;

create or replace function public.update_pastoral_request_status(
  p_request_id uuid,
  p_status text,
  p_public_response text default null,
  p_internal_note text default null,
  p_assigned_membership_id uuid default null
)
returns public.pastoral_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.pastoral_requests%rowtype;
begin
  select *
  into request_row
  from public.pastoral_requests
  where id = p_request_id
  for update;

  if request_row.id is null then
    raise exception 'Pastoral request not found.';
  end if;

  if not public.has_church_role(
    request_row.church_id,
    array['pastor', 'church_admin', 'leader']::text[],
    auth.uid()
  ) then
    raise exception 'Not authorized.';
  end if;

  update public.pastoral_requests
  set
    status = p_status,
    assigned_membership_id = coalesce(p_assigned_membership_id, assigned_membership_id),
    assigned_by = case when p_assigned_membership_id is not null then auth.uid() else assigned_by end,
    assigned_at = case when p_assigned_membership_id is not null then now() else assigned_at end,
    resolved_at = case when p_status = 'resolved' then now() else resolved_at end,
    closed_at = case when p_status in ('closed', 'cancelled') then now() else closed_at end
  where id = p_request_id
  returning * into request_row;

  if nullif(trim(coalesce(p_public_response, '')), '') is not null then
    insert into public.pastoral_request_responses (
      pastoral_request_id,
      responder_profile_id,
      body,
      internal_only
    )
    values (request_row.id, auth.uid(), trim(p_public_response), false);
  end if;

  if nullif(trim(coalesce(p_internal_note, '')), '') is not null then
    insert into public.pastoral_request_responses (
      pastoral_request_id,
      responder_profile_id,
      body,
      internal_only
    )
    values (request_row.id, auth.uid(), trim(p_internal_note), true);
  end if;

  insert into public.church_request_timeline (
    church_id,
    request_table,
    request_id,
    actor_profile_id,
    action,
    public_message,
    internal_note
  )
  values (
    request_row.church_id,
    'pastoral_requests',
    request_row.id,
    auth.uid(),
    p_status,
    p_public_response,
    p_internal_note
  );

  if p_assigned_membership_id is not null then
    perform public.create_internal_notification(
      (select profile_id from public.memberships where id = p_assigned_membership_id),
      'Pedido pastoral atribuido',
      'Existe um pedido pastoral que requer acompanhamento.',
      'pastoral_request_assigned',
      request_row.church_id,
      auth.uid(),
      request_row.urgency,
      'pastoral_requests',
      request_row.id,
      '/requests/pastoral/' || request_row.id::text,
      jsonb_build_object('status', p_status)
    );
  end if;

  return request_row;
end;
$$;

create or replace function public.record_pastoral_request_open(
  p_request_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.pastoral_requests%rowtype;
begin
  select * into request_row
  from public.pastoral_requests
  where id = p_request_id;

  if request_row.id is null then
    raise exception 'Pastoral request not found.';
  end if;

  if not (
    request_row.profile_id = auth.uid()
    or public.has_church_role(
      request_row.church_id,
      array['pastor', 'church_admin', 'leader']::text[],
      auth.uid()
    )
  ) then
    raise exception 'Not authorized.';
  end if;

  insert into public.pastoral_request_access_logs (
    pastoral_request_id,
    profile_id,
    action
  )
  values (p_request_id, auth.uid(), 'opened');

  update public.pastoral_requests
  set first_opened_at = coalesce(first_opened_at, now())
  where id = p_request_id;
end;
$$;

create or replace function public.create_administrative_request(
  p_church_id uuid,
  p_request_type text,
  p_subject text,
  p_description text,
  p_attachment_url text default null
)
returns public.administrative_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.administrative_requests%rowtype;
begin
  insert into public.administrative_requests (
    church_id,
    profile_id,
    request_type,
    subject,
    description,
    attachment_url,
    status
  )
  values (
    p_church_id,
    auth.uid(),
    p_request_type,
    trim(p_subject),
    trim(p_description),
    nullif(trim(coalesce(p_attachment_url, '')), ''),
    'new'
  )
  returning * into request_row;

  insert into public.church_request_timeline (
    church_id,
    request_table,
    request_id,
    actor_profile_id,
    action,
    public_message
  )
  values (
    request_row.church_id,
    'administrative_requests',
    request_row.id,
    auth.uid(),
    'created',
    'Pedido administrativo criado.'
  );

  return request_row;
end;
$$;

create or replace function public.review_administrative_request(
  p_request_id uuid,
  p_status text,
  p_response text default null,
  p_internal_note text default null,
  p_assigned_membership_id uuid default null
)
returns public.administrative_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.administrative_requests%rowtype;
begin
  select * into request_row
  from public.administrative_requests
  where id = p_request_id
  for update;

  if request_row.id is null then
    raise exception 'Administrative request not found.';
  end if;

  if not public.has_church_role(
    request_row.church_id,
    array['pastor', 'church_admin', 'leader']::text[],
    auth.uid()
  ) then
    raise exception 'Not authorized.';
  end if;

  update public.administrative_requests
  set
    status = p_status,
    response = coalesce(nullif(trim(coalesce(p_response, '')), ''), response),
    internal_notes = coalesce(nullif(trim(coalesce(p_internal_note, '')), ''), internal_notes),
    assigned_membership_id = coalesce(p_assigned_membership_id, assigned_membership_id)
  where id = p_request_id
  returning * into request_row;

  insert into public.church_request_timeline (
    church_id,
    request_table,
    request_id,
    actor_profile_id,
    action,
    public_message,
    internal_note
  )
  values (
    request_row.church_id,
    'administrative_requests',
    request_row.id,
    auth.uid(),
    p_status,
    p_response,
    p_internal_note
  );

  return request_row;
end;
$$;

alter table public.administrative_requests enable row level security;
alter table public.church_request_timeline enable row level security;
alter table public.pastoral_request_extraordinary_access enable row level security;

drop policy if exists "Users and church admins can read administrative requests" on public.administrative_requests;
create policy "Users and church admins can read administrative requests"
  on public.administrative_requests
  for select
  to authenticated
  using (
    profile_id = auth.uid()
    or public.has_church_role(church_id, array['pastor', 'church_admin', 'leader']::text[])
    or public.is_super_admin()
  );

drop policy if exists "Users can create own administrative requests" on public.administrative_requests;
create policy "Users can create own administrative requests"
  on public.administrative_requests
  for insert
  to authenticated
  with check (profile_id = auth.uid());

drop policy if exists "Church admins can update administrative requests" on public.administrative_requests;
create policy "Church admins can update administrative requests"
  on public.administrative_requests
  for update
  to authenticated
  using (public.has_church_role(church_id, array['pastor', 'church_admin', 'leader']::text[]))
  with check (public.has_church_role(church_id, array['pastor', 'church_admin', 'leader']::text[]));

drop policy if exists "Users can read public request timeline" on public.church_request_timeline;
create policy "Users can read public request timeline"
  on public.church_request_timeline
  for select
  to authenticated
  using (
    internal_note is null
    or public.is_super_admin()
    or exists (
      select 1 from public.church_join_requests r
      where request_table = 'church_join_requests'
        and r.id = request_id
        and (r.profile_id = auth.uid() or public.has_church_role(r.church_id, array['pastor', 'church_admin', 'leader']::text[]))
    )
    or exists (
      select 1 from public.pastoral_requests r
      where request_table = 'pastoral_requests'
        and r.id = request_id
        and public.has_church_role(r.church_id, array['pastor', 'church_admin', 'leader']::text[])
    )
    or exists (
      select 1 from public.administrative_requests r
      where request_table = 'administrative_requests'
        and r.id = request_id
        and (r.profile_id = auth.uid() or public.has_church_role(r.church_id, array['pastor', 'church_admin', 'leader']::text[]))
    )
  );

drop policy if exists "Super admins can read extraordinary access" on public.pastoral_request_extraordinary_access;
create policy "Super admins can read extraordinary access"
  on public.pastoral_request_extraordinary_access
  for select
  to authenticated
  using (public.is_super_admin());

grant select, insert, update on public.administrative_requests to authenticated;
grant select, insert on public.church_request_timeline to authenticated;
grant select, insert on public.pastoral_request_extraordinary_access to authenticated;

grant execute on function public.create_church_join_request(uuid, text, text, date, text, text, text, text, text, text, boolean) to authenticated;
grant execute on function public.respond_church_join_request(uuid, text) to authenticated;
grant execute on function public.cancel_church_join_request(uuid) to authenticated;
grant execute on function public.create_pastoral_request(uuid, text, text, text, text, text, text, text, text, boolean) to authenticated;
grant execute on function public.update_pastoral_request_status(uuid, text, text, text, uuid) to authenticated;
grant execute on function public.record_pastoral_request_open(uuid) to authenticated;
grant execute on function public.create_administrative_request(uuid, text, text, text, text) to authenticated;
grant execute on function public.review_administrative_request(uuid, text, text, text, uuid) to authenticated;
