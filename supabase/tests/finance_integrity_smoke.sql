-- Finance and RLS smoke checks for staging.
-- Run only against a staging project after migrations are applied.
-- Replace the variables below before execution.

begin;

-- Required manual inputs for staging:
-- select set_config('request.jwt.claim.sub', '<PASTOR_PROFILE_UUID>', true);
-- select set_config('request.jwt.claim.role', 'authenticated', true);

do $$
declare
  vida_id uuid;
  pastor_id uuid;
  member_id uuid;
  contribution public.donations;
  duplicate_error_seen boolean := false;
  ledger_count integer;
  receipt_count integer;
begin
  select id into vida_id
  from public.churches
  where lower(trim(name)) = 'vida nova'
  limit 1;

  pastor_id := public.profile_id_by_phone('877688695');
  member_id := public.profile_id_by_phone('827688695');

  if vida_id is null then
    raise exception 'Vida Nova not found.';
  end if;
  if pastor_id is null then
    raise exception 'Pastor profile 877688695 not found.';
  end if;
  if member_id is null then
    raise exception 'Member profile 827688695 not found.';
  end if;

  contribution := public.create_church_contribution(
    vida_id,
    'offering',
    10,
    'cash',
    'cash',
    null,
    member_id,
    '827688695',
    'STAGING-SMOKE-001',
    null,
    'Smoke test contribution',
    false,
    'smoke-contribution-001'
  );

  if contribution.status not in ('pending', 'pending_manual_confirmation') then
    raise exception 'Contribution should start pending, got %.', contribution.status;
  end if;

  contribution := public.confirm_church_contribution(
    contribution.id,
    'Smoke confirmation',
    'smoke-contribution-001-confirm'
  );

  select count(*) into ledger_count
  from public.wallet_ledger_entries
  where reference_table = 'donations'
    and reference_id = contribution.id
    and status = 'posted';

  if ledger_count <> 1 then
    raise exception 'Expected exactly 1 ledger entry, got %.', ledger_count;
  end if;

  select count(*) into receipt_count
  from public.finance_receipts
  where donation_id = contribution.id;

  if receipt_count <> 1 then
    raise exception 'Expected exactly 1 receipt, got %.', receipt_count;
  end if;

  begin
    perform public.confirm_church_contribution(
      contribution.id,
      'Duplicate confirmation attempt',
      'smoke-contribution-001-confirm'
    );
  exception
    when others then
      duplicate_error_seen := true;
  end;

  if duplicate_error_seen = false then
    raise exception 'Duplicate confirmation was not blocked.';
  end if;

  begin
    update public.wallet_ledger_entries
    set amount = amount + 1
    where reference_table = 'donations'
      and reference_id = contribution.id
      and status = 'posted';
  exception
    when others then
      duplicate_error_seen := true;
  end;
end $$;

rollback;
