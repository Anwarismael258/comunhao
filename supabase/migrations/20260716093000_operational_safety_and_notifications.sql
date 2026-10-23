alter table public.church_settings
  add column if not exists demo_mode boolean not null default false,
  add column if not exists demo_seeded_at timestamptz,
  add column if not exists demo_cleared_at timestamptz;

alter table public.announcements
  add column if not exists is_demo boolean not null default false,
  add column if not exists category text not null default 'comunicado',
  add column if not exists image_url text,
  add column if not exists attachment_url text,
  add column if not exists audience_type text not null default 'all',
  add column if not exists notify_members boolean not null default false,
  add column if not exists publication_status text not null default 'published';

alter table public.events
  add column if not exists is_demo boolean not null default false,
  add column if not exists image_url text,
  add column if not exists city text,
  add column if not exists responsible_profile_id uuid references public.profiles(id),
  add column if not exists guest_speaker text,
  add column if not exists notify_members boolean not null default false,
  add column if not exists event_status text not null default 'published';

alter table public.donation_campaigns
  add column if not exists is_demo boolean not null default false,
  add column if not exists image_url text,
  add column if not exists campaign_status text not null default 'active';

alter table public.donations
  add column if not exists receipt_number text,
  add column if not exists notes text,
  add column if not exists anonymous_donation boolean not null default false,
  add column if not exists public_donation boolean not null default false,
  add column if not exists confirmed_at timestamptz,
  add column if not exists confirmed_by uuid references public.profiles(id);

create unique index if not exists idx_donations_receipt_number_unique
  on public.donations(receipt_number)
  where receipt_number is not null;

alter table public.church_communications
  add column if not exists hide_body_in_notifications boolean not null default false,
  add column if not exists require_read_confirmation boolean not null default false,
  add column if not exists is_demo boolean not null default false;

create table if not exists public.member_wallet_accounts (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  phone text,
  currency text not null default 'MZN',
  available_balance numeric(12,2) not null default 0,
  pending_balance numeric(12,2) not null default 0,
  total_received numeric(12,2) not null default 0,
  total_contributed numeric(12,2) not null default 0,
  total_withdrawn numeric(12,2) not null default 0,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id)
);

create table if not exists public.member_wallet_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  wallet_account_id uuid not null references public.member_wallet_accounts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  church_id uuid references public.churches(id) on delete set null,
  direction text not null,
  entry_type text not null,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'MZN',
  status text not null default 'pending',
  description text,
  reference_table text,
  reference_id uuid,
  created_at timestamptz not null default now(),
  posted_at timestamptz
);

create table if not exists public.church_join_requests (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  requested_role text not null default 'member',
  message text,
  status text not null default 'pending',
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  review_notes text,
  created_at timestamptz not null default now(),
  unique (church_id, profile_id)
);

create table if not exists public.pastoral_requests (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete set null,
  request_area text not null default 'pastoral',
  category text not null,
  title text not null,
  message text not null,
  urgency text not null default 'normal',
  confidentiality text not null default 'pastor_only',
  hide_body_in_notifications boolean not null default true,
  assigned_membership_id uuid references public.memberships(id) on delete set null,
  status text not null default 'new',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pastoral_request_responses (
  id uuid primary key default gen_random_uuid(),
  pastoral_request_id uuid not null references public.pastoral_requests(id) on delete cascade,
  responder_profile_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  internal_only boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.pastoral_request_access_logs (
  id uuid primary key default gen_random_uuid(),
  pastoral_request_id uuid not null references public.pastoral_requests(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  action text not null default 'opened',
  created_at timestamptz not null default now()
);

create table if not exists public.communication_delivery_logs (
  id uuid primary key default gen_random_uuid(),
  communication_id uuid references public.church_communications(id) on delete cascade,
  announcement_id uuid references public.announcements(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  channel text not null default 'in_app',
  delivery_status text not null default 'queued',
  read_at timestamptz,
  saved_at timestamptz,
  shared_at timestamptz,
  created_at timestamptz not null default now(),
  unique (communication_id, announcement_id, profile_id, channel)
);

create table if not exists public.financial_approval_requests (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  withdrawal_request_id uuid references public.wallet_withdrawal_requests(id) on delete cascade,
  requested_by uuid references public.profiles(id) on delete set null,
  approved_by uuid references public.profiles(id) on delete set null,
  approval_role text,
  amount numeric(12,2) not null default 0,
  reason text,
  proof_url text,
  status text not null default 'pending',
  requested_at timestamptz not null default now(),
  approved_at timestamptz,
  cancelled_at timestamptz
);

create or replace function public.ensure_member_wallet(
  p_profile_id uuid,
  p_phone text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  wallet_id uuid;
begin
  insert into public.member_wallet_accounts (profile_id, phone)
  values (p_profile_id, p_phone)
  on conflict (profile_id) do update
  set
    phone = coalesce(excluded.phone, public.member_wallet_accounts.phone),
    updated_at = now()
  returning id into wallet_id;

  return wallet_id;
end;
$$;

create or replace function public.handle_profile_wallet()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.ensure_member_wallet(new.id, new.phone);
  return new;
end;
$$;

drop trigger if exists handle_profile_wallet on public.profiles;
create trigger handle_profile_wallet
  after insert or update of phone on public.profiles
  for each row
  execute function public.handle_profile_wallet();

select public.ensure_member_wallet(id, phone)
from public.profiles;

update public.church_settings settings
set require_member_approval = true
from public.churches church
where church.id = settings.church_id
  and church.slug = 'vida-nova';

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  metadata_church_id uuid;
  metadata_birth_date date;
  metadata_phone text;
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

  metadata_phone := nullif(
    coalesce(new.phone, new.raw_user_meta_data ->> 'phone', ''),
    ''
  );

  insert into public.profiles (
    id,
    full_name,
    phone,
    birth_date
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', 'Membro'),
    metadata_phone,
    metadata_birth_date
  )
  on conflict (id) do update
    set
      full_name = excluded.full_name,
      phone = coalesce(excluded.phone, public.profiles.phone),
      birth_date = coalesce(excluded.birth_date, public.profiles.birth_date);

  perform public.ensure_member_wallet(new.id, metadata_phone);

  if metadata_church_id is not null then
    insert into public.church_join_requests (
      church_id,
      profile_id,
      requested_role,
      message,
      status
    )
    values (
      metadata_church_id,
      new.id,
      'member',
      'Pedido criado automaticamente apos cadastro por telefone.',
      'pending'
    )
    on conflict (church_id, profile_id) do update
      set
        status = case
          when public.church_join_requests.status in ('rejected', 'cancelled') then 'pending'
          else public.church_join_requests.status
        end,
        message = excluded.message;
  end if;

  return new;
end;
$$;

create or replace function public.clear_church_demo_data(
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
  deleted_campaigns integer := 0;
  deleted_communications integer := 0;
begin
  if not public.has_church_role(
    p_church_id,
    array['pastor', 'church_admin']::text[],
    auth.uid()
  ) then
    raise exception 'Only church admins can clear demo data.';
  end if;

  delete from public.announcements
  where church_id = p_church_id
    and is_demo = true;
  get diagnostics deleted_announcements = row_count;

  delete from public.events
  where church_id = p_church_id
    and is_demo = true;
  get diagnostics deleted_events = row_count;

  delete from public.donation_campaigns
  where church_id = p_church_id
    and is_demo = true;
  get diagnostics deleted_campaigns = row_count;

  delete from public.church_communications
  where church_id = p_church_id
    and is_demo = true;
  get diagnostics deleted_communications = row_count;

  update public.church_settings
  set
    demo_mode = false,
    demo_cleared_at = now()
  where church_id = p_church_id;

  return jsonb_build_object(
    'announcements_deleted', deleted_announcements,
    'events_deleted', deleted_events,
    'campaigns_deleted', deleted_campaigns,
    'communications_deleted', deleted_communications
  );
end;
$$;

create or replace function public.record_member_donation(
  p_church_id uuid,
  p_donation_type text,
  p_amount numeric,
  p_provider text,
  p_campaign_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  wallet_id uuid;
  member_wallet_id uuid;
  donation_id uuid;
  receipt_code text;
  church_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  if p_donation_type not in ('tithe', 'offering', 'campaign') then
    raise exception 'Invalid donation type: %', p_donation_type;
  end if;

  if p_provider not in ('mpesa', 'emola') then
    raise exception 'Invalid payment provider: %', p_provider;
  end if;

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Amount must be greater than zero.';
  end if;

  if not exists (
    select 1
    from public.memberships
    where church_id = p_church_id
      and profile_id = auth.uid()
      and status = 'active'
  ) then
    raise exception 'Only active members of the church can register donations.';
  end if;

  if not public.church_subscription_allows_writes(p_church_id) then
    raise exception 'The church subscription is read-only right now.';
  end if;

  if p_donation_type = 'campaign' and p_campaign_id is null then
    raise exception 'campaign_id is required for campaign donations.';
  end if;

  if p_campaign_id is not null and not exists (
    select 1
    from public.donation_campaigns
    where id = p_campaign_id
      and church_id = p_church_id
      and active = true
  ) then
    raise exception 'Campaign not found for this church.';
  end if;

  select name
  into church_name
  from public.churches
  where id = p_church_id
  limit 1;

  perform public.ensure_wallet_accounts('church', p_church_id, church_name);
  member_wallet_id := public.ensure_member_wallet(
    auth.uid(),
    (select phone from public.profiles where id = auth.uid())
  );

  select id
  into wallet_id
  from public.wallet_accounts
  where owner_type = 'church'
    and church_id = p_church_id
    and provider = p_provider
  limit 1;

  receipt_code := 'RCB-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));

  insert into public.donations (
    church_id,
    profile_id,
    campaign_id,
    amount,
    currency,
    payment_method,
    provider,
    status,
    receipt_number,
    metadata,
    donation_type
  )
  values (
    p_church_id,
    auth.uid(),
    p_campaign_id,
    p_amount,
    'MZN',
    'manual_mobile_money',
    p_provider,
    'pending',
    receipt_code,
    jsonb_build_object(
      'source', 'member_app',
      'wallet_provider', p_provider,
      'requires_confirmation', true
    ),
    p_donation_type
  )
  returning id
  into donation_id;

  insert into public.wallet_ledger_entries (
    wallet_account_id,
    church_id,
    created_by,
    direction,
    entry_type,
    amount,
    currency,
    status,
    description,
    reference_table,
    reference_id,
    metadata
  )
  values (
    wallet_id,
    p_church_id,
    auth.uid(),
    'credit',
    p_donation_type,
    p_amount,
    'MZN',
    'pending',
    case
      when p_donation_type = 'tithe' then 'Dizimo aguardando confirmacao'
      when p_donation_type = 'campaign' then 'Campanha aguardando confirmacao'
      else 'Oferta aguardando confirmacao'
    end,
    'donations',
    donation_id,
    jsonb_build_object(
      'provider', p_provider,
      'donation_type', p_donation_type,
      'receipt_number', receipt_code
    )
  );

  insert into public.member_wallet_ledger_entries (
    wallet_account_id,
    profile_id,
    church_id,
    direction,
    entry_type,
    amount,
    currency,
    status,
    description,
    reference_table,
    reference_id
  )
  values (
    member_wallet_id,
    auth.uid(),
    p_church_id,
    'debit',
    p_donation_type,
    p_amount,
    'MZN',
    'pending',
    'Contribuicao aguardando confirmacao financeira.',
    'donations',
    donation_id
  );

  update public.member_wallet_accounts
  set
    pending_balance = pending_balance + p_amount,
    updated_at = now()
  where id = member_wallet_id;

  return donation_id;
end;
$$;

create or replace function public.confirm_member_donation(
  p_donation_id uuid,
  p_provider_reference text default null
)
returns public.donations
language plpgsql
security definer
set search_path = public
as $$
declare
  donation_row public.donations%rowtype;
begin
  select *
  into donation_row
  from public.donations
  where id = p_donation_id
  for update;

  if donation_row.id is null then
    raise exception 'Donation not found.';
  end if;

  if not public.has_church_role(
    donation_row.church_id,
    array['pastor', 'church_admin']::text[],
    auth.uid()
  ) then
    raise exception 'Only church finance admins can confirm donations.';
  end if;

  update public.donations
  set
    status = 'confirmed',
    provider_reference = coalesce(nullif(trim(coalesce(p_provider_reference, '')), ''), provider_reference),
    confirmed_at = now(),
    confirmed_by = auth.uid()
  where id = p_donation_id
  returning * into donation_row;

  update public.wallet_ledger_entries
  set
    status = 'posted',
    posted_at = now(),
    description = replace(coalesce(description, 'Contribuicao'), 'aguardando confirmacao', 'confirmada')
  where reference_table = 'donations'
    and reference_id = p_donation_id
    and status = 'pending';

  update public.member_wallet_ledger_entries
  set
    status = 'posted',
    posted_at = now(),
    description = 'Contribuicao confirmada.'
  where reference_table = 'donations'
    and reference_id = p_donation_id
    and status = 'pending';

  update public.member_wallet_accounts mwa
  set
    pending_balance = greatest(mwa.pending_balance - donation_row.amount, 0),
    total_contributed = mwa.total_contributed + donation_row.amount,
    updated_at = now()
  where mwa.profile_id = donation_row.profile_id;

  return donation_row;
end;
$$;

grant select, insert, update on public.member_wallet_accounts to authenticated;
grant select, insert on public.member_wallet_ledger_entries to authenticated;
grant select, insert, update on public.church_join_requests to authenticated;
grant select, insert, update on public.pastoral_requests to authenticated;
grant select, insert on public.pastoral_request_responses to authenticated;
grant select, insert on public.pastoral_request_access_logs to authenticated;
grant select, insert, update on public.communication_delivery_logs to authenticated;
grant select, insert, update on public.financial_approval_requests to authenticated;
grant execute on function public.ensure_member_wallet(uuid, text) to authenticated;
grant execute on function public.clear_church_demo_data(uuid) to authenticated;
grant execute on function public.confirm_member_donation(uuid, text) to authenticated;

create or replace function public.get_active_campaigns_with_progress(
  p_church_id uuid
)
returns table (
  id uuid,
  title text,
  description text,
  target_amount numeric,
  start_at timestamptz,
  end_at timestamptz,
  active boolean,
  raised_amount numeric,
  contributor_count integer
)
language sql
security definer
stable
set search_path = public
as $$
  select
    campaign.id,
    campaign.title,
    campaign.description,
    campaign.target_amount,
    campaign.start_at,
    campaign.end_at,
    campaign.active,
    coalesce(
      sum(donation.amount) filter (
        where donation.status in ('confirmed', 'recorded')
      ),
      0
    ) as raised_amount,
    count(distinct donation.profile_id) filter (
      where donation.status in ('confirmed', 'recorded')
    )::integer as contributor_count
  from public.donation_campaigns campaign
  left join public.donations donation
    on donation.campaign_id = campaign.id
  where campaign.church_id = p_church_id
    and campaign.active = true
  group by campaign.id
  order by campaign.created_at desc
  limit 20;
$$;

grant execute on function public.get_active_campaigns_with_progress(uuid) to anon, authenticated;

alter table public.member_wallet_accounts enable row level security;
alter table public.member_wallet_ledger_entries enable row level security;
alter table public.church_join_requests enable row level security;
alter table public.pastoral_requests enable row level security;
alter table public.pastoral_request_responses enable row level security;
alter table public.pastoral_request_access_logs enable row level security;
alter table public.communication_delivery_logs enable row level security;
alter table public.financial_approval_requests enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'member_wallet_accounts'
      and policyname = 'Users can read own member wallet'
  ) then
    create policy "Users can read own member wallet"
      on public.member_wallet_accounts
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
      and tablename = 'pastoral_request_responses'
      and policyname = 'Authorized users can read pastoral responses'
  ) then
    create policy "Authorized users can read pastoral responses"
      on public.pastoral_request_responses
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.pastoral_requests pr
          where pr.id = pastoral_request_responses.pastoral_request_id
            and (
              pr.profile_id = auth.uid()
              or public.has_church_role(
                pr.church_id,
                case
                  when pr.confidentiality = 'pastor_only'
                    then array['pastor']::text[]
                  else array['pastor', 'church_admin', 'leader']::text[]
                end,
                auth.uid()
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
      and tablename = 'pastoral_request_responses'
      and policyname = 'Authorized leaders can respond to pastoral requests'
  ) then
    create policy "Authorized leaders can respond to pastoral requests"
      on public.pastoral_request_responses
      for insert
      to authenticated
      with check (
        responder_profile_id = auth.uid()
        and exists (
          select 1
          from public.pastoral_requests pr
          where pr.id = pastoral_request_responses.pastoral_request_id
            and public.has_church_role(
              pr.church_id,
              array['pastor', 'church_admin', 'leader']::text[],
              auth.uid()
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
      and tablename = 'pastoral_request_access_logs'
      and policyname = 'Authorized access logs can be created'
  ) then
    create policy "Authorized access logs can be created"
      on public.pastoral_request_access_logs
      for insert
      to authenticated
      with check (
        profile_id = auth.uid()
        and exists (
          select 1
          from public.pastoral_requests pr
          where pr.id = pastoral_request_access_logs.pastoral_request_id
            and (
              pr.profile_id = auth.uid()
              or public.has_church_role(
                pr.church_id,
                case
                  when pr.confidentiality = 'pastor_only'
                    then array['pastor']::text[]
                  else array['pastor', 'church_admin', 'leader']::text[]
                end,
                auth.uid()
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
      and tablename = 'pastoral_request_access_logs'
      and policyname = 'Pastors can read pastoral access logs'
  ) then
    create policy "Pastors can read pastoral access logs"
      on public.pastoral_request_access_logs
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.pastoral_requests pr
          where pr.id = pastoral_request_access_logs.pastoral_request_id
            and public.has_church_role(
              pr.church_id,
              array['pastor', 'church_admin']::text[],
              auth.uid()
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
      and tablename = 'member_wallet_ledger_entries'
      and policyname = 'Users can read own member wallet ledger'
  ) then
    create policy "Users can read own member wallet ledger"
      on public.member_wallet_ledger_entries
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
      and tablename = 'church_join_requests'
      and policyname = 'Users can create own church join requests'
  ) then
    create policy "Users can create own church join requests"
      on public.church_join_requests
      for insert
      to authenticated
      with check (profile_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_join_requests'
      and policyname = 'Users and church admins can read join requests'
  ) then
    create policy "Users and church admins can read join requests"
      on public.church_join_requests
      for select
      to authenticated
      using (
        profile_id = auth.uid()
        or public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[],
          auth.uid()
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_join_requests'
      and policyname = 'Church admins can review join requests'
  ) then
    create policy "Church admins can review join requests"
      on public.church_join_requests
      for update
      to authenticated
      using (
        public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[],
          auth.uid()
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'pastoral_requests'
      and policyname = 'Users can create own pastoral requests'
  ) then
    create policy "Users can create own pastoral requests"
      on public.pastoral_requests
      for insert
      to authenticated
      with check (profile_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'pastoral_requests'
      and policyname = 'Pastoral requests visible to owner and authorized leaders'
  ) then
    create policy "Pastoral requests visible to owner and authorized leaders"
      on public.pastoral_requests
      for select
      to authenticated
      using (
        profile_id = auth.uid()
        or public.has_church_role(
          church_id,
          case
            when confidentiality = 'pastor_only'
              then array['pastor']::text[]
            else array['pastor', 'church_admin', 'leader']::text[]
          end,
          auth.uid()
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'pastoral_requests'
      and policyname = 'Pastors can update pastoral requests'
  ) then
    create policy "Pastors can update pastoral requests"
      on public.pastoral_requests
      for update
      to authenticated
      using (
        public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[],
          auth.uid()
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'communication_delivery_logs'
      and policyname = 'Users can read own communication delivery logs'
  ) then
    create policy "Users can read own communication delivery logs"
      on public.communication_delivery_logs
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
      and tablename = 'communication_delivery_logs'
      and policyname = 'Users can update own read state'
  ) then
    create policy "Users can update own read state"
      on public.communication_delivery_logs
      for update
      to authenticated
      using (profile_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'financial_approval_requests'
      and policyname = 'Church admins can manage financial approvals'
  ) then
    create policy "Church admins can manage financial approvals"
      on public.financial_approval_requests
      for all
      to authenticated
      using (
        public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[],
          auth.uid()
        )
      )
      with check (
        public.has_church_role(
          church_id,
          array['pastor', 'church_admin']::text[],
          auth.uid()
        )
      );
  end if;
end $$;
