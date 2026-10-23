create table if not exists public.wallet_accounts (
  id uuid primary key default gen_random_uuid(),
  owner_type text not null,
  church_id uuid references public.churches(id) on delete cascade,
  holder_name text not null,
  provider text not null,
  currency text not null default 'MZN',
  status text not null default 'active',
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'wallet_accounts_owner_type_check'
  ) then
    alter table public.wallet_accounts
      add constraint wallet_accounts_owner_type_check
      check (owner_type in ('platform', 'church'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'wallet_accounts_provider_check'
  ) then
    alter table public.wallet_accounts
      add constraint wallet_accounts_provider_check
      check (provider in ('mpesa', 'emola'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'wallet_accounts_status_check'
  ) then
    alter table public.wallet_accounts
      add constraint wallet_accounts_status_check
      check (status in ('active', 'inactive'));
  end if;
end $$;

create unique index if not exists idx_wallet_accounts_platform_provider_unique
  on public.wallet_accounts(owner_type, provider)
  where owner_type = 'platform' and church_id is null;

create unique index if not exists idx_wallet_accounts_church_provider_unique
  on public.wallet_accounts(owner_type, church_id, provider)
  where owner_type = 'church' and church_id is not null;

create table if not exists public.wallet_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  wallet_account_id uuid not null references public.wallet_accounts(id) on delete cascade,
  church_id uuid references public.churches(id) on delete cascade,
  created_by uuid references public.profiles(id),
  direction text not null,
  entry_type text not null,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'MZN',
  status text not null default 'posted',
  description text,
  reference_table text,
  reference_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  posted_at timestamptz,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'wallet_ledger_entries_direction_check'
  ) then
    alter table public.wallet_ledger_entries
      add constraint wallet_ledger_entries_direction_check
      check (direction in ('credit', 'debit'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'wallet_ledger_entries_entry_type_check'
  ) then
    alter table public.wallet_ledger_entries
      add constraint wallet_ledger_entries_entry_type_check
      check (
        entry_type in (
          'subscription_payment',
          'other_revenue',
          'tithe',
          'offering',
          'campaign',
          'withdrawal',
          'refund',
          'commission',
          'adjustment'
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'wallet_ledger_entries_status_check'
  ) then
    alter table public.wallet_ledger_entries
      add constraint wallet_ledger_entries_status_check
      check (status in ('pending', 'posted', 'reversed'));
  end if;
end $$;

create index if not exists idx_wallet_ledger_entries_wallet_account_id
  on public.wallet_ledger_entries(wallet_account_id);

create index if not exists idx_wallet_ledger_entries_church_id
  on public.wallet_ledger_entries(church_id);

create index if not exists idx_wallet_ledger_entries_created_at
  on public.wallet_ledger_entries(created_at desc);

create table if not exists public.wallet_withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  wallet_account_id uuid not null references public.wallet_accounts(id) on delete cascade,
  owner_type text not null,
  church_id uuid references public.churches(id) on delete cascade,
  requested_by uuid not null references public.profiles(id) on delete cascade,
  provider text not null,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'MZN',
  destination_number text not null,
  status text not null default 'pending',
  notes text,
  processed_at timestamptz,
  processed_by uuid references public.profiles(id),
  completed_at timestamptz,
  ledger_entry_id uuid references public.wallet_ledger_entries(id),
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'wallet_withdrawal_requests_owner_type_check'
  ) then
    alter table public.wallet_withdrawal_requests
      add constraint wallet_withdrawal_requests_owner_type_check
      check (owner_type in ('platform', 'church'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'wallet_withdrawal_requests_provider_check'
  ) then
    alter table public.wallet_withdrawal_requests
      add constraint wallet_withdrawal_requests_provider_check
      check (provider in ('mpesa', 'emola'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'wallet_withdrawal_requests_status_check'
  ) then
    alter table public.wallet_withdrawal_requests
      add constraint wallet_withdrawal_requests_status_check
      check (status in ('pending', 'processing', 'completed', 'rejected'));
  end if;
end $$;

create index if not exists idx_wallet_withdrawal_requests_wallet_account_id
  on public.wallet_withdrawal_requests(wallet_account_id);

create index if not exists idx_wallet_withdrawal_requests_church_id
  on public.wallet_withdrawal_requests(church_id);

create index if not exists idx_wallet_withdrawal_requests_status
  on public.wallet_withdrawal_requests(status);

alter table public.donations add column if not exists donation_type text not null default 'offering';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'donations_donation_type_check'
  ) then
    alter table public.donations
      add constraint donations_donation_type_check
      check (donation_type in ('tithe', 'offering', 'campaign'));
  end if;
end $$;

create or replace function public.church_subscription_allows_writes(
  p_church_id uuid
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    (
      select status in ('trial', 'active', 'grace_period')
      from public.church_subscriptions
      where church_id = p_church_id
      limit 1
    ),
    true
  );
$$;

create or replace function public.user_can_access_wallet_scope(
  p_owner_type text,
  p_church_id uuid default null,
  p_require_write boolean default false,
  check_user uuid default auth.uid()
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select case
    when p_owner_type = 'platform' then public.is_super_admin(coalesce(check_user, auth.uid()))
    when p_owner_type = 'church' and p_church_id is not null then
      public.has_church_role(
        p_church_id,
        array['pastor', 'church_admin']::text[],
        coalesce(check_user, auth.uid())
      )
      and (not p_require_write or public.church_subscription_allows_writes(p_church_id))
    else false
  end;
$$;

create or replace function public.ensure_wallet_accounts(
  p_owner_type text,
  p_church_id uuid default null,
  p_holder_name text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  effective_holder_name text;
begin
  if p_owner_type not in ('platform', 'church') then
    raise exception 'Invalid wallet owner type: %', p_owner_type;
  end if;

  if p_owner_type = 'church' and p_church_id is null then
    raise exception 'church_id is required for church wallets.';
  end if;

  if p_owner_type = 'platform' then
    effective_holder_name := coalesce(nullif(trim(coalesce(p_holder_name, '')), ''), 'Comunhao');
  else
    effective_holder_name := coalesce(
      nullif(trim(coalesce(p_holder_name, '')), ''),
      (
        select name
        from public.churches
        where id = p_church_id
        limit 1
      ),
      'Igreja'
    );
  end if;

  insert into public.wallet_accounts (
    owner_type,
    church_id,
    holder_name,
    provider,
    currency,
    sort_order
  )
  values
    (p_owner_type, p_church_id, effective_holder_name, 'mpesa', 'MZN', 1),
    (p_owner_type, p_church_id, effective_holder_name, 'emola', 'MZN', 2)
  on conflict do nothing;
end;
$$;

create or replace function public.wallet_account_balance(
  p_wallet_account_id uuid
)
returns numeric
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    sum(
      case
        when direction = 'credit' and status = 'posted' then amount
        when direction = 'debit' and status = 'posted' then -amount
        else 0
      end
    ),
    0
  )
  from public.wallet_ledger_entries
  where wallet_account_id = p_wallet_account_id;
$$;

create or replace function public.wallet_reserved_withdrawal_balance(
  p_wallet_account_id uuid
)
returns numeric
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    sum(amount),
    0
  )
  from public.wallet_withdrawal_requests
  where wallet_account_id = p_wallet_account_id
    and status in ('pending', 'processing');
$$;

create or replace function public.get_wallet_dashboard(
  p_owner_type text,
  p_church_id uuid default null
)
returns table (
  provider text,
  balance numeric,
  total_credits numeric,
  total_debits numeric,
  incoming_today numeric,
  incoming_month numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.user_can_access_wallet_scope(p_owner_type, p_church_id, false, auth.uid()) then
    raise exception 'You do not have access to this wallet.';
  end if;

  return query
  select
    wa.provider,
    coalesce(
      sum(
        case
          when le.direction = 'credit' and le.status = 'posted' then le.amount
          when le.direction = 'debit' and le.status = 'posted' then -le.amount
          else 0
        end
      ),
      0
    ) as balance,
    coalesce(
      sum(
        case
          when le.direction = 'credit' and le.status = 'posted' then le.amount
          else 0
        end
      ),
      0
    ) as total_credits,
    coalesce(
      sum(
        case
          when le.direction = 'debit' and le.status = 'posted' then le.amount
          else 0
        end
      ),
      0
    ) as total_debits,
    coalesce(
      sum(
        case
          when le.direction = 'credit'
            and le.status = 'posted'
            and le.created_at >= date_trunc('day', now())
          then le.amount
          else 0
        end
      ),
      0
    ) as incoming_today,
    coalesce(
      sum(
        case
          when le.direction = 'credit'
            and le.status = 'posted'
            and le.created_at >= date_trunc('month', now())
          then le.amount
          else 0
        end
      ),
      0
    ) as incoming_month
  from public.wallet_accounts wa
  left join public.wallet_ledger_entries le
    on le.wallet_account_id = wa.id
  where wa.owner_type = p_owner_type
    and (
      (p_owner_type = 'platform' and wa.church_id is null)
      or (p_owner_type = 'church' and wa.church_id = p_church_id)
    )
  group by wa.provider, wa.sort_order
  order by wa.sort_order, wa.provider;
end;
$$;

create or replace function public.get_wallet_ledger(
  p_owner_type text,
  p_church_id uuid default null,
  p_limit integer default 50
)
returns table (
  id uuid,
  wallet_account_id uuid,
  provider text,
  direction text,
  entry_type text,
  amount numeric,
  currency text,
  status text,
  description text,
  reference_table text,
  reference_id uuid,
  created_at timestamptz,
  posted_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.user_can_access_wallet_scope(p_owner_type, p_church_id, false, auth.uid()) then
    raise exception 'You do not have access to this wallet.';
  end if;

  return query
  select
    le.id,
    le.wallet_account_id,
    wa.provider,
    le.direction,
    le.entry_type,
    le.amount,
    le.currency,
    le.status,
    le.description,
    le.reference_table,
    le.reference_id,
    le.created_at,
    le.posted_at
  from public.wallet_ledger_entries le
  join public.wallet_accounts wa
    on wa.id = le.wallet_account_id
  where wa.owner_type = p_owner_type
    and (
      (p_owner_type = 'platform' and wa.church_id is null)
      or (p_owner_type = 'church' and wa.church_id = p_church_id)
    )
  order by le.created_at desc
  limit greatest(coalesce(p_limit, 50), 1);
end;
$$;

create or replace function public.record_platform_wallet_revenue(
  p_provider text,
  p_amount numeric,
  p_entry_type text default 'subscription_payment',
  p_description text default null
)
returns public.wallet_ledger_entries
language plpgsql
security definer
set search_path = public
as $$
declare
  wallet_id uuid;
  result public.wallet_ledger_entries;
begin
  if not public.is_super_admin(auth.uid()) then
    raise exception 'Only super admins can record platform revenue.';
  end if;

  if p_provider not in ('mpesa', 'emola') then
    raise exception 'Invalid provider: %', p_provider;
  end if;

  if p_entry_type not in ('subscription_payment', 'other_revenue', 'adjustment') then
    raise exception 'Invalid platform revenue entry type: %', p_entry_type;
  end if;

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Amount must be greater than zero.';
  end if;

  perform public.ensure_wallet_accounts('platform', null, 'Comunhao');

  select id
  into wallet_id
  from public.wallet_accounts
  where owner_type = 'platform'
    and church_id is null
    and provider = p_provider
  limit 1;

  insert into public.wallet_ledger_entries (
    wallet_account_id,
    direction,
    entry_type,
    amount,
    currency,
    status,
    description,
    created_by,
    posted_at
  )
  values (
    wallet_id,
    'credit',
    p_entry_type,
    p_amount,
    'MZN',
    'posted',
    coalesce(p_description, 'Receita registada manualmente pela Comunhao.'),
    auth.uid(),
    now()
  )
  returning *
  into result;

  return result;
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
  donation_id uuid;
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

  select id
  into wallet_id
  from public.wallet_accounts
  where owner_type = 'church'
    and church_id = p_church_id
    and provider = p_provider
  limit 1;

  insert into public.donations (
    church_id,
    profile_id,
    campaign_id,
    amount,
    currency,
    payment_method,
    provider,
    status,
    metadata,
    donation_type
  )
  values (
    p_church_id,
    auth.uid(),
    p_campaign_id,
    p_amount,
    'MZN',
    'wallet',
    p_provider,
    'recorded',
    jsonb_build_object(
      'source', 'member_app',
      'wallet_provider', p_provider
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
    metadata,
    posted_at
  )
  values (
    wallet_id,
    p_church_id,
    auth.uid(),
    'credit',
    p_donation_type,
    p_amount,
    'MZN',
    'posted',
    case
      when p_donation_type = 'tithe' then 'Entrada de dizimo'
      when p_donation_type = 'campaign' then 'Entrada de campanha'
      else 'Entrada de oferta'
    end,
    'donations',
    donation_id,
    jsonb_build_object(
      'provider', p_provider,
      'donation_type', p_donation_type
    ),
    now()
  );

  return donation_id;
end;
$$;

create or replace function public.create_wallet_withdrawal_request(
  p_owner_type text,
  p_provider text,
  p_amount numeric,
  p_destination_number text,
  p_church_id uuid default null,
  p_notes text default null
)
returns public.wallet_withdrawal_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  wallet_id uuid;
  holder_name text;
  available_balance numeric;
  reserved_balance numeric;
  result public.wallet_withdrawal_requests;
begin
  if p_owner_type not in ('platform', 'church') then
    raise exception 'Invalid wallet owner type: %', p_owner_type;
  end if;

  if p_provider not in ('mpesa', 'emola') then
    raise exception 'Invalid wallet provider: %', p_provider;
  end if;

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Amount must be greater than zero.';
  end if;

  if p_destination_number is null or trim(p_destination_number) = '' then
    raise exception 'Destination number is required.';
  end if;

  if not public.user_can_access_wallet_scope(p_owner_type, p_church_id, true, auth.uid()) then
    raise exception 'You do not have permission to request a withdrawal for this wallet.';
  end if;

  holder_name := case
    when p_owner_type = 'platform' then 'Comunhao'
    else (
      select name
      from public.churches
      where id = p_church_id
      limit 1
    )
  end;

  perform public.ensure_wallet_accounts(p_owner_type, p_church_id, holder_name);

  select id
  into wallet_id
  from public.wallet_accounts
  where owner_type = p_owner_type
    and provider = p_provider
    and (
      (p_owner_type = 'platform' and church_id is null)
      or (p_owner_type = 'church' and church_id = p_church_id)
    )
  limit 1;

  available_balance := public.wallet_account_balance(wallet_id);
  reserved_balance := public.wallet_reserved_withdrawal_balance(wallet_id);

  if (available_balance - reserved_balance) < p_amount then
    raise exception
      'Insufficient balance. Available to withdraw: %',
      (available_balance - reserved_balance);
  end if;

  insert into public.wallet_withdrawal_requests (
    wallet_account_id,
    owner_type,
    church_id,
    requested_by,
    provider,
    amount,
    currency,
    destination_number,
    status,
    notes
  )
  values (
    wallet_id,
    p_owner_type,
    p_church_id,
    auth.uid(),
    p_provider,
    p_amount,
    'MZN',
    trim(p_destination_number),
    'pending',
    p_notes
  )
  returning *
  into result;

  return result;
end;
$$;

create or replace function public.review_wallet_withdrawal_request(
  p_request_id uuid,
  p_status text,
  p_notes text default null
)
returns public.wallet_withdrawal_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.wallet_withdrawal_requests%rowtype;
  debit_entry_id uuid;
  available_balance numeric;
  result public.wallet_withdrawal_requests;
begin
  if not public.is_super_admin(auth.uid()) then
    raise exception 'Only super admins can review withdrawal requests.';
  end if;

  if p_status not in ('processing', 'completed', 'rejected') then
    raise exception 'Invalid withdrawal status: %', p_status;
  end if;

  select *
  into request_row
  from public.wallet_withdrawal_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Withdrawal request not found.';
  end if;

  if request_row.status = 'completed' then
    raise exception 'Withdrawal request is already completed.';
  end if;

  if p_status = 'completed' then
    available_balance := public.wallet_account_balance(request_row.wallet_account_id);
    if available_balance < request_row.amount then
      raise exception 'Insufficient balance to complete the withdrawal.';
    end if;

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
      metadata,
      posted_at
    )
    values (
      request_row.wallet_account_id,
      request_row.church_id,
      auth.uid(),
      'debit',
      'withdrawal',
      request_row.amount,
      request_row.currency,
      'posted',
      coalesce(p_notes, request_row.notes, 'Levantamento concluido.'),
      'wallet_withdrawal_requests',
      request_row.id,
      jsonb_build_object(
        'provider', request_row.provider,
        'destination_number', request_row.destination_number
      ),
      now()
    )
    returning id
    into debit_entry_id;

    update public.wallet_withdrawal_requests
    set
      status = 'completed',
      notes = coalesce(p_notes, notes),
      processed_at = now(),
      processed_by = auth.uid(),
      completed_at = now(),
      ledger_entry_id = debit_entry_id
    where id = p_request_id
    returning *
    into result;

    return result;
  end if;

  update public.wallet_withdrawal_requests
  set
    status = p_status,
    notes = coalesce(p_notes, notes),
    processed_at = now(),
    processed_by = auth.uid()
  where id = p_request_id
  returning *
  into result;

  return result;
end;
$$;

create or replace function public.get_wallet_withdrawal_requests(
  p_owner_type text default null,
  p_church_id uuid default null,
  p_limit integer default 50
)
returns table (
  id uuid,
  owner_type text,
  church_id uuid,
  church_name text,
  provider text,
  amount numeric,
  currency text,
  destination_number text,
  status text,
  notes text,
  created_at timestamptz,
  processed_at timestamptz,
  completed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_owner_type = 'platform' then
    if not public.is_super_admin(auth.uid()) then
      raise exception 'You do not have access to the platform withdrawal queue.';
    end if;
  elsif p_owner_type = 'church' then
    if not public.user_can_access_wallet_scope('church', p_church_id, false, auth.uid()) then
      raise exception 'You do not have access to this church withdrawal queue.';
    end if;
  elsif p_owner_type is null then
    if not public.is_super_admin(auth.uid()) then
      raise exception 'Only super admins can view all withdrawal requests.';
    end if;
  else
    raise exception 'Invalid owner_type filter: %', p_owner_type;
  end if;

  return query
  select
    wr.id,
    wr.owner_type,
    wr.church_id,
    c.name as church_name,
    wr.provider,
    wr.amount,
    wr.currency,
    wr.destination_number,
    wr.status,
    wr.notes,
    wr.created_at,
    wr.processed_at,
    wr.completed_at
  from public.wallet_withdrawal_requests wr
  left join public.churches c
    on c.id = wr.church_id
  where (p_owner_type is null or wr.owner_type = p_owner_type)
    and (p_church_id is null or wr.church_id = p_church_id)
  order by wr.created_at desc
  limit greatest(coalesce(p_limit, 50), 1);
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

    perform public.provision_church_trial_subscription(new_church_id, 30);
    perform public.ensure_wallet_accounts('church', new_church_id, application_row.church_name);

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

select public.ensure_wallet_accounts('platform', null, 'Comunhao');

do $$
declare
  church_row record;
begin
  for church_row in
    select id, name
    from public.churches
  loop
    perform public.ensure_wallet_accounts('church', church_row.id, church_row.name);
  end loop;
end $$;

grant select on public.donations to authenticated;
grant execute on function public.get_wallet_dashboard(text, uuid) to authenticated;
grant execute on function public.get_wallet_ledger(text, uuid, integer) to authenticated;
grant execute on function public.get_wallet_withdrawal_requests(text, uuid, integer) to authenticated;
grant execute on function public.record_platform_wallet_revenue(text, numeric, text, text) to authenticated;
grant execute on function public.record_member_donation(uuid, text, numeric, text, uuid) to authenticated;
grant execute on function public.create_wallet_withdrawal_request(text, text, numeric, text, uuid, text) to authenticated;
grant execute on function public.review_wallet_withdrawal_request(uuid, text, text) to authenticated;

alter table public.wallet_accounts enable row level security;
alter table public.wallet_ledger_entries enable row level security;
alter table public.wallet_withdrawal_requests enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'donations'
      and policyname = 'Users can read own donations'
  ) then
    create policy "Users can read own donations"
      on public.donations
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
      and tablename = 'donations'
      and policyname = 'Church admins can read donations in own church'
  ) then
    create policy "Church admins can read donations in own church"
      on public.donations
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
      and tablename = 'wallet_accounts'
      and policyname = 'Wallet viewers can read accounts'
  ) then
    create policy "Wallet viewers can read accounts"
      on public.wallet_accounts
      for select
      to authenticated
      using (
        public.user_can_access_wallet_scope(owner_type, church_id, false, auth.uid())
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'wallet_ledger_entries'
      and policyname = 'Wallet viewers can read ledger entries'
  ) then
    create policy "Wallet viewers can read ledger entries"
      on public.wallet_ledger_entries
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.wallet_accounts wa
          where wa.id = wallet_ledger_entries.wallet_account_id
            and public.user_can_access_wallet_scope(wa.owner_type, wa.church_id, false, auth.uid())
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'wallet_withdrawal_requests'
      and policyname = 'Wallet viewers can read withdrawal requests'
  ) then
    create policy "Wallet viewers can read withdrawal requests"
      on public.wallet_withdrawal_requests
      for select
      to authenticated
      using (
        public.is_super_admin(auth.uid())
        or (
          owner_type = 'church'
          and public.user_can_access_wallet_scope('church', church_id, false, auth.uid())
        )
      );
  end if;
end $$;
