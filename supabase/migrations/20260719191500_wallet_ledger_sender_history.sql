drop function if exists public.get_wallet_ledger(text, uuid, integer);

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
  posted_at timestamptz,
  sender_name text,
  sender_phone text
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
    le.posted_at,
    case
      when le.direction = 'credit' then nullif(trim(coalesce(
        donor.full_name,
        donation.anonymous_name,
        le.metadata ->> 'sender_name',
        le.metadata ->> 'member_name',
        actor.full_name
      )), '')
      else nullif(trim(coalesce(actor.full_name, le.metadata ->> 'actor_name')), '')
    end as sender_name,
    case
      when le.direction = 'credit' then nullif(trim(coalesce(
        donation.payer_phone,
        donor.phone,
        le.metadata ->> 'sender_phone',
        le.metadata ->> 'member_phone',
        actor.phone
      )), '')
      else nullif(trim(coalesce(actor.phone, le.metadata ->> 'actor_phone')), '')
    end as sender_phone
  from public.wallet_ledger_entries le
  join public.wallet_accounts wa
    on wa.id = le.wallet_account_id
  left join public.donations donation
    on le.reference_table = 'donations'
   and donation.id = le.reference_id
  left join public.profiles donor
    on donor.id = donation.profile_id
  left join public.profiles actor
    on actor.id = le.created_by
  where wa.owner_type = p_owner_type
    and (
      (p_owner_type = 'platform' and wa.church_id is null)
      or (p_owner_type = 'church' and wa.church_id = p_church_id)
    )
  order by le.created_at desc
  limit greatest(coalesce(p_limit, 50), 1);
end;
$$;

grant execute on function public.get_wallet_ledger(text, uuid, integer) to authenticated;
