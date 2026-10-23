create or replace function public.canonical_mz_phone(
  p_phone text
)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g') like '258%'
      and length(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')) = 12
      then substring(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g') from 4)
    when length(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')) = 9
      then regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')
    else regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')
  end;
$$;

create or replace function public.profile_id_by_phone(
  p_phone text
)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from public.profiles
  where public.canonical_mz_phone(phone) = public.canonical_mz_phone(p_phone)
  order by created_at
  limit 1;
$$;

create or replace function public.guard_wallet_ledger_immutability()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_OP = 'DELETE' then
    if old.status = 'posted' then
      raise exception 'Posted ledger entries are immutable. Use reversal or compensating entries.';
    end if;
    return old;
  end if;

  if old.status = 'posted' and (
    old.wallet_account_id is distinct from new.wallet_account_id
    or old.church_id is distinct from new.church_id
    or old.direction is distinct from new.direction
    or old.entry_type is distinct from new.entry_type
    or old.amount is distinct from new.amount
    or old.currency is distinct from new.currency
    or old.status is distinct from new.status
    or old.reference_table is distinct from new.reference_table
    or old.reference_id is distinct from new.reference_id
    or old.balance_before is distinct from new.balance_before
    or old.balance_after is distinct from new.balance_after
    or old.idempotency_key is distinct from new.idempotency_key
  ) then
    raise exception 'Posted ledger entries are immutable. Use reversal or compensating entries.';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_wallet_ledger_immutability
  on public.wallet_ledger_entries;

create trigger guard_wallet_ledger_immutability
  before update or delete
  on public.wallet_ledger_entries
  for each row
  execute function public.guard_wallet_ledger_immutability();

create or replace function public.guard_donation_finance_immutability()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_OP = 'DELETE' then
    if old.status = 'confirmed' then
      raise exception 'Confirmed contributions cannot be deleted. Use refund, reversal or adjustment.';
    end if;
    return old;
  end if;

  if new.status = 'confirmed'
    and old.status is distinct from 'confirmed'
    and new.profile_id is not null
    and auth.uid() = new.profile_id then
    raise exception 'Users cannot confirm their own contribution.';
  end if;

  if old.status = 'confirmed' and (
    old.church_id is distinct from new.church_id
    or old.profile_id is distinct from new.profile_id
    or old.campaign_id is distinct from new.campaign_id
    or old.amount is distinct from new.amount
    or old.currency is distinct from new.currency
    or old.payment_method is distinct from new.payment_method
    or old.provider is distinct from new.provider
    or old.provider_reference is distinct from new.provider_reference
    or old.status is distinct from new.status
    or old.donation_type is distinct from new.donation_type
    or old.receipt_number is distinct from new.receipt_number
    or old.validation_code is distinct from new.validation_code
  ) then
    raise exception 'Confirmed contributions are immutable. Use refund, reversal or adjustment.';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_donation_finance_immutability
  on public.donations;

create trigger guard_donation_finance_immutability
  before update or delete
  on public.donations
  for each row
  execute function public.guard_donation_finance_immutability();

create or replace function public.guard_church_expense_immutability()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_OP = 'DELETE' then
    if old.status = 'paid' then
      raise exception 'Paid expenses cannot be deleted. Use a compensating financial entry.';
    end if;
    return old;
  end if;

  if old.status = 'paid' and (
    old.church_id is distinct from new.church_id
    or old.category is distinct from new.category
    or old.title is distinct from new.title
    or old.amount is distinct from new.amount
    or old.currency is distinct from new.currency
    or old.spent_at is distinct from new.spent_at
    or old.payment_method is distinct from new.payment_method
    or old.payment_reference is distinct from new.payment_reference
    or old.status is distinct from new.status
    or old.ledger_entry_id is distinct from new.ledger_entry_id
  ) then
    raise exception 'Paid expenses are immutable. Use a compensating financial entry.';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_church_expense_immutability
  on public.church_expenses;

create trigger guard_church_expense_immutability
  before update or delete
  on public.church_expenses
  for each row
  execute function public.guard_church_expense_immutability();

create or replace function public.guard_withdrawal_approval_safety()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_OP = 'DELETE' then
    if old.status in ('approved', 'processing', 'paid', 'completed') then
      raise exception 'Approved or paid withdrawals cannot be deleted.';
    end if;
    return old;
  end if;

  if new.status in ('approved', 'processing', 'paid', 'completed')
    and new.requested_by = auth.uid()
    and coalesce(new.approved_by, auth.uid()) = auth.uid() then
    raise exception 'Requester cannot approve their own withdrawal.';
  end if;

  if old.status in ('paid', 'completed') and (
    old.amount is distinct from new.amount
    or old.currency is distinct from new.currency
    or old.status is distinct from new.status
    or old.destination_number is distinct from new.destination_number
    or old.ledger_entry_id is distinct from new.ledger_entry_id
  ) then
    raise exception 'Paid withdrawals are immutable. Use compensating entries.';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_withdrawal_approval_safety
  on public.wallet_withdrawal_requests;

create trigger guard_withdrawal_approval_safety
  before update or delete
  on public.wallet_withdrawal_requests
  for each row
  execute function public.guard_withdrawal_approval_safety();

create or replace function public.guard_finance_receipt_immutability()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'Finance receipts are immutable.';
end;
$$;

drop trigger if exists guard_finance_receipt_immutability
  on public.finance_receipts;

create trigger guard_finance_receipt_immutability
  before update or delete
  on public.finance_receipts
  for each row
  execute function public.guard_finance_receipt_immutability();

update storage.buckets
set public = false
where id = 'pastoral-publications';

drop policy if exists "Public can read pastoral publication files"
  on storage.objects;

drop policy if exists "Members can read pastoral publication files by church"
  on storage.objects;

create policy "Members can read pastoral publication files by church"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'pastoral-publications'
    and exists (
      select 1
      from public.memberships m
      where m.profile_id = auth.uid()
        and m.status = 'active'
        and split_part(storage.objects.name, '/', 1) = m.church_id::text
    )
  );

create or replace function public.reconcile_vida_nova_core_access()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  vida_id uuid;
  pastor_id uuid;
  member_id uuid;
  super_admin_id uuid;
begin
  select id
  into vida_id
  from public.churches
  where lower(trim(name)) = 'vida nova'
  order by created_at
  limit 1;

  pastor_id := public.profile_id_by_phone('877688695');
  member_id := public.profile_id_by_phone('827688695');
  super_admin_id := public.profile_id_by_phone('841130015');

  if vida_id is not null and pastor_id is not null then
    insert into public.memberships (
      church_id,
      profile_id,
      role,
      status
    )
    values (
      vida_id,
      pastor_id,
      'pastor',
      'active'
    )
    on conflict (church_id, profile_id) do update
      set role = 'pastor',
          status = 'active';
  end if;

  if vida_id is not null and member_id is not null then
    insert into public.memberships (
      church_id,
      profile_id,
      role,
      status
    )
    values (
      vida_id,
      member_id,
      'member',
      'active'
    )
    on conflict (church_id, profile_id) do update
      set role = case
            when public.memberships.role in ('pastor', 'church_admin', 'leader') then public.memberships.role
            else 'member'
          end,
          status = 'active';
  end if;

  if super_admin_id is not null then
    insert into public.platform_roles (
      profile_id,
      role,
      status
    )
    values (
      super_admin_id,
      'super_admin',
      'active'
    )
    on conflict (profile_id, role) do update
      set status = 'active';
  end if;

  return jsonb_build_object(
    'vida_nova_found', vida_id is not null,
    'pastor_found', pastor_id is not null,
    'member_found', member_id is not null,
    'super_admin_found', super_admin_id is not null
  );
end;
$$;

select public.reconcile_vida_nova_core_access();

revoke execute on function public.post_paid_church_expense_to_ledger()
  from anon, authenticated, public;

revoke execute on function public.guard_wallet_ledger_immutability()
  from anon, authenticated, public;

revoke execute on function public.guard_donation_finance_immutability()
  from anon, authenticated, public;

revoke execute on function public.guard_church_expense_immutability()
  from anon, authenticated, public;

revoke execute on function public.guard_withdrawal_approval_safety()
  from anon, authenticated, public;

revoke execute on function public.guard_finance_receipt_immutability()
  from anon, authenticated, public;

grant execute on function public.canonical_mz_phone(text) to authenticated;

revoke execute on function public.profile_id_by_phone(text)
  from anon, authenticated, public;

revoke execute on function public.reconcile_vida_nova_core_access()
  from anon, authenticated, public;
