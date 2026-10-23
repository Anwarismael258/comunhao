alter table public.donations
  add column if not exists contribution_type text,
  add column if not exists proof_url text,
  add column if not exists payer_phone text,
  add column if not exists anonymous_name text,
  add column if not exists registered_by uuid references public.profiles(id),
  add column if not exists confirmed_by uuid references public.profiles(id),
  add column if not exists confirmed_at timestamptz,
  add column if not exists rejected_by uuid references public.profiles(id),
  add column if not exists rejected_at timestamptz,
  add column if not exists rejection_reason text,
  add column if not exists internal_notes text,
  add column if not exists requested_new_proof_at timestamptz,
  add column if not exists receipt_number text,
  add column if not exists validation_code text,
  add column if not exists is_demo boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

update public.donations
set
  contribution_type = coalesce(contribution_type, donation_type, 'offering'),
  status = case when status = 'recorded' then 'confirmed' else status end,
  confirmed_at = case when status in ('recorded', 'confirmed') then coalesce(confirmed_at, created_at) else confirmed_at end
where contribution_type is null
   or status = 'recorded'
   or (status = 'confirmed' and confirmed_at is null);

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'donations_donation_type_check'
  ) then
    alter table public.donations
      drop constraint donations_donation_type_check;
  end if;
end $$;

alter table public.donations
  add constraint donations_donation_type_check
  check (
    donation_type in (
      'tithe',
      'offering',
      'campaign',
      'missions',
      'construction',
      'social_support',
      'event',
      'special',
      'other'
    )
  ) not valid;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'donations_status_check'
  ) then
    alter table public.donations
      drop constraint donations_status_check;
  end if;
end $$;

alter table public.donations
  add constraint donations_status_check
  check (
    status in (
      'draft',
      'pending',
      'processing',
      'provider_not_configured',
      'pending_manual_confirmation',
      'confirmed',
      'rejected',
      'cancelled',
      'refunded',
      'failed'
    )
  ) not valid;

create unique index if not exists idx_donations_receipt_number_unique
  on public.donations(receipt_number)
  where receipt_number is not null;

create unique index if not exists idx_donations_provider_reference_unique
  on public.donations(church_id, provider, provider_reference)
  where provider_reference is not null
    and status in ('pending', 'processing', 'confirmed');

create index if not exists idx_donations_church_status_created
  on public.donations(church_id, status, created_at desc);

create index if not exists idx_donations_campaign_status
  on public.donations(campaign_id, status)
  where campaign_id is not null;

alter table public.church_expenses
  add column if not exists vendor_name text,
  add column if not exists payment_method text,
  add column if not exists payment_reference text,
  add column if not exists proof_url text,
  add column if not exists cost_center text,
  add column if not exists ministry_id uuid references public.church_ministries(id),
  add column if not exists campaign_id uuid references public.donation_campaigns(id),
  add column if not exists status text not null default 'paid',
  add column if not exists requested_by uuid references public.profiles(id),
  add column if not exists approved_by uuid references public.profiles(id),
  add column if not exists approved_at timestamptz,
  add column if not exists second_approved_by uuid references public.profiles(id),
  add column if not exists second_approved_at timestamptz,
  add column if not exists paid_by uuid references public.profiles(id),
  add column if not exists paid_at timestamptz,
  add column if not exists rejection_reason text,
  add column if not exists ledger_entry_id uuid references public.wallet_ledger_entries(id),
  add column if not exists is_demo boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'church_expenses_status_check'
  ) then
    alter table public.church_expenses
      drop constraint church_expenses_status_check;
  end if;
end $$;

alter table public.church_expenses
  add constraint church_expenses_status_check
  check (
    status in (
      'draft',
      'pending_approval',
      'approved',
      'paid',
      'rejected',
      'cancelled'
    )
  ) not valid;

create index if not exists idx_church_expenses_status
  on public.church_expenses(church_id, status, spent_at desc);

alter table public.wallet_ledger_entries
  add column if not exists balance_before numeric(12,2),
  add column if not exists balance_after numeric(12,2),
  add column if not exists idempotency_key text,
  add column if not exists is_demo boolean not null default false;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'wallet_ledger_entries_entry_type_check'
  ) then
    alter table public.wallet_ledger_entries
      drop constraint wallet_ledger_entries_entry_type_check;
  end if;
end $$;

alter table public.wallet_ledger_entries
  add constraint wallet_ledger_entries_entry_type_check
  check (
    entry_type in (
      'subscription_payment',
      'other_revenue',
      'tithe',
      'offering',
      'campaign',
      'missions',
      'construction',
      'social_support',
      'event',
      'special',
      'expense',
      'withdrawal',
      'refund',
      'commission',
      'fee',
      'reserved',
      'adjustment'
    )
  ) not valid;

create unique index if not exists idx_wallet_ledger_idempotency_unique
  on public.wallet_ledger_entries(idempotency_key)
  where idempotency_key is not null;

alter table public.wallet_withdrawal_requests
  add column if not exists destination_holder text,
  add column if not exists destination_method_id uuid,
  add column if not exists estimated_fee numeric(12,2) not null default 0,
  add column if not exists net_amount numeric(12,2),
  add column if not exists reason text,
  add column if not exists approved_by uuid references public.profiles(id),
  add column if not exists approved_at timestamptz,
  add column if not exists second_approved_by uuid references public.profiles(id),
  add column if not exists second_approved_at timestamptz,
  add column if not exists provider_reference text,
  add column if not exists failure_reason text,
  add column if not exists idempotency_key text,
  add column if not exists reserved_amount numeric(12,2) not null default 0,
  add column if not exists is_demo boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'wallet_withdrawal_requests_status_check'
  ) then
    alter table public.wallet_withdrawal_requests
      drop constraint wallet_withdrawal_requests_status_check;
  end if;
end $$;

alter table public.wallet_withdrawal_requests
  add constraint wallet_withdrawal_requests_status_check
  check (
    status in (
      'draft',
      'pending',
      'pending_second_approval',
      'approved',
      'processing',
      'paid',
      'completed',
      'rejected',
      'failed',
      'cancelled'
    )
  ) not valid;

create unique index if not exists idx_wallet_withdrawals_idempotency_unique
  on public.wallet_withdrawal_requests(idempotency_key)
  where idempotency_key is not null;

create table if not exists public.church_receiving_methods (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  method text not null,
  label text not null,
  destination text not null,
  holder_name text not null,
  is_verified boolean not null default false,
  is_primary boolean not null default false,
  is_demo boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'church_receiving_methods_method_check'
  ) then
    alter table public.church_receiving_methods
      add constraint church_receiving_methods_method_check
      check (method in ('mpesa', 'emola', 'bank'));
  end if;
end $$;

create unique index if not exists idx_church_receiving_methods_unique
  on public.church_receiving_methods(church_id, method, destination);

create table if not exists public.finance_receipts (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  donation_id uuid not null references public.donations(id) on delete restrict,
  receipt_number text not null unique,
  validation_code text not null unique,
  issued_by uuid references public.profiles(id),
  issued_at timestamptz not null default now(),
  payload jsonb not null default '{}'::jsonb,
  is_demo boolean not null default false
);

create index if not exists idx_finance_receipts_church
  on public.finance_receipts(church_id, issued_at desc);

create table if not exists public.finance_audit_events (
  id uuid primary key default gen_random_uuid(),
  church_id uuid references public.churches(id) on delete cascade,
  actor_profile_id uuid references public.profiles(id),
  action text not null,
  target_table text not null,
  target_id uuid,
  amount numeric(12,2),
  idempotency_key text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_finance_audit_events_church
  on public.finance_audit_events(church_id, created_at desc);

create unique index if not exists idx_finance_audit_idempotency
  on public.finance_audit_events(idempotency_key)
  where idempotency_key is not null;

create or replace function public.user_has_finance_permission(
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
      'finance.view',
      'finance.confirm_contribution',
      'finance.create_expense',
      'finance.approve_expense',
      'finance.request_withdrawal',
      'finance.approve_withdrawal',
      'finance.export',
      'finance.manage_payment_methods',
      'subscription.manage'
    ) then public.has_church_role(
      p_church_id,
      array['pastor', 'church_admin']::text[],
      coalesce(check_user, auth.uid())
    )
    else false
  end;
$$;

create or replace function public.finance_log_event(
  p_church_id uuid,
  p_action text,
  p_target_table text,
  p_target_id uuid default null,
  p_amount numeric default null,
  p_idempotency_key text default null,
  p_details jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  event_id uuid;
begin
  insert into public.finance_audit_events (
    church_id,
    actor_profile_id,
    action,
    target_table,
    target_id,
    amount,
    idempotency_key,
    details
  )
  values (
    p_church_id,
    auth.uid(),
    p_action,
    p_target_table,
    p_target_id,
    p_amount,
    p_idempotency_key,
    coalesce(p_details, '{}'::jsonb)
  )
  on conflict (idempotency_key)
  where idempotency_key is not null
  do update set details = finance_audit_events.details
  returning id into event_id;

  return event_id;
end;
$$;

create or replace function public.finance_wallet_balance(
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
        when direction = 'credit' and status = 'posted' and is_demo = false then amount
        when direction = 'debit' and status = 'posted' and is_demo = false then -amount
        else 0
      end
    ),
    0
  )
  from public.wallet_ledger_entries
  where wallet_account_id = p_wallet_account_id;
$$;

create or replace function public.finance_reserved_balance(
  p_wallet_account_id uuid
)
returns numeric
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(sum(reserved_amount), 0)
  from public.wallet_withdrawal_requests
  where wallet_account_id = p_wallet_account_id
    and status in ('pending', 'pending_second_approval', 'approved', 'processing')
    and is_demo = false;
$$;

create or replace function public.create_church_contribution(
  p_church_id uuid,
  p_contribution_type text,
  p_amount numeric,
  p_method text,
  p_provider text default null,
  p_campaign_id uuid default null,
  p_member_profile_id uuid default null,
  p_payer_phone text default null,
  p_reference text default null,
  p_proof_url text default null,
  p_notes text default null,
  p_confirm_immediately boolean default false,
  p_idempotency_key text default null
)
returns public.donations
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.donations;
  effective_status text := 'pending';
  creator uuid := auth.uid();
begin
  if creator is null then
    raise exception 'Authentication is required.';
  end if;

  if not public.user_has_finance_permission(p_church_id, 'finance.view', creator)
    and not exists (
      select 1
      from public.memberships
      where church_id = p_church_id
        and profile_id = creator
        and status = 'active'
    ) then
    raise exception 'You cannot create contributions for this church.';
  end if;

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Amount must be greater than zero.';
  end if;

  if p_contribution_type not in (
    'tithe',
    'offering',
    'campaign',
    'missions',
    'construction',
    'social_support',
    'event',
    'special',
    'other'
  ) then
    raise exception 'Invalid contribution type: %', p_contribution_type;
  end if;

  if p_contribution_type = 'campaign' and p_campaign_id is null then
    raise exception 'campaign_id is required for campaign contributions.';
  end if;

  if p_confirm_immediately then
    if not public.user_has_finance_permission(p_church_id, 'finance.confirm_contribution', creator) then
      raise exception 'You cannot confirm contributions.';
    end if;
    effective_status := 'confirmed';
  elsif p_method in ('mpesa', 'emola') and nullif(trim(coalesce(p_reference, '')), '') is null then
    effective_status := 'provider_not_configured';
  elsif p_method in ('manual_transfer', 'bank') then
    effective_status := 'pending_manual_confirmation';
  end if;

  insert into public.donations (
    church_id,
    profile_id,
    campaign_id,
    amount,
    currency,
    payment_method,
    provider,
    provider_reference,
    status,
    metadata,
    donation_type,
    contribution_type,
    proof_url,
    payer_phone,
    registered_by,
    confirmed_by,
    confirmed_at,
    internal_notes
  )
  values (
    p_church_id,
    coalesce(p_member_profile_id, creator),
    p_campaign_id,
    p_amount,
    'MZN',
    p_method,
    coalesce(p_provider, p_method),
    nullif(trim(coalesce(p_reference, '')), ''),
    effective_status,
    jsonb_build_object(
      'source', 'professional_finance',
      'idempotency_key', p_idempotency_key
    ),
    p_contribution_type,
    p_contribution_type,
    nullif(trim(coalesce(p_proof_url, '')), ''),
    nullif(trim(coalesce(p_payer_phone, '')), ''),
    creator,
    case when effective_status = 'confirmed' then creator else null end,
    case when effective_status = 'confirmed' then now() else null end,
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning * into result;

  perform public.finance_log_event(
    p_church_id,
    'contribution.created',
    'donations',
    result.id,
    p_amount,
    p_idempotency_key,
    jsonb_build_object('status', effective_status, 'method', p_method)
  );

  if effective_status = 'confirmed' then
    perform public.confirm_church_contribution(result.id, 'Confirmacao imediata autorizada.', p_idempotency_key);
    select * into result from public.donations where id = result.id;
  end if;

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
  result public.donations;
begin
  result := public.create_church_contribution(
    p_church_id,
    p_donation_type,
    p_amount,
    p_provider,
    p_provider,
    p_campaign_id,
    auth.uid(),
    null,
    null,
    null,
    'Criado no app do membro. Aguarda confirmacao manual/provedor.',
    false,
    null
  );

  return result.id;
end;
$$;

create or replace function public.confirm_church_contribution(
  p_donation_id uuid,
  p_internal_note text default null,
  p_idempotency_key text default null
)
returns public.donations
language plpgsql
security definer
set search_path = public
as $$
declare
  donation_row public.donations%rowtype;
  wallet_id uuid;
  balance_before_value numeric;
  balance_after_value numeric;
  ledger_id uuid;
  receipt_no text;
  validation text;
  pastor_id uuid;
begin
  select *
  into donation_row
  from public.donations
  where id = p_donation_id
  for update;

  if not found then
    raise exception 'Contribution not found.';
  end if;

  if not public.user_has_finance_permission(donation_row.church_id, 'finance.confirm_contribution', auth.uid()) then
    raise exception 'You cannot confirm contributions for this church.';
  end if;

  if donation_row.status = 'confirmed' then
    if exists (
      select 1
      from public.wallet_ledger_entries
      where reference_table = 'donations'
        and reference_id = donation_row.id
        and status = 'posted'
    ) then
      raise exception 'Contribution is already confirmed.';
    end if;
  end if;

  if donation_row.status in ('rejected', 'cancelled', 'refunded', 'failed') then
    raise exception 'Cannot confirm a contribution with status %.', donation_row.status;
  end if;

  perform public.ensure_wallet_accounts('church', donation_row.church_id, (
    select name from public.churches where id = donation_row.church_id
  ));

  select id
  into wallet_id
  from public.wallet_accounts
  where owner_type = 'church'
    and church_id = donation_row.church_id
    and provider = case
      when donation_row.provider in ('emola', 'mpesa') then donation_row.provider
      else 'mpesa'
    end
  limit 1;

  balance_before_value := public.finance_wallet_balance(wallet_id);
  balance_after_value := balance_before_value + donation_row.amount;

  select id
  into ledger_id
  from public.wallet_ledger_entries
  where reference_table = 'donations'
    and reference_id = donation_row.id
    and status = 'posted'
  limit 1;

  if ledger_id is null then
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
      posted_at,
      balance_before,
      balance_after,
      idempotency_key,
      is_demo
    )
    values (
      wallet_id,
      donation_row.church_id,
      auth.uid(),
      'credit',
      donation_row.donation_type,
      donation_row.amount,
      donation_row.currency,
      'posted',
      'Contribuicao confirmada',
      'donations',
      donation_row.id,
      jsonb_build_object(
        'provider', donation_row.provider,
        'payment_method', donation_row.payment_method,
        'provider_reference', donation_row.provider_reference
      ),
      now(),
      balance_before_value,
      balance_after_value,
      coalesce(p_idempotency_key, 'donation:' || donation_row.id::text || ':confirm'),
      donation_row.is_demo
    )
    returning id into ledger_id;
  end if;

  receipt_no := coalesce(
    donation_row.receipt_number,
    'RCB-' || to_char(now(), 'YYYYMMDD') || '-' || upper(substr(replace(donation_row.id::text, '-', ''), 1, 8))
  );
  validation := coalesce(
    donation_row.validation_code,
    upper(substr(md5(donation_row.id::text || now()::text), 1, 12))
  );

  update public.donations
  set
    status = 'confirmed',
    confirmed_by = auth.uid(),
    confirmed_at = coalesce(confirmed_at, now()),
    receipt_number = receipt_no,
    validation_code = validation,
    internal_notes = coalesce(nullif(trim(coalesce(p_internal_note, '')), ''), internal_notes),
    updated_at = now()
  where id = donation_row.id
  returning * into donation_row;

  insert into public.finance_receipts (
    church_id,
    donation_id,
    receipt_number,
    validation_code,
    issued_by,
    payload,
    is_demo
  )
  values (
    donation_row.church_id,
    donation_row.id,
    receipt_no,
    validation,
    auth.uid(),
    jsonb_build_object(
      'amount', donation_row.amount,
      'currency', donation_row.currency,
      'type', donation_row.donation_type,
      'method', donation_row.payment_method,
      'reference', donation_row.provider_reference
    ),
    donation_row.is_demo
  )
  on conflict (receipt_number) do nothing;

  perform public.finance_log_event(
    donation_row.church_id,
    'contribution.confirmed',
    'donations',
    donation_row.id,
    donation_row.amount,
    coalesce(p_idempotency_key, 'donation:' || donation_row.id::text || ':confirm'),
    jsonb_build_object('ledger_entry_id', ledger_id, 'receipt_number', receipt_no)
  );

  if donation_row.profile_id is not null then
    perform public.create_internal_notification(
      donation_row.profile_id,
      'Contribuicao confirmada',
      'A sua contribuicao foi confirmada e o recibo foi emitido.',
      'contribution_confirmed',
      donation_row.church_id,
      auth.uid(),
      'normal',
      'donations',
      donation_row.id,
      '/donations',
      jsonb_build_object('receipt_number', receipt_no)
    );
  end if;

  return donation_row;
end;
$$;

create or replace function public.reject_church_contribution(
  p_donation_id uuid,
  p_reason text
)
returns public.donations
language plpgsql
security definer
set search_path = public
as $$
declare
  donation_row public.donations%rowtype;
begin
  if nullif(trim(coalesce(p_reason, '')), '') is null then
    raise exception 'A rejection reason is required.';
  end if;

  select *
  into donation_row
  from public.donations
  where id = p_donation_id
  for update;

  if not found then
    raise exception 'Contribution not found.';
  end if;

  if not public.user_has_finance_permission(donation_row.church_id, 'finance.confirm_contribution', auth.uid()) then
    raise exception 'You cannot reject contributions for this church.';
  end if;

  if donation_row.status = 'confirmed' then
    raise exception 'Confirmed contributions cannot be rejected. Use refund or reversal.';
  end if;

  update public.donations
  set
    status = 'rejected',
    rejected_by = auth.uid(),
    rejected_at = now(),
    rejection_reason = trim(p_reason),
    updated_at = now()
  where id = donation_row.id
  returning * into donation_row;

  perform public.finance_log_event(
    donation_row.church_id,
    'contribution.rejected',
    'donations',
    donation_row.id,
    donation_row.amount,
    null,
    jsonb_build_object('reason', p_reason)
  );

  if donation_row.profile_id is not null then
    perform public.create_internal_notification(
      donation_row.profile_id,
      'Contribuicao rejeitada',
      'A sua contribuicao precisa de correcao: ' || trim(p_reason),
      'contribution_rejected',
      donation_row.church_id,
      auth.uid(),
      'normal',
      'donations',
      donation_row.id,
      '/donations',
      jsonb_build_object('reason', p_reason)
    );
  end if;

  return donation_row;
end;
$$;

create or replace function public.get_church_finance_snapshot(
  p_church_id uuid,
  p_include_demo boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if not public.user_has_finance_permission(p_church_id, 'finance.view', auth.uid()) then
    raise exception 'You cannot view finance for this church.';
  end if;

  with ledger as (
    select *
    from public.wallet_ledger_entries
    where church_id = p_church_id
      and (p_include_demo or is_demo = false)
  ),
  donations_scope as (
    select *
    from public.donations
    where church_id = p_church_id
      and (p_include_demo or is_demo = false)
  ),
  expenses_scope as (
    select *
    from public.church_expenses
    where church_id = p_church_id
      and (p_include_demo or is_demo = false)
  ),
  withdrawals_scope as (
    select *
    from public.wallet_withdrawal_requests
    where church_id = p_church_id
      and (p_include_demo or is_demo = false)
  )
  select jsonb_build_object(
    'available_balance',
    coalesce(sum(case when ledger.direction = 'credit' and ledger.status = 'posted' then ledger.amount when ledger.direction = 'debit' and ledger.status = 'posted' then -ledger.amount else 0 end), 0)
      - coalesce((select sum(reserved_amount) from withdrawals_scope where status in ('pending', 'pending_second_approval', 'approved', 'processing')), 0),
    'pending_balance',
    coalesce((select sum(amount) from donations_scope where status in ('pending', 'processing', 'provider_not_configured', 'pending_manual_confirmation')), 0),
    'received_today',
    coalesce((select sum(amount) from donations_scope where status = 'confirmed' and confirmed_at >= date_trunc('day', now())), 0),
    'month_revenue',
    coalesce((select sum(amount) from donations_scope where status = 'confirmed' and confirmed_at >= date_trunc('month', now())), 0),
    'month_expenses',
    coalesce((select sum(amount) from expenses_scope where status = 'paid' and spent_at >= date_trunc('month', now())), 0),
    'month_net',
    coalesce((select sum(amount) from donations_scope where status = 'confirmed' and confirmed_at >= date_trunc('month', now())), 0)
      - coalesce((select sum(amount) from expenses_scope where status = 'paid' and spent_at >= date_trunc('month', now())), 0),
    'total_withdrawn',
    coalesce((select sum(amount) from withdrawals_scope where status in ('paid', 'completed')), 0),
    'pending_contributions',
    coalesce((select count(*) from donations_scope where status in ('pending', 'processing', 'provider_not_configured', 'pending_manual_confirmation')), 0),
    'pending_withdrawals',
    coalesce((select count(*) from withdrawals_scope where status in ('pending', 'pending_second_approval', 'approved', 'processing')), 0)
  )
  into result
  from ledger;

  return coalesce(result, '{}'::jsonb);
end;
$$;

create or replace function public.post_paid_church_expense_to_ledger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  wallet_id uuid;
  balance_before_value numeric;
  balance_after_value numeric;
  existing_entry_id uuid;
begin
  if new.status <> 'paid' then
    return new;
  end if;

  select id
  into existing_entry_id
  from public.wallet_ledger_entries
  where reference_table = 'church_expenses'
    and reference_id = new.id
    and status = 'posted'
  limit 1;

  if existing_entry_id is not null then
    return new;
  end if;

  perform public.ensure_wallet_accounts('church', new.church_id, (
    select name from public.churches where id = new.church_id
  ));

  select id
  into wallet_id
  from public.wallet_accounts
  where owner_type = 'church'
    and church_id = new.church_id
    and provider = case
      when new.payment_method in ('emola', 'mpesa') then new.payment_method
      else 'mpesa'
    end
  limit 1;

  balance_before_value := public.finance_wallet_balance(wallet_id);
  balance_after_value := balance_before_value - new.amount;

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
    posted_at,
    balance_before,
    balance_after,
    idempotency_key,
    is_demo
  )
  values (
    wallet_id,
    new.church_id,
    coalesce(new.paid_by, new.approved_by, new.created_by, auth.uid()),
    'debit',
    'expense',
    new.amount,
    new.currency,
    'posted',
    new.title,
    'church_expenses',
    new.id,
    jsonb_build_object(
      'category', new.category,
      'payment_method', new.payment_method,
      'payment_reference', new.payment_reference
    ),
    coalesce(new.paid_at, now()),
    balance_before_value,
    balance_after_value,
    'expense:' || new.id::text || ':paid',
    new.is_demo
  );

  perform public.finance_log_event(
    new.church_id,
    'expense.paid',
    'church_expenses',
    new.id,
    new.amount,
    'expense:' || new.id::text || ':paid',
    jsonb_build_object('category', new.category)
  );

  return new;
end;
$$;

drop trigger if exists trg_post_paid_church_expense_to_ledger
  on public.church_expenses;

create trigger trg_post_paid_church_expense_to_ledger
  after insert or update of status
  on public.church_expenses
  for each row
  execute function public.post_paid_church_expense_to_ledger();

create or replace function public.get_church_contributions(
  p_church_id uuid,
  p_limit integer default 100,
  p_status text default null
)
returns table (
  id uuid,
  church_id uuid,
  profile_id uuid,
  member_name text,
  member_phone text,
  campaign_id uuid,
  campaign_title text,
  amount numeric,
  currency text,
  donation_type text,
  payment_method text,
  provider text,
  provider_reference text,
  proof_url text,
  status text,
  confirmed_by uuid,
  confirmed_at timestamptz,
  rejection_reason text,
  receipt_number text,
  validation_code text,
  is_demo boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.user_has_finance_permission(p_church_id, 'finance.view', auth.uid()) then
    raise exception 'You cannot view contributions for this church.';
  end if;

  return query
  select
    donation.id,
    donation.church_id,
    donation.profile_id,
    profile.full_name as member_name,
    profile.phone as member_phone,
    donation.campaign_id,
    campaign.title as campaign_title,
    donation.amount,
    donation.currency,
    donation.donation_type,
    donation.payment_method,
    donation.provider,
    donation.provider_reference,
    donation.proof_url,
    donation.status,
    donation.confirmed_by,
    donation.confirmed_at,
    donation.rejection_reason,
    donation.receipt_number,
    donation.validation_code,
    donation.is_demo,
    donation.created_at
  from public.donations donation
  left join public.profiles profile on profile.id = donation.profile_id
  left join public.donation_campaigns campaign on campaign.id = donation.campaign_id
  where donation.church_id = p_church_id
    and (p_status is null or donation.status = p_status)
  order by donation.created_at desc
  limit greatest(coalesce(p_limit, 100), 1);
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
  receiving_method public.church_receiving_methods%rowtype;
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

  if not public.user_can_access_wallet_scope(p_owner_type, p_church_id, true, auth.uid()) then
    raise exception 'You do not have permission to request a withdrawal for this wallet.';
  end if;

  holder_name := case
    when p_owner_type = 'platform' then 'Comunhao'
    else (select name from public.churches where id = p_church_id limit 1)
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

  if p_owner_type = 'church' then
    select *
    into receiving_method
    from public.church_receiving_methods
    where church_id = p_church_id
      and method = p_provider
      and destination = trim(p_destination_number)
      and is_verified = true
    limit 1;

    if not found then
      raise exception 'Destino de levantamento nao verificado para esta igreja.';
    end if;
  end if;

  available_balance := public.finance_wallet_balance(wallet_id);
  reserved_balance := public.finance_reserved_balance(wallet_id);

  if (available_balance - reserved_balance) < p_amount then
    raise exception 'Insufficient balance. Available to withdraw: %', (available_balance - reserved_balance);
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
    destination_holder,
    destination_method_id,
    estimated_fee,
    net_amount,
    status,
    notes,
    reason,
    reserved_amount
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
    coalesce(receiving_method.holder_name, holder_name),
    receiving_method.id,
    0,
    p_amount,
    'pending',
    p_notes,
    p_notes,
    p_amount
  )
  returning * into result;

  perform public.finance_log_event(
    p_church_id,
    'withdrawal.requested',
    'wallet_withdrawal_requests',
    result.id,
    p_amount,
    null,
    jsonb_build_object('provider', p_provider, 'destination', p_destination_number)
  );

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
  balance_after_value numeric;
  result public.wallet_withdrawal_requests;
begin
  select *
  into request_row
  from public.wallet_withdrawal_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Withdrawal request not found.';
  end if;

  if request_row.owner_type = 'platform' then
    if not public.is_super_admin(auth.uid()) then
      raise exception 'Only super admins can review platform withdrawals.';
    end if;
  elsif not public.user_has_finance_permission(request_row.church_id, 'finance.approve_withdrawal', auth.uid()) then
    raise exception 'You cannot review withdrawals for this church.';
  end if;

  if p_status not in ('approved', 'processing', 'paid', 'completed', 'rejected', 'failed', 'cancelled') then
    raise exception 'Invalid withdrawal status: %', p_status;
  end if;

  if request_row.status in ('paid', 'completed') then
    raise exception 'Withdrawal request is already paid.';
  end if;

  if p_status in ('paid', 'completed') then
    available_balance := public.finance_wallet_balance(request_row.wallet_account_id);
    if available_balance < request_row.amount then
      raise exception 'Insufficient balance to complete the withdrawal.';
    end if;
    balance_after_value := available_balance - request_row.amount;

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
      posted_at,
      balance_before,
      balance_after,
      idempotency_key,
      is_demo
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
      coalesce(p_notes, request_row.notes, 'Levantamento pago.'),
      'wallet_withdrawal_requests',
      request_row.id,
      jsonb_build_object('provider', request_row.provider, 'destination_number', request_row.destination_number),
      now(),
      available_balance,
      balance_after_value,
      coalesce(request_row.idempotency_key, 'withdrawal:' || request_row.id::text || ':paid'),
      request_row.is_demo
    )
    returning id into debit_entry_id;

    update public.wallet_withdrawal_requests
    set
      status = 'paid',
      notes = coalesce(p_notes, notes),
      processed_at = now(),
      processed_by = auth.uid(),
      completed_at = now(),
      ledger_entry_id = debit_entry_id,
      reserved_amount = 0,
      updated_at = now()
    where id = p_request_id
    returning * into result;

    return result;
  end if;

  update public.wallet_withdrawal_requests
  set
    status = p_status,
    notes = coalesce(p_notes, notes),
    processed_at = case when p_status in ('processing', 'failed', 'rejected', 'cancelled') then now() else processed_at end,
    processed_by = auth.uid(),
    approved_by = case when p_status in ('approved', 'processing') then auth.uid() else approved_by end,
    approved_at = case when p_status in ('approved', 'processing') then now() else approved_at end,
    reserved_amount = case when p_status in ('failed', 'rejected', 'cancelled') then 0 else reserved_amount end,
    updated_at = now()
  where id = p_request_id
  returning * into result;

  return result;
end;
$$;

create or replace function public.seed_vida_nova_finance_methods()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  vida_id uuid;
  sara_id uuid;
begin
  select id into vida_id from public.churches where lower(name) = 'vida nova' limit 1;
  select id into sara_id from public.profiles where phone = '877688695' limit 1;

  if vida_id is null then
    return;
  end if;

  insert into public.church_receiving_methods (
    church_id,
    method,
    label,
    destination,
    holder_name,
    is_verified,
    is_primary,
    created_by
  )
  values (
    vida_id,
    'mpesa',
    'M-Pesa Igreja Vida Nova',
    '877688695',
    'Sara',
    true,
    true,
    sara_id
  )
  on conflict (church_id, method, destination) do update
    set holder_name = excluded.holder_name,
        is_verified = true,
        is_primary = true,
        updated_at = now();
end;
$$;

select public.seed_vida_nova_finance_methods();

grant select, insert, update on public.church_receiving_methods to authenticated;
grant select on public.finance_receipts to authenticated;
grant select on public.finance_audit_events to authenticated;
grant execute on function public.user_has_finance_permission(uuid, text, uuid) to authenticated;
grant execute on function public.create_church_contribution(uuid, text, numeric, text, text, uuid, uuid, text, text, text, text, boolean, text) to authenticated;
grant execute on function public.confirm_church_contribution(uuid, text, text) to authenticated;
grant execute on function public.reject_church_contribution(uuid, text) to authenticated;
grant execute on function public.get_church_finance_snapshot(uuid, boolean) to authenticated;
grant execute on function public.get_church_contributions(uuid, integer, text) to authenticated;
grant execute on function public.seed_vida_nova_finance_methods() to authenticated;
grant execute on function public.post_paid_church_expense_to_ledger() to authenticated;

alter table public.church_receiving_methods enable row level security;
alter table public.finance_receipts enable row level security;
alter table public.finance_audit_events enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_receiving_methods'
      and policyname = 'Church finance users can read receiving methods'
  ) then
    create policy "Church finance users can read receiving methods"
      on public.church_receiving_methods
      for select
      to authenticated
      using (public.user_has_finance_permission(church_id, 'finance.view', auth.uid()));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'church_receiving_methods'
      and policyname = 'Church finance users can manage receiving methods'
  ) then
    create policy "Church finance users can manage receiving methods"
      on public.church_receiving_methods
      for all
      to authenticated
      using (public.user_has_finance_permission(church_id, 'finance.manage_payment_methods', auth.uid()))
      with check (public.user_has_finance_permission(church_id, 'finance.manage_payment_methods', auth.uid()));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'finance_receipts'
      and policyname = 'Finance users can read church receipts'
  ) then
    create policy "Finance users can read church receipts"
      on public.finance_receipts
      for select
      to authenticated
      using (
        public.user_has_finance_permission(church_id, 'finance.view', auth.uid())
        or exists (
          select 1
          from public.donations donation
          where donation.id = finance_receipts.donation_id
            and donation.profile_id = auth.uid()
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'finance_audit_events'
      and policyname = 'Finance users can read audit events'
  ) then
    create policy "Finance users can read audit events"
      on public.finance_audit_events
      for select
      to authenticated
      using (public.user_has_finance_permission(church_id, 'finance.view', auth.uid()));
  end if;
end $$;
