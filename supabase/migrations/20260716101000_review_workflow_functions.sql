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

  if normalized_status not in ('approved', 'rejected') then
    raise exception 'Join request status must be approved or rejected.';
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

  update public.church_join_requests
  set
    status = normalized_status,
    reviewed_by = auth.uid(),
    reviewed_at = now(),
    notes = coalesce(nullif(trim(coalesce(p_notes, '')), ''), notes)
  where id = p_request_id
  returning * into request_row;

  if normalized_status = 'approved' then
    insert into public.memberships (church_id, profile_id, role, status)
    values (request_row.church_id, request_row.profile_id, 'member', 'active')
    on conflict (church_id, profile_id) do update
    set status = 'active',
        role = case
          when public.memberships.role in ('pastor', 'church_admin', 'leader') then public.memberships.role
          else 'member'
        end;
  end if;

  perform public.create_internal_notification(
    request_row.profile_id,
    case
      when normalized_status = 'approved' then 'Pedido aprovado'
      else 'Pedido recusado'
    end,
    case
      when normalized_status = 'approved' then 'A tua entrada na igreja foi aprovada.'
      else 'A tua entrada na igreja foi recusada pela lideranca.'
    end,
    'join_request',
    request_row.church_id,
    auth.uid(),
    'normal',
    'church_join_requests',
    request_row.id,
    '/church/join-requests',
    jsonb_build_object('status', normalized_status)
  );

  return request_row;
end;
$$;

create or replace function public.reject_member_donation(
  p_donation_id uuid,
  p_notes text default null
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
    raise exception 'Only church finance admins can reject donations.';
  end if;

  update public.donations
  set
    status = 'rejected',
    notes = coalesce(nullif(trim(coalesce(p_notes, '')), ''), notes),
    confirmed_at = now(),
    confirmed_by = auth.uid()
  where id = p_donation_id
  returning * into donation_row;

  update public.wallet_ledger_entries
  set
    status = 'reversed',
    description = 'Contribuicao rejeitada pela igreja.'
  where reference_table = 'donations'
    and reference_id = p_donation_id
    and status = 'pending';

  update public.member_wallet_ledger_entries
  set
    status = 'reversed',
    description = 'Contribuicao rejeitada pela igreja.'
  where reference_table = 'donations'
    and reference_id = p_donation_id
    and status = 'pending';

  update public.member_wallet_accounts mwa
  set
    pending_balance = greatest(mwa.pending_balance - donation_row.amount, 0),
    updated_at = now()
  where mwa.profile_id = donation_row.profile_id;

  return donation_row;
end;
$$;

grant execute on function public.review_church_join_request(uuid, text, text) to authenticated;
grant execute on function public.reject_member_donation(uuid, text) to authenticated;
